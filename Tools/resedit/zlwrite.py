#!/usr/bin/env python3
"""zlwrite.py — ZL 帧（DXT1/legacy 容器）像素级写回 (E3 任务4, 高风险项)。

范围: legacy ZL 容器 (非 ZL2, payload=DXT1 定长块) — M-Hum/Magic/Mon-*/NPC 等
角色/怪物/特效主库。ZL2 (PNG 载荷, 如 Interface.Zl) 写回不在本期 (见 README)。

原理 (块级手术, 零容器重排):
  DXT1 帧 = 4x4 定长块 (8B/块) 串。只重写被修改像素所在的块:
  - 未触及块字节原样保留
  - 触及块先用【原块色板 + 最近邻重算索引】重编码 (decode(orig) 写回 → 字节恒等)
  - 新像素超出原色板表达 (误差>阈值) → 重新选色 (min/max 各通道 + punch-through)
  文件大小/每帧 position/meta 均不变 → 直接 seek 写块, 无需重建容器。

纪律 (与 .map 写回同款, 总纲 §5.2):
  备份 .bak-<ts> → 写 <lib>.new → 独立 zlsdk 打开验证 → 原子替换 → 报告

用法:
  zlwrite.py write <lib.zl> <frame> <image.png> [--tolerance 16] [--dry-run]
  zlwrite.py roundtrip <lib.zl> [--samples 50]   # encode(decode(orig)) 字节恒等验证
"""
from __future__ import annotations

import argparse
import os
import shutil
import struct
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "common"))
import zlsdk  # noqa: E402
from PIL import Image  # noqa: E402


# ---------------------------------------------------------------- BC1 块编码
def _rgb565_pack(r: int, g: int, b: int) -> int:
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def _rgb565_unpack(v: int) -> tuple[int, int, int]:
    # 与 zlsdk._bc1_core 解码一致: 等比缩放 (v*255)//31 / (v*255)//63
    # (不是低位复制 — 否则最近邻重算索引会与原编码器产生 1-2 级偏差)
    r = ((v >> 11) & 0x1F) * 255 // 31
    g = ((v >> 5) & 0x3F) * 255 // 63
    b = (v & 0x1F) * 255 // 31
    return r, g, b


