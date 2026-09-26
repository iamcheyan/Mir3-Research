#!/usr/bin/env python3
"""Independent audit verifier; does not import map_connections_audit."""
import argparse
import json
import struct
from collections import Counter
from pathlib import Path


def inspect_map(file):
    raw = Path(file).read_bytes()
    if len(raw) < 28:
        raise ValueError("truncated header")
    width = int.from_bytes(raw[22:24], "little")
    height = int.from_bytes(raw[24:26], "little")
    start = 28 + (width >> 1) * (height >> 1) * 3
    cell_count = max(0, (len(raw) - start) // 14)
    return width, height, start, cell_count, raw


def verify(manifest, maps_dir):
    payload = json.loads(Path(manifest).read_text(encoding="utf-8"))
    recs = payload["records"]
    terrain_cache = {}
    findings = []
    statuses = Counter()
    seen_index = Counter()
    pairs = Counter()
    for row in recs:
        statuses[row["status"]] += 1
        seen_index[row["movement_index"]] += 1
        src, dst = row["source"], row["destination"]
        pairs[(src["map_file"], src.get("region_index"), dst["map_file"], dst.get("region_index"))] += 1
        for side, ep in (("source", src), ("destination", dst)):
            stem, x, y = ep["map_file"], ep["x"], ep["y"]
            p = Path(maps_dir) / f"{stem}.map" if stem else None
            if not p or not p.is_file():
                if ep["terrain_available"]:
                    findings.append({"movement_index":row["movement_index"],"side":side,"error":"manifest claims missing terrain is available"})
                continue
            try:
                if stem not in terrain_cache:
                    terrain_cache[stem] = inspect_map(p)
                w, h, start, n, data = terrain_cache[stem]
                inside = isinstance(x, int) and isinstance(y, int) and 0 <= x < w and 0 <= y < h
                if ep["in_bounds"] != inside:
                    findings.append({"movement_index":row["movement_index"],"side":side,"error":"bounds mismatch","expected":inside,"recorded":ep["in_bounds"]})
                walkable = bool(inside and x * h + y < n and (data[start + (x * h + y) * 14] & 3) == 3)
                if ep["walkable"] != walkable:
                    findings.append({"movement_index":row["movement_index"],"side":side,"error":"walkability mismatch","expected":walkable,"recorded":ep["walkable"]})
            except Exception as e:
                findings.append({"movement_index":row["movement_index"],"side":side,"error":f"terrain parse error: {e}"})
    duplicated_indices = sorted(k for k,v in seen_index.items() if v > 1)
    duplicate_relations = sorted([{"relation":list(k),"count":v} for k,v in pairs.items() if v>1],key=lambda x:(-x["count"],x["relation"]))
    return {"movement_records":len(recs),"terrain_files_checked":len(terrain_cache),"status_counts":dict(statuses),"duplicate_movement_indices":duplicated_indices,"duplicate_region_relations":duplicate_relations,"verification_errors":findings,"independent_parser":"28-byte header; half-resolution 3-byte ground area; column-major 14-byte cells; (flag & 3)==3","pass":not findings}


def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--manifest",default="docs/research/map-connections-audit-2026-09-26/connection-manifest.json"); ap.add_argument("--maps",default="/home/tetsuya/development/zircon/Debug/ServerCore/Map"); ap.add_argument("--out",default="docs/research/map-connections-audit-2026-09-26/connection-verification.json"); a=ap.parse_args()
    result=verify(a.manifest,a.maps)
    Path(a.out).write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps(result,ensure_ascii=False))
    raise SystemExit(0 if result["pass"] else 1)


if __name__=="__main__": main()
