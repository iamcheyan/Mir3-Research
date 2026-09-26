#!/usr/bin/env python3
"""Build a conservative movement audit staging manifest from workspace data.

This generator never modifies System.db, terrain, or map_links_v2.json. Walkability
is intentionally reimplemented here (not imported from mapedit.mapio).
"""
from __future__ import annotations

import argparse
import csv
import json
import struct
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WS = ROOT / "Tools/dbeditor/workspace"
DEFAULT_MAPS = Path("/home/tetsuya/development/zircon/Debug/ServerCore/Map")
MAP_MANIFEST = ROOT / "docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/map_manifest.json"
RELATIONS = {"exact", "renamed", "variant", "replacement", "pending"}


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def rows(ws, name):
    data = read_json(Path(ws) / f"{name}.json")
    return data.get("rows", data) if isinstance(data, dict) else data


def map_layout(ws):
    maps = {}
    for row in rows(ws, "MapInfo"):
        maps[row["FileName"]] = row
    return maps


def region_layout(ws):
    return {row["Index"]: row for row in rows(ws, "MapRegion")}


def terrain_info(path):
    """Independent EI map cell reader. Returns dimensions and walkable cells.

    The client cell table begins after the 28-byte header and the half-resolution
    ground table. EI walkability per the requested flag convention is flag&3==3.
    """
    b = Path(path).read_bytes()
    if len(b) < 28:
        raise ValueError("short header")
    w, h = struct.unpack_from("<HH", b, 22)
    base = 28 + (w // 2) * (h // 2) * 3
    n = max(0, min(w * h, (len(b) - base) // 14))
    walk = set()
    for i in range(n):
        if b[base + 14 * i] & 3 == 3:
            walk.add((i // h, i % h))
    return w, h, walk


def endpoint(region, maps, terrain, alias_rel):
    ref = region or {}
    reg = ref.get("row") or {}
    p = reg.get("PointRegion") or {}
    mapname = (reg.get("Map") or {}).get("Name")
    mi = maps.get(mapname, {})
    x, y = p.get("CenterX"), p.get("CenterY")
    file = mapname
    relation = alias_rel.get(mapname, "unmatched")
    t = terrain.get(file)
    in_bounds = None
    walkable = None
    if t and x is not None and y is not None:
        w, h, cells = t
        in_bounds = isinstance(x, int) and isinstance(y, int) and 0 <= x < w and 0 <= y < h
        walkable = bool(in_bounds and (x, y) in cells)
    return {
        "map_id": (reg.get("Map") or {}).get("Index"), "map_file": file,
        "map_description": mi.get("Description", ""), "region_index": reg.get("Index"),
        "region_description": reg.get("Description", ""), "x": x, "y": y,
        "walkable": walkable, "in_bounds": in_bounds,
        "map_relation": relation, "terrain_available": t is not None,
    }


def build(ws, maps_dir, manifest_path):
    maps = map_layout(ws)
    regions = region_layout(ws)
    relation = {}
    if Path(manifest_path).exists():
        for item in read_json(manifest_path).get("maps", []):
            mi = item.get("zircon_map_info") or {}
            if mi.get("file"):
                relation[mi["file"]] = item.get("relation", "unmatched")
    terrain = {}
    for f in Path(maps_dir).glob("*.map") if Path(maps_dir).is_dir() else []:
        try:
            terrain[f.stem] = terrain_info(f)
        except (OSError, ValueError, struct.error):
            pass
    records = []
    for m in rows(ws, "MovementInfo"):
        sreg = regions.get((m.get("SourceRegion") or {}).get("Index"))
        dreg = regions.get((m.get("DestinationRegion") or {}).get("Index"))
        src = endpoint({"row": sreg}, maps, terrain, relation)
        dst = endpoint({"row": dreg}, maps, terrain, relation)
        status = "pending_manual_review"
        reasons = []
        for label, ep in (("source", src), ("destination", dst)):
            if not ep["map_file"] or ep["map_file"] not in maps:
                status = "blocked-missing-map"; reasons.append(f"{label}: MapRegion map missing from MapInfo")
            elif not ep["terrain_available"]:
                if status != "blocked-missing-map": status = "pending_manual_review"
                reasons.append(f"{label}: terrain file unavailable in audited directory")
            elif ep["in_bounds"] is False:
                status = "blocked-out-of-bounds"; reasons.append(f"{label}: point outside terrain dimensions")
            elif ep["walkable"] is False:
                status = "blocked-nonwalkable"; reasons.append(f"{label}: flag&3 != 3")
        if status == "pending_manual_review":
            reasons.append("workspace region centroid is not an EI Envir gate record; no safe coordinate correction inferred")
        if src["map_file"] and dst["map_file"] and src["map_file"] == dst["map_file"]:
            reasons.append("same-map transition; inspect region semantics and directionality")
        rec = {
            "movement_index": m.get("Index"), "identity": m.get("_Identity"),
            "source": src, "destination": dst,
            "icon": m.get("Icon"), "need_item": m.get("NeedItem"),
            "need_hole": m.get("NeedHole"), "required_class": m.get("RequiredClass"),
            "effect": m.get("Effect"), "skip_validation": m.get("SkipValidation"),
            "raw_destination_map": dst["map_file"], "raw_destination_region": dst["region_index"],
            "resolved_destination_map": dst["map_file"], "resolved_destination_file": dst["map_file"],
            "resolved_destination_region": dst["region_index"],
            "directionality": "source-region-to-destination-region (MovementInfo directed edge)",
            "source_of_truth": [
                "1: Tools/dbeditor/workspace/MovementInfo.json + MapRegion.json",
                "2: reference/mir3-source/Source/GameServer/LocalDB.pas LoadMapInfos (MapInfo.txt gate model)",
                "3: 2026-09-25 map_manifest exact/renamed/variant/replacement/pending relation",
                "4: map terrain flag reader implemented independently by this audit generator",
            ],
            "confidence": 0.25 if status == "pending_manual_review" else 0.9,
            "status": status, "reason": "; ".join(dict.fromkeys(reasons)),
            "correction": None,
        }
        records.append(rec)
    return records, maps, terrain


def write_tsv(path, records):
    flat = []
    for r in records:
        flat.append({"movement_index":r["movement_index"],"source_map_id":r["source"]["map_id"],"source_file":r["source"]["map_file"],"source_description":r["source"]["map_description"],"source_region_index":r["source"]["region_index"],"source_region_description":r["source"]["region_description"],"source_x":r["source"]["x"],"source_y":r["source"]["y"],"source_walkable":r["source"]["walkable"],"source_in_bounds":r["source"]["in_bounds"],"source_map_relation":r["source"]["map_relation"],"icon":r["icon"],"need_item":r["need_item"],"required_class":r["required_class"],"raw_destination_map":r["raw_destination_map"],"raw_destination_region":r["raw_destination_region"],"resolved_destination_map":r["resolved_destination_map"],"resolved_destination_file":r["resolved_destination_file"],"destination_x":r["destination"]["x"],"destination_y":r["destination"]["y"],"destination_walkable":r["destination"]["walkable"],"destination_in_bounds":r["destination"]["in_bounds"],"destination_map_relation":r["destination"]["map_relation"],"directionality":r["directionality"],"source_of_truth":" | ".join(r["source_of_truth"]),"confidence":r["confidence"],"status":r["status"],"reason":r["reason"]})
    with open(path,"w",newline="",encoding="utf-8") as f:
        w=csv.DictWriter(f,fieldnames=list(flat[0]) if flat else [] ,delimiter="\t"); w.writeheader(); w.writerows(flat)


def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--workspace",default=DEFAULT_WS); ap.add_argument("--maps",default=DEFAULT_MAPS); ap.add_argument("--manifest",default=MAP_MANIFEST); ap.add_argument("--out",default=ROOT/"docs/research/map-connections-audit-2026-09-26"); ap.add_argument("--links",default=ROOT/"Tools/maps/map_links_v3.json"); a=ap.parse_args()
    out=Path(a.out); out.mkdir(parents=True,exist_ok=True)
    records,maps,terrain=build(a.workspace,a.maps,a.manifest)
    (out/"connection-manifest.json").write_text(json.dumps({"schema":"mir3-map-connections-audit-v1","records":records},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    write_tsv(out/"connection-manifest.tsv",records)
    links={"names":{k:v.get("Description",k) for k,v in maps.items()},"links":[[r["source"]["map_file"],r["destination"]["map_file"]] for r in records if r["source"]["map_file"] and r["destination"]["map_file"]],"audit_records":records,"_meta":{"generated":"2026-09-26","source":"System.db workspace MovementInfo/MapRegion; audited staging only","movement_rows":len(records),"audited_map_files":len(terrain)}}
    Path(a.links).write_text(json.dumps(links,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    baseline_path = ROOT / "Tools/maps/map_links_v2.json"
    baseline = read_json(baseline_path) if baseline_path.exists() else {"links": []}
    old_edges = {tuple(x) for x in baseline.get("links", [])}
    new_edges = {tuple(x) for x in links["links"]}
    diff = {
        "baseline": "Tools/maps/map_links_v2.json (read-only)",
        "staging": "Tools/maps/map_links_v3.json",
        "baseline_unique_edges": len(old_edges), "staging_unique_edges": len(new_edges),
        "added_edges": [list(x) for x in sorted(new_edges - old_edges)],
        "removed_edges": [list(x) for x in sorted(old_edges - new_edges)],
        "movement_rows_preserved": len(records), "movement_corrections": [],
    }
    (out/"connection-diff.json").write_text(json.dumps(diff,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    summary=Counter(r["status"] for r in records)
    (out/"_generation-summary.json").write_text(json.dumps({"movement_rows":len(records),"mapinfo_rows":len(maps),"terrain_files":len(terrain),"statuses":summary},ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"movement_rows":len(records),"mapinfo_rows":len(maps),"terrain_files":len(terrain),"statuses":summary},ensure_ascii=False))

if __name__=="__main__": main()
