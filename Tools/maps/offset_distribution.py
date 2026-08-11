#!/usr/bin/env python3
"""offset_distribution.py — EI 3.0 frame offset (offsetX/offsetY, WIL header +4/+6)
distribution across every Data/*.wil library (incl. theme subdirs Forest/Sand/Snow/Wood).

P9 closure: do TILE/OBJECT libraries (used by map layers, which the original
client reads with ZERO offset, C5) actually carry nonzero frame offsets, or are
they zero?  Actors apply offsets (+4/+6, C6).

Output: docs/research/mir3-map-reconstruction/offset-distribution.json
    { "<subdir>/<name>.wil" | "<name>.wil": {
        "category": ..., "count": N, "data_frames": N, "no_data": N,
        "zero_size": N, "nonzero_off_x": N, "nonzero_off_y": N, "either": N,
        "min_x": int, "max_x": int, "min_y": int, "max_y": int } }

Usage: python3 Tools/maps/offset_distribution.py [--root NAS_DATA_DIR] [--out PATH]
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "common"))
from wilsdk import categorize, open_library  # noqa: E402

THEME_DIRS = ("Forest", "Sand", "Snow", "Wood")


def scan_lib(wil_path: str) -> dict:
    lib = open_library(wil_path)
    count = lib.count
    no_data = 0
    zero_size = 0
    nz_x = 0
    nz_y = 0
    either = 0
    xs: list[int] = []
    ys: list[int] = []
    for i in range(count):
        hdr = lib.header(i)
        if hdr is None:
            no_data += 1
            continue
        if hdr["width"] <= 0 or hdr["height"] <= 0:
            zero_size += 1
        x, y = hdr["offsetX"], hdr["offsetY"]
        xs.append(x)
        ys.append(y)
        if x != 0:
            nz_x += 1
        if y != 0:
            nz_y += 1
        if x != 0 or y != 0:
            either += 1
    return {
        "category": categorize(os.path.basename(wil_path)),
        "count": count,
        "data_frames": count - no_data,
        "no_data": no_data,
        "zero_size": zero_size,
        "nonzero_off_x": nz_x,
        "nonzero_off_y": nz_y,
        "either": either,
        "min_x": min(xs) if xs else None,
        "max_x": max(xs) if xs else None,
        "min_y": min(ys) if ys else None,
        "max_y": max(ys) if ys else None,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.environ.get("MIR3_EI_ROOT"),
                    help="client root containing Data/ (default $MIR3_EI_ROOT)")
    ap.add_argument("--out", default=None,
                    help="output JSON path (default docs/research/mir3-map-reconstruction/"
                         "offset-distribution.json relative to repo root)")
    args = ap.parse_args()

    if not args.root:
        print("MIR3_EI_ROOT not set and --root not given", file=sys.stderr)
        return 2
    data = os.path.join(args.root, "Data")
    if not os.path.isdir(data):
        print(f"no Data dir at {data}", file=sys.stderr)
        return 2

    wil_paths = sorted(
        os.path.join(data, f) for f in os.listdir(data) if f.lower().endswith(".wil")
    )
    for theme in THEME_DIRS:
        tdir = os.path.join(data, theme)
        if os.path.isdir(tdir):
            wil_paths += sorted(
                os.path.join(tdir, f) for f in os.listdir(tdir) if f.lower().endswith(".wil")
            )

    result: dict = {}
    for p in wil_paths:
        rel = os.path.relpath(p, data)
        result[rel] = scan_lib(p)
        st = result[rel]
        print(f"{rel:40s} cat={st['category']:<16s} count={st['count']:6d} "
              f"data={st['data_frames']:6d} nzX={st['nonzero_off_x']:6d} "
              f"nzY={st['nonzero_off_y']:6d} either={st['either']:6d} "
              f"x[{st['min_x']}..{st['max_x']}] y[{st['min_y']}..{st['max_y']}]")

    out = args.out
    if out is None:
        repo = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        out = os.path.join(repo, "docs", "research", "mir3-map-reconstruction",
                           "offset-distribution.json")
    with open(out, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=1, sort_keys=True)
        f.write("\n")
    print(f"wrote {out} ({len(result)} libraries)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
