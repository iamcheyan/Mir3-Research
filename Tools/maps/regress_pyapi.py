#!/usr/bin/env python3
"""regress_pyapi.py — mapviewer 库级 API 回归指纹（拆模块前后对照）。

十个兄弟工具 `import mapviewer` 直接用库 API（thumb_gen / webres /
render_map_comparison / survey_mir3_maps ...）。本脚本对样本地图生成
parse_map 单元矩阵的规范摘要 + 几何/库解析 API 的输出指纹，拆分前后
各跑一次，逐字段相等 = 库 API 行为不变。

用法:
  python3 regress_pyapi.py --out /tmp/e1-regress/base-pyapi.json
"""
import argparse
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapviewer as mv


def cells_digest(path):
    w, h, cells = mv.parse_map(path)
    d = hashlib.sha256()
    d.update(f"{w}x{h}".encode())
    for x in range(w):
        for y in range(h):
            c = cells[x][y]
            d.update(f"{x},{y},{c.back_file},{c.back_img},{c.mid_file},{c.mid_img},"
                     f"{c.front_file},{c.front_img},{c.flag},{c.anim_a},{c.anim_b};".encode())
    return w, h, d.hexdigest()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--maps-dir", default=os.path.join(mv.DEFAULT_CLIENT_ROOT, "Map"))
    ap.add_argument("--data-dir", default=os.path.join(mv.DEFAULT_CLIENT_ROOT, "Data"))
    ap.add_argument("--out", required=True)
    args = ap.parse_args()

    out = {"kr_order": hashlib.sha256(
        json.dumps(mv.KR_ORDER, sort_keys=True).encode()).hexdigest()}

    names = sorted(f for f in os.listdir(args.maps_dir) if f.lower().endswith(".map"))
    sample = [names[0], names[len(names) // 2], names[-1]]
    for fixed in ("0.map", "3.map", "11.map"):
        if fixed in names and fixed not in sample:
            sample.append(fixed)
    d_first = next((n for n in names if n.upper().startswith("D")), None)
    if d_first and d_first not in sample:
        sample.append(d_first)

    out["cells"] = {}
    for n in sample:
        w, h, dig = cells_digest(os.path.join(args.maps_dir, n))
        out["cells"][n] = {"w": w, "h": h, "sha256": dig}
        print(f"[*] {n}: {w}x{h} {dig[:16]}")

    # 几何 API
    geo = []
    for (w, h) in ((100, 100), (1360, 1500), (7, 3), (1, 1), (1000, 641)):
        geo.append([mv.world_bounds(w, h), mv.map_ladder(w, h),
                    mv.cell_anchor(3, 5, h), mv.cell_anchor(0, 0, h, mv.LAYOUT_ISO)])
    out["geometry"] = hashlib.sha256(json.dumps(geo).encode()).hexdigest()

    # 库路径解析 + 帧头（FramePool 实际打开库）
    libs = {}
    pool = mv.FramePool(args.data_dir)
    for lid in (0, 3, 4, 5, 10, 11, 200, 45, 60):
        lib = pool._get_lib(lid)
        libs[str(lid)] = None if lib is None else (type(lib).__name__, lib.count)
    out["libs"] = libs

    # 渲染一瓦（走完整 render_tile 代码路径，进程内）
    tiles = {}
    for n, tx, ty, z in (("0.map", 2, 2, 1), ("3.map", 0, 0, 0), ("11.map", 1, 1, 2)):
        mc = mv.MapCache(args.maps_dir)
        try:
            data = mv.render_tile(mc, pool, n, tx, ty, z)
            tiles[f"{n}@{tx},{ty},z{z}"] = hashlib.sha256(data).hexdigest()
        except Exception as e:
            tiles[f"{n}@{tx},{ty},z{z}"] = f"ERROR {e!r}"
    out["render_tile"] = tiles

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"[*] -> {args.out}")


if __name__ == "__main__":
    main()
