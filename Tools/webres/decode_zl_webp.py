#!/usr/bin/env python3
"""decode_zl_webp.py — Zircon .Zl 帧库 → 逐帧 lossless WebP + manifest.json。

Web 移植阶段0 Spike 的资源瘦身管线原型：
    输入  一个 .Zl 帧库路径 (ZL2 容器或 legacy v0/v1 DXT 容器)
    输出  {out}/{帧号}.webp  +  {out}/manifest.json

复用 Tools/common/zlsdk.py 的 ZlLibrary 读取器/解码器，本脚本只做
  选帧(范围/均匀抽样) → decode() → PIL RGBA → Pillow lossless WebP 落盘
以及统计汇总 (源大小、总像素、webp 字节数、编解码耗时、codec 直方图)。

用法:
    # 全量转 Interface.Zl (含 q90 有损对照统计)
    python decode_zl_webp.py /path/Interface.Zl --out /path/WebData/interface --lossy-check

    # 均匀抽样 40 帧 (大库估算用)
    python decode_zl_webp.py /path/Interface1c.Zl --out /tmp/est/interface1c --sample 40 --lossy-check

    # 帧范围
    python decode_zl_webp.py /path/Interface.Zl --out DIR --start 100 --end 200

依赖: mir3-venv (Pillow + numpy + texture2ddecoder)，zlsdk 在 Tools/common。
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

# bootstrap: import Tools/common/zlsdk (本脚本位于 Tools/webres/)
_TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_TOOLS / "common"))
import zlsdk  # noqa: E402

# ZL2 codec id -> 名称 (zlsdk.Zl2Entry/ZlImageHeader 语义)
ZL2_CODECS = {0: "Dxt1", 1: "Dxt5", 2: "Bgra32", 3: "Bc7", 4: "Png"}


def effective_codec(lib: "zlsdk.ZlLibrary", index: int) -> str:
    """帧的有效源编码。legacy 容器 header.codec 无意义，按容器版本判:
    v0=DXT1(BC1), v1=DXT5(BC3) (见 zlsdk.ZlLibrary.decode 的 legacy 分支)。"""
    if lib.is_zl2:
        return ZL2_CODECS.get(lib.headers[index].codec, f"codec{lib.headers[index].codec}")
    return "Dxt1" if lib.version == 0 else "Dxt5"


def save_webp(im, path: Path, method: int) -> int:
    """Pillow lossless WebP 落盘，返回字节数。"""
    buf = io_save(im, method)
    path.write_bytes(buf)
    return len(buf)


def io_save(im, method: int) -> bytes:
    import io
    b = io.BytesIO()
    im.save(b, "WEBP", lossless=True, method=method)
    return b.getvalue()


def lossy_bytes(im, method: int) -> int:
    """有损 quality=90 对照 (不落盘)。"""
    import io
    b = io.BytesIO()
    im.save(b, "WEBP", lossless=False, quality=90, method=method)
    return b.getbuffer().nbytes


def select_frames(lib: "zlsdk.ZlLibrary", start: int | None, end: int | None,
                  sample: int | None) -> list[int]:
    """范围过滤后的可解码 (非 blank) 帧号列表，升序; --sample N 均匀抽样。"""
    lo = start if start is not None else 0
    hi = end if end is not None else lib.count - 1
    frames = [i for i in range(lo, hi + 1)
              if i in lib.headers and not lib.is_blank(i)]
    if sample and sample > 0 and sample < len(frames):
        step = len(frames) / sample
        frames = [frames[int(k * step)] for k in range(sample)]
    return frames


def main() -> int:
    ap = argparse.ArgumentParser(description=".Zl → lossless WebP + manifest.json")
    ap.add_argument("zl", help="输入 .Zl 帧库路径")
    ap.add_argument("--out", required=True, help="输出目录 (webp + manifest.json)")
    ap.add_argument("--start", type=int, default=None, help="起始帧号 (含)")
    ap.add_argument("--end", type=int, default=None, help="结束帧号 (含)")
    ap.add_argument("--sample", type=int, default=None,
                    help="从选中帧中均匀抽样 N 帧 (估算用)")
    ap.add_argument("--lossy-check", action="store_true",
                    help="每帧额外计算 lossy quality=90 字节数 (不落盘)")
    ap.add_argument("--webp-method", type=int, default=4,
                    help="WebP 压缩 effort 0-6 (默认 4; 6 更小更慢)")
    args = ap.parse_args()

    t0 = time.perf_counter()
    lib = zlsdk.ZlLibrary(args.zl)
    src_bytes = os.path.getsize(args.zl)
    frames = select_frames(lib, args.start, args.end, args.sample)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    print(f"{lib.name}: container={'ZL2' if lib.is_zl2 else f'legacy-v{lib.version}'} "
          f"slots={lib.count} headers={len(lib.headers)} -> {len(frames)} 帧 "
          f"(sample={args.sample}, range=[{args.start},{args.end}])")

    entries: list[dict] = []
    codec_hist: dict[str, int] = {}
    total_px = 0
    total_lossless = 0
    total_lossy = 0
    decode_s = 0.0
    encode_s = 0.0
    errors = 0

    for n, i in enumerate(frames):
        td = time.perf_counter()
        im = lib.decode(i)
        decode_s += time.perf_counter() - td
        if im is None:
            errors += 1
            entries.append({"index": i, "error": "decode_failed"})
            print(f"  [{n + 1}/{len(frames)}] frame {i}: DECODE FAILED")
            continue
        assert im.mode == "RGBA", f"frame {i}: mode={im.mode}"
        w, h = im.size
        hdr = lib.headers[i]
        codec = effective_codec(lib, i)

        te = time.perf_counter()
        nbytes = save_webp(im, out / f"{i}.webp", args.webp_method)
        q90 = lossy_bytes(im, args.webp_method) if args.lossy_check else None
        encode_s += time.perf_counter() - te

        total_px += w * h
        total_lossless += nbytes
        if q90 is not None:
            total_lossy += q90
        codec_hist[codec] = codec_hist.get(codec, 0) + 1
        entries.append({
            "index": i, "file": f"{i}.webp", "width": w, "height": h,
            "offset_x": hdr.offset_x, "offset_y": hdr.offset_y,
            "codec": codec, "webp_bytes": nbytes,
            **({"lossy_q90_bytes": q90} if q90 is not None else {}),
        })
        if (n + 1) % 50 == 0 or n + 1 == len(frames):
            print(f"  [{n + 1}/{len(frames)}] frame {i} {w}x{h} {codec} "
                  f"lossless={nbytes}B")

    wall = time.perf_counter() - t0
    present = sum(1 for i in range(lib.count) if i in lib.headers and not lib.is_blank(i))
    manifest = {
        "source": {
            "path": str(Path(args.zl).resolve()),
            "name": lib.name,
            "size_bytes": src_bytes,
            "container": "ZL2" if lib.is_zl2 else f"legacy-v{lib.version}",
            "frame_slots": lib.count,
            "frames_present": present,
            "total_pixels_all_frames": sum(
                h.width * h.height for h in lib.headers.values()),
        },
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "arguments": {
            "start": args.start, "end": args.end, "sample": args.sample,
            "lossy_check": args.lossy_check, "webp_method": args.webp_method,
        },
        "summary": {
            "frames_decoded": len(entries) - errors,
            "decode_errors": errors,
            "total_pixels": total_px,
            "webp_lossless_bytes": total_lossless,
            **({"webp_lossy_q90_bytes": total_lossy} if args.lossy_check else {}),
            "ratio_src_to_lossless": round(src_bytes / total_lossless, 3) if total_lossless else None,
            "bytes_per_pixel_lossless": round(total_lossless / total_px, 3) if total_px else None,
            "codec_histogram": codec_hist,
            "decode_seconds": round(decode_s, 2),
            "encode_seconds": round(encode_s, 2),
            "wall_seconds": round(wall, 2),
        },
        "frames": entries,
    }
    (out / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1))

    mb = 1048576
    print(f"\n== {lib.name} 完成 ==")
    print(f"帧: {len(entries) - errors}/{len(frames)} (错误 {errors})")
    print(f"源 .Zl: {src_bytes / mb:.2f} MB | 总像素: {total_px / 1e6:.2f} Mpx")
    print(f"lossless WebP: {total_lossless / mb:.2f} MB "
          f"(源/无损 = {src_bytes / total_lossless:.2f}x, {total_lossless / max(total_px, 1):.2f} B/px)")
    if args.lossy_check:
        print(f"lossy q90 WebP: {total_lossy / mb:.2f} MB (无损/有损 = {total_lossless / max(total_lossy, 1):.2f}x)")
    print(f"耗时: decode {decode_s:.1f}s + encode {encode_s:.1f}s (wall {wall:.1f}s)")
    print(f"manifest: {out / 'manifest.json'}")
    return 0 if errors == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
