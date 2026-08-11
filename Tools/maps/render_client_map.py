#!/usr/bin/env python3
"""Generate one static JPG from the current Zircon client map package.

The browser viewer calls the same renderer through ``/fullmap``.  This small
entry point is useful for batch jobs, visual diffs and checking a converted
map without starting the HTTP server.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mapviewer


def main() -> None:
    default_root = Path(mapviewer.DEFAULT_CLIENT_ROOT)
    parser = argparse.ArgumentParser()
    parser.add_argument("map", nargs="?", default="3.map", help="map file, e.g. 3.map")
    parser.add_argument("--client-root", type=Path, default=default_root)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--zoom", type=int, default=None,
                        help="renderer zoom (default: fit level from map size)")
    args = parser.parse_args()

    maps_dir = args.client_root / "Map"
    data_dir = args.client_root / "Data" / "Map Data"
    map_name = args.map if args.map.lower().endswith(".map") else args.map + ".map"
    if not (maps_dir / map_name).exists():
        raise SystemExit(f"map not found: {maps_dir / map_name}")
    if not data_dir.exists():
        raise SystemExit(f"map data not found: {data_dir}")

    cache = mapviewer.MapCache(str(maps_dir))
    pool = mapviewer.FramePool(str(data_dir))
    w, h, _ = cache.get(map_name)
    ladder = mapviewer.map_ladder(w, h, mapviewer.LAYOUT_RECT)
    zoom = ladder[-1] if args.zoom is None else args.zoom
    output = args.output or Path(f"/tmp/zircon-map-{Path(map_name).stem}-z{zoom}.jpg")
    output.parent.mkdir(parents=True, exist_ok=True)
    payload = mapviewer.render_full_map(cache, pool, map_name, zoom,
                                        fmt="JPEG", layout=mapviewer.LAYOUT_RECT)
    output.write_bytes(payload)
    print(f"map={map_name} cells={w}x{h} zoom=1:{1 << zoom} -> {output}")


if __name__ == "__main__":
    main()
