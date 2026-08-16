#!/usr/bin/env python3
"""mapedit.render — 瓦片/全图渲染管线 + 进程池并行解码。"""
from __future__ import annotations
import io
import math
import os
import threading
from concurrent.futures import ProcessPoolExecutor

from PIL import Image

from wilsdk import WilLibrary
from zlsdk import ZlLibrary

from mapedit.constants import (KR_ORDER, LAYOUT_ISO, LAYOUT_RECT, OFFSET_ALL,
                               OFFSET_MIDFRONT, OFFSET_MODES, OFFSET_NONE,
                               TILE_SZ)
from mapedit.frames import FramePool, _find_library_path
from mapedit.geom import cell_anchor, world_bounds
from mapedit.mapio import MapCache

# ------------------------------------------------------------------ parallel full-map decode

# Process-pool worker state: per-worker library cache + the data dir the
# worker was initialised with.  ZL BC1 decode is pure-Python (~2.7ms/frame),
# so full-map renders of big maps (00.map z3 needs ~23k unique frames)
# parallelise decode across cores; compositing stays single-process in
# painter order.
#
# [E6 P0-1] 死锁教训：fork 自多线程服务进程会继承 fork 瞬间的解释器 import 锁
# 快照——若此刻有线程正在 lazy import（PIL 插件 preinit 是重灾区），子进程里
# 该锁永远无人释放，worker 首次解码 PIL Image.open 时死等（审计 py-spy 实证
# importlib._lock_unlock_module 栈）。对策三条（缺一不可）：
#   1) initializer 里显式预载 PIL 插件并解码一帧（warm_worker）；
#   2) 服务启动期、一切后台线程起来之前 prewarm_pools() 把两个池的全部
#      worker 预 fork 出来——此后请求线程 submit 不再触发 os.fork；
#   3) 交互瓦片 submit 加超时，超时 503，绝无限等待。
_POOL_WORKERS = min(4, os.cpu_count() or 2)   # 快/慢池统一规模（2-4 档）
_TILE_SUBMIT_TIMEOUT = 20.0                    # 单瓦片交互渲染预算（秒）

_POOL: dict[str, ProcessPoolExecutor] = {}        # 慢池: 后台预渲染 (worker nice 5)
_FAST_POOL: dict[str, ProcessPoolExecutor] = {}   # 快池: 交互冷块现场渲染 (nice 0)
_POOL_MU = threading.Lock()
_WORKER_DATA_DIR: str | None = None
_WORKER_LIBS: dict[str, WilLibrary | ZlLibrary] = {}
_WORKER_MC: "MapCache | None" = None      # tile worker (快/慢池同构) 的地图 LRU
_WORKER_POOL: "FramePool | None" = None


