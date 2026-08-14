#!/usr/bin/env python3
"""mapviewer.py — Mir3 EI / Zircon .map browser (Server-rendered tile pyramid).

Correctly parses Zircon / Mir3 EI .map format & renders isometric layers:
  - Back (Ground) layer (half-res, 96x64 tiles)
  - Middle layer (SmTiles / Objects)
  - Front layer (Objects / Houses / Walls / Cliffs)

Maps KR Library IDs (0..55) to Wemade WIL / ZL image libraries (KROrder table).
"""

from __future__ import annotations

import argparse
import io
import json
import math
import os
import time
import re
import struct
import sys
import threading
from collections import OrderedDict
from functools import lru_cache

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from concurrent.futures import ProcessPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

try:
    from PIL import Image
except ImportError:
    Image = None

from wilsdk import WilLibrary
from zlsdk import ZlLibrary
from mapnames import resolve as map_cn

TILE_SZ = 512          # tile size in screen pixels
CACHE_MAPS_MAX = 3     # decoded maps kept in memory
CACHE_TILES_MAX = 400  # rendered tiles (PNG bytes) kept in memory
CACHE_FRAMES_BYTES = 256 * 1024 * 1024  # decoded frames LRU budget (per process)
THUMBS_DIR = "/tmp/wiki_thumbs"  # pre-rendered full-map thumbnails (shared with WikiServer/thumb_gen)
MAX_FULL_DIM = 16384   # full-map single image: longest side cap (px)
FIT_FULL_DIM = 2048    # full-map "fit" level: longest side target (px)
DEFAULT_CLIENT_ROOT = "/home/tetsuya/development/Zircon/Debug/Client"
DEFAULT_CONNECTIONS = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "../../docs/database/data/map-connections.json"))
# dbeditor JSON 工作区（System.db 全表导出，编辑器保存即更新）——NPC 位置与
# 地图连接的第一数据源（NPCInfo 294 行 × MapRegion 5009 行 × MovementInfo
# 1039 行，PointRegion 质心坐标 0 缺失，且包含 NpcMover 修正后的 EI 坐标）。
DEFAULT_DBWORKSPACE = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "../dbeditor/workspace"))
# 客户端显示名映射表（方案 B 本地化）：NPC/地图 中文名，zh 优先、英文兜底。
DEFAULT_DB_NAMES = os.path.expanduser(
    "~/development/zircon/GodotClient/translations/db_names.json")
# Full chinese-name map: {map stem -> cn}.  Generated from DBserver/Envir
# MapInfo.txt + System.db descriptions + mapnames rules (see gen_static_maps.py).
MAP_CN_FILE = "/tmp/map_cn_full.json"

def _load_map_cn() -> dict:
    try:
        with open(MAP_CN_FILE, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}

MAP_CN = _load_map_cn()
# Bump whenever map parsing/library mapping changes.  Old cached JPGs can be
# visually valid files but represent the pre-Sabak or pre-cell-offset parser.
CACHE_VERSION = "v3"

# Layout modes.  Mir3.exe (EI 2002) renders the map grid axis-aligned:
# every draw call projects cell (x,y) with a single-axis term (x*48, y*32)
# and the viewport is a plain 36x36 square; the 8-way scroll table moves
# N/E/S/W by a single pixel axis.  The apparent "isometric" look of the
# game comes from perspective baked into the sprites, not the projection.
# "iso" is kept only as a legacy/debug view.
LAYOUT_RECT = "rect"
LAYOUT_ISO = "iso"

# WIL frame-offset modes (rect layout only; iso keeps the legacy
# centre-anchor + offset behaviour and ignores this switch).
# Disassembly of Mir3.exe is conclusive that the EI map layers NEVER read
# the frame +4/+6 offset fields (ground 0x43b440/0x43b9a0/0x43c3xx/0x43c4c9,
# animated ground 0x434a20, mid/front 0x43bb10/0x43be00, blend 0x43bcf5) —
# only the actor layer (0x41cbd0/0x40b5xx/0x40fbxx/0x430axx) does.  These
# modes exist purely to record the divergence ("none" = the original).
OFFSET_NONE = "none"      # original: no offsets anywhere
OFFSET_ALL = "all"        # hypothetical: back + mid/front shifted by frame offsets
OFFSET_MIDFRONT = "midfront"  # hypothetical: only mid/front shifted
OFFSET_MODES = (OFFSET_NONE, OFFSET_ALL, OFFSET_MIDFRONT)

# ---- Game minimap assets (MiniMap.Zl / mmap.wil) ----
# MapInfo.MiniMap (System.db, via Tools/SystemDbProbe --minimap) maps a map
# file stem -> frame index in the MiniMap library.  The library lives next to
# the other map-tile libs in the data dir.
MINIMAP_MAP_FILE = "/tmp/minimap_map.txt"    # 2017 ZL client: {stem -> frame} dump (244 maps)
MINIMAP_EI_FILE = "/tmp/minimap_map_ei.txt"  # EI client: {stem -> libname -> frame} dump (182 maps)
MINIMAP_LIB_NAME = "MiniMap.Zl"             # 2017 ZL client
MINIMAP_EI_LIBS = ("FMMap.wil", "MMap.wil") # EI client: FMMap = full/overland, MMap = dungeon


