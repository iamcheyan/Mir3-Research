#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_stores.py — 从 wiki_all_fixed.json 生成 /tmp/stores.json (商店板块输入)。

stores_build.py 期望:
  stores["npcs"]: [{map, mapFile, name, index, image, points}]
    map    = "地图中文名 (码) - 区域名"  (stores_build split(' (')/' - ' 取地图名与店类型)
    mapFile= 地图文件名 (0.map)
    points = [{x, y}]  实际坐标 (来自 MapRegion.PointRegion)
  stores["goods"]: [{item, rate}]   NPCGood.Item(名字) + Rate
"""
import json
import sys

ALL = sys.argv[1] if len(sys.argv) > 1 else "/tmp/wiki_all_fixed.json"
OUT = sys.argv[2] if len(sys.argv) > 2 else "/tmp/stores.json"

d = json.load(open(ALL, encoding="utf-8"))
rows = lambda t: d.get(t, {}).get("rows", [])

# 地图: Description -> FileName
map_file = {}
for r in rows("MapInfo"):
    if r.get("Description"):
        map_file[r["Description"]] = r.get("FileName")

# 区域: Description -> {Map, PointRegion}
region_map = {}
region_points = {}
for r in rows("MapRegion"):
    desc = r.get("Description")
    if not desc:
        continue
    region_map[desc] = r.get("Map")
    pts = r.get("PointRegion") or []
    region_points[desc] = [{"x": p[0], "y": p[1]} for p in pts if isinstance(p, list) and len(p) == 2]

# NPC: NPCName -> {Region, Image, Index}
npcs = []
for r in rows("NPCInfo"):
    name = r.get("NPCName")
    region = r.get("Region")
    if not name or not region:
        continue
    mname = region_map.get(region)
    mfile = map_file.get(mname) if mname else None
    npcs.append({
        "map": f"{mname} ({mfile[:-4] if mfile else '?'}) - {region}" if mname else region,
        "mapFile": mfile,
        "name": name,
        "index": r.get("Index"),
        "image": r.get("Image"),
        "points": region_points.get(region, []),
    })

# NPCGood: Item(名字) + Rate
goods = []
for r in rows("NPCGood"):
    item = r.get("Item")
    if not item:
        continue
    goods.append({"item": item, "rate": r.get("Rate") if r.get("Rate") is not None else 1})

out = {"npcs": npcs, "goods": goods}
json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False)
print(f"输出 {OUT}: NPC {len(npcs)} / 货品 {len(goods)}")