def warm_worker(data_dir: str):
    """Worker 预热：fork 后立刻完成所有 lazy import 并解码/编码一帧。

    PIL 的 PNG/JPEG 插件、zlsdk 的解码路径全部走一遍，worker 此后不再
    触碰 import 机制（import 锁死锁的根除手段）。任何失败只忽略——
    预热失败顶多退化回旧行为，不能拖死 worker 启动。"""
    try:
        import io as _io
        from PIL import Image
        import PIL.PngImagePlugin   # 解码 (ZL2 PNG 载荷) + 编码 (z0 tile)
        import PIL.JpegImagePlugin  # 编码 (z>=1 tile)
        lib_name = KR_ORDER.get(0) or "tilesc"
        path = _find_library_path(data_dir, lib_name)
        if path:
            lib = (ZlLibrary(path) if path.lower().endswith(".zl")
                   else WilLibrary(path))
            im = lib.decode(0)
            if im is not None:
                buf = _io.BytesIO()
                im.save(buf, format="PNG")
                im.resize((max(1, im.width // 2), max(1, im.height // 2)),
                          Image.NEAREST).save(buf, format="JPEG")
    except Exception:
        pass


def _init_worker(data_dir: str):
    global _WORKER_DATA_DIR
    _WORKER_DATA_DIR = data_dir
    try:
        os.nice(5)   # 后台批量渲染让位交互请求/游戏服务器
    except OSError:
        pass
    warm_worker(data_dir)


def _init_fast_worker(data_dir: str):
    global _WORKER_DATA_DIR
    _WORKER_DATA_DIR = data_dir   # 交互现场渲染, 不降优先级
    warm_worker(data_dir)


def _decode_frame_worker(args: tuple) -> tuple | None:
    """Decode (lib_id, frame, scale) in a pool worker -> sprite payload.

    Returns (lib_id, frame, w, h, offsetX, offsetY, PNG bytes) or None (invalid /
    empty frame).  Each worker opens each library once and keeps it for the
    process lifetime (mmap shares the OS page cache with the parent)."""
    lib_id, frame, scale = args
    lib_name = KR_ORDER.get(lib_id)
    if not lib_name:
        return None
    lib = _WORKER_LIBS.get(lib_name)
    if lib is None:
        path = _find_library_path(_WORKER_DATA_DIR, lib_name)
        if path is None:
            return None
        lib = (ZlLibrary(path) if path.lower().endswith(".zl") else WilLibrary(path))
        _WORKER_LIBS[lib_name] = lib
    try:
        hdr = lib.header(frame)
        if hdr is None or hdr["width"] <= 0 or hdr["height"] <= 0:
            return None
        if scale > 1 and hasattr(lib, "decode_scaled"):
            im = lib.decode_scaled(frame, scale)
        else:
            im = lib.decode(frame)
            if im is not None and scale > 1:
                im = im.resize((max(1, im.width // scale),
                                max(1, im.height // scale)), Image.NEAREST)
        if im is None:
            return None
        return (lib_id, frame, im.width, im.height, hdr["offsetX"], hdr["offsetY"],
                im.tobytes())
    except Exception:
        return None


def _get_pool(data_dir: str) -> ProcessPoolExecutor:
    """慢池 (预渲染): nice(5), 让位同机游戏服务器。"""
    with _POOL_MU:
        pool = _POOL.get(data_dir)
        if pool is None:
            pool = _POOL[data_dir] = ProcessPoolExecutor(
                max_workers=_POOL_WORKERS,
                initializer=_init_worker, initargs=(data_dir,))
        return pool


def _get_fast_pool(data_dir: str) -> ProcessPoolExecutor:
    """快池 (交互冷块): nice(0), 用户正在等, 不让路。"""
    with _POOL_MU:
        pool = _FAST_POOL.get(data_dir)
        if pool is None:
            pool = _FAST_POOL[data_dir] = ProcessPoolExecutor(
                max_workers=_POOL_WORKERS,
                initializer=_init_fast_worker, initargs=(data_dir,))
        return pool


def _warm_noop() -> None:
    return None


def prewarm_pools(data_dir: str, timeout: float = 30.0) -> int:
    """启动期一次性预建快/慢池，并把全部 worker fork + 预热到位。

    必须在服务端口就绪前、任何后台线程（prewarm/api-maps-warm）启动前
    调用：此刻主进程只有单线程，fork 出的子进程继承干净的锁状态。
    返回预热成功的 worker 数。失败不抛——池坏了后续 submit 自会暴露。"""
    ok = 0
    for get in (_get_pool, _get_fast_pool):
        try:
            pool = get(data_dir)
            futs = [pool.submit(_warm_noop) for _ in range(_POOL_WORKERS)]
            for f in futs:
                try:
                    f.result(timeout=timeout)
                    ok += 1
                except Exception:
                    pass
        except Exception:
            pass
    return ok

def _render_tile_worker(args: tuple) -> tuple | None:
    """Render one whole tile in a pool worker -> (key, png_bytes) | None.

    每个 worker 持有自己的 MapCache/FramePool（地图 LRU + 帧字节预算），
    完整复用 render_tile 的解码与合成逻辑；主进程只收字节落盘，不被
    CPU 密集的渲染阻塞（HTTP 响应由主进程承担）。"""
    map_path, key = args
    map_name, tx, ty, z, layout, om = key
    global _WORKER_MC, _WORKER_POOL
    try:
        if _WORKER_MC is None or _WORKER_MC.maps_dir != os.path.dirname(map_path):
            _WORKER_MC = MapCache(os.path.dirname(map_path))
            _WORKER_POOL = FramePool(_WORKER_DATA_DIR)
        data = render_tile(_WORKER_MC, _WORKER_POOL, map_name, tx, ty, z,
                           True, True, True, layout=layout, offset_mode=om)
        return (key, data) if data else None
    except Exception:
        return None


def tile_cache_path(cache_dir: str, layout: str, map_name: str,
                    tx: int, ty: int, z: int, g: bool, m: bool, f: bool,
                    om: str) -> str:
    """Disk path for one rendered tile (handler 与预渲染共用)."""
    safe = map_name.replace("/", "_").replace("\\", "_")
    ext = "png" if z == 0 else "jpg"
    tag = "r" if layout == LAYOUT_RECT else "i"
    omt = "n" if om == OFFSET_NONE else ("a" if om == OFFSET_ALL else "m")
    return os.path.join(cache_dir, safe,
                        f"{tag}_{tx}_{ty}_{z}_{int(g)}{int(m)}{int(f)}{omt}.{ext}")




# ------------------------------------------------------------------ renderer

def is_object_library(lib_id: int) -> bool:
    """True if lib_id refers to an object/building library (Houses, Walls, SmTiles, Objects, etc).

    Excludes empty (255) and pure ground tile libraries (tilesc, tiles30c, tiles5c, wood_tilesc).
    """
    if lib_id == 255:
        return False
    lib_name = KR_ORDER.get(lib_id, "")
    if not lib_name:
        return False
    # Only pure ground tiles should be excluded from object rendering; smtilesc contains houses/stairs!
    if lib_name in ("tilesc", "tiles30c", "tiles5c", "wood_tilesc", "tiles"):
        return False
    return True


def render_tile(map_cache: MapCache, pool: FramePool, map_name: str,
                tx: int, ty: int, zoom: int,
                draw_ground: bool = True, draw_mid: bool = True,
                draw_front: bool = True,
                layout: str = LAYOUT_RECT,
                offset_mode: str = OFFSET_NONE) -> bytes:
    """Render a single tile at zoom level `zoom` (0 is 1:1, 1 is 1:2, etc).

    `offset_mode` (rect only) selects the WIL frame-offset experiment mode;
    OFFSET_NONE is the original Mir3.exe behaviour (no offsets)."""
    scale = 1 << zoom
    tile_world_sz = TILE_SZ * scale
    w, h, _ = map_cache.get(map_name)

    wx0, wy0 = tx * tile_world_sz, ty * tile_world_sz
    wx1, wy1 = wx0 + tile_world_sz, wy0 + tile_world_sz

    canvas = Image.new("RGBA", (TILE_SZ, TILE_SZ), (16, 16, 20, 255))

    cells = map_cache.sparse_slice(map_name, wx0, wx1, wy0, wy1, layout=layout)

    for x, y, cell in cells:
        cx, cy = cell_anchor(x, y, h, layout)

        if cx + 512 < wx0 or cx - 512 > wx1 or cy + 512 < wy0 or cy - 512 > wy1:
            continue

        # 1. Back Ground Layer.  Mir3.exe 0x43b9a0 anchors ground blocks at
        # the cell top-left (rect: x*48, y*32) and never reads WIL offsets.
        # .map ground storage only fills even cells (2x2 blocks), so in the
        # rect layout one 96x64 block exactly covers cells (x..x+1, y..y+1).
        # (The iso view keeps the legacy centre-anchor + offset behaviour.)
        if draw_ground and cell.back_file != 255 and cell.back_img >= 0:
            got = pool.decode(cell.back_file, cell.back_img, scale)
            if got is not None:
                if layout == LAYOUT_ISO:
                    img, off_x, off_y = got
                    px = cx - 24 + off_x
                    py = cy - 16 + off_y
                else:
                    img, off_x, off_y = got
                    if offset_mode == OFFSET_ALL:
                        px = cx + off_x * scale
                        py = cy + off_y * scale
                    else:
                        px, py = cx, cy
                iw, ih = img.width * scale, img.height * scale
                if px + iw >= wx0 and px <= wx1 and py + ih >= wy0 and py <= wy1:
                    canvas.alpha_composite(img, ((px - wx0) // scale, (py - wy0) // scale))

        # 2. Middle Layer (SmTiles, SmObjects, Furnitures, etc)
        # Mir3.exe anchors mid/front sprites bottom-LEFT to the cell and
        # never reads the WIL frame offset (dest math at 0x43bce6/0x43bfd2:
        # destX = (x-viewX)*48 - scrollX - 200, destY = (y-viewY)*32 -
        # scrollY - h - 125; the ground's -157 vs mid/front's -125 differ by
        # exactly one cell height, so the frame bottom sits on the cell's
        # bottom edge).  The ZL C# client (MapControl.cs DrawObjects) does the
        # same: Draw(index, drawX, drawY - h, useOffSet=false) with drawX =
        # cell left and drawY = cell bottom.  Some libs (e.g. SmTilesc) carry
        # garbage offsets (-1132, -19694) that would fling sprites off-map.
        # `offset_mode` switches those offsets on for the experiment only.
        #
        # Frame index semantics: the .map file stores the raw WIL frame index
        # (Mir3.exe 0x43b3c7 pushes cell+5 verbatim; the 2017 ZL client reads
        # +1 and draws -1, netting to the raw value).  No -1 here.
        if draw_mid and is_object_library(cell.mid_file) and cell.mid_img > 0 and cell.mid_img < 65535:
            frame_idx = cell.mid_img
            got = pool.decode(cell.mid_file, frame_idx, scale)
            if got is not None:
                img, off_x, off_y = got
                if layout == LAYOUT_ISO:
                    px = cx - 24
                    py = cy + 16 - img.height * scale
                elif offset_mode in (OFFSET_ALL, OFFSET_MIDFRONT):
                    px = cx + off_x * scale
                    py = cy + 32 - img.height * scale + off_y * scale
                else:
                    px = cx
                    py = cy + 32 - img.height * scale
                iw, ih = img.width * scale, img.height * scale
                if px + iw >= wx0 and px <= wx1 and py + ih >= wy0 and py <= wy1:
                    canvas.alpha_composite(img, ((px - wx0) // scale, (py - wy0) // scale))

        # 3. Front Layer (Houses, Walls, Cliffs, Objects, etc)
        if draw_front and is_object_library(cell.front_file) and cell.front_img > 0 and cell.front_img < 65535:
            frame_idx = cell.front_img
            got = pool.decode(cell.front_file, frame_idx, scale)
            if got is not None:
                img, off_x, off_y = got
                if layout == LAYOUT_ISO:
                    px = cx - 24
                    py = cy + 16 - img.height * scale
                elif offset_mode in (OFFSET_ALL, OFFSET_MIDFRONT):
                    px = cx + off_x * scale
                    py = cy + 32 - img.height * scale + off_y * scale
                else:
                    px = cx
                    py = cy + 32 - img.height * scale
                iw, ih = img.width * scale, img.height * scale
                if px + iw >= wx0 and px <= wx1 and py + ih >= wy0 and py <= wy1:
                    canvas.alpha_composite(img, ((px - wx0) // scale, (py - wy0) // scale))

    buf = io.BytesIO()
    if zoom == 0:
        canvas.save(buf, format="PNG")
    else:
        canvas.convert("RGB").save(buf, format="JPEG", quality=75)
    return buf.getvalue()


LIB_IDS = {name: lid for lid, name in KR_ORDER.items()}
PARALLEL_MIN_FRAMES = 200  # unique frames above which full-map decode uses the process pool


def render_full_map(map_cache: MapCache, pool: FramePool, map_name: str, z: int,
                    draw_ground: bool = True, draw_mid: bool = True,
                    draw_front: bool = True,
                    fmt: str = "JPEG", layout: str = LAYOUT_RECT,
                    offset_mode: str = OFFSET_NONE) -> bytes:
    scale = 1 << z
    w, h, _ = map_cache.get(map_name)
    world_w, world_h = world_bounds(w, h, layout)
    W, H = math.ceil(world_w / scale), math.ceil(world_h / scale)

    needs: dict[int, set[int]] = {}
    cells = list(map_cache.sparse_slice(map_name, 0, world_w, 0, world_h, layout=layout))
    for _, _, cell in cells:
        if draw_ground and cell.back_file != 255 and cell.back_img >= 0:
            needs.setdefault(cell.back_file, set()).add(cell.back_img)
        if draw_mid and is_object_library(cell.mid_file) and cell.mid_img > 0 and cell.mid_img < 65535:
            needs.setdefault(cell.mid_file, set()).add(cell.mid_img)
        if draw_front and is_object_library(cell.front_file) and cell.front_img > 0 and cell.front_img < 65535:
            needs.setdefault(cell.front_file, set()).add(cell.front_img)

    tasks: list[tuple] = []
    for lib_id, frames in needs.items():
        lib = pool._get_lib(lib_id)
        if lib is None:
            continue
        for fr in frames:
            if 0 <= fr < lib.count:
                tasks.append((lib_id, fr, scale))

    sprites: dict[tuple[int, int], tuple] = {}
    if len(tasks) >= PARALLEL_MIN_FRAMES:
        for res in _get_pool(pool.data_dir).map(_decode_frame_worker, tasks):
            if res is None:
                continue
            lib_id, fr, iw, ih, off_x, off_y, rgba = res
            img = Image.frombuffer("RGBA", (iw, ih), rgba, "raw", "RGBA", 0, 1)
            sprites[(lib_id, fr)] = (img, off_x, off_y, _sprite_opaque(img, lib_id))
    else:
        for lib_id, frames in needs.items():
            for fr in frames:
                got = pool.decode(lib_id, fr, scale)
                if got is not None:
                    img, off_x, off_y = got
                    sprites[(lib_id, fr)] = (img, off_x, off_y, _sprite_opaque(img, lib_id))

    canvas = Image.new("RGBA", (W, H), (16, 16, 20, 255))
    for x, y, cell in cells:
        cx, cy = cell_anchor(x, y, h, layout)
        # 1. Back Ground Layer
        if draw_ground and cell.back_file != 255 and cell.back_img >= 0:
            got = sprites.get((cell.back_file, cell.back_img))
            if got is not None:
                img, off_x, off_y, opaque = got
                if layout == LAYOUT_ISO:
                    _blit(canvas, img, cx - 24 + off_x, cy - 16 + off_y, scale, opaque)
                elif offset_mode == OFFSET_ALL:
                    _blit(canvas, img, cx + off_x * scale, cy + off_y * scale, scale, opaque)
                else:
                    _blit(canvas, img, cx, cy, scale, opaque)
        # 2. Middle Layer
        if draw_mid and is_object_library(cell.mid_file) and cell.mid_img > 0 and cell.mid_img < 65535:
            got = sprites.get((cell.mid_file, cell.mid_img))
            if got is not None:
                img, off_x, off_y, opaque = got
                if layout == LAYOUT_ISO:
                    _blit(canvas, img, cx - 24, cy + 16 - img.height * scale, scale, False)
                elif offset_mode in (OFFSET_ALL, OFFSET_MIDFRONT):
                    _blit(canvas, img, cx + off_x * scale,
                          cy + 32 - img.height * scale + off_y * scale, scale, False)
                else:
                    _blit(canvas, img, cx, cy + 32 - img.height * scale, scale, False)
        # 3. Front Layer
        if draw_front and is_object_library(cell.front_file) and cell.front_img > 0 and cell.front_img < 65535:
            got = sprites.get((cell.front_file, cell.front_img))
            if got is not None:
                img, off_x, off_y, opaque = got
                if layout == LAYOUT_ISO:
                    _blit(canvas, img, cx - 24, cy + 16 - img.height * scale, scale, False)
                elif offset_mode in (OFFSET_ALL, OFFSET_MIDFRONT):
                    _blit(canvas, img, cx + off_x * scale,
                          cy + 32 - img.height * scale + off_y * scale, scale, False)
                else:
                    _blit(canvas, img, cx, cy + 32 - img.height * scale, scale, False)

    buf = io.BytesIO()
    if fmt == "PNG":
        canvas.convert("RGB").save(buf, format="PNG")
    else:
        canvas.convert("RGB").save(buf, format="JPEG", quality=78)
    return buf.getvalue()


def render_offset_strip(map_cache: MapCache, pool: FramePool, map_name: str, z: int,
                        draw_ground: bool = True, draw_mid: bool = True,
                        draw_front: bool = True,
                        layout: str = LAYOUT_RECT) -> bytes:
    """Side-by-side PNG of the three offset experiment modes (none|all|midfront).

    Panels are full-map renders at zoom z, downscaled to height 400 with
    labelled bars — same layout as the offline comparisons/*__offset_modes_z4.png
    strips, so /strip (sim "导出对比图" button) and the offline generator share
    one code path."""
    from PIL import Image, ImageDraw

    labels = {
        OFFSET_NONE: "none (Mir3.exe)",
        OFFSET_ALL: "all (back+mid/front)",
        OFFSET_MIDFRONT: "midfront",
    }
    panels = {}
    for om in (OFFSET_NONE, OFFSET_ALL, OFFSET_MIDFRONT):
        buf = render_full_map(map_cache, pool, map_name, z, draw_ground, draw_mid,
                              draw_front, fmt="PNG", layout=layout, offset_mode=om)
        im = Image.open(io.BytesIO(buf)).convert("RGB")
        im.thumbnail((10_000, 400), Image.LANCZOS)
        panels[om] = im
    w = max(i.width for i in panels.values())
    h = max(i.height for i in panels.values())
    gap, bar = 8, 26
    strip = Image.new("RGB", (3 * w + 2 * gap, bar + h), (20, 20, 26))
    d = ImageDraw.Draw(strip)
    for k, om in enumerate((OFFSET_NONE, OFFSET_ALL, OFFSET_MIDFRONT)):
        x = k * (w + gap)
        d.rectangle([x, 0, x + w, bar], fill=(32, 32, 44))
        d.text((x + 6, 8), f"{map_name}  offset={labels[om]}", fill=(240, 240, 240))
        strip.paste(panels[om], (x, bar))
    buf = io.BytesIO()
    strip.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def _sprite_opaque(img: Image.Image, lib_id: int = None) -> bool:
    """True when the sprite has no transparent pixels (paste == composite).

    Ground libraries are always fully opaque.  This matters for ZL data:
    the ZL toolchain stores Wood/Tilesc.Zl and Wood/Tiles5c.Zl BC3 alpha as
    4 (placeholder) instead of 255, while the ZL client never consumes those
    libs per-tile (it draws ground from MapInfo.Background) — so the
    placeholder never surfaced there.  In our per-tile ground renderer a
    composite with alpha=4 would make the whole ground layer vanish, so
    treat every ground frame as opaque regardless of its stored alpha.
    """
    lib_name = KR_ORDER.get(lib_id, "") if lib_id is not None else ""
    if lib_name in ("tilesc", "tiles30c", "tiles5c", "wood_tilesc", "tiles"):
        return True
    try:
        return img.getextrema()[3] == (255, 255)
    except Exception:
        return False


def _blit(canvas: Image.Image, img: Image.Image, px: int, py: int, scale: int,
          opaque: bool = False):
    """Draw `img` onto `canvas` at world (px, py) clipped to the canvas edge.

    Opaque sprites (all ground tiles, most walls) use paste - ~4x cheaper
    than alpha_composite; translucent sprites alpha-composite in painter
    order.  Sprites anchored left/up of the cell are cropped."""
    W, H = canvas.width, canvas.height
    sx, sy = px // scale, py // scale
    iw, ih = img.width, img.height
    if sy < 0:
        top = min(ih, -sy)
        img = img.crop((0, top, iw, ih)); ih = img.height; sy = 0
    if sx < 0:
        left = min(iw, -sx)
        img = img.crop((left, 0, iw, ih)); iw = img.width; sx = 0
    if sx >= W or sy >= H:
        return
    iw = min(iw, W - sx); ih = min(ih, H - sy)
    if iw <= 0 or ih <= 0:
        return
    if iw < img.width or ih < img.height:
        img = img.crop((0, 0, iw, ih))
    if opaque:
        canvas.paste(img, (sx, sy))
    else:
        canvas.alpha_composite(img, (sx, sy))


# ------------------------------------------------------------------ web server

