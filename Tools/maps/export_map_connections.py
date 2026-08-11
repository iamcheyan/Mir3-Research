#!/usr/bin/env python3
"""Export Zircon map-region/movement documentation to viewer JSON.

The current client stores map connections in System.db.  The research repo
already contains the lossless Markdown export produced by SystemDbProbe; this
script turns that export into a small, stable JSON file consumed by
``mapviewer.py``.  Coordinates are region centroids in *game cells*, not
screen pixels.

Usage (defaults target this repository and the current Zircon client):
    python3 Tools/maps/export_map_connections.py
    python3 Tools/maps/export_map_connections.py --output /tmp/map-links.json
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

REGION_RE = re.compile(r"^### #(\d+) · (\S+) \(#\d+\) / (.*)$")
POINT_RE = re.compile(r"\{X=(-?\d+),Y=(-?\d+)\}")
MOVE_RE = re.compile(
    r"^\|\s*(\d+)\s*\|\s*(\S+) \(#(\d+)\) / (.*?)\s*\|\s*"
    r"(\S+) \(#(\d+)\) / (.*?)\s*\|\s*([^|]+)\|"
)


def parse_regions(paths: list[Path]) -> dict[int, dict]:
    regions: dict[int, dict] = {}
    current = None
    for path in paths:
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            match = REGION_RE.match(raw.strip())
            if match:
                idx, map_name, description = match.groups()
                current = regions[int(idx)] = {
                    "index": int(idx), "map": map_name,
                    "description": description, "points": []
                }
                continue
            if current is not None and "PointRegion" in raw:
                current["points"] = [
                    {"x": int(x), "y": int(y)} for x, y in POINT_RE.findall(raw)
                ]
    for region in regions.values():
        points = region["points"]
        if points:
            region["x"] = round(sum(p["x"] for p in points) / len(points), 2)
            region["y"] = round(sum(p["y"] for p in points) / len(points), 2)
    return regions


def parse_movements(paths: list[Path], regions: dict[int, dict]) -> list[dict]:
    links = []
    for path in paths:
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            match = MOVE_RE.match(raw.strip())
            if not match:
                continue
            idx, smap, sregion, sdesc, dmap, dregion, ddesc, icon = match.groups()
            source = regions.get(int(sregion), {"map": smap, "description": sdesc})
            dest = regions.get(int(dregion), {"map": dmap, "description": ddesc})
            links.append({
                "index": int(idx), "icon": icon.strip(),
                "source": {"map": source.get("map", smap), "region": int(sregion),
                            "description": source.get("description", sdesc),
                            "x": source.get("x"), "y": source.get("y")},
                "destination": {"map": dest.get("map", dmap), "region": int(dregion),
                                "description": dest.get("description", ddesc),
                                "x": dest.get("x"), "y": dest.get("y")},
            })
    return links


def main() -> None:
    parser = argparse.ArgumentParser()
    root = Path(__file__).resolve().parents[2]
    parser.add_argument("--docs", type=Path, default=root / "docs/database/data")
    parser.add_argument("--output", type=Path,
                        default=root / "docs/database/data/map-connections.json")
    args = parser.parse_args()
    region_files = sorted(args.docs.glob("MapRegion.*.md"))
    movement_files = sorted(args.docs.glob("MovementInfo.*.md"))
    if not region_files or not movement_files:
        raise SystemExit(f"missing database Markdown export under {args.docs}")
    regions = parse_regions(region_files)
    links = parse_movements(movement_files, regions)
    data = {"version": 1, "source": "SystemDbProbe Markdown export",
            "regions": list(regions.values()), "links": links}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n",
                           encoding="utf-8")
    print(f"regions={len(regions)} links={len(links)} -> {args.output}")


if __name__ == "__main__":
    main()