@lru_cache(maxsize=1)
def _minimap_index():
    """{map stem (no ext) -> MiniMap frame index}, or {} if the dump is absent."""
    try:
        idx = {}
        with open(MINIMAP_MAP_FILE, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line:
                    continue
                parts = line.split("\t")
                if len(parts) == 2:
                    try:
                        idx[parts[0]] = int(parts[1])
                    except ValueError:
                        pass
        return idx
    except FileNotFoundError:
        return {}


@lru_cache(maxsize=1)
def _minimap_index_ei():
    """{map stem -> (lib name, frame index)} for the EI client, or {}.

    Dump produced from the EI server's Envir/MiniMap.txt (see
    Tools/maps/gen_minimap_ei.py): overland maps use FMMap.wil with
    frame = value - 1001, dungeon/field maps use MMap.wil with frame = value.
    """
    try:
        idx = {}
        with open(MINIMAP_EI_FILE, encoding="utf-8") as f:
            for line in f:
                line = line.rstrip("\n")
                if not line:
                    continue
                parts = line.split("\t")
                if len(parts) == 3:
                    try:
                        idx[parts[0]] = (parts[1], int(parts[2]))
                    except ValueError:
                        pass
        return idx
    except FileNotFoundError:
        return {}


class MiniMapSource:
    """Decodes the game's minimap library.

    Supports two client generations, auto-detected from the data dir:
      - 2017 ZL client: MiniMap.Zl (frames via System.db MapInfo.MiniMap,
        dumped by SystemDbProbe --minimap into MINIMAP_MAP_FILE).
      - EI client: FMMap.wil (overland, frame = value - 1001) and MMap.wil
        (dungeon/field, frame = value); index dumped from the EI server's
        Envir/MiniMap.txt into MINIMAP_EI_FILE.

    One instance per data dir; libraries are opened lazily.  ``frame(stem)``
    returns the minimap image for a map, or None when the map has no minimap
    or the libraries are missing.
    """

    def __init__(self, data_dir: str):
        self.data_dir = data_dir
        self._zl_lib = None          # 2017: MiniMap.Zl
        self._ei_libs = {}           # EI: name -> WilLibrary
        self._mode = None            # "zl" | "ei"

    _instances: dict = {}

    @classmethod
    def _for(cls, data_dir: str) -> "MiniMapSource":
        """Per-data-dir singleton: minimap libraries are opened at most once."""
        src = cls._instances.get(data_dir)
        if src is None:
            src = cls._instances[data_dir] = cls(data_dir)
        return src

    def _detect(self):
        if self._mode is not None:
            return self._mode
        if not self.data_dir:
            self._mode = None
            return None
        for root in (self.data_dir, os.path.join(self.data_dir, "Map Data")):
            if os.path.exists(os.path.join(root, MINIMAP_LIB_NAME)):
                self._mode = "zl"
                return self._mode
        for root in (self.data_dir, os.path.join(self.data_dir, "Map Data")):
            if os.path.exists(os.path.join(root, "MMap.wil")):
                self._mode = "ei"
                return self._mode
        self._mode = None
        return None

    def _open(self):
        mode = self._detect()
        if mode == "zl":
            if self._zl_lib is not None:
                return self._zl_lib
            for root in (self.data_dir, os.path.join(self.data_dir, "Map Data")):
                p = os.path.join(root, MINIMAP_LIB_NAME)
                if os.path.exists(p):
                    try:
                        self._zl_lib = ZlLibrary(p)
                        return self._zl_lib
                    except Exception:
                        continue
            return None
        if mode == "ei":
            for name in MINIMAP_EI_LIBS:
                if name in self._ei_libs:
                    continue
                for root in (self.data_dir, os.path.join(self.data_dir, "Map Data")):
                    p = os.path.join(root, name)
                    if os.path.exists(p):
                        try:
                            self._ei_libs[name] = WilLibrary(p)
                        except Exception:
                            pass
                        break
            return self._ei_libs or None
        return None

    def frame(self, stem: str):
        mode = self._detect()
        if mode == "zl":
            lib = self._open()
            if lib is None:
                return None
            fid = _minimap_index().get(stem)
            if fid is None:
                return None
            try:
                return lib.decode(fid)
            except Exception:
                return None
        if mode == "ei":
            entry = _minimap_index_ei().get(stem)
            if entry is None:
                return None
            libname, fid = entry
            lib = self._open().get(libname) if self._open() else None
            if lib is None:
                return None
            try:
                return lib.decode(fid)
            except Exception:
                return None
        return None

# KROrder Mapping from LibraryCore/Libraries.cs
KR_ORDER = {
    0: "tilesc",
    1: "tiles30c",
    2: "tiles5c",
    3: "smtilesc",
    4: "housesc",
    5: "cliffsc",
    6: "dungeonsc",
    7: "innersc",
    8: "furnituresc",
    9: "wallsc",
    10: "smobjectsc",
    11: "animationsc",
    12: "object1c",
    13: "object2c",

    15: "wood_tilesc",
    16: "wood_tiles30c",
    17: "wood_tiles5c",
    18: "wood_smtilesc",
    19: "wood_housesc",
    20: "wood_cliffsc",
    21: "wood_dungeonsc",
    22: "wood_innersc",
    23: "wood_furnituresc",
    24: "wood_wallsc",
    25: "wood_smobjectsc",
    26: "wood_animationsc",

    30: "sand_tilesc",
    31: "sand_tiles30c",
    32: "sand_tiles5c",
    33: "sand_smtilesc",
    34: "sand_housesc",
    35: "sand_cliffsc",
    36: "sand_dungeonsc",
    37: "sand_innersc",
    38: "sand_furnituresc",
    39: "sand_wallsc",
    40: "sand_smobjectsc",
    41: "sand_animationsc",

    45: "snow_tilesc",
    46: "snow_tiles30c",
    47: "snow_tiles5c",
    48: "snow_smtilesc",
    49: "snow_housesc",
    50: "snow_cliffsc",
    51: "snow_dungeonsc",
    52: "snow_innersc",
    53: "snow_furnituresc",
    54: "snow_wallsc",
    55: "snow_smobjectsc",
    56: "snow_animationsc",

    60: "forest_tilesc",
    61: "forest_tiles30c",
    62: "forest_tiles5c",
    63: "forest_smtilesc",
    64: "forest_housesc",
    65: "forest_cliffsc",
    66: "forest_dungeonsc",
    67: "forest_innersc",
    68: "forest_furnituresc",
    69: "forest_wallsc",
    70: "forest_smobjectsc",
    71: "forest_animationsc",
    # Zircon client custom Sabak package; 3.map uses this slot in all layers.
    200: "sabak",
}


# ------------------------------------------------------------------- .map I/O

class MapCell:
    __slots__ = ('back_file', 'back_img', 'mid_file', 'mid_img', 'front_file', 'front_img',
                 'flag', 'anim_a', 'anim_b')

    def __init__(self):
        self.back_file = 255
        self.back_img = 0
        self.mid_file = 255
        self.mid_img = 0
        self.front_file = 255
        self.front_img = 0
        self.flag = 0
        self.anim_a = 0xFF
        self.anim_b = 0xFF


def parse_map_header(path: str) -> tuple[int, int]:
    with open(path, "rb") as f:
        hdr = f.read(28)
    w = struct.unpack_from("<H", hdr, 22)[0]
    h = struct.unpack_from("<H", hdr, 24)[0]
    return w, h


def parse_map(path: str) -> tuple[int, int, list[list[MapCell]]]:
    """Parse Zircon / Mir3 EI .map file into cell matrix Cells[Width][Height]."""
    with open(path, "rb") as f:
        data = f.read()

    w = struct.unpack_from("<H", data, 22)[0]
    h = struct.unpack_from("<H", data, 24)[0]

    cells = [[MapCell() for _ in range(h)] for _ in range(w)]

    offset = 28
    # Segment 1: Back (Ground) layer (Half-res, 3 bytes per entry for even cells)
    for x in range(w // 2):
        for y in range(h // 2):
            bf = data[offset]
            bi = struct.unpack_from("<H", data, offset + 1)[0]
            offset += 3
            cells[x * 2][y * 2].back_file = bf
            cells[x * 2][y * 2].back_img = bi

    # Segment 2: Full-res Cells (14 bytes each).  This segment follows the
    # half-resolution Back table; restarting at offset 28 would interpret
    # Back bytes as flags/library ids and produces a mostly black map.
    cell_base = offset
    n_cells = min(w * h, max(0, (len(data) - cell_base) // 14))
    for i in range(n_cells):
        x, y = divmod(i, h)
        offset = cell_base + i * 14
        # cell structure:
        # 0: flag, 1: midAnim, 2: frontAnim, 3: frontFile, 4: midFile
        # 5-6: midImg (uint16), 7-8: frontImg (uint16), 9+: unused/padding
        ff = data[offset + 3]
        mf = data[offset + 4]
        mi = struct.unpack_from("<H", data, offset + 5)[0]
        fi = struct.unpack_from("<H", data, offset + 7)[0]

        c = cells[x][y]
        c.flag = data[offset]
        c.anim_a = data[offset + 1]
        c.anim_b = data[offset + 2]
        c.mid_file = mf
        c.mid_img = mi
        c.front_file = ff
        c.front_img = fi

    return w, h, cells


class MapCache:
    """LRU of parsed maps + two cell indexes.

    Index A (iso): cells bucketed by s = x + y (isometric screen row),
    within a bucket sorted by x.  Index B (rect): cells bucketed by x,
    within a bucket sorted by y — used for the axis-aligned (original)
    projection where a tile window is a plain x/y rectangle.
    """

    def __init__(self, maps_dir: str, max_keep: int = CACHE_MAPS_MAX):
        self.maps_dir = maps_dir
        self.max_keep = max_keep
        self._store: dict[str, tuple[int, int, list[list[MapCell]]]] = {}
        self._buckets: dict[str, list[list[tuple[int, MapCell]]]] = {}
        self._bxs: dict[str, list[list[int]]] = {}
        self._rows: dict[str, list[list[tuple[int, MapCell]]]] = {}
        self._rys: dict[str, list[list[int]]] = {}
        self._lock = threading.Lock()
        self._build_locks: dict[str, threading.Lock] = {}

    def _build_lock(self, name: str) -> threading.Lock:
        with self._lock:
            lk = self._build_locks.get(name)
            if lk is None:
                lk = self._build_locks[name] = threading.Lock()
            return lk

    def get(self, name: str) -> tuple[int, int, list[list[MapCell]]]:
        """Parse (once) and return (w, h, cells). Never holds the global lock
        while parsing, so concurrent tile requests are not serialized on a
        slow first parse."""
        with self._lock:
            entry = self._store.get(name)
        if entry is None:
            with self._build_lock(name):
                with self._lock:
                    entry = self._store.get(name)
                if entry is None:
                    entry = parse_map(os.path.join(self.maps_dir, name))
                    with self._lock:
                        self._store[name] = entry
                        while len(self._store) > self.max_keep:
                            k = next(iter(self._store))
                            self._store.pop(k)
                            self._buckets.pop(k, None)
                            self._bxs.pop(k, None)
                            self._rows.pop(k, None)
                            self._rys.pop(k, None)
        return self._store[name]

    def sparse(self, name: str) -> tuple[list, list]:
        """(buckets, bxs): buckets[s] = [(x, cell), ...] sorted by x, with
        parallel x-only lists for bisect. s = x + y in [0, w+h-2]."""
        with self._lock:
            buckets = self._buckets.get(name)
            bxs = self._bxs.get(name)
        if buckets is None:
            entry = self.get(name)  # ensure parsed; may block on the parse lock
            with self._build_lock(name):
                with self._lock:
                    buckets = self._buckets.get(name)
                if buckets is None:
                    w, h, cells = entry
                    buckets = [[] for _ in range(w + h - 1)]
                    for x in range(w):
                        for y in range(h):
                            c = cells[x][y]
                            if c.back_file != 255 or c.mid_file != 255 or c.front_file != 255:
                                buckets[x + y].append((x, c))
                    bxs = []
                    for b in buckets:
                        b.sort(key=lambda t: t[0])
                        bxs.append([t[0] for t in b])
                    with self._lock:
                        self._buckets[name] = buckets
                        self._bxs[name] = bxs
        return self._buckets[name], self._bxs[name]

    def sparse_rows(self, name: str) -> tuple[list, list]:
        """(rows, rys): rows[x] = [(y, cell), ...] sorted by y, with parallel
        y-only lists for bisect.  Used by the axis-aligned (rect) layout."""
        with self._lock:
            rows = self._rows.get(name)
            rys = self._rys.get(name)
        if rows is None:
            entry = self.get(name)
            with self._build_lock(name):
                with self._lock:
                    rows = self._rows.get(name)
                if rows is None:
                    w, h, cells = entry
                    rows = [[] for _ in range(w)]
                    for x in range(w):
                        for y in range(h):
                            c = cells[x][y]
                            if c.back_file != 255 or c.mid_file != 255 or c.front_file != 255:
                                rows[x].append((y, c))
                    rys = []
                    for r in rows:
                        r.sort(key=lambda t: t[0])
                        rys.append([t[0] for t in r])
                    with self._lock:
                        self._rows[name] = rows
                        self._rys[name] = rys
        return self._rows[name], self._rys[name]

    def sparse_slice(self, name: str, wx0: int, wx1: int, wy0: int, wy1: int,
                     margin: int = 512, layout: str = LAYOUT_RECT):
        """Yield (x, y, cell) for every non-empty cell whose anchor lies inside
        [wx0-margin, wx1+margin] x [wy0-margin, wy1+margin] (world px)."""
        import bisect
        w, h, _ = self.get(name)
        if layout == LAYOUT_ISO:
            buckets, bxs = self.sparse(name)
            # screen rows: cy = s*16 + 16 must intersect [wy0-margin, wy1+margin]
            s0 = max(0, (wy0 - margin - 16 + 15) // 16)
            s1 = min(len(buckets) - 1, (wy1 + margin - 16) // 16)
            # per-row screen x: cx = (2x - s)*24 + h*24 + 24
            cx_lo = wx0 - margin - h * 24 - 24
            cx_hi = wx1 + margin - h * 24 - 24
            for s in range(s0, s1 + 1):
                xs = bxs[s]
                x0 = (cx_lo + s * 24 + 47) // 48  # ceil
                x1 = (cx_hi + s * 24) // 48       # floor
                i0 = bisect.bisect_left(xs, x0)
                i1 = bisect.bisect_right(xs, x1)
                if i0 >= i1:
                    continue
                bucket = buckets[s]
                for k in range(i0, i1):
                    x, c = bucket[k]
                    yield x, s - x, c
            return

        rows, rys = self.sparse_rows(name)
        x0 = max(0, (wx0 - margin) // 48)
        x1 = min(w - 1, (wx1 + margin - 1) // 48)
        y0 = max(0, (wy0 - margin) // 32)
        y1 = min(h - 1, (wy1 + margin - 1) // 32)
        for x in range(x0, x1 + 1):
            ys = rys[x]
            i0 = bisect.bisect_left(ys, y0)
            i1 = bisect.bisect_right(ys, y1)
            if i0 >= i1:
                continue
            row = rows[x]
            for k in range(i0, i1):
                y, c = row[k]
                yield x, y, c


# ------------------------------------------------------------------ WIL pool

def _find_library_path(data_dir: str, lib_name: str) -> str | None:
    """Find a library in Data, Data/Map Data, or a terrain subdirectory."""
    parts = lib_name.split("_", 1)
    if len(parts) == 2 and parts[0] in {"wood", "sand", "snow", "forest"}:
        folder, filename = parts[0].title(), parts[1]
    else:
        folder, filename = None, lib_name
    filename_candidates = [filename + ".Zl", filename + ".zl", filename + ".wil"]
    roots = [data_dir, os.path.join(data_dir, "Map Data")]
    for root in roots:
        candidates = []
        if folder:
            candidates.append(os.path.join(root, folder))
        candidates.append(root)
        for directory in candidates:
            if not os.path.isdir(directory):
                continue
            for entry in os.listdir(directory):
                if entry.lower() in {name.lower() for name in filename_candidates}:
                    return os.path.join(directory, entry)
    return None


class FramePool:
    """Map library IDs to either legacy WIL or current Zircon ZL libraries."""

    def __init__(self, data_dir: str):
        self.libs: dict[str, WilLibrary | ZlLibrary | None] = {}
        self.lib_paths: dict[str, str] = {}  # lib_name -> resolved file path
        self.data_dir = data_dir
        self._lock = threading.RLock()
        self._frames: OrderedDict = OrderedDict()
        self._frame_bytes = 0

    def _get_lib(self, lib_id: int) -> WilLibrary | ZlLibrary | None:
        lib_name = KR_ORDER.get(lib_id)
        if not lib_name:
            return None
        with self._lock:
            if lib_name not in self.libs:
                path = _find_library_path(self.data_dir, lib_name)
                if path is None:
                    self.libs[lib_name] = None
                elif path.lower().endswith(".zl"):
                    self.libs[lib_name] = ZlLibrary(path)
                    self.lib_paths[lib_name] = path
                else:
                    self.libs[lib_name] = WilLibrary(path)
                    self.lib_paths[lib_name] = path
            return self.libs[lib_name]

    def decode(self, lib_id: int, frame: int, scale: int = 1):
        """Returns (PIL.Image at 1/scale resolution, offsetX, offsetY) or None.

        scale > 1 decodes WIL frames natively at 1/scale (no full-res pass);
        ZL frames are decoded at 1:1 then NEAREST-downscaled (PNG decode is
        C-speed so the win there is cache memory).  Byte-budget LRU: the same
        frame is never re-decoded while its tile is on screen."""
        lib = self._get_lib(lib_id)
        if lib is None or frame < 0 or frame >= lib.count:
            return None
        try:
            hdr = lib.header(frame)
        except Exception:
            return None
        if hdr is None or hdr["width"] <= 0 or hdr["height"] <= 0:
            return None
        key = (lib_id, frame, scale)
        with self._lock:
            img = self._frames.get(key)
            if img is not None:
                self._frames.move_to_end(key)
        if img is None:
            try:
                if scale > 1 and hasattr(lib, "decode_scaled"):
                    im = lib.decode_scaled(frame, scale)
                else:
                    im = lib.decode(frame)
                    if im is not None and scale > 1:
                        im = im.resize((max(1, im.width // scale),
                                        max(1, im.height // scale)), Image.NEAREST)
            except Exception:
                return None
            if im is None:
                return None
            img = (im, hdr["offsetX"], hdr["offsetY"])
            with self._lock:
                self._frames[key] = img
                self._frames.move_to_end(key)
                budget = im.width * im.height * 4 + 64
                self._frame_bytes += budget
                while self._frame_bytes > CACHE_FRAMES_BYTES and len(self._frames) > 1:
                    _, evicted = self._frames.popitem(last=False)
                    self._frame_bytes -= evicted[0].width * evicted[0].height * 4 + 64
        return img


# ------------------------------------------------------------------ parallel full-map decode

# Process-pool worker state: per-worker library cache + the data dir the
# worker was initialised with.  ZL BC1 decode is pure-Python (~2.7ms/frame),
# so full-map renders of big maps (00.map z3 needs ~23k unique frames)
# parallelise decode across cores; compositing stays single-process in
# painter order.
_POOL: dict[str, ProcessPoolExecutor] = {}
_POOL_MU = threading.Lock()
_WORKER_DATA_DIR: str | None = None
_WORKER_LIBS: dict[str, WilLibrary | ZlLibrary] = {}


def _init_worker(data_dir: str):
    global _WORKER_DATA_DIR
    _WORKER_DATA_DIR = data_dir


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
    with _POOL_MU:
        pool = _POOL.get(data_dir)
        if pool is None:
            pool = _POOL[data_dir] = ProcessPoolExecutor(
                max_workers=min(10, os.cpu_count() or 2),
                initializer=_init_worker, initargs=(data_dir,))
        return pool


# ------------------------------------------------------------------ geometry

def world_bounds(w: int, h: int, layout: str = LAYOUT_RECT) -> tuple[int, int]:
    """Full assembled map size in world pixels."""
    if layout == LAYOUT_ISO:
        return (w + h + 3) * 24, (w + h + 2) * 16
    return w * 48, h * 32


def cell_anchor(x: int, y: int, h: int, layout: str = LAYOUT_RECT) -> tuple[int, int]:
    """World-pixel position of cell (x,y): its top-left corner (rect,
    matching Mir3.exe's (x-view.x)*48 / (y-view.y)*32) or its centre (iso)."""
    if layout == LAYOUT_ISO:
        return (x - y) * 24 + h * 24 + 24, (x + y) * 16 + 16
    return x * 48, y * 32


def map_ladder(w: int, h: int, layout: str = LAYOUT_RECT) -> list[int]:
    """Full-map static zoom ladder: [deepest, ..., fit] as zoom levels
    (0 = 1:1).  Deepest keeps the whole map within MAX_FULL_DIM px on its
    longest side (a single image is feasible); fit is the default overview
    (~FIT_FULL_DIM px).  A full 1:1 image of e.g. 00.map (1360x1500 cells,
    68k x 46k world px) is physically impossible, hence the cap."""
    max_dim = max(world_bounds(w, h, layout))
    deep_z = 0
    while (max_dim >> deep_z) > MAX_FULL_DIM:
        deep_z += 1
    fit_z = deep_z
    while (max_dim >> (fit_z + 1)) >= FIT_FULL_DIM:
        fit_z += 1
    return list(range(deep_z, fit_z + 1))


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

SIM_TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>Mir3 EI 原版 800×600 模拟器</title>
<style>
    html, body { margin:0; padding:0; background:#222; overflow:hidden; font-family:sans-serif; }
    #stage { position:relative; width:800px; height:600px; margin:0 auto; background:#000;
             box-shadow:0 0 30px rgba(0,0,0,.8); overflow:hidden; }
    /* world view: the full-map render is positioned so the requested cell is centered */
    #world { position:absolute; left:0; top:0; width:800px; height:600px; overflow:hidden; }
    #world img { position:absolute; display:block; image-rendering:pixelated; }
    /* original HUD bottom bar (0,465)-(800,600) — semi-transparent over the world */
    #hud { position:absolute; left:0; top:465px; width:800px; height:135px;
           background:rgba(12,12,16,.88); border-top:2px solid #4a3a1a; box-sizing:border-box; }
    #hud .cell-label { position:absolute; left:10px; top:6px; font-size:12px; color:#d8c890;
                       font-family:ui-monospace,monospace; text-shadow:1px 1px 0 #000; }
    #hud .stats { position:absolute; left:10px; top:26px; font-size:11px; color:#9aa;
                  font-family:ui-monospace,monospace; line-height:1.5; }
    #hud .cell-nav { position:absolute; left:10px; top:88px; font-size:11px; color:#887; }
    #hud .cell-nav b { color:#dd8; cursor:pointer; }
    #hud .cell-nav b:hover { color:#ffd; }
    #hud .oob { position:absolute; right:10px; top:6px; font-size:11px; color:#f86; font-family:ui-monospace,monospace; }
    /* original minimap widget: fixed (672,0)-(800,128) */
    #mm { position:absolute; left:672px; top:0; width:128px; height:128px;
          background:rgba(8,10,14,.85); border-left:1px solid #3a3a46; border-bottom:1px solid #3a3a46;
          box-sizing:border-box; }
    #mm img { width:128px; height:128px; image-rendering:pixelated; display:block; }
    #mm .mm-label { position:absolute; left:3px; top:2px; font-size:10px; color:#ffe; opacity:.8;
                    text-shadow:1px 1px 0 #000; }
    #mm .mm-zoom { position:absolute; right:3px; bottom:2px; font-size:10px; color:#ffe; opacity:.9; }
    /* HUD buttons from the static evidence (GameInter.wil frames at hud.left+offset) */
    .hud-btn { position:absolute; background:rgba(60,50,30,.55); border:1px solid #6a5a30;
               box-sizing:border-box; }
    /* entity layer: sprites + name tags, positioned over the world view */
    #ents { position:absolute; left:0; top:0; width:800px; height:600px; pointer-events:none; }
    .ent { position:absolute; transform:translate(-50%,-100%); pointer-events:auto;
           cursor:pointer; }
    .ent img { display:block; image-rendering:pixelated; filter:drop-shadow(2px 2px 0 rgba(0,0,0,.5)); }
    .ent .tag { position:absolute; left:50%; top:100%; transform:translateX(-50%);
                font-size:10px; color:#fff; background:rgba(0,0,0,.55); border:1px solid #555;
                padding:0 3px; white-space:nowrap; border-radius:2px; pointer-events:none; }
    .ent.npc img { border:1px solid rgba(120,200,120,.35); }
    .ent.monster img { border:1px solid rgba(230,80,60,.4); }
    .ent.player img { border:1px solid rgba(120,180,255,.6); }
    .ent.player .tag { color:#8cf; border-color:#46a; }
    .ent:hover .tag { background:rgba(255,220,90,.92); color:#000; }
    .ent.target { outline:2px solid #ffd23d; outline-offset:1px; }
    .ent .info { display:none; position:absolute; left:50%; bottom:calc(100% + 6px);
                 transform:translateX(-50%); background:rgba(10,12,18,.94); color:#ddd;
                 border:1px solid #6a5a30; border-radius:3px; padding:5px 8px;
                 font-size:11px; min-width:150px; white-space:nowrap; z-index:5; }
    .ent:hover .info { display:block; }
    #mm .mm-box { position:absolute; border:1px solid #ffd23d; background:rgba(255,210,61,.25);
                  box-sizing:border-box; }
    /* title bar / toolbar outside the stage */
    #bar { width:800px; margin:6px auto 4px; display:flex; gap:8px; align-items:center;
           color:#ccc; font-size:12px; }
    #bar select { background:#333; color:#eee; border:1px solid #555; border-radius:3px; padding:2px 6px; }
    #bar label { cursor:pointer; }
    #bar button { background:#333; color:#eee; border:1px solid #555; border-radius:3px; cursor:pointer; }
    #tip { width:800px; margin:0 auto; font-size:11px; color:#777; font-family:ui-monospace,monospace; }
</style>
</head>
<body>
<div id="bar">
    <span>地图:</span><select id="sel-map"></select>
    <img id="map-thumb" alt="" style="height:22px;border:1px solid #555;border-radius:2px;display:none;">
    <span>中心格:</span><span id="sel-cell" style="font-family:ui-monospace,monospace;">—</span>
    <label><input type="checkbox" id="chk-g" checked> Back</label>
    <label><input type="checkbox" id="chk-m" checked> Middle</label>
    <label><input type="checkbox" id="chk-f" checked> Front</label>
    <span>offset:</span><select id="sel-off" title="WIL 帧 offset 实验模式；原版 Mir3.exe 地图层从不读取 offset（none）">
        <option value="none" selected>none 原版</option>
        <option value="all">all 全层</option>
        <option value="midfront">mid/front</option>
    </select>
    <button id="btn-strip" title="导出三模式 offset 对比条带 PNG（新标签页）">导出对比图</button>
    <button id="btn-hud" title="切换原版 HUD 显示">HUD 开/关</button>
    <button id="btn-mm" title="T 键 128/256 小地图">小地图 128/256</button>
    <button id="btn-back">← 返回浏览器</button>
</div>
<div id="stage">
    <div id="world"><img id="wimg" alt=""></div>
    <div id="ents"></div>
    <div id="cell-info" style="display:none;position:absolute;z-index:50;pointer-events:none;
        background:rgba(10,10,14,.92);border:1px solid #666;border-radius:4px;
        color:#d8e6ff;font:11px ui-monospace,monospace;padding:5px 7px;white-space:pre;"></div>
    <div id="mm"><img id="mimg" alt=""><span class="mm-label" id="mm-name"></span>
        <span class="mm-zoom" id="mm-zoom">128</span><div class="mm-box" id="mm-box"></div></div>
    <div id="hud">
        <div class="cell-label" id="hud-map">—</div>
        <div class="stats" id="hud-stats"></div>
        <div class="cell-nav">方向键/WASD 移动 1 格 · <b>←</b> <b>↑</b> <b>↓</b> <b>→</b> 箭头移动 · Ctrl+滚轮缩放 · T 切换小地图 · H 切换 HUD</div>
        <div class="oob" id="hud-oob"></div>
    </div>
</div>
<div id="tip">Mir3 EI 原版 800×600 模拟 · 世界画面 rect 投影 · 小地图固定 (672,0)-(800,128) · 底部 HUD (0,465)-(800,600)（原版静态证据 layout.json）</div>
<script>
const stage = document.getElementById("stage");
const wimg = document.getElementById("wimg");
const mimg = document.getElementById("mimg");
const selMap = document.getElementById("sel-map");
const selOff = document.getElementById("sel-off");
const selCell = document.getElementById("sel-cell");
const hudMap = document.getElementById("hud-map");
const hudStats = document.getElementById("hud-stats");
const hudOob = document.getElementById("hud-oob");
const mmName = document.getElementById("mm-name");
const mmZoom = document.getElementById("mm-zoom");
let maps = [], curName = null, cat = null;
let cx = 0, cy = 0, z = 0;            // center cell + zoom ladder level
let mm = 128;                          // minimap surface: 128 or 256 (T key)
let showHud = true;
let ents = [], target = null;          // entities on the current map; clicked target
let player = { x: -1, y: -1 };         // player cell (spawn point when available)

const entStyle = {
    player:   { src: "/sprite?lib=M-Hum.wil&frame=0&scale=1", label: "我" },
    npc:      { src: "/sprite?lib=NPC.wil&frame=0&scale=1",    label: "" },
    monster:  { src: "/sprite?lib=Mon-1.wil&frame=0&scale=1", label: "" },
};

async function init() {
    const res = await fetch("/api/maps");
    maps = await res.json();
    selMap.innerHTML = maps.map(m =>
        `<option value="${m.name.replace(/"/g, "&quot;")}">${(m.cn || "") + " " + m.name}</option>`).join("");
    // hash: #sim=3.map&c=200,300&z=2
    let target = maps[0] && maps[0].name;
    const h = location.hash.match(/sim=([^&]+)/);
    if (h && maps.some(m => m.name === decodeURIComponent(h[1]))) target = decodeURIComponent(h[1]);
    selMap.value = target;
    const cm = location.hash.match(/c=(\\d+),(\\d+)/);
    if (cm) { cx = +cm[1]; cy = +cm[2]; }
    const zm = location.hash.match(/z=(\\d+)/);
    if (zm) z = +zm[1];
    const om = location.hash.match(/om=([a-z]+)/);
    if (om && ["none", "all", "midfront"].includes(om[1])) selOff.value = om[1];
    pick(target);
}
function pick(name) {
    curName = name;
    const mi = maps.find(m => m.name === name);
    if (!mi) return;
    // default center: map middle; player: spawn point if this map has one
    if (!location.hash.match(/c=/)) { cx = Math.floor(mi.w / 2); cy = Math.floor(mi.h / 2); }
    const maxZ = mi.ladder.length - 1;
    const minZ = mi.ladder[0] ?? 0;   // server clamps z up to ladder[0]; client must match
    z = Math.min(Math.max(z, minZ), maxZ);
    loadEntities(mi);
    loadCat(mi);
    loadThumb();
    loadImg();
    loadMini();
    updateHash();
}
async function loadEntities(mi) {
    ents = []; target = null;
    const box = document.getElementById("ents");
    box.innerHTML = "";
    try {
        const res = await fetch("/api/entities?map=" + encodeURIComponent(mi.name));
        const d = await res.json();
        if (d.ok) ents = d.entities;
    } catch (e) { ents = []; }
    const spawn = ents.find(e => e.kind === "spawn");
    if (spawn) player = { x: spawn.x, y: spawn.y };
    else player = { x: Math.floor(mi.w / 2), y: Math.floor(mi.h / 2) };
    renderEnts();
}
function renderEnts() {
    const mi = maps.find(m => m.name === curName);
    const box = document.getElementById("ents");
    box.innerHTML = "";
    const s = 1 << z;
    const cxw = cx * 48 + 24, cyw = cy * 32 + 16;
    // visible filter: cell within screen + margin
    const visX = 800 / 48 * s + 2, visY = 600 / 32 * s + 2;
    const all = [{ x: player.x, y: player.y, kind: "player", name: "玩家", info: "" }];
    for (const e of ents) {
        if (e.kind === "spawn") continue;   // spawn point is the player start, not an entity
        all.push(e);
    }
    for (const e of all) {
        if (Math.abs(e.x - cx) > visX || Math.abs(e.y - cy) > visY) continue;
        const st = entStyle[e.kind];
        const div = document.createElement("div");
        div.className = "ent " + e.kind;
        if (target && target.x === e.x && target.y === e.y && target.kind === e.kind) div.classList.add("target");
        div.style.left = (400 + (e.x * 48 + 24 - cxw) / s) + "px";
        div.style.top = (300 + (e.y * 32 + 16 - cyw) / s) + "px";
        const img = document.createElement("img");
        img.src = st.src; img.alt = "";
        div.appendChild(img);
        const tag = document.createElement("div");
        tag.className = "tag";
        tag.textContent = (e.kind === "player" ? "我" : (e.name || e.kind));
        div.appendChild(tag);
        const info = document.createElement("div");
        info.className = "info";
        let t = e.kind === "player" ? "玩家" : (e.kind === "npc" ? "NPC" : "怪物");
        info.innerHTML = `<b>${t}</b> ${e.name || ""}<br>格 ${e.x},${e.y}${e.kind === "npc" ? " · face " + (e.face ?? 0) + " · body " + (e.body ?? 0) : ""}${e.kind === "monster" ? " · Lv " + (e.level ?? 0) + (e.count && e.count > 1 ? " · ×" + e.count : "") : ""}`;
        if (e.kind === "monster" && Array.isArray(e.drops) && e.drops.length) {
            const fmtCh = (d) => (d.chance < 1 ? "1/" + Math.round(1 / d.chance) : "1/1");
            const top = e.drops.slice(0, 5).map(d => `${d.item}${d.count > 1 ? "×" + d.count : ""}(${fmtCh(d)})`).join(" ");
            info.innerHTML += `<br><span style="color:#ffd27f;">掉落: ${top}${e.drops.length > 5 ? " …" : ""}</span>`;
        }
        div.appendChild(info);
        div.addEventListener("click", () => {
            target = { x: e.x, y: e.y, kind: e.kind, name: e.name };
            renderEnts(); renderHud(); renderMiniBox();
        });
        box.appendChild(div);
    }
    renderMiniBox();
}
function renderMiniBox() {
    const mi = maps.find(m => m.name === curName);
    const bb = document.getElementById("mm-box");
    if (!mi) { bb.style.display = "none"; return; }
    const size = 128;   // fixed display size; `mm` = render surface (128/256)
    const bw = Math.max(3, 128 / mi.w * size), bh = Math.max(3, 128 / mi.h * size);
    const px = player.x / mi.w * size, py = player.y / mi.h * size;
    bb.style.display = "block";
    bb.style.width = bw + "px"; bb.style.height = bh + "px";
    bb.style.left = (px - bw / 2) + "px"; bb.style.top = (py - bh / 2) + "px";
}
async function loadCat(mi) {
    try {
        const res = await fetch("/api/catalog?map=" + encodeURIComponent(mi.name));
        const d = await res.json();
        cat = d.ok ? d.catalog : null;
    } catch (e) { cat = null; }
    renderHud();
}
function loadImg() {
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    const s = 1 << z;
    const onload = () => {
        // center world px on stage center (400, 300)
        const cxw = cx * 48 + 24, cyw = cy * 32 + 16;   // rect anchor
        const left = 400 - cxw / s, top = 300 - cyw / s;
        wimg.style.left = left + "px";
        wimg.style.top = top + "px";
        renderHud();
    };
    wimg.onload = onload;
    wimg.src = "/fullmap?map=" + encodeURIComponent(mi.name) + "&z=" + z +
               "&g=" + (document.getElementById("chk-g").checked ? 1 : 0) +
               "&m=" + (document.getElementById("chk-m").checked ? 1 : 0) +
               "&f=" + (document.getElementById("chk-f").checked ? 1 : 0) +
               "&om=" + selOff.value;
}
function loadMini() {
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    mimg.src = "/minimap?map=" + encodeURIComponent(mi.name);
    mmName.textContent = (mi.cn || "") + " " + mi.name;
}
function renderHud() {
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    hudMap.textContent = (mi.cn || "") + " " + mi.name + " | 中心格 " + cx + "," + cy + " | 缩放 1:" + (1 << z);
    selCell.textContent = cx + "," + cy;
    if (cat) {
        const ev = (cat.evidence && cat.evidence.level) || "derived";
        let s = `主题 ${cat.theme_name || "base"} · ${cat.w}×${cat.h} · ${cat.cell_bytes}B/格 · 证据 ${ev}`;
        const gl = Object.keys(cat.ground || {}).length;
        const ml = Object.keys(cat.mid || {}).length;
        const fl = Object.keys(cat.front || {}).length;
        s += ` · 库 g${gl}/m${ml}/f${fl}`;
        if (cat.animated_cells) s += " · 动画格 " + cat.animated_cells;
        if (target) s += ` · 目标: ${target.kind === "npc" ? "NPC" : target.kind === "monster" ? "怪物" : "玩家"} ${target.name || ""} @${target.x},${target.y}`;
        hudStats.textContent = s;
        hudOob.textContent = cat.anomaly_total ? `⚠ ${cat.anomaly_total} 帧越界 (${Object.keys(cat.anomalies || {}).length} 项)` : "";
    } else {
        hudStats.textContent = "（无 catalog 数据）";
        hudOob.textContent = "";
    }
    const scale = mm === 128 ? "128" : "256";
    mmZoom.textContent = scale;
    document.getElementById("hud").style.display = showHud ? "block" : "none";
}
function move(dx, dy) {
    cx += dx; cy += dy;
    const mi = maps.find(m => m.name === curName);
    if (mi) { cx = Math.max(0, Math.min(cx, mi.w - 1)); cy = Math.max(0, Math.min(cy, mi.h - 1)); }
    loadImg();
    renderEnts();
    updateHash();
}
function updateHash() {
    history.replaceState(null, "", `#sim=${encodeURIComponent(curName)}&c=${cx},${cy}&z=${z}&om=${selOff.value}`);
}
selMap.addEventListener("change", () => { cx = Math.floor((maps.find(m => m.name === selMap.value) || {}).w / 2) || 0;
    cy = Math.floor((maps.find(m => m.name === selMap.value) || {}).h / 2) || 0; pick(selMap.value); });
document.getElementById("chk-g").addEventListener("change", loadImg);
document.getElementById("chk-m").addEventListener("change", loadImg);
document.getElementById("chk-f").addEventListener("change", loadImg);
selOff.addEventListener("change", () => { updateHash(); loadImg(); });
document.getElementById("btn-strip").addEventListener("click", () => {
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    const g = document.getElementById("chk-g").checked ? 1 : 0;
    const m = document.getElementById("chk-m").checked ? 1 : 0;
    const f = document.getElementById("chk-f").checked ? 1 : 0;
    window.open("/strip?map=" + encodeURIComponent(mi.name) + "&z=2&g=" + g + "&m=" + m + "&f=" + f, "_blank");
});
function loadThumb() {
    const mi = maps.find(m => m.name === curName);
    const t = document.getElementById("map-thumb");
    if (!mi) { t.style.display = "none"; return; }
    t.src = "/thumb?map=" + encodeURIComponent(mi.name);
    t.style.display = "inline-block";
}
document.getElementById("btn-hud").addEventListener("click", () => { showHud = !showHud; renderHud(); });
document.getElementById("btn-mm").addEventListener("click", () => { mm = mm === 128 ? 256 : 128; renderHud(); });
document.getElementById("btn-back").addEventListener("click", () => { location.href = "/"; });
window.addEventListener("keydown", (e) => {
    const k = e.key;
    if (k === "ArrowLeft" || k === "a" || k === "A") move(-1, 0);
    else if (k === "ArrowRight" || k === "d" || k === "D") move(1, 0);
    else if (k === "ArrowUp" || k === "w" || k === "W") move(0, -1);
    else if (k === "ArrowDown" || k === "s" || k === "S") move(0, 1);
    else if (k === "t" || k === "T") { mm = mm === 128 ? 256 : 128; renderHud(); }
    else if (k === "h" || k === "H") { showHud = !showHud; renderHud(); }
    else return;
    e.preventDefault();
});
window.addEventListener("wheel", (e) => {
    if (!e.ctrlKey) return;
    e.preventDefault();
    const mi = maps.find(m => m.name === curName);
    if (!mi) return;
    const maxZ = mi.ladder.length - 1;
    const minZ = mi.ladder[0] ?? 0;
    if (e.deltaY < 0 && z > minZ) z--;
    else if (e.deltaY > 0 && z < maxZ) z++;
    else return;
    loadImg(); renderEnts(); updateHash();
}, { passive: false });

// hover: cell under cursor -> /api/cell (per-layer file/frame/flag/animation)
const cellInfo = document.getElementById("cell-info");
let cellTimer = null;
wimg.addEventListener("mousemove", (e) => {
    if (!curName) return;
    const s = 1 << z;
    const wx = Math.floor(e.offsetX * s / 48);
    const wy = Math.floor(e.offsetY * s / 32);
    if (wx < 0 || wy < 0) { cellInfo.style.display = "none"; return; }
    clearTimeout(cellTimer);
    cellTimer = setTimeout(async () => {
        try {
            const r = await fetch("/api/cell?map=" + encodeURIComponent(curName) +
                                  "&x=" + wx + "&y=" + wy);
            const d = await r.json();
            if (!d.ok) { cellInfo.style.display = "none"; return; }
            const fmt = (o) => o.frame !== undefined ? `${o.frame}` : "—";
            cellInfo.textContent =
                `格 ${d.x},${d.y}  flag=${d.flag} anim=${d.anim[0]},${d.anim[1]}\n` +
                `Back  : ${d.back.lib} [${d.back.file}] f${fmt(d.back)}\n` +
                `Middle: ${d.mid.lib} [${d.mid.file}] f${fmt(d.mid)}\n` +
                `Front : ${d.front.lib} [${d.front.file}] f${fmt(d.front)}`;
            cellInfo.style.left = Math.min(e.clientX + 14, window.innerWidth - 260) + "px";
            cellInfo.style.top = Math.max(6, e.clientY - 90) + "px";
            cellInfo.style.display = "block";
        } catch (_) { cellInfo.style.display = "none"; }
    }, 60);
});
wimg.addEventListener("mouseleave", () => { cellInfo.style.display = "none"; });
init();
</script>
</body>
</html>
"""

HTML_TEMPLATE = """<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <title>Zircon / Mir3 EI 地图浏览器</title>
    <link rel="stylesheet" href="/_webui/tokens.css">
    <link rel="stylesheet" href="/_webui/mobile-shell.css">
    <script src="/_webui/gesture.js?v=2"></script>
    <style>
        body { margin:0; padding:0; background:#111; color:#eee; font-family:sans-serif; overflow:hidden; user-select:none; }
        #toolbar { height:40px; background:#222; display:flex; align-items:center; padding:0 10px; gap:10px; border-bottom:1px solid #333; }
        #viewport { position:absolute; top:40px; left:0; right:0; bottom:0; overflow:auto; background:#0b0b0f; cursor:grab; }
        #viewport.dragging { cursor:grabbing; }
        #map-img { display:block; background:#000; }
        #grid-canvas { position:absolute; top:40px; left:0; pointer-events:none; }
        #route-svg { position:absolute; pointer-events:none; z-index:4; overflow:visible; }
        #ent-layer { position:absolute; pointer-events:none; z-index:5; overflow:visible; }
        #tile-layer { position:absolute; left:0; top:0; z-index:1; pointer-events:none; }
        #tile-layer img { position:absolute; image-rendering:pixelated; }
        #ent-layer .ent { position:absolute; transform:translate(-50%,-100%); text-align:center; cursor:default; }
        #ent-layer .ent .ent-icon { display:block; width:28px; height:28px; margin:0 auto; image-rendering:pixelated; }
        #ent-layer .ent .ent-label { font-size:11px; color:#fff; text-shadow:0 1px 2px #000, 0 0 3px #000; background:rgba(0,0,0,.45); border-radius:2px; padding:0 3px; white-space:nowrap; }
        #ent-layer .ent.npc .ent-icon { filter:drop-shadow(0 0 3px rgba(114,214,255,.8)); }
        #ent-layer .ent.spawn .ent-icon { filter:drop-shadow(0 0 3px rgba(255,213,74,.9)); }
        #ent-layer .ent.npc .ent-label { color:#8cf; }
        #ent-layer .ent.spawn .ent-label { color:#ffd54a; }
        #cat-panel { position:fixed; left:10px; bottom:10px; width:330px; max-height:46vh; overflow:auto;
            background:rgba(10,12,16,.92); border:1px solid #3a3a46; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; z-index:60; display:none; line-height:1.45; }
        #cat-panel h4 { margin:0 0 6px; font-size:13px; color:#ffd54a; }
        #cat-panel .row { display:flex; justify-content:space-between; gap:10px; }
        #cat-panel .k { color:#8a8a98; }
        #cat-panel .v { color:#e8e8f0; font-family:ui-monospace,monospace; }
        #cat-panel .warn { color:#ff8f6b; }
        #cat-panel .lib { font-family:ui-monospace,monospace; }
        #cat-panel .lib .oob { color:#ff8f6b; }
        #cat-panel::-webkit-scrollbar { width:8px; } #cat-panel::-webkit-scrollbar-thumb { background:#3a3a44; border-radius:4px; }
        #conn-panel { position:fixed; left:10px; top:50px; width:300px; max-height:60vh; overflow:auto;
            background:rgba(10,12,16,.92); border:1px solid #3a3a46; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; z-index:70; display:none; line-height:1.5; }
        #conn-panel h4 { margin:0 0 6px; font-size:13px; color:#3de88a; }
        #conn-panel .conn-row { display:flex; gap:8px; align-items:baseline; padding:2px 0; }
        #conn-panel .conn-row.link { cursor:pointer; }
        #conn-panel .conn-row.link:hover { background:#2a2e38; border-radius:3px; }
        #conn-panel .conn-name { color:#e8e8f0; flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
        #conn-panel .conn-dir { color:#ffd54a; font-family:ui-monospace,monospace; font-size:11px; }
        #conn-panel .conn-file { color:#6a6a75; font-family:ui-monospace,monospace; font-size:11px; }
        #conn-panel .conn-empty { color:#6a6a75; }
        #conn-panel::-webkit-scrollbar { width:8px; } #conn-panel::-webkit-scrollbar-thumb { background:#3a3a44; border-radius:4px; }
        #info { font-size:12px; color:#aaa; white-space:nowrap; }
        #status { margin-left:auto; font-size:12px; color:#e90; white-space:nowrap; }
        button { font-size:14px; min-width:32px; padding:4px 9px; white-space:nowrap; cursor:pointer; background:#333; color:#eee; border:1px solid #555; border-radius:3px; }
        button:disabled { opacity:.35; cursor:default; }
        label { font-size:13px; cursor:pointer; white-space:nowrap; }
        #minimap { position:fixed; top:48px; right:10px; background:rgba(0,0,0,.75); border:1px solid #444; border-radius:4px; padding:4px; z-index:50; box-shadow:0 2px 8px rgba(0,0,0,.5); }
        #minimap .mm-title { font-size:11px; color:#aaa; margin-bottom:3px; }
        #mm-box { position:relative; cursor:crosshair; }
        #mm-img { display:block; width:172px; background:#000; border-radius:2px; }
        #mm-rect { position:absolute; border:1.5px solid #ffd54a; background:rgba(255,213,74,.10); pointer-events:none; }
        #statusbar { position:fixed; right:10px; bottom:8px; background:rgba(0,0,0,.78); border:1px solid #3a3a46;
            border-radius:5px; padding:5px 11px; font-size:12px; color:#c8c8d2; z-index:90; display:flex; gap:14px;
            font-family:ui-monospace,monospace; pointer-events:none; }
        #statusbar #coord-info { color:#8cf; }
        #statusbar #zoom-info { color:#ffd54a; }
        #statusbar #map-info { color:#9a9; }
        #legend-panel { position:fixed; left:10px; bottom:38px; background:rgba(10,12,16,.92); border:1px solid #3a3a46;
            border-radius:6px; padding:9px 12px; font-size:12px; color:#c8c8d2; z-index:80; line-height:1.7; }
        #legend-panel .lg-row { display:flex; align-items:center; gap:8px; }
        #legend-panel .lg-dot { width:11px; height:11px; border-radius:50%; display:inline-block; }
        #port-tooltip { position:fixed; background:rgba(10,12,16,.95); border:1px solid #3de88a; border-radius:6px;
            padding:8px 10px; font-size:12px; color:#e8e8f0; z-index:120; pointer-events:none; max-width:240px; line-height:1.5;
            box-shadow:0 4px 16px rgba(0,0,0,.6); }
        #port-tooltip img { display:block; max-width:200px; margin:4px auto 0; border-radius:3px; border:1px solid #333; }
        #ent-tooltip { position:fixed; background:rgba(10,12,16,.95); border:1px solid #72d6ff; border-radius:5px;
            padding:5px 9px; font-size:12px; color:#cfe; z-index:120; pointer-events:none; box-shadow:0 3px 12px rgba(0,0,0,.6); }
        /* custom map selector */
        .msel { position:relative; }
        #map-sel-btn { display:flex; align-items:center; gap:8px; min-width:180px; max-width:260px; background:#2b2b31;
            color:#eee; border:1px solid #4a4a55; border-radius:4px; padding:4px 9px; cursor:pointer; font-size:13px; }
        #map-sel-btn:hover { background:#34343b; border-color:#5c5c6a; }
        #map-sel-label { flex:1; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; text-align:left; }
        .msel-caret { color:#8a8a95; font-size:10px; }
        .msel-pop { position:absolute; top:calc(100% + 4px); left:0; min-width:280px; max-width:380px; background:#232329;
            border:1px solid #4a4a55; border-radius:6px; box-shadow:0 8px 24px rgba(0,0,0,.6); z-index:100; overflow:hidden; }
        #map-sel-filter { width:100%; box-sizing:border-box; padding:7px 9px; background:#1c1c21; color:#eee;
            border:none; border-bottom:1px solid #3a3a44; outline:none; font-size:13px; }
        #map-sel-filter::placeholder { color:#6a6a75; }
        .msel-list { max-height:340px; overflow-y:auto; }
        .msel-item { padding:6px 10px; cursor:pointer; font-size:13px; color:#d5d5dd; display:flex; gap:8px; align-items:baseline; }
        .msel-item .msel-cn { color:#9a9aa5; }
        .msel-item:hover, .msel-item.active { background:#3a3a44; color:#fff; }
        .msel-item.empty { color:#6a6a75; cursor:default; }
        .msel-item.empty:hover { background:none; }
        .msel-cat { padding:5px 12px 3px; font-size:11px; color:#8bc34a; font-weight:600; border-bottom:1px solid #2e2e36; background:#1e1e24; position:sticky; top:0; }
        .msel-list::-webkit-scrollbar { width:8px; }
        .msel-list::-webkit-scrollbar-thumb { background:#3a3a44; border-radius:4px; }

        /* Toast Notifications */
        #toast-container { position:fixed; top:54px; right:20px; z-index:999999; display:flex; flex-direction:column; gap:10px; pointer-events:none; }
        .toast { pointer-events:auto; background:rgba(22, 26, 36, 0.95); border:1px solid #3de88a; border-left:4px solid #3de88a; border-radius:6px; padding:12px 16px; box-shadow:0 8px 24px rgba(0,0,0,0.5); backdrop-filter:blur(8px); min-width:280px; max-width:420px; transform:translateX(120%); transition:transform 0.35s cubic-bezier(0.18, 0.89, 0.32, 1.28), opacity 0.35s; opacity:0; }
        .toast.show { transform:translateX(0); opacity:1; }
        .toast-title { font-size:14px; font-weight:600; color:#3de88a; margin-bottom:4px; display:flex; align-items:center; gap:6px; }
        .toast-body { font-size:12px; color:#c5c5d0; line-height:1.4; word-break:break-all; }

        /* Custom Modal Dialog */
        #custom-modal-overlay { display:none; position:fixed; top:0; left:0; width:100vw; height:100vh; background:rgba(0,0,0,0.7); backdrop-filter:blur(4px); z-index:999999; align-items:center; justify-content:center; }
        .modal-card { background:#1e222d; border:1px solid #3de88a; border-radius:8px; width:400px; max-width:90vw; padding:20px; box-shadow:0 12px 32px rgba(0,0,0,0.7); display:flex; flex-direction:column; gap:14px; }
        .modal-header { font-size:16px; font-weight:600; color:#3de88a; display:flex; align-items:center; gap:8px; }
        .modal-body { font-size:13px; color:#ccc; line-height:1.5; }
        .modal-actions { display:flex; justify-content:flex-end; gap:10px; margin-top:6px; }
        .btn-modal { padding:6px 16px; font-size:13px; border-radius:4px; cursor:pointer; font-weight:500; }
        .btn-modal-cancel { background:#2a2e3a; color:#aaa; border:1px solid #444; }
        .btn-modal-cancel:hover { background:#343948; color:#eee; }
        .btn-modal-confirm { background:#183828; color:#85ffc7; border:1px solid #3de88a; }
        .btn-modal-confirm:hover { background:#1f4834; }

        /* Spinner & Overlay */
        @keyframes spin { 0% { transform:rotate(0deg); } 100% { transform:rotate(360deg); } }
        #loading-overlay { display:none; position:fixed; top:0; left:0; width:100vw; height:100vh;
            background:rgba(12, 14, 18, 0.85); backdrop-filter:blur(6px); -webkit-backdrop-filter:blur(6px);
            z-index:99999; flex-direction:column; align-items:center; justify-content:center; color:#fff; }
        .spinner { width:52px; height:52px; border:4px solid rgba(61,232,138,0.15); border-top-color:#3de88a;
            border-radius:50%; animation:spin 0.8s linear infinite; box-shadow:0 0 16px rgba(61,232,138,0.3); }

        /* ---- 地图工坊六大增强 ---- */
        #view-tabs { display:flex; gap:2px; background:#1a1a20; border:1px solid #3a3a46; border-radius:5px; padding:2px; }
        .vtab { font-size:12px; min-width:0; padding:3px 9px; border-radius:4px; background:transparent; border:none; color:#9a9aa5; }
        .vtab.active { background:#2f6a44; color:#d2ffe4; }
        #heat-canvas { position:absolute; top:0; left:0; pointer-events:none; z-index:3; }
        #quest-svg, #pick-svg { position:absolute; left:0; top:0; pointer-events:none; z-index:4; overflow:visible; }
        #route-svg circle.port { pointer-events:auto; cursor:pointer; }   /* 父层 pointer-events:none 会继承，出口圆点需显式恢复 */
        @keyframes qpulse { 0% { r:6; opacity:1; } 50% { r:11; opacity:.55; } 100% { r:6; opacity:1; } }
        #quest-svg circle.qkill { animation:qpulse 1.2s ease-in-out infinite; }
        #heat-tooltip { position:fixed; background:rgba(10,12,16,.95); border:1px solid #ff8f6b; border-radius:6px;
            padding:6px 9px; font-size:12px; color:#ffe; z-index:130; pointer-events:none; max-width:280px;
            line-height:1.6; box-shadow:0 4px 16px rgba(0,0,0,.6); display:none; }
        #quest-panel { position:fixed; right:10px; top:250px; width:250px; max-height:44vh; overflow:auto;
            background:rgba(10,12,16,.92); border:1px solid #ffd54a; border-radius:6px; padding:8px 10px;
            font-size:12px; color:#c8c8d2; z-index:75; display:none; line-height:1.5; }
        #quest-panel h4 { margin:0 0 6px; font-size:13px; color:#ffd54a; }
        #quest-panel .qstep { margin:4px 0; padding:4px 6px; border-left:3px solid #555; background:#171922; border-radius:3px; }
        #quest-panel .qstep.kill { border-color:#ff5b5b; }
        #quest-panel .qstep.visit { border-color:#ffd54a; }
        #quest-panel .qstep.item { border-color:#e8963d; }
        #quest-panel .qstep.current { background:#26314a; border-left-color:#72d6ff; box-shadow:0 0 0 1px #72d6ff inset; }
        #quest-panel .qstep .qplay { float:right; background:#1d3a4a; border:1px solid #72d6ff; color:#cfe;
            border-radius:3px; cursor:pointer; font-size:11px; padding:1px 7px; }
        #quest-panel .qstep .qplay:hover { background:#2a4a5e; }
        #quest-panel .qnav { display:flex; gap:6px; margin:8px 0 4px; }
        #quest-panel .qnav button { flex:1; font-size:12px; padding:4px 0; }
        #quest-panel .qmap { color:#8cf; cursor:pointer; text-decoration:underline; padding:1px 0; display:inline-block; }
        #quest-panel .qmap:hover { color:#bff; }
        #pick-panel { position:fixed; left:10px; bottom:64px; background:rgba(10,12,16,.93); border:1px solid #72d6ff;
            border-radius:6px; padding:8px 12px; font-size:13px; color:#cfe; z-index:85; display:none;
            font-family:ui-monospace,monospace; line-height:1.7; box-shadow:0 4px 12px rgba(0,0,0,.5); }
        #pick-panel .pick-copy { font-size:12px; padding:2px 10px; margin-left:8px; background:#1d3a4a; border-color:#72d6ff; color:#cfe; }
        #pick-panel .pick-dist { color:#ffd54a; }
        #pick-panel .pick-hint { color:#6a6a75; font-size:11px; }
        #overview-view, #graph-view { position:absolute; top:40px; left:0; right:0; bottom:0; overflow:auto;
            background:#0b0b0f; display:none; padding:12px; }
        #ov-filters { display:flex; gap:6px; flex-wrap:wrap; align-items:center; margin-bottom:10px; position:sticky; top:0;
            background:#0b0b0f; padding:6px 0; z-index:5; }
        .ov-chip { font-size:12px; padding:3px 11px; border-radius:12px; background:#232329; color:#aaa;
            border:1px solid #3a3a46; cursor:pointer; }
        .ov-chip.active { background:#2f6a44; color:#d2ffe4; border-color:#3de88a; }
        #ov-grid { display:grid; grid-template-columns:repeat(auto-fill, minmax(148px, 1fr)); gap:10px; }
        .ov-card { background:#15161c; border:1px solid #2a2b33; border-radius:6px; overflow:hidden; cursor:pointer; }
        .ov-card:hover { border-color:#5a8f6a; }
        .ov-thumb { position:relative; aspect-ratio:4/3; background:#0d0e12; display:flex; align-items:center;
            justify-content:center; overflow:hidden; }
        .ov-thumb img { width:100%; height:100%; object-fit:contain; image-rendering:pixelated; }
        .ov-thumb .ph { color:#3c3d46; font-size:22px; }
        .ov-thumb .ov-crown { position:absolute; top:3px; right:5px; font-size:14px; text-shadow:0 1px 2px #000; }
        .ov-thumb .ov-nofile { position:absolute; bottom:2px; left:4px; font-size:10px; color:#e8963d; }
        .ov-name { font-size:12px; color:#e8e8f0; padding:4px 7px 1px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }
        .ov-name .ov-id { color:#6a6a75; font-family:ui-monospace,monospace; font-size:10px; }
        .ov-meta { font-size:10.5px; color:#8a8a98; padding:0 7px 5px; }
        .ov-meta .lv { font-weight:600; }
        .tier-low { color:#8fce8f; } .tier-mid { color:#e8d95a; } .tier-high { color:#f0a05a; }
        .tier-max { color:#f07575; } .tier-none { color:#7a7a85; }
        .ov-card .ov-bar { height:3px; }
        .bar-low { background:#7a9a78; } .bar-mid { background:#d9c34a; } .bar-high { background:#e8963d; }
        .bar-max { background:#e05555; } .bar-none { background:#3a3a44; }
        #ov-audit { margin-top:16px; }
        #ov-audit h3 { color:#3de88a; font-size:14px; margin:12px 0 6px; }
        #audit-table { width:100%; border-collapse:collapse; font-size:12px; background:#13141a; border-radius:6px; }
        #audit-table th, #audit-table td { padding:5px 9px; border-bottom:1px solid #23242c; text-align:left; }
        #audit-table th { color:#8a8a98; font-weight:600; position:sticky; top:0; background:#1a1b22; }
        .audit-miss { color:#ff5b5b; font-weight:700; }
        .audit-ok { color:#8fce8f; }
        #graph-view svg { display:block; }
        #graph-stats { font-size:12px; color:#8a8a98; margin-bottom:6px; }
        #graph-stats b { color:#e8e8f0; }
        #graph-stats .g-isl { color:#ff5b5b; } #graph-stats .g-cut { color:#ffd54a; }
        .gnode { cursor:pointer; } .gnode text { font-size:9px; fill:#9a9aa5; paint-order:stroke; stroke:#0b0b0f; stroke-width:2px; }
        #legend-panel .lg-block { display:inline-block; width:14px; height:9px; border-radius:2px; margin-right:6px; vertical-align:middle; }
        /* ---- 移动端共享壳接入（桌面 fine-pointer/宽屏零影响，Goal MAP-P0-01） ---- */
        #layer-group { display:contents; }            /* 桌面：包裹不改变工具栏 flex 布局 */
        #layer-group .lg-title { display:none; }
        #btn-layers { display:none; }
        @media (max-width:640px) {
            html, body { height:100%; }
            body { display:flex; flex-direction:column; height:100dvh; }
            #toolbar { position:static; height:auto; min-height:44px; flex:none; order:0;
                       flex-wrap:wrap; padding:6px 8px; gap:6px 8px; }
            #map-lbl { display:none; }
            #viewport, #overview-view, #graph-view {
                position:relative; top:auto; left:auto; right:auto; bottom:auto;
                flex:1 1 auto; order:1; min-height:0;
                margin-bottom:calc(54px + var(--safe-bottom,0px));
            }
            /* 视图切换 → 底部导航（≥44px 触控目标） */
            #view-tabs { position:fixed; left:0; right:0; bottom:0; z-index:95; margin:0;
                         background:rgba(16,18,24,.97); border-top:1px solid #3a3a46;
                         border-radius:0; padding:4px 6px calc(4px + var(--safe-bottom,0px)); }
            .vtab { flex:1; min-height:48px; font-size:13px; border-radius:8px; }
            /* 图层/任务/图例控件 → 底部抽屉 */
            #btn-layers { display:inline-flex; align-items:center; gap:4px; }
            #layer-group { display:none; position:fixed; left:0; right:0; bottom:0; z-index:96;
                           max-height:70dvh; overflow-y:auto; flex-wrap:wrap; gap:8px 10px; align-items:center;
                           background:rgba(16,18,24,.98); border-top:1px solid #3a3a46;
                           border-radius:14px 14px 0 0; padding:12px 14px calc(14px + var(--safe-bottom,0px)); }
            #layer-group.open { display:flex; }
            #layer-group .lg-title { display:block; flex-basis:100%; color:#ffd54a; font-size:13px; }
            .msel-pop { min-width:240px; max-width:calc(100vw - 24px); }
            /* 固定面板收口：不允许超出 390px 视口 */
            #cat-panel, #conn-panel, #quest-panel, #legend-panel, #pick-panel, #statusbar {
                max-width:calc(100vw - 20px); }
            #cat-panel   { width:auto; bottom:calc(60px + var(--safe-bottom,0px)); }
            #legend-panel{ bottom:calc(60px + var(--safe-bottom,0px)); }
            #pick-panel  { bottom:calc(60px + var(--safe-bottom,0px)); }
            #conn-panel  { top:calc(52px + var(--safe-top,0px)); }
            #quest-panel { top:auto; right:8px; bottom:calc(60px + var(--safe-bottom,0px)); max-height:40dvh; }
            #statusbar   { bottom:calc(58px + var(--safe-bottom,0px)); right:8px; flex-wrap:wrap; gap:4px 10px; }
            #toast-container { top:calc(52px + var(--safe-top,0px)); right:8px; left:8px; }
            .toast { min-width:0; max-width:100%; }
            #minimap { display:none; }
            #overview-view { padding:6px; }
            #ov-grid { grid-template-columns:repeat(auto-fill, minmax(108px, 1fr)); gap:6px; }
        }
        @media (pointer:coarse) {
            #viewport { touch-action:none; }   /* 手势由 gesture.js 接管（MAP-P0-02） */
            #toolbar button, #toolbar select { min-height:44px; }
            #toolbar label { min-height:44px; display:inline-flex; align-items:center; padding:0 6px; }
            .ov-chip { min-height:40px; display:inline-flex; align-items:center; }
        }
    </style>
</head>
<body class="wu-shell">
    <!-- Toast 通知容器 -->
    <div id="toast-container"></div>

    <!-- 自定义 Modal 对话框 -->
    <div id="custom-modal-overlay">
        <div class="modal-card">
            <div class="modal-header" id="modal-title">⚡ 提示</div>
            <div class="modal-body" id="modal-msg">确定要进行此操作吗？</div>
            <div class="modal-actions">
                <button class="btn-modal btn-modal-cancel" id="btn-modal-cancel">取消</button>
                <button class="btn-modal btn-modal-confirm" id="btn-modal-confirm">确认</button>
            </div>
        </div>
    </div>

    <!-- 全屏客户端切换加载蒙版遮罩 -->
    <div id="loading-overlay">
        <div class="spinner"></div>
        <div id="loading-title" style="margin-top:18px; font-size:17px; font-weight:600; color:#3de88a; letter-spacing:0.5px;">正在切换客户端资源库…</div>
        <div id="loading-detail" style="margin-top:8px; font-size:13px; color:#aaa; font-family:monospace;">正在加载新客户端数据...</div>
    </div>

    <div id="toolbar">
        <div id="view-tabs" title="视图切换">
            <button class="vtab active" data-view="map" type="button">🗺️ 地图</button>
            <button class="vtab" data-view="overview" type="button">📋 总览</button>
            <button class="vtab" data-view="graph" type="button">🕸️ 连通</button>
        </div>
        <span id="map-lbl">🗺️ 地图:</span>
        <div class="msel" id="map-sel">
            <button id="map-sel-btn" type="button" title="选择地图">
                <span id="map-sel-label">加载中…</span><span class="msel-caret">▾</span>
            </button>
            <div class="msel-pop" id="map-sel-pop" hidden>
                <input id="map-sel-filter" type="text" placeholder="搜索地图文件名或中文名…" autocomplete="off">
                <div class="msel-list" id="map-sel-list"></div>
            </div>
        </div>
        <button id="btn-zoom-in" title="放大 (+)">＋</button>
        <button id="btn-zoom-out" title="缩小 (-)">－</button>
        <button id="btn-fit" title="适配全图窗口大小">⛶ 适配</button>
        <button id="btn-layers" type="button" title="图层与叠加">☰ 图层</button>
        <div id="layer-group">
            <div class="lg-title">图层 / 叠加</div>
        <label><input type="checkbox" id="chk-g" checked> Back</label>
        <label><input type="checkbox" id="chk-m" checked> Middle</label>
        <label><input type="checkbox" id="chk-f" checked> Front</label>
        <label><input type="checkbox" id="chk-grid"> 网格</label>
        <label><input type="checkbox" id="chk-ents" checked title="显示 NPC/传送点"> NPC</label>
        <label><input type="checkbox" id="chk-resp" title="怪物刷新热力图层"> 怪物刷新</label>
        <select id="quest-sel" title="任务叠加模式" style="max-width:170px; font-size:12px; background:#2b2b31; color:#eee; border:1px solid #4a4a55; border-radius:4px; padding:3px 5px;">
            <option value="">📜 任务叠加…</option>
        </select>
        <button id="btn-legend" title="图例说明">❓</button>
        </div>
        <span id="status"></span>

        <!-- 后台预生成实时进度条 -->
        <div id="progress-box" style="display:none; background:#141d18; border:1px solid #3de88a; border-radius:6px; padding:3px 10px; font-size:12px; color:#3de88a; align-items:center; gap:8px;">
            <span>⚡ 预生成:</span>
            <div style="width:140px; height:8px; background:#2a2e38; border-radius:4px; overflow:hidden;">
                <div id="progress-bar-fill" style="width:0%; height:100%; background:linear-gradient(90deg, #3de88a, #e8a33d); transition:width 0.3s;"></div>
            </div>
            <span id="progress-text" style="font-family:monospace;">0% (0/0)</span>
        </div>

        <button id="btn-clear-cache" style="background:#4a2e18; border-color:#e8a33d; color:#ffd899;" title="清除全部缓存并重新生成">🔄 重新生成</button>
    </div>
    <div id="layer-backdrop" class="wu-backdrop"></div>
    <div id="viewport"><img id="map-img" draggable="false" alt=""><div id="tile-layer"></div><svg id="route-svg" aria-hidden="true"></svg><canvas id="heat-canvas" width="0" height="0"></canvas><svg id="quest-svg" aria-hidden="true"></svg><svg id="pick-svg" aria-hidden="true"></svg><canvas id="grid-canvas" width="0" height="0"></canvas><div id="ent-layer"></div></div>
    <div id="overview-view">
        <div id="ov-filters">
            <span style="color:#8a8a98;">📋 全库地图总览</span>
            <span class="ov-chip active" data-f="all">全部</span>
            <span class="ov-chip" data-f="town">城镇</span>
            <span class="ov-chip" data-f="cave">洞穴</span>
            <span class="ov-chip" data-f="boss">👑 BOSS</span>
            <span class="ov-chip" data-f="hasmob">有怪</span>
            <span class="ov-chip active" data-c="lvl">按等级染色</span>
            <span class="ov-chip" data-c="npc">按 NPC 数染色</span>
        </div>
        <div id="ov-grid"></div>
        <div id="ov-audit"><h3>🏪 NPC 功能覆盖审计</h3><div id="audit-table-box">加载中…</div></div>
    </div>
    <div id="graph-view">
        <div id="graph-stats">加载连通图谱中…</div>
        <div id="graph-box"></div>
    </div>
    <div id="cat-panel"></div>
    <div id="conn-panel"></div>
    <div id="minimap">
        <div class="mm-title">全图</div>
        <div id="mm-box"><img id="mm-img" draggable="false" alt=""><div id="mm-rect" style="display:none"></div></div>
    </div>
    <div id="statusbar"><span id="coord-info"></span><span id="zoom-info"></span><span id="map-info"></span></div>
    <div id="legend-panel" style="display:none"></div>
    <div id="port-tooltip" style="display:none"></div>
    <div id="ent-tooltip" style="display:none"></div>
    <div id="heat-tooltip"></div>
    <div id="quest-panel"></div>
    <div id="pick-panel"></div>
    <script>

        // Static full-map viewer: the server pre-renders the whole map at each
        // zoom ladder level once (disk-cached JPEG); the browser only displays
        // images. No tile requests, no canvas compositing.
        const vp = document.getElementById("viewport");
        const imgEl = document.getElementById("map-img");
        const mselBtn = document.getElementById("map-sel-btn");
        const mselLabel = document.getElementById("map-sel-label");
        const mselPop = document.getElementById("map-sel-pop");
        const mselFilter = document.getElementById("map-sel-filter");
        const mselList = document.getElementById("map-sel-list");
        const infoEl = document.getElementById("map-info");
        const statusEl = document.getElementById("status");
        const mmImg = document.getElementById("mm-img");
        const mmBox = document.getElementById("mm-box");
        const mmRect = document.getElementById("mm-rect");

        let maps = [], cur = -1, scaleLadder = [0,1,2,3,4,5,6,7], worldW = 0, worldH = 0;
        const MAP_CN = /*__MAP_CN__*/;
        let version = 0;            // render generation; ignore stale loads
        let anchorX = 0, anchorY = 0; // world px at viewport center
        let dragging = false, dragX = 0, dragY = 0, scX = 0, scY = 0;
        let miniReady = false, miniDrag = false;
        let tileLayer = document.getElementById("tile-layer");

        let curName = null;
        const curMap = () => maps.find(m => m.name === curName);
        const curZ = () => scaleLadder[cur];
        const curScale = () => 1 << curZ();
        const isTileMode = () => curZ() <= 1;   // 1:1 / 1:2 -> tiles; 1:4+ -> fullmap
        const gOn = () => document.getElementById("chk-g").checked ? 1 : 0;
        const mOn = () => document.getElementById("chk-m").checked ? 1 : 0;
        const fOn = () => document.getElementById("chk-f").checked ? 1 : 0;

        function fmt(mi, z) {
            const s = 1 << z;
            const iw = Math.ceil(worldW / s), ih = Math.ceil(worldH / s);
            return (mi.cn ? mi.cn + " · " : "") + mi.name + " | " + mi.w + "×" + mi.h +
                   " 格 | 1:" + s + " | " + iw + "×" + ih + "px";
        }

        function setAnchorFromView() {
            anchorX = (vp.scrollLeft + vp.clientWidth / 2) * curScale();
            anchorY = (vp.scrollTop + vp.clientHeight / 2) * curScale();
        }

        function applyAnchor() {
            const s = curScale();
            const maxX = Math.max(0, worldW / s - vp.clientWidth);
            const maxY = Math.max(0, worldH / s - vp.clientHeight);
            vp.scrollLeft = Math.max(0, Math.min(anchorX / s - vp.clientWidth / 2, maxX));
            vp.scrollTop  = Math.max(0, Math.min(anchorY / s - vp.clientHeight / 2, maxY));
        }

        // ---- tile mode: dynamically load /tile images covering the viewport ----
        function drawTiles() {
            const mi = curMap();
            if (!mi || !isTileMode()) { tileLayer.innerHTML = ""; return; }
            const s = curScale();
            const z = curZ();
            const TILE = 512 / s;   // tile size in screen px at this zoom
            // world px visible in viewport (scroll position is screen px at 1:1 of current scale)
            const vx0 = vp.scrollLeft * s, vy0 = vp.scrollTop * s;
            const vx1 = vx0 + vp.clientWidth * s, vy1 = vy0 + vp.clientHeight * s;
            const tx0 = Math.floor(vx0 / 512), ty0 = Math.floor(vy0 / 512);
            const tx1 = Math.floor(vx1 / 512), ty1 = Math.floor(vy1 / 512);
            const tileH = Math.floor(worldH / 512) + 1;
            const tileW = Math.floor(worldW / 512) + 1;
            const v = version;
            const layer = tileLayer;
            layer.innerHTML = "";
            layer.style.width = (worldW / s) + "px";
            layer.style.height = (worldH / s) + "px";
            // spacer: makes viewport scrollable to the full world at this zoom
            const spacer = document.createElement("div");
            spacer.style.width = (worldW / s) + "px";
            spacer.style.height = (worldH / s) + "px";
            spacer.style.position = "absolute";
            spacer.style.left = "0"; spacer.style.top = "0";
            layer.appendChild(spacer);
            for (let ty = ty0; ty <= ty1; ty++) {
                if (ty < 0 || ty >= tileH) continue;
                for (let tx = tx0; tx <= tx1; tx++) {
                    if (tx < 0 || tx >= tileW) continue;
                    const img = document.createElement("img");
                    img.style.left = (tx * 512 / s) + "px";
                    img.style.top = (ty * 512 / s) + "px";
                    img.style.width = TILE + "px";
                    img.style.height = TILE + "px";
                    img.loading = "lazy";
                    img.onload = () => { if (v !== version) img.remove(); };
                    img.onerror = () => {
                        if (v !== version) { img.remove(); return; }
                        // retry once after a delay
                        img.removeAttribute("src");
                        setTimeout(() => { if (v === version) img.src = "/tile?map=" + encodeURIComponent(mi.name) + "&tx=" + tx + "&ty=" + ty + "&z=" + z + "&g=" + gOn() + "&m=" + mOn() + "&f=" + fOn(); }, 800);
                    };
                    img.src = "/tile?map=" + encodeURIComponent(mi.name) + "&tx=" + tx + "&ty=" + ty +
                              "&z=" + z + "&g=" + gOn() + "&m=" + mOn() + "&f=" + fOn();
                    layer.appendChild(img);
                }
            }
        }

        function render(keepAnchor) {
            const mi = curMap();
            if (!mi) return;
            const z = curZ();
            const v = ++version;
            if (!keepAnchor) setAnchorFromView();
            statusEl.textContent = "加载中…";
            document.getElementById("btn-zoom-in").disabled = cur <= 0;
            document.getElementById("btn-zoom-out").disabled = cur >= scaleLadder.length - 1;
            if (isTileMode()) {
                // tile mode: hide fullmap img, show tiles
                imgEl.style.display = "none";
                imgEl.src = "";
                tileLayer.style.display = "block";
                drawTiles();          // 先建 spacer（可滚动域）再落点
                applyAnchor();        // hash 深链/锚点在 tile 模式同样生效（此前漏掉 → 深链落在左上角）
                drawQuest();          // 按新视口重算任务标记（剔除逻辑依赖 scroll）
                drawTiles();          // 滚动后按新视口补瓦片（scroll 事件亦会触发）
                drawMini();
                drawGrid();
                drawRoutes();
                drawEntities();
                statusEl.textContent = "就绪";
                hideLoading();
                return;
            }
            // fullmap mode
            imgEl.style.display = "";
            tileLayer.style.display = "none";
            const img = new Image();
            img.onload = () => {
                if (v !== version) return;
                imgEl.src = img.src;
                statusEl.textContent = "就绪";
                applyAnchor();
                drawMini();
                drawGrid();
                drawRoutes();
                drawEntities();
                updateStatusBar();
                hideLoading();
            };
            img.onerror = () => {
                if (v === version) {
                    statusEl.textContent = "生成失败";
                    showToast("地图渲染失败", `${mi.name} 无法生成整图。可能图库资源缺失或地图数据异常。<br>可尝试点击右上角「重新生成」清除缓存。`);
                    hideLoading();
                }
            };
            img.src = "/fullmap?map=" + encodeURIComponent(mi.name) + "&z=" + z +
                      "&g=" + gOn() + "&m=" + mOn() + "&f=" + fOn();
        }

        function loadMap() {
            const mi = curMap();
            if (!mi) return;
            worldW = mi.world_w || (mi.w + mi.h + 3) * 24;
            worldH = mi.world_h || (mi.w + mi.h + 2) * 16;
            // default: 100% (1:1, game view)
            cur = 0;
            anchorX = worldW / 2; anchorY = worldH / 2;
            version++;
            imgEl.src = "";
            tileLayer.innerHTML = "";
            loadMini();
            loadRoutes(mi);
            loadEntities(mi);
            render(true);
        }

        function loadMini() {
            const mi = curMap();
            if (!mi) return;
            miniReady = false;
            mmRect.style.display = "none";
            mmImg.onload = () => { miniReady = true; drawMini(); };
            mmImg.onerror = () => { miniReady = false; };
            mmImg.src = "/minimap?map=" + encodeURIComponent(mi.name);
        }

        function drawMini() {
            if (!miniReady || !worldW || !worldH || !mmBox.clientWidth) return;
            const s = curScale();
            const bw = mmBox.clientWidth, bh = mmBox.clientHeight;
            mmRect.style.display = "block";
            mmRect.style.left   = (vp.scrollLeft * s / worldW * bw) + "px";
            mmRect.style.top    = (vp.scrollTop  * s / worldH * bh) + "px";
            mmRect.style.width  = Math.max(2, Math.min(vp.clientWidth  * s / worldW * bw, bw)) + "px";
            mmRect.style.height = Math.max(2, Math.min(vp.clientHeight * s / worldH * bh, bh)) + "px";
        }

        function miniPan(cx, cy) {
            anchorX = cx; anchorY = cy;
            applyAnchor();
            drawMini();
            if (isTileMode()) drawTiles();
        }

        // ---- grid overlay (rect layout: cell = 48x32 world px) ----
        const gridCanvas = document.getElementById("grid-canvas");
        const gridCtx = gridCanvas.getContext("2d");
        const gridOn = () => document.getElementById("chk-grid").checked;

        function drawGrid() {
            const s = curScale();
            if (!gridOn() || !imgEl.naturalWidth) { gridCanvas.width = 0; gridCanvas.height = 0; return; }
            // canvas is a child of #viewport (position:absolute), so imgRect
            // (viewport-relative) maps 1:1 to canvas coordinates
            const vpRect = vp.getBoundingClientRect();
            const imgRect = imgEl.getBoundingClientRect();
            const ox = imgRect.left - vpRect.left, oy = imgRect.top - vpRect.top;
            gridCanvas.style.left = ox + "px";
            gridCanvas.style.top = oy + "px";
            const cw = imgRect.width, ch = imgRect.height;
            if (cw <= 0 || ch <= 0) return;
            gridCanvas.width = cw * (window.devicePixelRatio || 1);
            gridCanvas.height = ch * (window.devicePixelRatio || 1);
            gridCanvas.style.width = cw + "px";
            gridCanvas.style.height = ch + "px";
            const ctx = gridCtx;
            ctx.setTransform(1, 0, 0, 1, 0, 0);
            ctx.clearRect(0, 0, gridCanvas.width, gridCanvas.height);
            ctx.scale(window.devicePixelRatio || 1, window.devicePixelRatio || 1);
            const cwPx = 48 / s, chPx = 32 / s;   // world->screen at this zoom
            if (cwPx < 2 || chPx < 2) return;      // too dense to draw
            ctx.strokeStyle = "rgba(255,213,74,0.35)";
            ctx.lineWidth = 1;
            ctx.beginPath();
            for (let x = 0; x <= cw; x += cwPx) { ctx.moveTo(x, 0); ctx.lineTo(x, ch); }
            for (let y = 0; y <= ch; y += chPx) { ctx.moveTo(0, y); ctx.lineTo(cw, y); }
            ctx.stroke();
        }

        // ---- map connections (game-cell coordinates, not screen coordinates) ----
        const routeSvg = document.getElementById("route-svg");
        const portTooltip = document.getElementById("port-tooltip");
        let routeCache = {};
        function drawRoutes() {
            const mi = curMap();
            const routes = routeCache[mi?.name] || [];
            if (!mi) { routeSvg.innerHTML = ""; return; }
            const s = curScale();
            // overlay is viewport-relative; world->screen: cell*48/s - scrollLeft
            const px = p => Number(p.x) * 48 / s - vp.scrollLeft;
            const py = p => Number(p.y) * 32 / s - vp.scrollTop;
            routeSvg.style.left = "0px";
            routeSvg.style.top = "0px";
            routeSvg.setAttribute("width", vp.clientWidth);
            routeSvg.setAttribute("height", vp.clientHeight);
            const vw = vp.clientWidth, vh = vp.clientHeight;
            const hereStem = mi.name.replace(/\\.map$/i, "");
            // 聚合：同 (方向, 对面地图, icon) 的多条 movement（如逐格排列的传送门）
            // 合成一个出口标记，位置取本图端点质心 —— 否则地图边缘会出现几十个
            // 重叠圆点。movement 源数据 = System.db MovementInfo (workspace 最新)。
            const groups = {};
            for (const r of routes) {
                if (!r.source || !r.destination) continue;
                const sourceHere = String(r.source.map).replace(/\\.map$/i, "") === hereStem;
                const destHere = String(r.destination.map).replace(/\\.map$/i, "") === hereStem;
                if (!sourceHere && !destHere) continue;
                const here = sourceHere ? r.source : r.destination;
                const other = sourceHere ? r.destination : r.source;
                if (here.x == null) continue;   // 本图端点无坐标，无法定位出口
                const otherStem = String(other.map).replace(/\\.map$/i, "");
                const dir = sourceHere ? "O" : "I";
                const key = dir + "|" + otherStem + "|" + (r.icon || "None");
                const g = groups[key] = groups[key] || {
                    dir, otherStem, icon: r.icon || "None",
                    sx: 0, sy: 0, n: 0, ox: other.x, oy: other.y, hasO: other.x != null,
                };
                g.sx += Number(here.x); g.sy += Number(here.y); g.n++;
                if (other.x != null) { g.ox = other.x; g.oy = other.y; }
            }
            routeSvg.innerHTML = Object.values(groups).map(g => {
                const cx = px({ x: g.sx / g.n }), cy = py({ y: g.sy / g.n });
                if (cx < -60 || cy < -60 || cx > vw + 60 || cy > vh + 60) return "";
                const tcn = MAP_CN[g.otherStem] || g.otherStem;
                // color by icon type: Cave/Down=red, Building=green, Exit/Up=blue, Province=yellow
                let color = "#72d6ff";
                if (/Cave|Down/.test(g.icon)) color = "#ff6b6b";
                else if (/Building/.test(g.icon)) color = "#7CFF7C";
                else if (/Province/.test(g.icon)) color = "#ffd54a";
                const arrow = g.dir === "O" ? "→" : "←";   // 出口/入口方向
                const label = g.otherStem === hereStem
                    ? `本图内传送 · ${g.n} 处`
                    : `${g.dir === "O" ? "通往" : "来自"} ${tcn} · ${g.n} 处`;
                const dstAttr = (g.ox != null)
                    ? ` data-dstmap="${g.otherStem}" data-dstx="${Math.round(g.ox)}" data-dsty="${Math.round(g.oy)}" data-dstcn="${encodeURIComponent(tcn)}"`
                    : "";
                return `<g class="port-wrap"><circle class="port"${dstAttr} cx="${cx}" cy="${cy}" r="7" fill="${color}" stroke="#111" stroke-width="2" opacity=".92"><title>${label}${g.ox != null ? ` · 对面格 ${Math.round(g.ox)},${Math.round(g.oy)}` : ""}</title></circle>` +
                    `<text x="${cx}" y="${cy + 4}" text-anchor="middle" font-size="10" fill="#fff" pointer-events="none">${arrow}</text></g>`;
            }).join("");
        }
        // hover portal -> show destination map thumbnail
        routeSvg.addEventListener("mouseover", (e) => {
            const c = e.target.closest("circle.port");
            if (!c || !c.dataset.dstmap) { portTooltip.style.display = "none"; return; }
            const dst = c.dataset.dstmap, dx = c.dataset.dstx, dy = c.dataset.dsty, cn = decodeURIComponent(c.dataset.dstcn || dst);
            const dstName = dst + ".map";
            portTooltip.innerHTML = `<b>${cn}</b> · 格 ${dx},${dy}<br><img src="/thumb?map=${encodeURIComponent(dstName)}" alt="">`;
            portTooltip.style.display = "block";
            const r = e.clientX, b = e.clientY;
            portTooltip.style.left = Math.min(r + 14, window.innerWidth - 260) + "px";
            portTooltip.style.top = Math.min(b + 14, window.innerHeight - 200) + "px";
        });
        routeSvg.addEventListener("mouseout", (e) => {
            if (!e.target.closest("circle.port")) portTooltip.style.display = "none";
        });
        // click portal -> jump to destination map
        routeSvg.addEventListener("click", (e) => {
            const c = e.target.closest("circle.port");
            if (!c || !c.dataset.dstmap) return;
            const dst = c.dataset.dstmap, dx = c.dataset.dstx || 0, dy = c.dataset.dsty || 0;
            if (maps.some(m => m.name === dst + ".map")) {
                history.replaceState(null, '', `#map=${encodeURIComponent(dst + ".map")}&cur=0&x=${Math.round(dx * 48)}&y=${Math.round(dy * 32)}&g=1&m=1&f=1`);
                init();
            }
        });
        async function loadRoutes(mi) {
            try {
                const res = await fetch("/api/connections?map=" + encodeURIComponent(mi.name));
                const data = await res.json(); routeCache[mi.name] = data.links || [];
            } catch (e) { routeCache[mi.name] = []; }
            drawRoutes();
            renderConnPanel(mi);
        }
        // ---- 连接列表面板：本图 ↔ 哪些图互连（中文地图名，点击跳转） ----
        function renderConnPanel(mi) {
            const panel = document.getElementById("conn-panel");
            if (!panel) return;
            const hereStem = mi.name.replace(/\\.map$/i, "");
            const routes = routeCache[mi.name] || [];
            const groups = {};
            for (const r of routes) {
                if (!r.source || !r.destination) continue;
                const sourceHere = String(r.source.map).replace(/\\.map$/i, "") === hereStem;
                const destHere = String(r.destination.map).replace(/\\.map$/i, "") === hereStem;
                if (!sourceHere && !destHere) continue;
                const other = sourceHere ? r.destination : r.source;
                const otherStem = String(other.map).replace(/\\.map$/i, "");
                const g = groups[otherStem] = groups[otherStem] ||
                    { out: 0, in: 0, ox: other.x, oy: other.y };
                if (sourceHere) g.out++; else g.in++;
                if (other.x != null) { g.ox = other.x; g.oy = other.y; }
            }
            const stems = Object.keys(groups).sort((a, b) =>
                (groups[b].out + groups[b].in) - (groups[a].out + groups[a].in));
            const cn = st => MAP_CN[st] || st;
            let html = `<h4>🔗 地图连接 (${stems.length})</h4>`;
            if (!stems.length) {
                html += `<div class="conn-empty">无连接数据</div>`;
            } else {
                for (const st of stems) {
                    const g = groups[st];
                    const exists = maps.some(m => m.name === st + ".map");
                    const jump = (exists && g.ox != null)
                        ? ` data-jump="${st}" data-x="${Math.round(g.ox)}" data-y="${Math.round(g.oy)}"`
                        : "";
                    const dirs = [];
                    if (g.out) dirs.push(`→${g.out}`);
                    if (g.in) dirs.push(`←${g.in}`);
                    html += `<div class="conn-row${jump ? " link" : ""}"${jump}>` +
                        `<span class="conn-name">${cn(st)}</span>` +
                        `<span class="conn-dir">${dirs.join(" ")}</span>` +
                        `${st !== hereStem ? `<span class="conn-file">${st}</span>` : "<span class='conn-file'>本图内</span>"}` +
                        `</div>`;
                }
            }
            panel.innerHTML = html;
            panel.style.display = "block";
            panel.querySelectorAll(".conn-row.link").forEach(row => {
                row.addEventListener("click", () => {
                    const dst = row.dataset.jump;
                    if (!dst) return;
                    history.replaceState(null, '',
                        `#map=${encodeURIComponent(dst + ".map")}&cur=0&x=${Math.round(Number(row.dataset.x) * 48)}&y=${Math.round(Number(row.dataset.y) * 32)}&g=1&m=1&f=1`);
                    init();
                });
            });
        }

        // ---- entities (NPC / spawn / monsters) from Mud3 Envir ----
        const entLayer = document.getElementById("ent-layer");
        const entTooltip = document.getElementById("ent-tooltip");
        let entCache = {};
        function entColor(kind, name) {
            if (kind === "spawn") return "#ffd54a";
            if (kind === "monster") return "#ff6b6b";
            const n = name || "";
            // merchant / storage / function NPC -> green, else blue
            if (/仓|商|卖|买|功能|保管|商店|铺|店/.test(n)) return "#7CFF7C";
            return "#8cf";
        }
        function entShape(kind) {
            if (kind === "monster") return "border-radius:2px;";
            return "border-radius:50%;";
        }
        function drawEntities() {
            const mi = curMap();
            const ents = entCache[mi?.name] || [];
            if (!mi) { entLayer.innerHTML = ""; return; }
            if (!document.getElementById("chk-ents").checked) { entLayer.innerHTML = ""; return; }
            const s = curScale();
            entLayer.style.left = "0px";
            entLayer.style.top = "0px";
            entLayer.style.width = vp.clientWidth + "px";
            entLayer.style.height = vp.clientHeight + "px";
            const vw = vp.clientWidth, vh = vp.clientHeight;
            const hlName = window.__hlName || null;
            entLayer.innerHTML = ents.map(e => {
                const px = Number(e.x) * 48 / s - vp.scrollLeft;
                const py = Number(e.y) * 32 / s - vp.scrollTop;
                // wide culling: entities are few, keep visible beyond viewport edges
                if (px < -200 || py < -200 || px > vw + 200 || py > vh + 200) return "";
                const kind = e.kind || "npc";
                const color = entColor(kind, e.name);
                const shape = entShape(kind);
                const label = e.name || "";
                const d = e.drops ? ` · 掉落 ${e.drops.length} 种` : "";
                const hlCls = (hlName && e.name === hlName) ? " target" : "";
                return `<div class="ent ${kind}${hlCls}" data-name="${label.replace(/"/g, "&quot;")}" data-x="${e.x}" data-y="${e.y}" data-kind="${kind}" style="left:${px}px;top:${py}px"><span class="ent-icon" style="background:${color};box-shadow:0 0 4px ${color};${shape}"></span><span class="ent-label">${label}</span></div>`;
            }).join("");
        }
        // hover entity -> tooltip
        entLayer.addEventListener("mouseover", (e) => {
            const d = e.target.closest(".ent");
            if (!d) { entTooltip.style.display = "none"; return; }
            entTooltip.textContent = `${d.dataset.name} · 格 ${d.dataset.x},${d.dataset.y}`;
            entTooltip.style.display = "block";
            entTooltip.style.left = Math.min(e.clientX + 12, window.innerWidth - 200) + "px";
            entTooltip.style.top = Math.max(4, e.clientY - 28) + "px";
        });
        entLayer.addEventListener("mouseout", (e) => {
            if (!e.target.closest(".ent")) entTooltip.style.display = "none";
        });
        async function loadEntities(mi) {
            try {
                const res = await fetch("/api/entities?map=" + encodeURIComponent(mi.name));
                const d = await res.json();
                entCache[mi.name] = d.ok ? d.entities : [];
            } catch (e) { entCache[mi.name] = []; }
            // 首次打开且用户未指定视点时，默认居中到 NPC/出生点质心（城镇区），
            // 而不是地图几何中心（大图中心常是无人区，NPC 标记全在视口外）。
            if (!window.__userAnchor && entCache[mi.name] && entCache[mi.name].length) {
                let sx = 0, sy = 0, n = 0;
                for (const e of entCache[mi.name]) {
                    if (e.kind === "npc" || e.kind === "spawn") { sx += Number(e.x); sy += Number(e.y); n++; }
                }
                if (n > 0) {
                    anchorX = (sx / n) * 48 + 24;
                    anchorY = (sy / n) * 32 + 16;
                    applyAnchor();
                    if (isTileMode()) drawTiles();
                    drawRoutes();
                    drawEntities();
                    drawGrid();
                    drawMini();
                    updateUrlHash();
                }
            }
            drawEntities();
        }

        // ---- cursor cell coordinate readout (rect: world px -> cell) ----
        vp.addEventListener("scroll", () => { drawRoutes(); drawEntities(); });
        window.addEventListener("resize", () => { drawGrid(); drawRoutes(); drawEntities(); });

        // ---- catalog info panel ----
        let catCache = {};   // map_name -> catalog doc

        function cellFlag(cat, x, y) {
            // flag byte lives at cell offset +0; catalog doesn't store the
            // full matrix, so report only when the flag histogram says 1s exist.
            return "";
        }

        function fmtLibRow(layer, entries) {
            const rows = [];
            for (const [lid, info] of Object.entries(entries)) {
                const oob = info.frame_oob ? `<span class="oob"> OOB ${info.frame_oob}</span>` : "";
                rows.push(`<div class="row"><span class="k">${layer} ${lid} ${info.lib}</span><span class="v">${info.cells}格 ≤${info.frame_max}${oob}</span></div>`);
            }
            return rows.join("");
        }

        async function loadCatalog(mi) {
            if (catCache[mi.name]) { renderCat(mi); return; }
            try {
                const res = await fetch("/api/catalog?map=" + encodeURIComponent(mi.name));
                const data = await res.json();
                if (data.ok) catCache[mi.name] = data.catalog;
                else catCache[mi.name] = null;
            } catch (e) { catCache[mi.name] = null; }
            renderCat(mi);
        }

        function renderCat(mi) {
            const panel = document.getElementById("cat-panel");
            const cat = catCache[mi.name];
            if (!cat) { panel.style.display = "none"; return; }
            const anom = cat.anomaly_total || 0;
            const warn = anom ? `<span class="warn"> ⚠ ${anom} 帧越界</span>` : "";
            let html = `<h4>${cat.name}${cat.display ? " · MiniMap " + cat.display : ""}${warn}</h4>
<div class="row"><span class="k">主题</span><span class="v">${cat.theme_name || "base"}</span></div>
<div class="row"><span class="k">尺寸</span><span class="v">${cat.w}×${cat.h} · ${cat.cell_bytes}B/格${cat.legacy_13b ? " · legacy" : ""}</span></div>
<div class="row"><span class="k">动画格</span><span class="v">${cat.animated_cells || 0}</span></div>`;
            for (const layer of ["ground", "mid", "front"]) {
                const e = cat[layer];
                if (e && Object.keys(e).length) html += `<div class="lib"><b>${layer}</b>${fmtLibRow(layer, e)}</div>`;
            }
            panel.innerHTML = html;
            panel.style.display = "block";
        }

        // ---- custom map dropdown ----
        function mselLabelOf(m) { return m ? (m.cn ? m.cn + " — " : "") + m.name : "加载中…"; }
        function mselOpen() { mselPop.hidden = false; mselFilter.value = ""; renderMselList(); mselFilter.focus(); }
        function mselClose() { mselPop.hidden = true; }
        function mselFiltered() {
            const q = mselFilter.value.trim().toLowerCase();
            if (!q) return maps;
            return maps.filter(m =>
                m.name.toLowerCase().includes(q) || (m.cn || "").toLowerCase().includes(q));
        }
        const CAT_LABEL = { town: "🏘️ 城镇", cave: "⛰️ 洞穴/地牢", room: "🚪 小房间/建筑", other: "📦 其他" };
        function renderMselList() {
            const items = mselFiltered();
            if (items.length === 0) {
                mselList.innerHTML = '<div class="msel-item empty">没有匹配的地图</div>';
                return;
            }
            const q = mselFilter.value.trim().toLowerCase();
            if (q) {
                // search mode: flat list
                mselList.innerHTML = items.map(m =>
                    '<div class="msel-item" data-name="' + m.name.replace(/"/g, "&quot;") + '">' +
                    '<span class="msel-cn">' + (m.cn || "") + '</span><span>' + m.name + '</span></div>'
                ).join("");
            } else {
                // browse mode: grouped by category
                const groups = {};
                for (const m of items) {
                    const c = m.cat || "other";
                    (groups[c] = groups[c] || []).push(m);
                }
                let html = "";
                for (const c of ["town", "cave", "room", "other"]) {
                    const g = groups[c];
                    if (!g || !g.length) continue;
                    html += `<div class="msel-cat">${CAT_LABEL[c]} (${g.length})</div>`;
                    html += g.map(m =>
                        '<div class="msel-item" data-name="' + m.name.replace(/"/g, "&quot;") + '">' +
                        '<span class="msel-cn">' + (m.cn || "") + '</span><span>' + m.name + '</span></div>'
                    ).join("");
                }
                mselList.innerHTML = html;
            }
            // scroll active/current item into view
            const cur = mselList.querySelector('.msel-item[data-name="' + curName + '"]');
            if (cur) { cur.classList.add("active"); cur.scrollIntoView({ block: "nearest" }); }
        }
        function mselPick(name) {
            const mi = maps.find(m => m.name === name);
            if (!mi) return;
            curName = name;
            mselLabel.textContent = mselLabelOf(mi);
            mselClose();
            loadMap();
            loadCatalog(mi);
        }
        mselBtn.addEventListener("click", (e) => {
            e.stopPropagation();
            if (mselPop.hidden) mselOpen(); else mselClose();
        });
        mselFilter.addEventListener("input", renderMselList);
        mselFilter.addEventListener("keydown", (e) => {
            if (e.key === "Enter") {
                const first = mselList.querySelector('.msel-item[data-name]');
                if (first) mselPick(first.dataset.name);
            } else if (e.key === "ArrowDown" || e.key === "ArrowUp") {
                e.preventDefault();
                const items = [...mselList.querySelectorAll('.msel-item[data-name]')];
                if (!items.length) return;
                let idx = items.findIndex(i => i.classList.contains("active"));
                idx = e.key === "ArrowDown" ? (idx + 1) % items.length : (idx - 1 + items.length) % items.length;
                items.forEach(i => i.classList.remove("active"));
                items[idx].classList.add("active");
                items[idx].scrollIntoView({ block: "nearest" });
            } else if (e.key === "Escape") { mselClose(); }
        });
        mselList.addEventListener("click", (e) => {
            const it = e.target.closest('.msel-item[data-name]');
            if (it) mselPick(it.dataset.name);
        });
        window.addEventListener("click", (e) => {
            if (!mselPop.hidden && !e.target.closest("#map-sel")) mselClose();
        });
        window.addEventListener("keydown", (e) => {
            if (e.key === "Escape" && !mselPop.hidden) mselClose();
        });
        // ---- Hash & State Memory ----
        function updateUrlHash() {
            if (!curMap()) return;
            const s = curScale();
            const ax = Math.round(anchorX || (vp.scrollLeft + vp.clientWidth / 2) * s);
            const ay = Math.round(anchorY || (vp.scrollTop + vp.clientHeight / 2) * s);
            const g = document.getElementById("chk-g").checked ? 1 : 0;
            const m = document.getElementById("chk-m").checked ? 1 : 0;
            const f = document.getElementById("chk-f").checked ? 1 : 0;
            const hash = `#map=${encodeURIComponent(curMap().name)}&cur=${cur}&x=${ax}&y=${ay}&g=${g}&m=${m}&f=${f}`;
            history.replaceState(null, '', hash);
            saveState();
        }

        // ---- Toast System ----
        function showToast(title, body, duration = 5000) {
            const container = document.getElementById("toast-container");
            const toast = document.createElement("div");
            toast.className = "toast";
            toast.innerHTML = `<div class="toast-title"><span>🎉</span> ${title}</div><div class="toast-body">${body}</div>`;
            container.appendChild(toast);
            requestAnimationFrame(() => toast.classList.add("show"));
            setTimeout(() => {
                toast.classList.remove("show");
                setTimeout(() => toast.remove(), 400);
            }, duration);
        }

        // ---- Custom Confirm Modal ----
        function showConfirm(title, message) {
            return new Promise((resolve) => {
                const modal = document.getElementById("custom-modal-overlay");
                const mTitle = document.getElementById("modal-title");
                const mMsg = document.getElementById("modal-msg");
                const btnCancel = document.getElementById("btn-modal-cancel");
                const btnConfirm = document.getElementById("btn-modal-confirm");

                mTitle.textContent = title || "⚡ 提示";
                mMsg.textContent = message || "确定要执行此操作吗？";
                modal.style.display = "flex";

                function cleanup(result) {
                    modal.style.display = "none";
                    btnCancel.onclick = null;
                    btnConfirm.onclick = null;
                    resolve(result);
                }

                btnCancel.onclick = () => cleanup(false);
                btnConfirm.onclick = () => cleanup(true);
            });
        }

        const overlay = document.getElementById("loading-overlay");
        const loadingTitle = document.getElementById("loading-title");
        const loadingDetail = document.getElementById("loading-detail");

        function showLoading(title, detail) {
            if (title) loadingTitle.textContent = title;
            if (detail) loadingDetail.textContent = detail;
            overlay.style.display = "flex";
        }
        function hideLoading() {
            overlay.style.display = "none";
        }

        // ---- init ----
        const STATE_KEY = "zircon-map-viewer-v1";
        function saveState() {
            try {
                const mi = curMap();
                if (!mi) return;
                localStorage.setItem(STATE_KEY, JSON.stringify({
                    map: mi.name,
                    cur: cur,
                    ax: Math.round(anchorX), ay: Math.round(anchorY),
                    g: gOn(), m: mOn(), f: fOn(),
                }));
            } catch (e) {}
        }
        function loadState() {
            try {
                const raw = localStorage.getItem(STATE_KEY);
                return raw ? JSON.parse(raw) : null;
            } catch (e) { return null; }
        }

        async function init() {
            const res = await fetch("/api/maps");
            maps = await res.json();
            if (!maps.length) return;

            // Parse Hash params: #map=0.map&cur=1&x=1200&y=800 (hash wins over saved state)
            let targetMap = maps[0].name;
            let targetCur = null;
            let targetX = null;
            let targetY = null;
            const st = loadState();
            const hasHash = !!location.hash;
            window.__hlName = null;
            window.__userAnchor = false;   // 用户显式指定视点后不再自动居中到 NPC 质心
            if (hasHash) {
                const matchMap = location.hash.match(/map=([^&]+)/);
                const matchCur = location.hash.match(/cur=(\\d+)/);
                const matchX   = location.hash.match(/x=(\\d+)/);
                const matchY   = location.hash.match(/y=(\\d+)/);
                const matchHl  = location.hash.match(/hl=([^&]+)/);
                if (matchMap) {
                    const parsed = decodeURIComponent(matchMap[1]);
                    if (maps.some(m => m.name.toLowerCase() === parsed.toLowerCase())) {
                        targetMap = parsed;
                    }
                }
                if (matchCur) targetCur = parseInt(matchCur[1]);
                if (matchX) targetX = parseInt(matchX[1]);
                if (matchY) targetY = parseInt(matchY[1]);
                if (matchHl) window.__hlName = decodeURIComponent(matchHl[1]);
            } else if (st && maps.some(m => m.name === st.map)) {
                targetMap = st.map;
                targetCur = st.cur;
                targetX = st.ax;
                targetY = st.ay;
            }

            mselPick(targetMap);

            if (targetCur !== null && targetCur >= 0 && targetCur < scaleLadder.length) {
                cur = targetCur;
            }
            if (targetX !== null && targetY !== null) {
                anchorX = targetX;
                anchorY = targetY;
                window.__userAnchor = true;
            }
            render(true);
            updateUrlHash();   // 立即用实际加载的地图/坐标回写 URL(自愈坏 hash)
            saveState();
        }
        init();

        // 轮询后台预生成进度
        async function pollProgress() {
            try {
                const res = await fetch("/api/progress");
                const data = await res.json();
                const box = document.getElementById("progress-box");
                if (data.running) {
                    box.style.display = "inline-flex";
                    document.getElementById("progress-bar-fill").style.width = data.percent + "%";
                    document.getElementById("progress-text").textContent = `${data.percent}% (${data.current}/${data.total} · 生成中 ${data.current_map})`;
                } else if (data.total > 0 && data.done + data.failed >= data.total) {
                    box.style.display = "inline-flex";
                    document.getElementById("progress-bar-fill").style.width = "100%";
                    document.getElementById("progress-text").textContent = `100% (全库 ${data.total} 张地图预生成完毕！)`;
                } else {
                    box.style.display = "none";
                }
            } catch (e) {}
        }
        setInterval(pollProgress, 1000);
        pollProgress();

        window.addEventListener("hashchange", () => {
            if (!location.hash) return;
            const matchMap = location.hash.match(/map=([^&]+)/);
            if (matchMap) {
                const parsed = decodeURIComponent(matchMap[1]);
                const mi = curMap();
                if (mi && mi.name.toLowerCase() !== parsed.toLowerCase()) {
                    init();
                }
            }
        });

        vp.addEventListener("scroll", () => {
            drawTiles();
            drawMini();
            drawGrid();
            setAnchorFromView();
            updateUrlHash();
        });

        document.getElementById("btn-zoom-in").addEventListener("click", () => {
            if (cur <= 0) return; setAnchorFromView(); cur--; render(true); updateUrlHash(); saveState();
        });
        document.getElementById("btn-zoom-out").addEventListener("click", () => {
            if (cur >= scaleLadder.length - 1) return; setAnchorFromView(); cur++; render(true); updateUrlHash(); saveState();
        });
        document.getElementById("btn-fit").addEventListener("click", () => {
            // fit whole map into viewport: pick smallest scale that fits
            let fitCur = 0;
            for (let i = 0; i < scaleLadder.length; i++) {
                const s = 1 << scaleLadder[i];
                if (worldW / s <= vp.clientWidth * 0.98 && worldH / s <= vp.clientHeight * 0.98) {
                    fitCur = i; break;
                }
            }
            cur = fitCur;
            anchorX = worldW / 2; anchorY = worldH / 2;
            render(true);
            updateUrlHash();
            saveState();
        });
        document.getElementById("btn-clear-cache").addEventListener("click", async () => {
            const ok = await showConfirm("🔄 重新生成", `确定要清除全部缓存并重新生成全库 ${maps.length} 张地图吗？\n\n将删除磁盘 tile 缓存，后台并行重新预生成所有地图（4 线程）。\n\n生成过程约需 10-30 分钟，期间可正常浏览，顶部进度条实时更新。`);
            if (!ok) return;
            statusEl.textContent = "正在清除缓存并触发全库预生成…";
            try {
                await fetch("/api/rebuild_all", { method: "POST" });
            } catch (e) {}
            // force the current map to re-render from scratch
            version++;
            imgEl.src = "";
            render(true);
            showToast("缓存清除完成", `已清空全部缓存，后台正在并行重新预生成 ${maps.length} 张地图。<br>顶部进度条实时更新。`);
            saveState();
        });

        document.getElementById("chk-g").addEventListener("change", () => { render(); updateUrlHash(); saveState(); });
        document.getElementById("chk-m").addEventListener("change", () => { render(); updateUrlHash(); saveState(); });
        document.getElementById("chk-f").addEventListener("change", () => { render(); updateUrlHash(); saveState(); });
        document.getElementById("chk-grid").addEventListener("change", () => { drawGrid(); });
        document.getElementById("chk-ents").addEventListener("change", () => { drawEntities(); drawRoutes(); });
        document.getElementById("btn-legend").addEventListener("click", () => {
            const panel = document.getElementById("legend-panel");
            panel.style.display = panel.style.display === "none" ? "block" : "none";
        });
        document.getElementById("legend-panel").innerHTML =
            '<div class="lg-row"><span class="lg-dot" style="background:#8cf;box-shadow:0 0 4px #8cf;"></span> NPC（db_names 中文名）</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#7CFF7C;box-shadow:0 0 4px #7CFF7C;"></span> 商店类 NPC / 建筑 (Building)</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#ffd54a;box-shadow:0 0 4px #ffd54a;"></span> 出生点 / 省际传送 (Province)</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#ff6b6b;box-shadow:0 0 4px #ff6b6b;"></span> 怪物刷新 / 洞穴入口 (Cave/Down)</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#72d6ff;box-shadow:0 0 4px #72d6ff;"></span> 城镇出口 (Exit/Up)</div>' +
            '<div class="lg-row"><span style="color:#aaa;font-size:11px;">→ 出口（通往对面图） · ← 入口（从对面图来）<br>圆点可点击跳转对面地图 · 左上面板=连接列表</div>';

        // ---- right-bottom status bar: coord + zoom + map ----
        const coordEl = document.getElementById("coord-info");
        const zoomEl = document.getElementById("zoom-info");
        const mapInfoEl = document.getElementById("map-info");
        function updateStatusBar(cx, cy) {
            const mi = curMap();
            if (!mi) return;
            const s = curScale();
            const pct = (100 / s).toFixed(0) + "%";
            zoomEl.textContent = "比例 " + pct;
            mapInfoEl.textContent = (mi.cn ? mi.cn + " · " : "") + mi.name.replace(".map", "");
            if (cx !== undefined && cy !== undefined && cx >= 0 && cy >= 0) {
                coordEl.textContent = "格 " + cx + "," + cy;
            } else {
                coordEl.textContent = "格 —,—";
            }
        }
        // mouse move -> coord (game-accurate 48x32)
        vp.addEventListener("mousemove", (e) => {
            const mi = curMap();
            if (!mi) return;
            const s = curScale();
            const rect = vp.getBoundingClientRect();
            const wx = (vp.scrollLeft + e.clientX - rect.left) * s;
            const wy = (vp.scrollTop + e.clientY - rect.top) * s;
            const cx = Math.floor(wx / 48), cy = Math.floor(wy / 32);
            updateStatusBar(cx, cy);
        });
        vp.addEventListener("mouseleave", () => updateStatusBar(-1, -1));
        vp.addEventListener("scroll", () => { drawTiles(); updateStatusBar(); saveState(); });

        // G/M/F hotkeys toggle layers
        window.addEventListener("keydown", (e) => {
            if (e.target.tagName === "INPUT" || e.target.tagName === "TEXTAREA") return;
            const k = e.key.toLowerCase();
            if (k === "g") { const c = document.getElementById("chk-g"); c.checked = !c.checked; c.dispatchEvent(new Event("change")); }
            else if (k === "m") { const c = document.getElementById("chk-m"); c.checked = !c.checked; c.dispatchEvent(new Event("change")); }
            else if (k === "f") { const c = document.getElementById("chk-f"); c.checked = !c.checked; c.dispatchEvent(new Event("change")); }
            else if (k === "e") { const c = document.getElementById("chk-ents"); c.checked = !c.checked; c.dispatchEvent(new Event("change")); }
        });

        // Drag to pan
        vp.addEventListener("mousedown", (e) => {
            dragging = true; vp.classList.add("dragging");
            dragX = e.clientX; dragY = e.clientY;
            scX = vp.scrollLeft; scY = vp.scrollTop;
            e.preventDefault();
        });
        window.addEventListener("mousemove", (e) => {
            if (!dragging) return;
            vp.scrollLeft = scX - (e.clientX - dragX);
            vp.scrollTop  = scY - (e.clientY - dragY);
            drawMini();
            drawTiles();
        });
        window.addEventListener("mouseup", () => { dragging = false; vp.classList.remove("dragging"); });

        // Ctrl + 滚轮: zoom around the mouse point (swap ladder level)
        window.addEventListener("wheel", (e) => {
            if (!e.ctrlKey) return;
            e.preventDefault();
            const rect = vp.getBoundingClientRect();
            const mx = e.clientX - rect.left, my = e.clientY - rect.top;
            const s = curScale();
            anchorX = (vp.scrollLeft + mx) * s;
            anchorY = (vp.scrollTop + my) * s;
            let changed = false;
            if (e.deltaY < 0 && cur > 0) { cur--; changed = true; }
            else if (e.deltaY > 0 && cur < scaleLadder.length - 1) { cur++; changed = true; }
            if (changed) { render(true); updateUrlHash(); }
        }, { passive: false });

        // Minimap click/drag -> pan main view
        mmBox.addEventListener("mousedown", (e) => {
            miniDrag = true;
            const r = mmBox.getBoundingClientRect();
            miniPan((e.clientX - r.left) / r.width * worldW,
                    (e.clientY - r.top) / r.height * worldH);
            e.preventDefault();
        });
        window.addEventListener("mousemove", (e) => {
            if (!miniDrag) return;
            const r = mmBox.getBoundingClientRect();
            miniPan((e.clientX - r.left) / r.width * worldW,
                    (e.clientY - r.top) / r.height * worldH);
        });
        window.addEventListener("mouseup", () => { miniDrag = false; });

        // ============================================================ 地图工坊
        // 六大增强：刷怪热力 / 任务叠加 / 等级总览 / 连通图谱 / NPC 审计 / 坐标拾取

        // ---- 视图切换（地图 / 总览 / 连通） ----
        const viewTabs = document.querySelectorAll(".vtab");
        let curView = "map";
        const ovView = document.getElementById("overview-view");
        const gvView = document.getElementById("graph-view");
        const mapOnlyEls = () => ["#minimap", "#statusbar", "#cat-panel", "#conn-panel", "#quest-panel",
            "#pick-panel", "#port-tooltip", "#ent-tooltip", "#heat-tooltip"].map(s => document.querySelector(s));
        function showView(v) {
            curView = v;
            viewTabs.forEach(t => t.classList.toggle("active", t.dataset.view === v));
            vp.style.display = v === "map" ? "" : "none";
            ovView.style.display = v === "overview" ? "block" : "none";
            gvView.style.display = v === "graph" ? "block" : "none";
            if (v !== "map") {
                mapOnlyEls().forEach(el => { if (el) el.style.display = "none"; });
            } else {
                document.getElementById("statusbar").style.display = "flex";
                document.getElementById("minimap").style.display = "";
                if (questData) questPanel.style.display = "block";
                if (pickA) pickPanel.style.display = "block";
                for (const id of ["cat-panel", "conn-panel"]) {
                    const el = document.getElementById(id);
                    if (el && el.innerHTML.trim()) el.style.display = "block";
                }
            }
            if (v === "overview") { initOverview(); }
            if (v === "graph") { initGraph(); }
        }
        viewTabs.forEach(t => t.addEventListener("click", () => showView(t.dataset.view)));

        const heatCanvas = document.getElementById("heat-canvas");
        const heatCtx = heatCanvas.getContext("2d");
        const heatTooltip = document.getElementById("heat-tooltip");
        const chkResp = document.getElementById("chk-resp");
        const HEAT_FILL = { t1: "rgba(96,210,96,.26)", t2: "rgba(255,213,74,.28)",
                            t3: "rgba(255,140,50,.30)", t4: "rgba(255,60,60,.32)" };
        const HEAT_EDGE = { t1: "rgba(96,210,96,.7)", t2: "rgba(255,213,74,.75)",
                            t3: "rgba(255,140,50,.8)", t4: "rgba(255,60,60,.85)" };
        let respCache = {};      // map name -> {groups:[{x,y,half,entries[]}], raw}
        async function loadRespawns(mi) {
            if (respCache[mi.name]) { drawHeat(); return; }
            try {
                const res = await fetch("/api/respawns?map=" + encodeURIComponent(mi.name));
                const d = await res.json();
                if (!d.ok) { chkResp.disabled = true; chkResp.title = "刷怪数据不可用（workspace RespawnInfo 缺失）"; respCache[mi.name] = null; return; }
                // 同 Region 的多条 respawn 合成一个色块（tier 取最高），tooltip 列全部怪物
                const gmap = {};
                for (const r of d.respawns) {
                    const k = r.x + "," + r.y + "," + r.half;
                    const g = gmap[k] = gmap[k] || { x: r.x, y: r.y, half: r.half, entries: [] };
                    g.entries.push(r);
                }
                const groups = Object.values(gmap).map(g => {
                    const best = g.entries.reduce((a, b) => a.count >= b.count ? a : b);
                    return { ...g, tier: best.tier };
                });
                respCache[mi.name] = { groups, raw: d.respawns };
            } catch (e) { respCache[mi.name] = null; }
            drawHeat();
        }
        function drawHeat() {
            const mi = curMap();
            const d = mi ? respCache[mi.name] : null;
            if (!chkResp.checked || !d) { heatCanvas.width = 0; heatCanvas.height = 0; return; }
            const s = curScale();
            const dpr = window.devicePixelRatio || 1;
            const w = vp.clientWidth, h = vp.clientHeight;
            heatCanvas.width = w * dpr; heatCanvas.height = h * dpr;
            heatCanvas.style.width = w + "px"; heatCanvas.style.height = h + "px";
            const ctx = heatCtx;
            ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
            ctx.clearRect(0, 0, w, h);
            // Region 方块：质心 (x,y) ± half 格（世界格 -> 屏幕：x*48/s, y*32/s）
            for (const g of d.groups) {
                const cx = g.x * 48 / s - vp.scrollLeft, cy = g.y * 32 / s - vp.scrollTop;
                const bw = g.half * 2 * 48 / s, bh = g.half * 2 * 32 / s;
                if (cx + bw / 2 < 0 || cy + bh / 2 < 0 || cx - bw / 2 > w || cy - bh / 2 > h) continue;
                ctx.fillStyle = HEAT_FILL[g.tier]; ctx.strokeStyle = HEAT_EDGE[g.tier];
                ctx.lineWidth = 1;
                ctx.fillRect(cx - bw / 2, cy - bh / 2, bw, bh);
                ctx.strokeRect(cx - bw / 2, cy - bh / 2, bw, bh);
            }
        }
        // 悬停命中检测（世界格坐标 -> 最近 Region 方块）
        vp.addEventListener("mousemove", (e) => {
            if (!chkResp.checked || curView !== "map") { heatTooltip.style.display = "none"; return; }
            const mi = curMap();
            const d = mi ? respCache[mi.name] : null;
            if (!d) { heatTooltip.style.display = "none"; return; }
            const rect = vp.getBoundingClientRect();
            const s = curScale();
            const wx = (vp.scrollLeft + e.clientX - rect.left) * s;
            const wy = (vp.scrollTop + e.clientY - rect.top) * s;
            const cx = wx / 48, cy = wy / 32;
            let best = null;
            for (const g of d.groups) {
                if (Math.abs(cx - g.x) <= g.half && Math.abs(cy - g.y) <= g.half) {
                    if (!best || g.half < best.half) best = g;
                }
            }
            if (!best) { heatTooltip.style.display = "none"; return; }
            heatTooltip.innerHTML = "<b>👹 刷新区</b> " + MAP_CN[mi.name.replace(/\\.map$/i, "")] +
                "<br>" + best.entries.map(r =>
                    `${r.mc} ×${r.count} · 刷新延迟 ${r.delay}s · DropSet ${r.dropset}` +
                    (r.boss ? " · 👑BOSS" : "")).join("<br>");
            heatTooltip.style.display = "block";
            heatTooltip.style.left = Math.min(e.clientX + 14, window.innerWidth - 300) + "px";
            heatTooltip.style.top = Math.max(4, e.clientY - 20) + "px";
        });
        vp.addEventListener("mouseleave", () => { heatTooltip.style.display = "none"; });
        chkResp.addEventListener("change", () => { drawHeat(); });

        // ---- 2. 任务叠加模式（VisitRegion 金框 / KillMonster·GainItem 红色脉冲） ----
        const questSvg = document.getElementById("quest-svg");
        const questPanel = document.getElementById("quest-panel");
        const questSel = document.getElementById("quest-sel");
        let questList = null, questData = null;   // questData = 当前选中任务覆盖层
        async function loadQuests() {
            if (questList) return;
            try {
                const res = await fetch("/api/quests");
                const d = await res.json();
                if (!d.ok) {
                    questSel.innerHTML = '<option value="">📜 任务数据不可用</option>';
                    questSel.disabled = true; questSel.title = "workspace QuestInfo 缺失";
                    return;
                }
                questList = d.quests;
                for (const q of questList) {
                    const opt = document.createElement("option");
                    opt.value = q.id;
                    opt.textContent = `📜 ${q.name} (${q.kinds.join("+")})`;
                    questSel.appendChild(opt);
                }
            } catch (e) { questSel.innerHTML = '<option value="">📜 任务数据不可用</option>'; questSel.disabled = true; }
        }
        questSel.addEventListener("change", async () => {
            const id = questSel.value;
            if (!id) { questData = null; drawQuest(); questPanel.style.display = "none"; return; }
            try {
                const res = await fetch("/api/quest?id=" + encodeURIComponent(id));
                const d = await res.json();
                questData = d.ok ? d : null;
            } catch (e) { questData = null; }
            drawQuest(); renderQuestPanel();
        });
        function drawQuest() {
            const mi = curMap();
            questSvg.setAttribute("width", vp.clientWidth);
            questSvg.setAttribute("height", vp.clientHeight);
            if (!mi || !questData) { questSvg.innerHTML = ""; return; }
            const s = curScale();
            const hereStem = mi.name.replace(/\\.map$/i, "");
            const px = v => v * 48 / s - vp.scrollLeft;
            const py = v => v * 32 / s - vp.scrollTop;
            let html = "";
            // VisitRegion -> 金色描边 + 半透明填充
            for (const r of (questData.regions || [])) {
                if (String(r.map) !== hereStem) continue;
                const bw = r.half * 2 * 48 / s, bh = r.half * 2 * 32 / s;
                const x = px(r.x) - bw / 2, y = py(r.y) - bh / 2;
                html += `<rect x="${x}" y="${y}" width="${bw}" height="${bh}" fill="rgba(255,213,74,.18)" stroke="#ffd54a" stroke-width="2.5"><title>任务区域：${r.desc || r.idx}</title></rect>`;
            }
            // KillMonster/GainItem 怪物点位 -> 红色/橙色脉冲
            for (const m of (questData.monsters || [])) {
                const color = m.kind === "KillMonster" ? "#ff4b4b" : "#ff9b3d";
                for (const p of (m.points || [])) {
                    if (String(p.map) !== hereStem) continue;
                    const cx = px(p.x), cy = py(p.y);
                    if (cx < -40 || cy < -40 || cx > vp.clientWidth + 40 || cy > vp.clientHeight + 40) continue;
                    html += `<g class="qmarker"><circle class="qkill" data-jmap="${p.map}" data-x="${p.x}" data-y="${p.y}" cx="${cx}" cy="${cy}" r="7" fill="${color}" stroke="#fff" stroke-width="1.5" opacity=".95"><title>${m.m} ×${p.count}${m.item ? " · 掉 " + m.item : ""}</title></circle></g>`;
                }
            }
            questSvg.innerHTML = html;
        }
        questSvg.addEventListener("click", (e) => {
            const c = e.target.closest("circle.qkill");
            if (c) e.stopPropagation();
        });
        // 步骤序列（MAP-P1-01）：monster 步骤 + region 步骤展开成可播放单元
        let questSteps = [], questStepIdx = -1;
        function questStepList() {
            // 与面板 .qstep 行一一对应：每个 monster 取首个有图文件的点，每个 region 一步
            const hasMap = st => maps.some(x => x.name === String(st) + ".map");
            const steps = [];
            for (const m of (questData.monsters || [])) {
                const p = (m.points || [])[0];   // 与面板 ▶定位 按钮同一判定
                if (p && hasMap(p.map)) steps.push({ kind: m.kind, label: (m.item || m.m) + " ×" + m.amount, map: String(p.map), x: +p.x, y: +p.y });
            }
            for (const r of (questData.regions || []))
                if (hasMap(r.map)) steps.push({ kind: "VisitRegion", label: "探访 " + (MAP_CN[r.map] || r.map), map: String(r.map), x: +r.x, y: +r.y });
            return steps;
        }
        function gotoQuestStep(i) {
            if (!questSteps.length) return;
            questStepIdx = (i + questSteps.length) % questSteps.length;   // 循环播放
            const st = questSteps[questStepIdx];
            showView("map");
            history.replaceState(null, "", `#map=${encodeURIComponent(st.map + ".map")}&cur=0&x=${Math.round(st.x * 48)}&y=${Math.round(st.y * 32)}&g=1&m=1&f=1`);
            init();
            markCurrentStep();
        }
        function markCurrentStep() {
            questPanel.querySelectorAll(".qstep").forEach(el => {
                el.classList.toggle("current", el.dataset.step !== undefined && +el.dataset.step === questStepIdx);
            });
        }
        function renderQuestPanel() {
            if (!questData) { questPanel.style.display = "none"; return; }
            const q = questData.quest;
            const kindLabel = { KillMonster: "讨伐", GainItem: "收集", VisitRegion: "探访" };
            let html = `<h4>📜 ${q.name}</h4>`;
            html += `<div class="qnav"><button id="qprev" type="button">⏮ 上一步</button>` +
                `<button id="qplay-all" type="button">▶ 逐步播放</button>` +
                `<button id="qnext" type="button">下一步 ⏭</button></div>`;
            let stepNo = 0;
            for (const m of (questData.monsters || [])) {
                const byMap = {};
                for (const p of (m.points || [])) (byMap[p.map] = byMap[p.map] || []).push(p);
                const spots = Object.keys(byMap).map(st => {
                    const exists = maps.some(x => x.name === st + ".map");
                    const jump = exists ? ` class="qmap" data-jmap="${st}" data-x="${byMap[st][0].x}" data-y="${byMap[st][0].y}"` : "";
                    return `<span${jump}>${MAP_CN[st] || st}${exists ? "" : " (无图文件)"}</span>`;
                }).join(" · ");
                const firstPt = (m.points || [])[0];
                const playable = firstPt && maps.some(x => x.name === String(firstPt.map) + ".map");
                const playBtn = playable ? `<button class="qplay" type="button" data-step="${stepNo}">▶ 定位</button>` : "";
                html += `<div class="qstep ${m.kind === "KillMonster" ? "kill" : "item"}"${playable ? ` data-step="${stepNo}"` : ""}>${playBtn}` +
                    `<b>${m.item || m.m}</b> ${kindLabel[m.kind] || m.kind} ×${m.amount}` +
                    `<br><span style="color:#8a8a98">怪物：</span>${m.m}` +
                    (spots ? `<br><span style="color:#8a8a98">位置：</span>${spots}` : "（无刷新点数据）") + `</div>`;
                stepNo++;
            }
            for (const r of (questData.regions || [])) {
                const exists = maps.some(x => x.name === String(r.map) + ".map");
                const playBtn = exists ? `<button class="qplay" type="button" data-step="${stepNo}">▶ 定位</button>` : "";
                html += `<div class="qstep visit"${exists ? ` data-step="${stepNo}"` : ""}>${playBtn}<b>探访区域</b>：${MAP_CN[r.map] || r.map} · ${r.desc || r.idx}</div>`;
                stepNo++;
            }
            if (!questData.monsters.length && !questData.regions.length) html += '<div class="qstep">该任务无地理步骤</div>';
            questPanel.innerHTML = html;
            questPanel.style.display = "block";
            questSteps = questStepList();
            // 播放控制
            const prev = questPanel.querySelector("#qprev"), next = questPanel.querySelector("#qnext"), playAll = questPanel.querySelector("#qplay-all");
            if (prev) prev.addEventListener("click", () => gotoQuestStep(questStepIdx < 0 ? 0 : questStepIdx - 1));
            if (next) next.addEventListener("click", () => gotoQuestStep(questStepIdx + 1));
            if (playAll) playAll.addEventListener("click", () => {
                if (window.__qTimer) { clearInterval(window.__qTimer); window.__qTimer = null; playAll.textContent = "▶ 逐步播放"; return; }
                gotoQuestStep(0);
                playAll.textContent = "⏸ 停止";
                window.__qTimer = setInterval(() => gotoQuestStep(questStepIdx + 1), 4000);
            });
            questPanel.querySelectorAll(".qplay").forEach(b =>
                b.addEventListener("click", (e) => { e.stopPropagation(); if (window.__qTimer) { clearInterval(window.__qTimer); window.__qTimer = null; } gotoQuestStep(+b.dataset.step); }));
            markCurrentStep();
            questPanel.querySelectorAll(".qmap").forEach(el => el.addEventListener("click", () => {
                showView("map");
                history.replaceState(null, "", `#map=${encodeURIComponent(el.dataset.jmap + ".map")}&cur=0&x=${Math.round(Number(el.dataset.x) * 48)}&y=${Math.round(Number(el.dataset.y) * 32)}&g=1&m=1&f=1`);
                init();
            }));
        }

        // ---- 6. 坐标拾取器（点击取格坐标 / Shift 双点曼哈顿距离） ----
        const pickSvg = document.getElementById("pick-svg");
        const pickPanel = document.getElementById("pick-panel");
        let pickA = null, pickB = null, pickDown = null;
        vp.addEventListener("mousedown", (e) => { pickDown = [e.clientX, e.clientY]; });
        vp.addEventListener("click", (e) => {
            if (pickDown && (Math.abs(e.clientX - pickDown[0]) + Math.abs(e.clientY - pickDown[1])) > 5) return;  // 拖拽后的 click
            const mi = curMap();
            if (!mi) return;
            const rect = vp.getBoundingClientRect();
            const s = curScale();
            const cx = Math.floor((vp.scrollLeft + e.clientX - rect.left) * s / 48);
            const cy = Math.floor((vp.scrollTop + e.clientY - rect.top) * s / 32);
            if (e.shiftKey) { pickB = [cx, cy]; if (!pickA) pickA = [cx, cy]; }
            else { pickA = [cx, cy]; pickB = null; }
            renderPick();
        });
        function renderPick() {
            pickSvg.setAttribute("width", vp.clientWidth);
            pickSvg.setAttribute("height", vp.clientHeight);
            const s = curScale();
            const dot = (p, label, color) => {
                const x = p[0] * 48 / s + 24 - vp.scrollLeft, y = p[1] * 32 / s + 16 - vp.scrollTop;
                return `<circle cx="${x}" cy="${y}" r="8" fill="none" stroke="${color}" stroke-width="2.5"><title>${label} (${p[0]},${p[1]})</title></circle>` +
                    `<text x="${x + 11}" y="${y + 4}" font-size="12" font-weight="700" fill="${color}" style="paint-order:stroke;stroke:#000;stroke-width:2px">${label}</text>`;
            };
            pickSvg.innerHTML = (pickA ? dot(pickA, "A", "#72d6ff") : "") + (pickB ? dot(pickB, "B", "#3de88a") : "") +
                ((pickA && pickB) ? `<line x1="${pickA[0] * 48 / s + 24 - vp.scrollLeft}" y1="${pickA[1] * 32 / s + 16 - vp.scrollTop}" x2="${pickB[0] * 48 / s + 24 - vp.scrollLeft}" y2="${pickB[1] * 32 / s + 16 - vp.scrollTop}" stroke="#ffd54a" stroke-dasharray="5 4" stroke-width="1.5" opacity=".8"/>` : "");
            if (!pickA) { pickPanel.style.display = "none"; return; }
            const copyBtn = (t, label) => `<button class="pick-copy" data-copy="${t}">复制${label || ""}</button>`;
            let html = `🎯 拾取 A: <b>(${pickA[0]}, ${pickA[1]})</b>${copyBtn(pickA[0] + ", " + pickA[1])}`;
            if (pickB) {
                const dist = Math.abs(pickB[0] - pickA[0]) + Math.abs(pickB[1] - pickA[1]);
                html += `<br>🎯 拾取 B: <b>(${pickB[0]}, ${pickB[1]})</b>${copyBtn(pickB[0] + ", " + pickB[1])}` +
                    `<br><span class="pick-dist">📏 曼哈顿距离：${dist} 格${copyBtn(String(dist), "距离")}</span>`;
            }
            html += `<br><span class="pick-hint">点击取 A · Shift+点击取 B 测距 · 双击清除</span>`;
            pickPanel.innerHTML = html;
            pickPanel.style.display = "block";
            attachCopy(pickPanel);
        }
        vp.addEventListener("dblclick", () => { pickA = pickB = null; renderPick(); });

        // ---- 3. 等级分层总览 + 5. NPC 审计 ----
        let ovData = null, ovAudit = null, ovFilter = "all", ovColorMode = "lvl", ovObserver = null;
        const NPC_TIERS = [
            { max: 0, cls: "none", label: "0" }, { max: 5, cls: "low", label: "1-5" },
            { max: 15, cls: "mid", label: "6-15" }, { max: 10000, cls: "high", label: "16+" }];
        function attachCopy(panel) {
            panel.querySelectorAll(".pick-copy").forEach(b => b.addEventListener("click", () => {
                const t = b.dataset.copy;
                const done = () => { b.textContent = "✅ 已复制"; setTimeout(() => b.textContent = "复制", 1200); };
                if (navigator.clipboard && window.isSecureContext) {
                    navigator.clipboard.writeText(t).then(done, () => fallbackCopy(t, done));
                } else fallbackCopy(t, done);
            }));
        }
        function fallbackCopy(text, done) {
            const ta = document.createElement("textarea");
            ta.value = text; ta.style.position = "fixed"; ta.style.opacity = "0";
            document.body.appendChild(ta); ta.select();
            try { document.execCommand("copy"); } catch (e) {}
            ta.remove(); if (done) done();
        }
        async function initOverview() {
            if (!ovData) {
                try {
                    const res = await fetch("/api/overview");
                    const d = await res.json();
                    ovData = d.ok ? d.maps : [];
                } catch (e) { ovData = []; }
                document.querySelector("#ov-filters span").textContent =
                    `📋 全库地图总览（${ovData.length} 张，缩略图后台生成中）`;
            }
            renderOvGrid();
            if (!ovAudit) {
                const box = document.getElementById("audit-table-box");
                try {
                    const res = await fetch("/api/npc_audit");
                    const d = await res.json();
                    ovAudit = d.ok ? d.rows : [];
                    const funcs = d.funcs || ["药店", "仓库", "修理", "传送"];
                    let html = '<table id="audit-table"><tr><th>地图</th><th>NPC数</th>';
                    for (const f of funcs) html += `<th>${f}</th>`;
                    html += "</tr>";
                    for (const r of ovAudit) {
                        if (!r.total) continue;
                        html += `<tr><td>${r.cn} <span style="color:#6a6a75">${r.map}</span></td><td>${r.total}</td>`;
                        for (const f of funcs) {
                            const names = (r.funcs || {})[f] || [];
                            html += `<td>${names.length
                                ? `<span class="audit-ok">✓ ${names.slice(0, 2).join("、")}${names.length > 2 ? "…" : ""}</span>`
                                : `<span class="audit-miss">✗ 缺</span>`}</td>`;
                        }
                        html += "</tr>";
                    }
                    box.innerHTML = html + "</table>";
                } catch (e) { box.textContent = "NPC 审计数据不可用"; }
            }
        }
        function renderOvGrid() {
            const grid = document.getElementById("ov-grid");
            const items = ovData.filter(m => {
                if (ovFilter === "boss") return m.boss;
                if (ovFilter === "hasmob") return m.resp > 0;
                if (ovFilter === "town" || ovFilter === "cave") return m.cat === ovFilter;
                return true;
            });
            if (ovObserver) ovObserver.disconnect();
            ovObserver = new IntersectionObserver((ents) => {
                for (const en of ents) {
                    if (en.isIntersecting) {
                        const img = en.target.querySelector("img[data-src]");
                        if (img) { img.src = img.dataset.src; delete img.dataset.src; }
                        ovObserver.unobserve(en.target);
                    }
                }
            }, { root: ovView, rootMargin: "500px 0px" });
            const LVL_LABEL = { low: "Lv1-15", mid: "Lv16-30", high: "Lv31-50", max: "Lv51+", none: "无怪" };
            grid.innerHTML = items.map(m => {
                let cls;
                if (ovColorMode === "npc") {
                    const t = NPC_TIERS.find(t => m.npcs <= t.max);
                    cls = t.cls;
                } else cls = m.tier;
                const meta = ovColorMode === "npc"
                    ? `NPC <span class="tier-${cls}">${m.npcs}</span> · 怪 ${m.resp}`
                    : `<span class="lv tier-${m.tier}">${LVL_LABEL[m.tier]}${m.lvl != null ? " · 均" + m.lvl : ""}</span> · 怪 ${m.resp} · NPC ${m.npcs}`;
                return `<div class="ov-card" data-map="${m.id}" data-file="${m.file ? 1 : 0}">` +
                    `<div class="ov-thumb">${m.file
                        ? `<img data-src="/thumb?map=${encodeURIComponent(m.id + ".map")}" alt="" loading="lazy">`
                        : `<span class="ph">🗺️</span><span class="ov-nofile">无图文件</span>`}` +
                    (m.boss ? `<span class="ov-crown" title="BOSS 刷新点">👑</span>` : "") + `</div>` +
                    `<div class="ov-name" title="${m.cn} (${m.id})">${m.cn} <span class="ov-id">${m.id}</span></div>` +
                    `<div class="ov-meta">${meta}</div>` +
                    `<div class="ov-bar bar-${cls}"></div></div>`;
            }).join("");
            grid.querySelectorAll(".ov-card").forEach(card => {
                ovObserver.observe(card);
                card.addEventListener("click", () => {
                    if (card.dataset.file !== "1") return;
                    showView("map");
                    history.replaceState(null, "", `#map=${encodeURIComponent(card.dataset.map + ".map")}&cur=0&g=1&m=1&f=1`);
                    init();
                });
            });
        }
        document.querySelectorAll("#ov-filters .ov-chip").forEach(chip => {
            chip.addEventListener("click", () => {
                if (chip.dataset.f) {
                    ovFilter = chip.dataset.f;
                    document.querySelectorAll('#ov-filters .ov-chip[data-f]').forEach(c => c.classList.toggle("active", c === chip));
                } else {
                    ovColorMode = chip.dataset.c;
                    document.querySelectorAll('#ov-filters .ov-chip[data-c]').forEach(c => c.classList.toggle("active", c === chip));
                }
                if (ovData) renderOvGrid();
            });
        });

        // ---- 4. 连通性图谱（力导向 + 孤岛红标 + 割点黄标） ----
        let graphInit = false;
        async function initGraph() {
            if (graphInit) return;
            const statsEl = document.getElementById("graph-stats");
            const box = document.getElementById("graph-box");
            let d;
            try { d = await (await fetch("/api/graph")).json(); } catch (e) { d = null; }
            if (!d || !d.ok) { statsEl.textContent = "连通数据不可用（workspace MovementInfo 缺失）"; return; }
            graphInit = true;
            const nodes = new Map(d.nodes.map(n => [n.id, n]));
            const linked = d.nodes.filter(n => !n.isolated);
            const isolated = d.nodes.filter(n => n.isolated);
            // FR 力导向（有边节点）；孤岛节点外圈环形排布
            const W = 1600, H = 1100;
            const pos = new Map();
            linked.forEach((n, i) => {
                const a = i * 2.399963;   // 黄金角散布
                const r = 60 + 90 * Math.sqrt(i / Math.max(1, linked.length));
                pos.set(n.id, [W / 2 + r * Math.cos(a) * 2.2, H / 2 + r * Math.sin(a)]);
            });
            const adj = new Map(d.nodes.map(n => [n.id, new Set()]));
            for (const [a, b] of d.edges) {
                if (a === b || !adj.has(a) || !adj.has(b)) continue;
                adj.get(a).add(b); adj.get(b).add(a);
            }
            const k = Math.sqrt(W * H / Math.max(1, linked.length)) * 0.16;
            for (let it = 0; it < 260; it++) {
                const disp = new Map(linked.map(n => [n.id, [0, 0]]));
                for (let i = 0; i < linked.length; i++) {
                    for (let j = i + 1; j < linked.length; j++) {
                        const a = linked[i].id, b = linked[j].id;
                        let dx = pos.get(a)[0] - pos.get(b)[0], dy = pos.get(a)[1] - pos.get(b)[1];
                        let dist = Math.max(1, Math.hypot(dx, dy));
                        const f = k * k / dist;
                        disp.get(a)[0] += dx / dist * f; disp.get(a)[1] += dy / dist * f;
                        disp.get(b)[0] -= dx / dist * f; disp.get(b)[1] -= dy / dist * f;
                    }
                }
                for (const [a, nbrs] of adj) {
                    for (const b of nbrs) {
                        if (!pos.has(a) || !pos.has(b)) continue;
                        let dx = pos.get(a)[0] - pos.get(b)[0], dy = pos.get(a)[1] - pos.get(b)[1];
                        let dist = Math.max(1, Math.hypot(dx, dy));
                        const f = dist * dist / k;
                        if (disp.has(a)) { disp.get(a)[0] -= dx / dist * f; disp.get(a)[1] -= dy / dist * f; }
                    }
                }
                const t = Math.max(2, 30 * (1 - it / 260));
                for (const [id, dp] of disp) {
                    const p = pos.get(id);
                    const dl = Math.max(1, Math.hypot(dp[0], dp[1]));
                    p[0] = Math.min(W, Math.max(0, p[0] + dp[0] / dl * Math.min(dl, t)));
                    p[1] = Math.min(H, Math.max(0, p[1] + dp[1] / dl * Math.min(dl, t)));
                }
            }
            isolated.forEach((n, i) => {
                const a = i * 2.399963;
                pos.set(n.id, [W / 2 + (W * 0.62) * Math.cos(a), H / 2 + (H * 0.62) * Math.sin(a)]);
            });
            // 渲染 SVG
            const islands = d.nodes.filter(n => n.island).length;
            const cuts = d.nodes.filter(n => n.cut).length;
            statsEl.innerHTML = `<b>${d.nodes.length}</b> 节点 · <b>${d.edges.length}</b> 边 · ` +
                `<span class="g-isl">孤岛(入度0) ${islands}</span> · <span class="g-cut">割点(必经) ${cuts}</span>` +
                ` · 拖拽平移 / 滚轮缩放 · 点击节点跳转`;
            let svg = `<svg id="graph-svg" viewBox="0 0 ${W} ${H}" style="width:100%; height:calc(100vh - 120px); cursor:grab; touch-action:none;">`;
            for (const [a, b] of d.edges) {
                if (!pos.has(a) || !pos.has(b)) continue;
                svg += `<line x1="${pos.get(a)[0]}" y1="${pos.get(a)[1]}" x2="${pos.get(b)[0]}" y2="${pos.get(b)[1]}" stroke="#3a4a5a" stroke-width="1" opacity=".8"/>`;
            }
            for (const n of d.nodes) {
                const p = pos.get(n.id);
                const fill = n.island ? "#ff5b5b" : (d.spawn_stems || []).includes(n.id) ? "#3de88a" : "#5a8fd0";
                const stroke = n.cut ? "#ffd54a" : "#111";
                const sw = n.cut ? 3 : 1.5;
                const r = n.isolated ? 3 : (n.indeg + n.outdeg > 8 ? 8 : 5);
                svg += `<g class="gnode" data-id="${n.id}" data-file="${n.file ? 1 : 0}">` +
                    `<circle cx="${p[0]}" cy="${p[1]}" r="${r}" fill="${fill}" stroke="${stroke}" stroke-width="${sw}">` +
                    `<title>${n.cn} (${n.id}) · 入${n.indeg}/出${n.outdeg}${n.island ? " · 孤岛" : ""}${n.cut ? " · 割点(必经之路)" : ""}${n.file ? "" : " · 无图文件"}</title></circle>` +
                    `${r > 4 ? `<text x="${p[0] + 9}" y="${p[1] + 3}">${n.cn}</text>` : ""}</g>`;
            }
            svg += "</svg>";
            box.innerHTML = svg;
            const gsvg = document.getElementById("graph-svg");
            let vb = [0, 0, W, H], gDrag = null;
            gsvg.addEventListener("wheel", (e) => {
                e.preventDefault();
                const f = e.deltaY > 0 ? 1.15 : 0.87;
                vb = [vb[0] + vb[2] * (1 - f) / 2, vb[1] + vb[3] * (1 - f) / 2, vb[2] * f, vb[3] * f];
                gsvg.setAttribute("viewBox", vb.join(" "));
            }, { passive: false });
            gsvg.addEventListener("mousedown", (e) => { gDrag = [e.clientX, e.clientY, ...vb]; });
            window.addEventListener("mousemove", (e) => {
                if (!gDrag) return;
                const sc = vb[2] / gsvg.clientWidth;
                vb = [gDrag[2] - (e.clientX - gDrag[0]) * sc, gDrag[3] - (e.clientY - gDrag[1]) * sc, gDrag[4], gDrag[5]];
                gsvg.setAttribute("viewBox", vb.join(" "));
            });
            window.addEventListener("mouseup", () => { gDrag = null; });
            if (window.WU && window.matchMedia && matchMedia("(pointer:coarse)").matches) {
                WU.gesture(gsvg, {
                    pan: (dx, dy) => {
                        const sc = vb[2] / gsvg.clientWidth;
                        vb = [vb[0] - dx * sc, vb[1] - dy * sc, vb[2], vb[3]];
                        gsvg.setAttribute("viewBox", vb.join(" "));
                    },
                    pinch: (step, cx, cy) => {
                        const f = step > 0 ? 1 / 1.15 : 1.15;
                        const sx = vb[0] + cx / gsvg.clientWidth * vb[2];
                        const sy = vb[1] + cy / gsvg.clientHeight * vb[3];
                        vb = [sx - (sx - vb[0]) * f, sy - (sy - vb[1]) * f, vb[2] * f, vb[3] * f];
                        gsvg.setAttribute("viewBox", vb.join(" "));
                    }
                });
            }
            gsvg.addEventListener("click", (e) => {
                const g = e.target.closest(".gnode");
                if (!g || g.dataset.file !== "1") return;
                showView("map");
                history.replaceState(null, "", `#map=${encodeURIComponent(g.dataset.id + ".map")}&cur=0&g=1&m=1&f=1`);
                init();
            });
        }

        // ---- 钩子：地图渲染/滚动/缩放时同步重绘三个叠加层 ----
        const _renderBase = render;
        render = function (keepAnchor) {
            _renderBase(keepAnchor);
            drawHeat(); drawQuest(); renderPick();
        };
        vp.addEventListener("scroll", () => { drawHeat(); drawQuest(); renderPick(); });
        window.addEventListener("resize", () => { drawHeat(); drawQuest(); renderPick(); });
        const _loadMapBase = loadMap;
        loadMap = function () {
            _loadMapBase();
            const mi = curMap();
            if (mi) { loadRespawns(mi); drawQuest(); renderQuestPanelSafe(); }
        };
        function renderQuestPanelSafe() {
            if (questData) questPanel.style.display = "block"; else questPanel.style.display = "none";
        }
        loadQuests();

        // 图例补充：热力分级 + 任务标记 + 拾取
        const legendPanel = document.getElementById("legend-panel");
        legendPanel.innerHTML +=
            '<hr style="border-color:#2e2e36;">' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(96,210,96,.5);"></span>刷怪 &lt;10</div>' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(255,213,74,.55);"></span>刷怪 10-49</div>' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(255,140,50,.55);"></span>刷怪 50-149</div>' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(255,60,60,.55);"></span>刷怪 ≥150</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#ff4b4b;box-shadow:0 0 6px #ff4b4b;"></span> 任务讨伐怪物刷新点（脉冲）</div>' +
            '<div class="lg-row"><span class="lg-dot" style="background:#ff9b3d;"></span> 任务收集掉落怪物点位</div>' +
            '<div class="lg-row"><span class="lg-block" style="background:rgba(255,213,74,.3);border:1px solid #ffd54a;"></span> 任务探访区域</div>' +
            '<div class="lg-row"><span style="color:#aaa;font-size:11px;">🎯 点击地图拾取格坐标 · Shift+点击测距</div>';

        // ---- 移动端：图层抽屉 + 触控手势（MAP-P0-01/02；桌面鼠标/滚轮路径不变） ----
        (function () {
            const layerGroup = document.getElementById("layer-group");
            const layerBackdrop = document.getElementById("layer-backdrop");
            const btnLayers = document.getElementById("btn-layers");
            if (!layerGroup || !btnLayers) return;
            const layerSheet = (open) => {
                layerGroup.classList.toggle("open", open);
                layerBackdrop.classList.toggle("open", open);
            };
            btnLayers.addEventListener("click", (e) => {
                e.stopPropagation();
                layerSheet(!layerGroup.classList.contains("open"));
            });
            layerBackdrop.addEventListener("click", () => layerSheet(false));
            window.addEventListener("keydown", (e) => { if (e.key === "Escape") layerSheet(false); });

            // 单指平移（滚动手感）/ 双指阶梯缩放 / 双击放大 —— 锚点逻辑与 Ctrl+滚轮一致
            if (window.WU && window.matchMedia && matchMedia("(pointer:coarse)").matches) {
                const zoomAt = (step, cx, cy) => {
                    anchorX = (vp.scrollLeft + cx) * curScale();
                    anchorY = (vp.scrollTop + cy) * curScale();
                    if (step > 0 && cur > 0) cur--;
                    else if (step < 0 && cur < scaleLadder.length - 1) cur++;
                    else return;
                    render(true); updateUrlHash(); saveState();
                };
                WU.gesture(vp, {
                    pan: (dx, dy) => { vp.scrollLeft -= dx; vp.scrollTop -= dy; },
                    pinch: (step, cx, cy) => zoomAt(step, cx, cy),
                    doubleTap: (x, y) => zoomAt(+1, x, y)
                });
            }
        })();
    </script>
</body>
</html>
"""

BATCH_PROGRESS = {
    "running": False,
    "total": 0,
    "current": 0,
    "current_map": "",
    "done": 0,
    "failed": 0,
    "percent": 0
}


KNOWN_CANDIDATE_ROOTS = [
    "/home/tetsuya/development/Zircon/Debug/Client",
    "/home/tetsuya/NAS/TMP/EI传奇3.0客户端",
    "/home/tetsuya/NAS/TMP/mir3ei"
]

def get_client_roots() -> list[dict]:
    roots = []
    for path in KNOWN_CANDIDATE_ROOTS:
        if os.path.exists(path):
            name = os.path.basename(path.rstrip("/"))
            m_dir = os.path.join(path, "Map") if os.path.exists(os.path.join(path, "Map")) else path
            d_dir = os.path.join(path, "Data") if os.path.exists(os.path.join(path, "Data")) else path
            roots.append({
                "name": name,
                "path": path,
                "map_dir": m_dir,
                "data_dir": d_dir
            })
    return roots


class ViewerHandler(BaseHTTPRequestHandler):
    map_cache: MapCache
    pool: FramePool
    tile_cache: dict[tuple, bytes] = {}
    tile_cache_lock = threading.Lock()
    protocol_version = "HTTP/1.1"
    cache_dir: str = ""   # disk cache root; empty disables persistence
    thumbs_dir: str = THUMBS_DIR  # full-map thumbnail dir (shared with WikiServer)
    render_locks: dict = {}       # per-fullmap-key render locks (dedupe work)
    render_locks_mu = threading.Lock()
    current_root_path: str = ""
    layout: str = LAYOUT_RECT   # axis-aligned (original Mir3.exe projection); "iso" legacy
    catalog: dict = {}          # map_name -> catalog doc (build_map_catalog.py)
    entities: list = []         # Mud3 Envir entity data (load_entities)
    connections: list = []      # exported System.db movement records
    db_names: dict = {}         # db_names.json: npcs/maps en->zh 显示名
    atlas: dict = {}            # 地图工坊索引（build_atlas：热力/任务/总览/连通/NPC审计）
    _thumb_map_cache = None     # MapCache13（13B 旧格式回退），/thumb 与预渲染共享

    @classmethod
    def _render_lock(cls, key: tuple):
        with cls.render_locks_mu:
            lk = cls.render_locks.get(key)
            if lk is None:
                lk = cls.render_locks[key] = threading.Lock()
            return lk


    def _json_200(self, body: bytes):
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    @classmethod
    def _thumb_mc(cls):
        """缩略图专用 MapCache：MapCache13 支持 13 字节旧格式地图回退。"""
        mc = cls._thumb_map_cache
        if mc is None:
            try:
                from thumb_gen import MapCache13
                mc = MapCache13(cls.map_cache.maps_dir, max_keep=4)
            except Exception:
                mc = cls.map_cache
            cls._thumb_map_cache = mc
        return mc

    def do_POST(self):
        from urllib.parse import parse_qs, urlparse
        if self.path.startswith("/api/switch_root"):
            qs = parse_qs(urlparse(self.path).query)
            target_path = qs.get("path", [""])[0]
            roots = get_client_roots()
            found = next((r for r in roots if r["path"] == target_path), None)
            if found:
                ViewerHandler.map_cache = MapCache(found["map_dir"])
                ViewerHandler.pool = FramePool(found["data_dir"])
                ViewerHandler.current_root_path = found["path"]
                ViewerHandler.cache_dir = os.path.join(found["map_dir"], ".tilecache")
                body = json.dumps({"ok": True, "current": found}).encode("utf-8")
            else:
                body = json.dumps({"ok": False, "error": "not_found"}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/rebuild":
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            if map_name:
                safe = map_name.replace("/", "_").replace("\\", "_")
                cdir = os.path.join(self.cache_dir, safe)
                if os.path.exists(cdir):
                    import shutil
                    shutil.rmtree(cdir, ignore_errors=True)
            body = b'{"ok": true}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/rebuild_all":
            if BATCH_PROGRESS["running"]:
                body = json.dumps({"ok": True, "msg": "already_running"}).encode("utf-8")
            else:
                def batch_worker():
                    BATCH_PROGRESS["running"] = True
                    maps = scan_maps(self.map_cache.maps_dir)
                    BATCH_PROGRESS["total"] = len(maps)
                    BATCH_PROGRESS["current"] = 0
                    BATCH_PROGRESS["done"] = 0
                    BATCH_PROGRESS["failed"] = 0
                    BATCH_PROGRESS["percent"] = 0
                    # clear stale cache so every map re-renders from scratch
                    if self.cache_dir and os.path.isdir(self.cache_dir):
                        try:
                            for name in os.listdir(self.cache_dir):
                                p = os.path.join(self.cache_dir, name)
                                if os.path.isdir(p):
                                    import shutil
                                    shutil.rmtree(p, ignore_errors=True)
                                else:
                                    os.remove(p)
                            print(f"[*] Cache cleared: {self.cache_dir}")
                        except Exception as ex:
                            print(f"[!] Cache clear failed: {ex}")
                    print(f"[*] Starting background pre-render for {len(maps)} maps...")
                    from concurrent.futures import ThreadPoolExecutor, as_completed

                    def render_one(m):
                        mname = m["name"]
                        w, h, _ = self.map_cache.get(mname)
                        ladder = map_ladder(w, h, self.layout)
                        if ladder:
                            z = ladder[-1]
                            data = render_full_map(self.map_cache, self.pool, mname, z, True, True, True,
                                                   layout=self.layout,
                                                   offset_mode=OFFSET_NONE)
                            key = (mname, z, True, True, True, OFFSET_NONE)
                            dp = self._fullmap_path(key)
                            os.makedirs(os.path.dirname(dp), exist_ok=True)
                            with open(dp, "wb") as f:
                                f.write(data)
                        return mname, None

                    done_i = [0]
                    with ThreadPoolExecutor(max_workers=4) as ex:
                        futs = {ex.submit(render_one, m): m for m in maps}
                        for fut in as_completed(futs):
                            mname = futs[fut].get("name")
                            BATCH_PROGRESS["current"] += 1
                            BATCH_PROGRESS["current_map"] = mname
                            BATCH_PROGRESS["percent"] = int((BATCH_PROGRESS["current"] / len(maps)) * 100)
                            try:
                                fut.result()
                                BATCH_PROGRESS["done"] += 1
                            except Exception as ex:
                                BATCH_PROGRESS["failed"] += 1
                                print(f"[!] Pre-render map {mname} failed: {ex}")

                    BATCH_PROGRESS["running"] = False
                    BATCH_PROGRESS["current_map"] = "完成"
                    print("[*] Background pre-render completed!")

                threading.Thread(target=batch_worker, daemon=True).start()
                body = json.dumps({"ok": True, "msg": "started"}).encode("utf-8")

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        else:
            self.send_error(404)

    def do_GET(self):
        if self.path == "/" or self.path == "/index.html":
            body = HTML_TEMPLATE.replace("/*__MAP_CN__*/",
                    json.dumps(MAP_CN, ensure_ascii=False)).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.split("?")[0].startswith("/_webui/"):
            # 共享移动端壳（Tools/common/webui/），见 TOOLS_MOBILE_ENHANCE_GOAL §3.1
            from pathlib import Path as _P
            name = self.path.split("?")[0][len("/_webui/"):]
            if not name or "/" in name or ".." in name:
                self.send_error(403)
                return
            f = _P(__file__).resolve().parent.parent / "common" / "webui" / name
            if not f.is_file():
                self.send_error(404)
                return
            ctype = {".css": "text/css; charset=utf-8",
                     ".js": "application/javascript; charset=utf-8"}.get(f.suffix, "application/octet-stream")
            body = f.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.split("?")[0] in ("/sim", "/sim.html"):
            body = SIM_TEMPLATE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/maps":
            maps = scan_maps(self.map_cache.maps_dir, self.layout)
            for m in maps:
                fid = m["name"][:-4] if m["name"].endswith(".map") else m["name"]
                cn = MAP_CN.get(fid)
                if not cn or cn.startswith("EI ") or cn == fid:
                    cn = map_cn(fid)
                m["cn"] = cn
                m["cat"] = map_category(fid)
            body = json.dumps(maps).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/progress":
            body = json.dumps(BATCH_PROGRESS).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/roots":
            roots = get_client_roots()
            cur = self.current_root_path or (roots[0]["path"] if roots else "")
            body = json.dumps({"roots": roots, "current": cur}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/api/catalog?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            doc = self.catalog.get(map_name)
            if doc is None:
                body = json.dumps({"ok": False, "error": "not_in_catalog"}).encode("utf-8")
            else:
                body = json.dumps({"ok": True, "catalog": doc}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/api/connections?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.splitext(os.path.basename(qs.get("map", [""])[0]))[0]
            links = self.conn_index.get(map_name, [])
            body = json.dumps({"ok": True, "map": map_name, "links": links}, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/api/entities?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            map_stem = os.path.splitext(map_name)[0]
            # 兼容 "0.map"（Envir 实体）与 "0"（workspace 实体）两种命名
            ents = [e for e in self.entities
                    if e.get("map") == map_name or e.get("map") == map_stem]
            # 合并 System.db 位置实体（dbviewer 服务 8800 运行时启用）：
            # 刷怪点 / NPC / 守卫 / 传送点 / 安全区，格式与 Envir 实体一致。
            try:
                import urllib.request
                db_url = "http://127.0.0.1:8800/api/map-entities?map=" + urllib.parse.quote(map_name)
                with urllib.request.urlopen(db_url, timeout=3) as r:
                    db = json.loads(r.read().decode("utf-8"))
                for e in db.get("entities", []):
                    if not any(x.get("x") == e.get("x") and x.get("y") == e.get("y")
                               and x.get("kind") == e.get("kind") and x.get("name") == e.get("name")
                               for x in ents):
                        ents.append(e)
            except Exception:
                pass
            body = json.dumps({"ok": True, "count": len(ents), "entities": ents},
                              ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        # ------------------------------------------------ 地图工坊端点
        # 全部优雅降级：atlas 缺失（workspace 表不全）时返回 ok=False + 200，
        # 前端禁用对应图层并提示，不崩。
        elif self.path.startswith("/api/respawns?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            stem = os.path.splitext(os.path.basename(qs.get("map", [""])[0]))[0]
            respawns = (self.atlas or {}).get("respawns_by_map", {}).get(stem, [])
            body = json.dumps({"ok": True, "map": stem, "count": len(respawns),
                               "respawns": respawns}, ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/quests"):
            quests = (self.atlas or {}).get("quests") or []
            body = json.dumps({"ok": bool(quests), "count": len(quests),
                               "quests": [{"id": q["id"], "name": q["name"],
                                           "type": q["type"],
                                           "kinds": sorted({t["type"] for t in q["tasks"]})}
                                          for q in quests]},
                              ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/quest?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            atlas = self.atlas or {}
            try:
                qid = int(qs.get("id", ["0"])[0])
            except ValueError:
                qid = 0
            quest = next((q for q in atlas.get("quests", []) if q["id"] == qid), None)
            if quest is None:
                body = json.dumps({"ok": False, "error": "quest_not_found"},
                                  ensure_ascii=False).encode("utf-8")
            else:
                # 解析任务 -> 覆盖层：VisitRegion 金框 / KillMonster·GainItem
                # 怪物刷新点（跨地图）。点位取 respawns_by_monster 反查。
                rbm = atlas.get("respawns_by_monster", {})
                regions, monsters = [], []
                seen_m = set()
                for t in quest["tasks"]:
                    if t["type"] == "VisitRegion" and t.get("region"):
                        regions.append(t["region"])
                    for men in t["monsters"]:
                        if men in seen_m:
                            continue
                        seen_m.add(men)
                        monsters.append({
                            "m": men, "kind": t["type"],
                            "item": t.get("item_cn") or t.get("item"),
                            "amount": t["amount"],
                            "points": rbm.get(men, []),
                        })
                body = json.dumps({"ok": True, "quest": quest,
                                   "regions": regions, "monsters": monsters},
                                  ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/overview"):
            overview = (self.atlas or {}).get("overview") or []
            body = json.dumps({"ok": bool(overview), "count": len(overview),
                               "maps": overview}, ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.split("?")[0] == "/api/map_links_v2.json":
            path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "map_links_v2.json")
            try:
                with open(path, "rb") as f:
                    body = f.read()
            except OSError:
                body = json.dumps((self.atlas or {}).get("links_v2") or
                                  {"ok": False, "error": "links_v2_not_generated"},
                                  ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/graph"):
            graph = (self.atlas or {}).get("graph") or {}
            body = json.dumps({"ok": bool(graph), **graph},
                              ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/npc_audit"):
            rows = (self.atlas or {}).get("npc_audit") or []
            body = json.dumps({"ok": bool(rows), "count": len(rows), "rows": rows,
                               "funcs": [f for f, _, _ in NPC_FUNC_RULES]},
                              ensure_ascii=False).encode("utf-8")
            self._json_200(body)


        elif self.path.startswith("/api/cell?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            try:
                x = int(qs.get("x", ["0"])[0])
                y = int(qs.get("y", ["0"])[0])
            except ValueError:
                self.send_error(400, "x/y must be ints")
                return
            try:
                w, h, cells = self.map_cache.get(map_name)
            except Exception as ex:
                self.send_error(404, f"map not readable: {ex}")
                return
            if not (0 <= x < w and 0 <= y < h):
                body = json.dumps({"ok": False, "error": "out_of_bounds",
                                   "w": w, "h": h}).encode("utf-8")
            else:
                c = cells[x][y]
                def lib_name(lid):
                    return KR_ORDER.get(lid, f"lib{lid}") if lid >= 0 else "none"
                body = json.dumps({
                    "ok": True, "x": x, "y": y, "w": w, "h": h,
                    "flag": c.flag, "anim": [c.anim_a, c.anim_b],
                    "back": {"file": c.back_file, "lib": lib_name(c.back_file),
                             "frame": c.back_img},
                    "mid": {"file": c.mid_file, "lib": lib_name(c.mid_file),
                            "frame": c.mid_img},
                    "front": {"file": c.front_file, "lib": lib_name(c.front_file),
                              "frame": c.front_img},
                }, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/strip?"):
            # Export the 3-mode offset comparison strip as PNG (sim "导出对比图").
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            if not map_name.lower().endswith(".map"):
                self.send_error(400, "map must be a .map file")
                return
            try:
                z = int(qs.get("z", ["2"])[0])
            except ValueError:
                z = 2
            g = qs.get("g", ["1"])[0] == "1"
            m = qs.get("m", ["1"])[0] == "1"
            f = qs.get("f", ["1"])[0] == "1"
            try:
                data = render_offset_strip(self.map_cache, self.pool, map_name, z,
                                           g, m, f, layout=self.layout)
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception as ex:
                self.send_error(500, str(ex))

        elif self.path.startswith("/sprite?"):
            # Decode a single frame from a named WIL library (character / NPC /
            # monster sprites for the simulator) as a transparent PNG.
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            lib_name = os.path.basename(qs.get("lib", [""])[0])
            try:
                frame = int(qs.get("frame", ["0"])[0])
                scale = int(qs.get("scale", ["1"])[0])
            except ValueError:
                self.send_error(400, "frame/scale must be ints")
                return
            if not lib_name.lower().endswith(".wil"):
                self.send_error(400, "lib must be a .wil file")
                return
            lib_path = os.path.join(self.pool.data_dir, lib_name)
            if not os.path.exists(lib_path):
                self.send_error(404, "lib not found in data dir")
                return
            try:
                from wilsdk import open_library as _open_wil
                lib = _open_wil(lib_path)
                img = lib.decode(frame) if frame < lib.count else None
                if img is None:
                    self.send_error(404, f"frame {frame} blank or out of range")
                    return
                if scale > 1:
                    img = img.resize((max(1, img.width // scale), max(1, img.height // scale)),
                                     Image.NEAREST)
                buf = io.BytesIO()
                img.save(buf, format="PNG")
                data = buf.getvalue()
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Cache-Control", "public, max-age=86400")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception as ex:
                self.send_error(500, str(ex))

        elif self.path.startswith("/thumb?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            thumb_path = os.path.join(self.thumbs_dir, map_name + ".png")
            if not os.path.exists(thumb_path):
                # On-demand render + disk cache (one-time, ~seconds to tens of
                # seconds for large maps; shared with WikiServer/thumb_gen).
                # 13B 旧格式地图经 MapCache13 回退解析；与后台预渲染共享 per-map
                # 锁，避免并发写坏 PNG。
                with self._render_lock(("thumb", map_name)):
                    if not os.path.exists(thumb_path):
                        try:
                            from thumb_gen import render_one
                            mc = self._thumb_mc()
                            w, h, _ = mc.get(map_name)
                            render_one(mc, self.pool, self.thumbs_dir, map_name, w, h)
                        except Exception as ex:
                            self.send_error(500, f"thumb render failed: {ex}")
                            return
            try:
                with open(thumb_path, "rb") as f:
                    body = f.read()
            except FileNotFoundError:
                self.send_error(404, "thumb not generated")
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Cache-Control", "public, max-age=3600")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/minimap?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            stem = map_name[:-4] if map_name.lower().endswith(".map") else map_name
            img = None
            try:
                img = MiniMapSource._for(self.pool.data_dir).frame(stem)
            except Exception:
                img = None
            if img is None:
                self.send_error(404, "no minimap for %s" % map_name)
                return
            buf = io.BytesIO()
            if img.mode != "RGB":
                img = img.convert("RGB")
            img.save(buf, format="JPEG", quality=85)
            data = buf.getvalue()
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Cache-Control", "public, max-age=86400")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        elif self.path.startswith("/fullmap?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            if not map_name.lower().endswith(".map"):
                self.send_error(400, "map must be a .map file")
                return
            z = int(qs.get("z", ["0"])[0])
            g = qs.get("g", ["1"])[0] == "1"
            m = qs.get("m", ["1"])[0] == "1"
            f = qs.get("f", ["1"])[0] == "1"
            om = qs.get("om", [OFFSET_NONE])[0]
            if om not in OFFSET_MODES:
                om = OFFSET_NONE
            try:
                w, h, _ = self.map_cache.get(map_name)
                ladder = map_ladder(w, h, self.layout)
                if ladder:
                    z = min(max(z, ladder[0]), ladder[-1])
                key = (map_name, z, g, m, f, om)
                dp = self._fullmap_path(key)
                try:
                    with open(dp, "rb") as f:
                        data = f.read()
                except FileNotFoundError:
                    data = None
                if data is None:
                    with self._render_lock(key):
                        try:
                            with open(dp, "rb") as f:
                                data = f.read()
                        except FileNotFoundError:
                            data = None
                        if data is None:
                            # One full-map render per (map, zoom, layers);
                            # disk-cached, so the browser's next open is a
                            # static file read instead of a re-render.
                            data = render_full_map(self.map_cache, self.pool,
                                                   map_name, z, g, m, f,
                                                   layout=self.layout,
                                                   offset_mode=om)
                            os.makedirs(os.path.dirname(dp), exist_ok=True)
                            tmp = dp + ".tmp"
                            with open(tmp, "wb") as f:
                                f.write(data)
                            os.replace(tmp, dp)
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Cache-Control", "public, max-age=86400")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception as ex:
                self.send_error(500, str(ex))

        elif self.path.startswith("/tile?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = qs.get("map", [""])[0]
            tx = int(qs.get("tx", ["0"])[0])
            ty = int(qs.get("ty", ["0"])[0])
            z = int(qs.get("z", ["0"])[0])
            g = qs.get("g", ["1"])[0] == "1"
            m = qs.get("m", ["1"])[0] == "1"
            f = qs.get("f", ["1"])[0] == "1"
            om = qs.get("om", [OFFSET_NONE])[0]
            if om not in OFFSET_MODES:
                om = OFFSET_NONE

            try:
                key = (map_name, tx, ty, z, g, m, f, om)
                with self.tile_cache_lock:
                    data = self.tile_cache.get(key)
                if data is None and self.cache_dir:
                    # L2: disk cache survives restarts; the expensive render
                    # (4.6k Python RLE decodes + 122k composites for a 350x350
                    # map) is paid once per tile EVER, not once per session.
                    dp = self._tile_path(key)
                    try:
                        with open(dp, "rb") as f:
                            data = f.read()
                    except FileNotFoundError:
                        data = None
                if data is None:
                    data = render_tile(self.map_cache, self.pool, map_name, tx, ty, z, g, m, f,
                                       layout=self.layout, offset_mode=om)
                    with self.tile_cache_lock:
                        self.tile_cache[key] = data
                        while len(self.tile_cache) > CACHE_TILES_MAX:
                            self.tile_cache.pop(next(iter(self.tile_cache)))
                    if self.cache_dir:
                        dp = self._tile_path(key)
                        os.makedirs(os.path.dirname(dp), exist_ok=True)
                        tmp = dp + ".tmp"
                        with open(tmp, "wb") as f:
                            f.write(data)
                        os.replace(tmp, dp)
                self.send_response(200)
                self.send_header("Content-Type", "image/png" if z == 0 else "image/jpeg")
                self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception as ex:
                self.send_error(500, str(ex))
        else:
            self.send_error(404)

    def _tile_path(self, key: tuple) -> str:
        map_name, tx, ty, z, g, m, f, om = key
        safe = map_name.replace("/", "_").replace("\\", "_")
        ext = "png" if z == 0 else "jpg"
        tag = "r" if self.layout == LAYOUT_RECT else "i"
        omt = "n" if om == OFFSET_NONE else ("a" if om == OFFSET_ALL else "m")
        return os.path.join(self.cache_dir, safe, f"{tag}_{tx}_{ty}_{z}_{int(g)}{int(m)}{int(f)}{omt}.{ext}")

    def _fullmap_path(self, key: tuple) -> str:
        map_name, z, g, m, f, om = key
        safe = map_name.replace("/", "_").replace("\\", "_")
        tag = "r" if self.layout == LAYOUT_RECT else "i"
        omt = "n" if om == OFFSET_NONE else ("a" if om == OFFSET_ALL else "m")
        return os.path.join(self.cache_dir, safe, f"full_{tag}_{z}_{int(g)}{int(m)}{int(f)}{omt}.jpg")


def map_category(fid: str) -> str:
    """Classify a map stem into town / cave / room."""
    f = (fid or "").strip()
    if not f:
        return "other"
    # sub-areas / buildings / small rooms: contains '_' (e.g. 0_000, 1_001, D404_002)
    if "_" in f:
        return "room"
    up = f.upper()
    # caves / dungeons / mines: D / ID prefixes
    if up.startswith("D") or up.startswith("ID"):
        return "cave"
    # towns / overland: plain numbers, E roads, GM
    if f.isdigit() or up.startswith("E") or up.startswith("GM"):
        return "town"
    return "other"


def scan_maps(maps_dir: str, layout: str = LAYOUT_RECT) -> list[dict]:
    out = []
    for fn in os.listdir(maps_dir):
        if not fn.lower().endswith(".map"):
            continue
        try:
            w, h = parse_map_header(os.path.join(maps_dir, fn))
            ww, wh = world_bounds(w, h, layout)
            out.append({
                "name": fn,
                "w": w,
                "h": h,
                "world_w": ww,
                "world_h": wh,
                "ladder": map_ladder(w, h, layout),
            })
        except Exception:
            continue
    out.sort(key=lambda m: m["name"])
    return out


def load_catalog(catalog_dir: str) -> dict:
    """Load map-catalog.json (from build_map_catalog.py) into
    {map_name: doc}.  Returns {} when the dir/file is absent or invalid."""
    if not catalog_dir:
        return {}
    p = os.path.join(catalog_dir, "map-catalog.json")
    if not os.path.exists(p):
        return {}
    try:
        with open(p, encoding="utf-8") as f:
            data = json.load(f)
        return {d.get("name"): d for d in data.get("maps", []) if d.get("name")}
    except Exception:
        return {}


def load_connections(path: str) -> list[dict]:
    """Load exported System.db movements, keeping only renderable endpoints."""
    if not path or not os.path.exists(path):
        return []
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return [x for x in data.get("links", [])
                if x.get("source", {}).get("map") and x.get("destination", {}).get("map")]
    except (OSError, ValueError, TypeError):
        return []


# ------------------------------------------------ dbeditor workspace 直读
# NPC 位置与地图连接的第一数据源：Tools/dbeditor/workspace/*.json 是
# System.db 的全表 JSON 导出（dbeditor 保存即更新 / NpcMover 坐标修正同样
# 落在这里）。坐标取 MapRegion.PointRegion 质心（CenterX/CenterY，游戏格）。

def _ws_rows(workspace: str, table: str) -> list[dict]:
    p = os.path.join(workspace, table + ".json")
    try:
        with open(p, encoding="utf-8") as f:
            data = json.load(f)
        rows = data.get("rows") if isinstance(data, dict) else data
        return rows or []
    except (OSError, ValueError, TypeError):
        return []


def load_db_names(path: str) -> dict:
    """db_names.json -> {npcs/maps/monsters/items: {en: zh}} (zh 优先, en 兜底)."""
    out: dict[str, dict] = {k: {} for k in ("npcs", "maps", "monsters", "items")}
    if not path or not os.path.exists(path):
        return out
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for section in ("npcs", "maps", "monsters", "items"):
            sec = data.get(section) or {}
            for en, entry in sec.items():
                zh = entry.get("zh") if isinstance(entry, dict) else None
                out[section][en] = zh if zh else en
    except (OSError, ValueError, TypeError, AttributeError):
        pass
    return out


def load_workspace_entities(workspace: str, db_names: dict | None = None) -> list[dict]:
    """NPCInfo x MapRegion -> [{map,x,y,kind:'npc',name,name_en}].

    name 为中文名（db_names.npcs 命中时），name_en 保留 DB 原名；坐标为
    Region.PointRegion 质心（EI 坐标系，NpcMover 修正后的最新值）。"""
    npc_names = (db_names or {}).get("npcs", {})
    regions = {r.get("Index"): r for r in _ws_rows(workspace, "MapRegion")}
    out: list[dict] = []
    for n in _ws_rows(workspace, "NPCInfo"):
        reg = regions.get((n.get("Region") or {}).get("Index"))
        if not reg:
            continue
        pr = reg.get("PointRegion") or {}
        x, y = pr.get("CenterX"), pr.get("CenterY")
        if x is None or y is None:
            continue
        en = n.get("NPCName") or ""
        out.append({
            "map": str((reg.get("Map") or {}).get("Name", "")),
            "x": x, "y": y, "kind": "npc",
            "name": npc_names.get(en, en) or en,
            "name_en": en,
        })
    return out


def load_workspace_connections(workspace: str) -> list[dict]:
    """MovementInfo x MapRegion -> links（与 map-connections.json 同 schema）.

    Region 质心坐标直接从 workspace MapRegion 取（0 缺失），比 8月11 的
    Markdown 导出（155 端点 x=null）完整；MovementInfo 1039 行含 D 系地下城
    连接。"""
    regions = {r.get("Index"): r for r in _ws_rows(workspace, "MapRegion")}

    def endpoint(ref) -> dict:
        reg = regions.get((ref or {}).get("Index")) or {}
        pr = reg.get("PointRegion") or {}
        x, y = pr.get("CenterX"), pr.get("CenterY")
        return {
            "map": str((reg.get("Map") or {}).get("Name", "")),
            "region": (ref or {}).get("Index"),
            "description": reg.get("Description", ""),
            "x": x if x is not None else None,
            "y": y if y is not None else None,
        }

    links = []
    for m in _ws_rows(workspace, "MovementInfo"):
        src = endpoint(m.get("SourceRegion"))
        dst = endpoint(m.get("DestinationRegion"))
        if not src["map"] or not dst["map"]:
            continue
        links.append({"index": m.get("Index"), "icon": str(m.get("Icon") or "None"),
                      "source": src, "destination": dst})
    return links


# ------------------------------------------------------ 地图工坊 atlas
# 启动时对 workspace/*.json（System.db 全表导出）做一次全量 JOIN，构建内存
# 索引：地图号 -> [regions/respawns/npcs]，怪物 -> 刷新点，任务 -> 覆盖层，
# MovementInfo -> 连通图谱 + map_links_v2.json。所有端点 O(1) 查询，无每请求
# 全表扫描。MapRegion 无显式矩形（只有 PointRegion 质心 + Size 格数），色块
# 以质心为中心、边长 = sqrt(Size) 格的方块近似。

# 出生点地图（连通图谱孤岛判定排除项）
SPAWN_STEMS = {"0"}
# 守卫类怪物等级（Guard/Archer = 250）不参与地图等级均值 —— 否则每张城图
# 都被守卫拉成 51+ 红区，总览分层失去意义。
GUARD_LEVEL_CAP = 200

# NPC 功能覆盖审计规则：先按 EntryPage 匹配，再按中/英文名关键词兜底。
NPC_FUNC_RULES = [
    ("药店", ("Basic Potion",), ("药", "Potion", "Pharmacy")),
    ("仓库", ("Storage",), ("仓", "Storage", "Warehouse")),
    ("修理", ("Weapon Refiner", "Repair"), ("修理", "铁匠", "Repair", "Refin", "Smith")),
    ("传送", ("Teleport",), ("传送", "Teleport")),
]


def _region_block(reg: dict) -> tuple[int, int, int] | None:
    """MapRegion -> (CenterX, CenterY, half_side_cells) 或 None（无质心）。"""
    pr = reg.get("PointRegion") or {}
    x, y = pr.get("CenterX"), pr.get("CenterY")
    if x is None or y is None:
        return None
    size = reg.get("Size") or pr.get("PointCount") or 1
    half = max(1, round((size ** 0.5) / 2))
    return int(x), int(y), half


def level_tier(avg: float | None) -> str:
    """总览染色分层：1-15 灰绿 / 16-30 黄 / 31-50 橙 / 51+ 红 / 无怪 灰。"""
    if avg is None:
        return "none"
    if avg <= 15:
        return "low"
    if avg <= 30:
        return "mid"
    if avg <= 50:
        return "high"
    return "max"


def respawn_tier(count: int) -> str:
    """刷怪热力分级：绿<10 黄<50 橙<150 红>=150。"""
    if count < 10:
        return "t1"
    if count < 50:
        return "t2"
    if count < 150:
        return "t3"
    return "t4"


def _articulation_points(nodes: set, adj: dict) -> set:
    """无向图割点（Tarjan）。adj 为双向邻接表。"""
    seen, disc, low = set(), {}, {}
    cut = set()
    timer = [0]

    def dfs(u: int, parent: int):
        seen.add(u)
        disc[u] = low[u] = timer[0]
        timer[0] += 1
        children = 0
        for v in adj.get(u, ()):
            if v == parent:
                continue
            if v in seen:
                low[u] = min(low[u], disc[v])
            else:
                dfs(v, u)
                low[u] = min(low[u], low[v])
                children += 1
                if parent != -1 and low[v] >= disc[u]:
                    cut.add(u)
        if parent == -1 and children > 1:
            cut.add(u)

    order = sorted(nodes)   # 确定性遍历顺序
    for n in order:
        if n not in seen:
            dfs(n, -1)
    return cut


def build_atlas(workspace: str, db_names: dict, maps_dir: str) -> dict:
    """workspace 全表 JOIN -> 地图工坊六大功能的内存索引（见模块注释）。"""
    regions = {r.get("Index"): r for r in _ws_rows(workspace, "MapRegion")}
    monsters = {m.get("Index"): m for m in _ws_rows(workspace, "MonsterInfo")}
    m_cn = db_names.get("monsters", {})
    i_cn = db_names.get("items", {})
    n_cn = db_names.get("npcs", {})
    npc_stems = db_names.get("maps", {})

    def cn_of_map(stem: str, desc: str = "") -> str:
        return MAP_CN.get(stem) or npc_stems.get(desc) or desc or stem

    atlas: dict = {
        "respawns_by_map": {}, "regions_by_map": {}, "respawns_by_monster": {},
        "quests": [], "overview": [], "npc_audit": [], "links_v2": {},
        "graph": {}, "item_droppers": {},
    }

    # ---- MapRegion：地图号 -> 区域块（质心 + Size 方块近似） ----
    for reg in regions.values():
        blk = _region_block(reg)
        if blk is None:
            continue
        stem = str((reg.get("Map") or {}).get("Name", ""))
        if not stem:
            continue
        x, y, half = blk
        atlas["regions_by_map"].setdefault(stem, []).append({
            "idx": reg.get("Index"), "desc": reg.get("Description", ""),
            "x": x, "y": y, "half": half,
        })

    # ---- RespawnInfo × MapRegion × MonsterInfo -> 刷怪热力 ----
    for r in _ws_rows(workspace, "RespawnInfo"):
        reg = regions.get((r.get("Region") or {}).get("Index")) or {}
        blk = _region_block(reg)
        if blk is None:
            continue
        stem = str((reg.get("Map") or {}).get("Name", ""))
        if not stem:
            continue
        x, y, half = blk
        men = (r.get("Monster") or {}).get("Name") or ""
        minfo = monsters.get((r.get("Monster") or {}).get("Index")) or {}
        count = int(r.get("Count") or 0)
        entry = {
            "m": men, "mc": m_cn.get(men, men), "x": x, "y": y, "half": half,
            "count": count, "delay": r.get("Delay"), "dropset": r.get("DropSet"),
            "tier": respawn_tier(count),
            "level": minfo.get("Level"), "boss": bool(minfo.get("IsBoss")),
        }
        atlas["respawns_by_map"].setdefault(stem, []).append(entry)
        atlas["respawns_by_monster"].setdefault(men, []).append(
            {"map": stem, "x": x, "y": y, "count": count})

    # ---- DropInfo 反查：物品 -> 掉落怪物（GainItem 任务兜底） ----
    for d in _ws_rows(workspace, "DropInfo"):
        item = (d.get("Item") or {}).get("Name") or ""
        mon = (d.get("Monster") or {}).get("Name") or ""
        if item and mon:
            s = atlas["item_droppers"].setdefault(item, set())
            s.add(mon)

    # ---- QuestInfo × QuestTask × QuestTaskMonsterDetails -> 任务叠加 ----
    qtasks = {t.get("Index"): t for t in _ws_rows(workspace, "QuestTask")}
    qdetails = {t.get("Index"): t for t in _ws_rows(workspace, "QuestTaskMonsterDetails")}
    for q in _ws_rows(workspace, "QuestInfo"):
        tasks = []
        for tref in q.get("Tasks") or []:
            t = qtasks.get(tref.get("Index"))
            if not t:
                continue
            monsters = []
            for dref in t.get("MonsterDetails") or []:
                det = qdetails.get(dref.get("Index")) or {}
                m = (det.get("Monster") or {}).get("Name")
                if m:
                    monsters.append(m)
            item = (t.get("ItemParameter") or {}).get("Name") or None
            # GainItem 无 MonsterDetails 时用 DropInfo 反查兜底
            if item and t.get("Task") == "GainItem" and not monsters:
                monsters = sorted(atlas["item_droppers"].get(item, ()))
            reg_param = t.get("RegionParameter") or {}
            reg = regions.get(reg_param.get("Index")) or {}
            rblk = _region_block(reg)
            tasks.append({
                "type": t.get("Task"), "amount": t.get("Amount") or 0,
                "item": item, "item_cn": i_cn.get(item, item) if item else None,
                "monsters": monsters,
                "region": {
                    "map": str((reg.get("Map") or {}).get("Name", "")),
                    "x": rblk[0], "y": rblk[1], "half": rblk[2], "idx": reg.get("Index"),
                    "desc": reg.get("Description", ""),
                } if rblk else None,
            })
        start = (q.get("StartNPC") or {}).get("Name") or ""
        atlas["quests"].append({
            "id": q.get("Index"), "name": q.get("QuestName") or f"Quest {q.get('Index')}",
            "type": q.get("QuestType"), "start": start, "tasks": tasks,
        })

    # ---- NPCInfo -> NPC 审计（功能覆盖检查按地图聚合） ----
    audit: dict[str, dict] = {}
    for n in _ws_rows(workspace, "NPCInfo"):
        reg = regions.get((n.get("Region") or {}).get("Index")) or {}
        stem = str((reg.get("Map") or {}).get("Name", ""))
        if not stem:
            continue
        en = n.get("NPCName") or ""
        page = (n.get("EntryPage") or {}).get("Name") or ""
        zh = n_cn.get(en, en)
        row = audit.setdefault(stem, {"map": stem, "npcs": [], "funcs": {k: [] for k, _, _ in NPC_FUNC_RULES}})
        row["npcs"].append({"en": en, "cn": zh, "page": page})
        for func, page_pats, name_pats in NPC_FUNC_RULES:
            if any(p in page for p in page_pats) or any(p in zh for p in name_pats) or any(p in en for p in name_pats):
                row["funcs"][func].append(zh or en)
    map_files = set()
    if maps_dir and os.path.isdir(maps_dir):
        map_files = {f[:-4] for f in os.listdir(maps_dir) if f.lower().endswith(".map")}
    npc_counts = {s: len(r["npcs"]) for s, r in audit.items()}
    for stem in sorted(audit):
        row = audit[stem]
        row["cn"] = cn_of_map(stem)
        row["total"] = len(row["npcs"])
        row["missing"] = [f for f, _, _ in NPC_FUNC_RULES if not row["funcs"][f]]
        row["file"] = stem in map_files
        atlas["npc_audit"].append(row)
    atlas["npc_audit"].sort(key=lambda r: -r["total"])

    # ---- MapInfo + 刷怪等级 -> 总览（627 张图） ----
    for mi in _ws_rows(workspace, "MapInfo"):
        stem = str(mi.get("FileName") or "")
        if not stem:
            continue
        desc = mi.get("Description") or ""
        respawns = atlas["respawns_by_map"].get(stem) or []
        lv_sum = lv_n = 0
        boss = False
        seen_m = set()
        for e in respawns:
            boss = boss or e["boss"]
            if e["m"] in seen_m or e["level"] is None:
                continue
            seen_m.add(e["m"])
            if e["level"] < GUARD_LEVEL_CAP:
                lv_sum += e["level"]
                lv_n += 1
        avg = round(lv_sum / lv_n, 1) if lv_n else None
        atlas["overview"].append({
            "id": stem, "cn": cn_of_map(stem, desc), "desc": desc,
            "file": stem in map_files, "lvl": avg, "tier": level_tier(avg),
            "boss": boss, "resp": len(respawns), "npcs": npc_counts.get(stem, 0),
            "cat": map_category(stem),
        })

    # ---- MovementInfo -> 连通图谱 + map_links_v2 ----
    edges: set[tuple[str, str]] = set()
    for m in _ws_rows(workspace, "MovementInfo"):
        s = str((regions.get((m.get("SourceRegion") or {}).get("Index")) or {}).get("Map", {}).get("Name", ""))
        d = str((regions.get((m.get("DestinationRegion") or {}).get("Index")) or {}).get("Map", {}).get("Name", ""))
        if s and d:
            edges.add((s, d))
    names = {row["id"]: row["cn"] for row in atlas["overview"]}
    d_edges = sorted([list(e) for e in edges if e[0].startswith("D") or e[1].startswith("D") or e[0].startswith("d") or e[1].startswith("d")])
    atlas["links_v2"] = {
        "names": names,
        "links": sorted([list(e) for e in edges]),
        "_meta": {
            "generated": time.strftime("%Y-%m-%d %H:%M:%S"),
            "source": "System.db MovementInfo (Tools/dbeditor/workspace/MovementInfo.json)",
            "movement_rows": len(_ws_rows(workspace, "MovementInfo")),
            "unique_links": len(edges),
            "d_series_links": len(d_edges),
            "note": "地图号对齐 MapInfo.FileName；names 覆盖全部 MapInfo 地图",
        },
    }
    # 图谱统计：孤岛（入度0且非出生点）/ 割点（无向割点=必经之路）
    indeg = {s: 0 for s in names}
    outdeg = {s: 0 for s in names}
    undirected: set[frozenset] = set()
    for a, b in edges:
        if a == b:
            continue
        outdeg[a] = outdeg.get(a, 0) + 1
        indeg[b] = indeg.get(b, 0) + 1
        undirected.add(frozenset((a, b)))
    adj: dict[str, set] = {}
    for e in undirected:
        a, b = tuple(e)
        adj.setdefault(a, set()).add(b)
        adj.setdefault(b, set()).add(a)
    cut = _articulation_points(set(names), adj)
    graph_nodes = []
    for stem in names:
        island = indeg.get(stem, 0) == 0 and stem not in SPAWN_STEMS
        graph_nodes.append({
            "id": stem, "cn": names[stem],
            "indeg": indeg.get(stem, 0), "outdeg": outdeg.get(stem, 0),
            "island": island, "isolated": stem not in adj,
            "cut": stem in cut,
            "file": stem in map_files, "npcs": npc_counts.get(stem, 0),
        })
    atlas["graph"] = {
        "nodes": graph_nodes, "edges": sorted([list(e) for e in edges]),
        "spawn_stems": sorted(SPAWN_STEMS),
    }
    return atlas


def write_map_links_v2(atlas: dict, path: str) -> bool:
    """把 links_v2 落盘到 Tools/maps/map_links_v2.json（git 跟踪的产出物）。"""
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(atlas["links_v2"], f, ensure_ascii=False, indent=1)
        return True
    except OSError:
        return False


def prewarm_thumbs(maps_dir: str, data_dir: str, thumbs_dir: str) -> None:
    """后台守护线程：为总览视图逐张预渲染缩略图（/tmp/wiki_thumbs，磁盘缓存）。

    只渲染缺失项，已存在的跳过；与 /thumb 端点共享 per-map 渲染锁避免并发
    写坏 PNG。"""
    def work():
        try:
            from thumb_gen import render_one, MapCache13
            mc = MapCache13(maps_dir, max_keep=4)
            pool = FramePool(data_dir)
            names = sorted(f for f in os.listdir(maps_dir) if f.lower().endswith(".map"))
            done = 0
            for name in names:
                out = os.path.join(thumbs_dir, name + ".png")
                if os.path.exists(out):
                    continue
                lock = ViewerHandler._render_lock(("thumb", name))
                try:
                    with lock:
                        if os.path.exists(out):
                            continue
                        w, h, _ = mc.get(name)
                        render_one(mc, pool, thumbs_dir, name, w, h)
                        done += 1
                except Exception as ex:
                    print(f"[!] thumb prewarm {name}: {ex}")
            if done:
                print(f"[*] Thumb prewarm: {done} new thumbnails rendered")
        except Exception as ex:
            print(f"[!] Thumb prewarm disabled: {ex}")

    threading.Thread(target=work, daemon=True, name="thumb-prewarm").start()


_DROPS_CACHE: dict[str, list[dict]] = {}


def load_drops(envir_dir: str, monster_name: str) -> list[dict]:
    """Parse Envir/MonItems/<monster>.txt into a drop list.

    Lines are '<num>/<den> <item> [count]' (GBK item names).  Returns up to
    12 entries sorted by chance descending: [{item, chance (num/den), count}].
    Falls back to the trailing-digit-stripped name (e.g. '巨象兽8' -> '巨象兽'),
    then to None.  Cached per envir_dir+name.
    """
    key = (envir_dir, monster_name)
    cached = _DROPS_CACHE.get(key)
    if cached is not None:
        return cached
    import re as _re
    candidates = [monster_name]
    stripped = _re.sub(r"\d+$", "", monster_name)
    if stripped != monster_name:
        candidates.append(stripped)
    result: list[dict] = []
    for cand in candidates:
        p = os.path.join(envir_dir, "MonItems", cand + ".txt")
        try:
            raw = open(p, "rb").read()
        except OSError:
            continue
        text = raw.decode("gbk", errors="replace")
        for ln in text.splitlines():
            ln = ln.strip()
            if not ln or ln.startswith(";"):
                continue
            m = _re.match(r"^(\d+)/(\d+)\s+(.+)$", ln)
            if not m:
                continue
            num, den = int(m.group(1)), int(m.group(2))
            rest = m.group(3).split()
            item = rest[0]
            count = int(rest[1]) if len(rest) > 1 and rest[1].isdigit() else 1
            result.append({"item": item, "chance": num / den, "count": count})
        if result:
            break
    result.sort(key=lambda d: (-d["chance"], d["item"]))
    result = result[:12]
    _DROPS_CACHE[key] = result
    return result


def load_entities(envir_dir: str) -> list[dict]:
    """Parse Mud3 server entity data into a flat list of dicts.

    Sources (all GBK-encoded names):
      StartPoint.txt  -> one spawn point per map  (map x y)
      Merchant.txt    -> NPCs                      (name map x y face body)
      MonGen.txt      -> loadgen lines expanding to .gen files in Mon_Def/
                        (map x y name count level attack respawn)
    Returns [{map, x, y, kind, name, face?, body?, count?, level?}].
    Map names are normalised to '<name>.map'.  MonGen's loadgen refs that do
    not resolve to a file are skipped (pending note)."""
    out: list[dict] = []

    def norm(name: str) -> str:
        name = name.strip()
        return name if name.lower().endswith(".map") else name + ".map"

    def lines(path: str):
        try:
            with open(path, "rb") as f:
                raw = f.read()
        except OSError:
            return
        try:
            text = raw.decode("gbk", errors="replace")
        except Exception:
            text = raw.decode("utf-8", errors="replace")
        for ln in text.splitlines():
            ln = ln.strip()
            if not ln or ln.startswith(";"):
                continue
            yield ln

    # spawn points
    sp = os.path.join(envir_dir, "StartPoint.txt")
    for ln in lines(sp):
        parts = ln.split()
        if len(parts) >= 3 and parts[0].replace(".", "", 1).isdigit():
            try:
                out.append({"map": norm(parts[0]), "x": int(parts[1]),
                            "y": int(parts[2]), "kind": "spawn", "name": "出生点"})
            except ValueError:
                pass

    # merchants / NPCs
    mp = os.path.join(envir_dir, "Merchant.txt")
    for ln in lines(mp):
        parts = ln.split()
        if len(parts) < 6:
            continue
        fname, mapn, xs, ys = parts[0], parts[1], parts[2], parts[3]
        if not fname or mapn in ("Map", "map") or not xs.isdigit():
            continue
        try:
            out.append({"map": norm(mapn), "x": int(xs), "y": int(ys),
                        "kind": "npc", "name": parts[4],
                        "face": int(parts[5]) if parts[5].isdigit() else 0,
                        "body": int(parts[6]) if len(parts) > 6 and parts[6].isdigit() else 0})
        except (ValueError, IndexError):
            continue

    # monsters: MonGen.txt loadgen refs -> .gen files (Mon_Def/ and Envir/)
    mon_gen = os.path.join(envir_dir, "MonGen.txt")
    gen_files: list[str] = []
    for ln in lines(mon_gen):
        low = ln.lower()
        if low.startswith("loadgen"):
            ref = ln.split('"')[1] if '"' in ln else ln.split()[1]
            for base in (os.path.join(envir_dir, "Mon_Def"), envir_dir):
                p = os.path.join(base, ref)
                if os.path.exists(p):
                    gen_files.append(p)
                    break
    for gp in gen_files:
        for ln in lines(gp):
            parts = ln.split()
            if len(parts) < 4:
                continue
            try:
                mon = {"map": norm(parts[0]), "x": int(parts[1]), "y": int(parts[2]),
                       "kind": "monster", "name": parts[3],
                       "count": int(parts[4]) if len(parts) > 4 and parts[4].isdigit() else 1,
                       "level": int(parts[5]) if len(parts) > 5 and parts[5].isdigit() else 0}
            except (ValueError, IndexError):
                continue
            drops = load_drops(envir_dir, mon["name"])
            if drops:
                mon["drops"] = drops
            out.append(mon)
    return out

def main():

    parser = argparse.ArgumentParser(description="Mir3 EI / Zircon Map Viewer")
    parser.add_argument("maps_dir", nargs="?", help="Folder containing .map files (default: current Zircon client)")
    parser.add_argument("--client-root", default=DEFAULT_CLIENT_ROOT,
                        help="Client root containing Map/ and Data/ (default: Zircon Debug/Client)")
    parser.add_argument("--data", help="Folder containing WIL / ZL libraries", default=None)
    parser.add_argument("--port", type=int, default=8766, help="HTTP Server Port")
    parser.add_argument("--cache-dir", default=None,
                        help="Disk tile cache dir (default: <maps_dir>/.tilecache; empty disables)")
    parser.add_argument("--catalog", default=None,
                        help="map-catalog.json dir from build_map_catalog.py (enables /api/catalog)")
    parser.add_argument("--envir", default=None,
                        help="Mud3 server Envir dir (enables /api/entities: spawn/NPC/monster positions)")
    parser.add_argument("--db-workspace", default=DEFAULT_DBWORKSPACE,
                        help="dbeditor workspace dir (NPCInfo/MapRegion/MovementInfo JSON; default: %(default)s)")
    parser.add_argument("--db-names", default=DEFAULT_DB_NAMES,
                        help="db_names.json (NPC/地图中文名映射; default: %(default)s)")
    parser.add_argument("--thumbs-dir", default=THUMBS_DIR,
                        help="Full-map thumbnail dir (shared with WikiServer/thumb_gen)")
    parser.add_argument("--layout", choices=[LAYOUT_RECT, LAYOUT_ISO], default=LAYOUT_RECT,
                        help="Map projection: rect (axis-aligned, original Mir3.exe) or iso (legacy diamond)")
    parser.add_argument("--connections", default=DEFAULT_CONNECTIONS,
                        help="JSON exported by export_map_connections.py")
    args = parser.parse_args()

    if not args.maps_dir:
        args.maps_dir = os.path.join(args.client_root, "Map")
    if not os.path.isdir(args.maps_dir):
        parser.error(f"maps directory not found: {args.maps_dir}")

    data_dir = args.data
    if not data_dir:
        candidates = [
            os.path.join(args.maps_dir, "..", "Data"),
            os.path.join(args.maps_dir, "..", "Data", "Map Data"),
            os.path.join(args.maps_dir, "Data"),
            os.path.join(args.maps_dir, "Data", "Map Data"),
            "/home/tetsuya/development/Zircon/Debug/Client/Data",
            "/home/tetsuya/development/Zircon/Debug/Client/Data/Map Data",
            args.maps_dir
        ]
        for c in candidates:
            if os.path.exists(c):
                data_dir = c
                break

    print(f"[*] Maps directory: {args.maps_dir}")
    ViewerHandler.map_cache = MapCache(args.maps_dir)
    ViewerHandler.pool = FramePool(data_dir)
    cache_dir = args.cache_dir if args.cache_dir is not None else os.path.join(args.maps_dir, f".tilecache-{CACHE_VERSION}")
    ViewerHandler.cache_dir = cache_dir
    ViewerHandler.thumbs_dir = args.thumbs_dir
    ViewerHandler.layout = args.layout
    ViewerHandler.catalog = load_catalog(args.catalog)
    ViewerHandler.connections = load_connections(args.connections)
    ViewerHandler.db_names = load_db_names(args.db_names)
    # dbeditor workspace 直读：NPCInfo + MapRegion 质心坐标（NpcMover 修正后
    # 的 EI 坐标）+ MovementInfo 连接。workspace 数据比 8月11 的 Markdown 导出
    # 新（294 NPC / 1039 movement / 坐标 0 缺失），作为第一数据源。
    ws_ents = load_workspace_entities(args.db_workspace, ViewerHandler.db_names)
    if ws_ents:
        ViewerHandler.entities = ws_ents + ViewerHandler.entities
        print(f"[*] Workspace NPCs: {len(ws_ents)} loaded from {args.db_workspace}")
    ws_links = load_workspace_connections(args.db_workspace)
    if ws_links:
        ViewerHandler.connections = ws_links
        print(f"[*] Workspace movements: {len(ws_links)} (override Markdown export)")
    # 连接索引：map stem -> links（/api/connections O(1) 查询用）
    conn_index: dict[str, list] = {}
    for link in ViewerHandler.connections:
        for side in ("source", "destination"):
            stem = os.path.splitext(str((link.get(side) or {}).get("map", "")))[0]
            if stem:
                conn_index.setdefault(stem, []).append(link)
    ViewerHandler.conn_index = conn_index
    # 地图工坊 atlas：workspace 全表 JOIN（热力/任务/总览/连通/NPC 审计）
    try:
        t0 = time.time()
        ViewerHandler.atlas = build_atlas(args.db_workspace, ViewerHandler.db_names, args.maps_dir)
        lv2 = ViewerHandler.atlas.get("links_v2") or {}
        graph = ViewerHandler.atlas.get("graph") or {}
        islands = sum(1 for n in graph.get("nodes", []) if n.get("island"))
        cuts = sum(1 for n in graph.get("nodes", []) if n.get("cut"))
        print(f"[*] Atlas built in {time.time()-t0:.1f}s: "
              f"{len(ViewerHandler.atlas.get('overview', []))} maps / "
              f"{sum(len(v) for v in ViewerHandler.atlas.get('respawns_by_map', {}).values())} respawns / "
              f"{len(ViewerHandler.atlas.get('quests', []))} quests / "
              f"{len(lv2.get('links', []))} links (D系 {lv2.get('_meta', {}).get('d_series_links', 0)}) / "
              f"islands {islands} / cut {cuts}")
        if write_map_links_v2(ViewerHandler.atlas, os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "map_links_v2.json")):
            print("[*] map_links_v2.json written to Tools/maps/")
    except Exception as ex:
        ViewerHandler.atlas = {}
        print(f"[!] Atlas build failed (layers disabled): {ex}")
    if ViewerHandler.catalog:
        print(f"[*] Catalog: {len(ViewerHandler.catalog)} maps loaded")
    print(f"[*] Connections: {len(ViewerHandler.connections)} movements loaded ({len(conn_index)} maps indexed)")
    if args.envir:
        ViewerHandler.entities = load_entities(args.envir) + ViewerHandler.entities
        print(f"[*] Envir entities: {len(ViewerHandler.entities)} loaded")
    else:
        if not ws_ents:
            ViewerHandler.entities = []
    # 总览缩略图后台预渲染（守护线程，只补缺失项）
    prewarm_thumbs(args.maps_dir, data_dir, args.thumbs_dir)
    print(f"[*] Tile cache: {cache_dir}")

    server = ThreadingHTTPServer(("0.0.0.0", args.port), ViewerHandler)
    print(f"[*] Map Viewer running on http://127.0.0.1:{args.port}/")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] Stopping server.")


if __name__ == "__main__":
    main()