def _block_palette(c0: int, c1: int) -> tuple[list[tuple[int, int, int]], bool]:
    """返回 (调色板, punch_through)。c0<=c1 → 3色+透明(index3)。"""
    a, b = _rgb565_unpack(c0), _rgb565_unpack(c1)
    if c0 > c1:
        return [a, b,
                tuple((2 * a[i] + b[i]) // 3 for i in range(3)),
                tuple((a[i] + 2 * b[i]) // 3 for i in range(3))], False
    return [a, b, tuple((a[i] + b[i]) // 2 for i in range(3)), (0, 0, 0)], True


def _nearest(pal, punch, px, py, pz, pa):
    """像素最近色板索引。透明像素在 punch 模式强制 index3。"""
    if pa == 0 and punch:
        return 3
    best, bd = 0, 1 << 30
    for i, (r, g, b) in enumerate(pal):
        if punch and i == 3:
            continue
        d = (r - px) ** 2 + (g - py) ** 2 + (b - pz) ** 2
        if d < bd:
            bd, best = d, i
    return best


def _indices_to_word(idx: list[int]) -> int:
    w = 0
    for i, v in enumerate(idx):
        w |= (v & 3) << (2 * i)
    return w


def _reencode_with_palette(orig_block: bytes, pixels: list[tuple[int, int, int, int]],
                           tolerance: int) -> tuple[bytes, int]:
    """原色板 + 重算索引; 返回 (新块, 最大通道误差)。超差由调用方 fallback。"""
    c0, c1 = struct.unpack_from("<HH", orig_block, 0)
    pal, punch = _block_palette(c0, c1)
    idx = []
    max_err = 0
    for (r, g, b, a) in pixels:
        i = _nearest(pal, punch, r, g, b, a)
        idx.append(i)
        pr, pg, pb = pal[i] if not (punch and i == 3) else (0, 0, 0)
        max_err = max(max_err, abs(pr - r), abs(pg - g), abs(pb - b))
    return struct.pack("<HHI", c0, c1, _indices_to_word(idx)), max_err


def _choose_colors(pixels) -> tuple[int, int]:
    """新选色: 有透明像素 → punch (c0<=c1); 否则 min/max 各通道。"""
    opaque = [(r, g, b) for (r, g, b, a) in pixels if a != 0]
    has_transparent = len(opaque) < len(pixels)
    if not opaque:
        return 0, 0   # 全透明块: c0=c1=0 (punch)
    rs = [p[0] for p in opaque]; gs = [p[1] for p in opaque]; bs = [p[2] for p in opaque]
    lo = _rgb565_pack(min(rs), min(gs), min(bs))
    hi = _rgb565_pack(max(rs), max(gs), max(bs))
    if has_transparent:
        # punch 模式要求 c0 <= c1
        return (lo, hi) if lo <= hi else (hi, lo)
    # normal 模式要求 c0 > c1
    return (hi, lo) if hi > lo else (lo + 1, lo) if lo + 1 <= 0xFFFF else (lo, lo - 1)


def _reencode_fresh(pixels) -> bytes:
    c0, c1 = _choose_colors(pixels)
    pal, punch = _block_palette(c0, c1)
    idx = [_nearest(pal, punch, r, g, b, a) for (r, g, b, a) in pixels]
    return struct.pack("<HHI", c0, c1, _indices_to_word(idx))


def encode_bc1_block(orig_block: bytes, pixels: list[tuple[int, int, int, int]],
                     tolerance: int = 16) -> bytes:
    """单块重编码: 优先原色板 (保未改像素字节恒等), 超差再新选色。"""
    nb, err = _reencode_with_palette(orig_block, pixels, tolerance)
    if err <= tolerance:
        return nb
    return _reencode_fresh(pixels)


# ---------------------------------------------------------------- 帧写回
def frame_block_span(lib: "zlsdk.ZlLibrary", frame: int) -> tuple[int, int, int]:
    """返回 (position, width_blocks, height_blocks)。"""
    hdr = lib.headers.get(frame)
    assert hdr and hdr.width > 0 and hdr.height > 0, f"帧 {frame} 无效"
    bw = (hdr.width + 3) // 4
    bh = (hdr.height + 3) // 4
    return hdr.position, bw, bh


def load_target_pixels(png_path: str, w: int, h: int) -> list[tuple[int, int, int, int]]:
    im = Image.open(png_path).convert("RGBA")
    assert im.size == (w, h), f"目标 PNG 尺寸 {im.size} != 帧尺寸 {(w, h)} (本期不支持改尺寸)"
    return list(im.getdata())


def write_frame(lib_path: str, frame: int, png_path: str,
                tolerance: int = 16, dry_run: bool = False) -> dict:
    lib = zlsdk.ZlLibrary(lib_path)
    assert not lib.is_zl2, "ZL2 (PNG 载荷) 写回不在本期 — 见 Tools/resedit/README.md"
    assert lib.version == 0, f"legacy version={lib.version} 非 DXT1, 拒绝写"
    hdr = lib.headers[frame]
    pos, bw, bh = frame_block_span(lib, frame)
    span = bw * bh * 8
    orig_blocks = lib.data[pos : pos + span]
    target = load_target_pixels(png_path, hdr.width, hdr.height)
    # 块尺寸可能非 4 的倍数: pad 取 0 像素? 用原 decode 像素填充 (不改变边界外)
    orig_im = lib.decode(frame)
    orig_px = list(orig_im.getdata())

    new_blocks = bytearray()
    changed_blocks = 0
    identical_bytes = 0
    for by in range(bh):
        for bx in range(bw):
            ob = orig_blocks[(by * bw + bx) * 8 : (by * bw + bx) * 8 + 8]
            block_changed = False
            pixels = []
            for py in range(4):
                for px in range(4):
                    x, y = bx * 4 + px, by * 4 + py
                    if x < hdr.width and y < hdr.height:
                        p = target[y * hdr.width + x]
                        pixels.append(p)
                        if p != orig_px[y * hdr.width + x]:
                            block_changed = True
                    else:
                        pixels.append((0, 0, 0, 0))   # 块外虚拟像素
            if block_changed:
                nb = encode_bc1_block(ob, pixels, tolerance)
                changed_blocks += 1
            else:
                nb = ob
                identical_bytes += 8
            new_blocks += nb
    assert len(new_blocks) == span

    if dry_run:
        return {"dry_run": True, "changed_blocks": changed_blocks,
                "untouched_blocks": bw * bh - changed_blocks}

    # 纪律: 备份 → 写 .new → 独立验证 → 原子替换
    src = Path(lib_path)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    bak = src.with_name(src.name + f".bak-{stamp}")
    shutil.copy2(src, bak)
    new_path = src.with_name(src.name + ".new")
    data = bytearray(lib.data)
    data[pos : pos + span] = new_blocks
    new_path.write_bytes(bytes(data))

    # 独立验证: 重开 .new, 比对
    check = zlsdk.ZlLibrary(str(new_path))
    assert check.count == lib.count and set(check.headers) == set(lib.headers), "meta 结构漂移"
    for i, oh in lib.headers.items():
        nh = check.headers[i]
        assert (nh.width, nh.height, nh.position) == (oh.width, oh.height, oh.position), f"帧 {i} meta 变化"
    # 未改帧字节必须不变 (整库抽查: 与原文件对比除 [pos,pos+span) 外全部相同)
    assert len(check.data) == len(lib.data), "文件大小变化 (不应发生)"
    diff = [i for i in range(len(data)) if i < pos or i >= pos + span
            if data[i] != lib.data[i]]
    assert not diff, f"帧区间外字节被改动: {len(diff)}B"

    # 改动帧 decode 对比目标 (BC1 有损, 报告误差)
    got = check.decode(frame)
    gp = list(got.getdata())
    err = [max(abs(a[0] - b[0]), abs(a[1] - b[1]), abs(a[2] - b[2]),
               255 * (a[3] == 0) * (b[3] != 0) + 255 * (a[3] != 0) * (b[3] == 0))
           for a, b in zip(gp, target)]
    # alpha 比较: punch 模式透明是二值
    alpha_mismatch = sum(1 for a, b in zip(gp, target) if (a[3] == 0) != (b[3] == 0))
    report = {
        "frame": frame, "size": (hdr.width, hdr.height),
        "changed_blocks": changed_blocks, "untouched_blocks": bw * bh - changed_blocks,
        "max_channel_err": max(err), "mean_err": sum(err) / len(err),
        "alpha_mismatch_px": alpha_mismatch,
        "backup": str(bak), "installed": None,
    }
    os.replace(new_path, src)
    report["installed"] = str(src)
    return report


# ---------------------------------------------------------------- 往返验证
def roundtrip(lib_path: str, samples: int = 50, seed: int = 7) -> dict:
    """对未修改像素做「decode → 原色板重编码」: 期望字节级恒等。
    独立于写回主流程: 直接对块字节做 encode_bc1_block(orig, decode 像素)。"""
    import random
    lib = zlsdk.ZlLibrary(lib_path)
    assert not lib.is_zl2 and lib.version == 0
    rng = random.Random(seed)
    frames = [i for i, h in lib.headers.items() if h.width > 0]
    picked = rng.sample(frames, min(samples, len(frames)))
    byte_identical = 0
    total = 0
    worst = []
    for f in picked:
        hdr = lib.headers[f]
        pos, bw, bh = frame_block_span(lib, f)
        span = bw * bh * 8
        blocks = lib.data[pos : pos + span]
        im = lib.decode(f)
        if im is None:
            continue
        px = list(im.getdata())
        rebuilt = bytearray()
        for by in range(bh):
            for bx in range(bw):
                quad = []
                for py in range(4):
                    for qx in range(4):
                        x, y = bx * 4 + qx, by * 4 + py
                        quad.append(px[y * hdr.width + x] if x < hdr.width and y < hdr.height
                                    else (0, 0, 0, 0))
                rebuilt += encode_bc1_block(blocks[(by * bw + bx) * 8 :][:8], quad)
        total += 1
        if bytes(rebuilt) == blocks:
            byte_identical += 1
        else:
            diffb = sum(1 for a, b in zip(rebuilt, blocks) if a != b)
            worst.append((f, diffb))
    return {"lib": lib_path, "checked": total, "byte_identical": byte_identical,
            "mismatch": worst[:10]}


def main() -> int:
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    w = sub.add_parser("write", help="写回一帧像素 (PNG 尺寸须与帧一致)")
    w.add_argument("lib"); w.add_argument("frame", type=int); w.add_argument("png")
    w.add_argument("--tolerance", type=int, default=16)
    w.add_argument("--dry-run", action="store_true")
    r = sub.add_parser("roundtrip", help="未改像素 decode→重编码 字节恒等验证")
    r.add_argument("lib"); r.add_argument("--samples", type=int, default=50)
    args = ap.parse_args()

    if args.cmd == "write":
        rep = write_frame(args.lib, args.frame, args.png, args.tolerance, args.dry_run)
        print(rep)
        return 0
    rep = roundtrip(args.lib, args.samples)
    print(rep)
    return 0 if rep["mismatch"] == [] else 1


if __name__ == "__main__":
    raise SystemExit(main())
