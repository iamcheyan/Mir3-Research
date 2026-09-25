#!/usr/bin/env python3
"""Independent verifier for the offline alignment manifest.

This file intentionally does not import the builder.  It decodes map dimensions
and cell flags independently, then checks bounds, walkability, duplicate target
points, and the no-delete/no-business-field invariants.
"""
from __future__ import annotations

import argparse
import json
import struct
from collections import Counter, defaultdict
from pathlib import Path


def read_map(path: Path):
    raw = path.read_bytes()
    if len(raw) < 28:
        raise ValueError(f"short map header: {path}")
    w, h = struct.unpack_from("<HH", raw, 22)
    data_start = 28 + (w // 2) * (h // 2) * 3
    required = data_start + w * h * 14
    if required > len(raw):
        raise ValueError(f"short cell segment: {path} expected={required} actual={len(raw)}")
    return w, h, data_start, raw


def flag(map_path: Path, x: int, y: int) -> tuple[str, int | None]:
    w, h, start, raw = read_map(map_path)
    if x < 0 or y < 0 or x >= w or y >= h:
        return "fail", None
    # Independent implementation: calculate the x-major record offset rather
    # than using the builder's cached cell grid.
    off = start + (x * h + y) * 14
    value = raw[off]
    return ("pass" if (value & 3) == 3 else "fail"), value


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.manifest.read_text(encoding="utf-8"))
    errors: list[str] = []
    format_issues: list[str] = []
    warnings: list[str] = []
    maps = {str(m["original_map"]).casefold(): m for m in data["maps"]}
    npc_points: dict[tuple[str, int, int], list[int]] = defaultdict(list)
    npc_before = {int(n["current_npc_index"]): n for n in data["npcs"]}
    for n in data["npcs"]:
        if n.get("hero_kill_map") is None or n.get("hero_kill_xy") is None:
            continue
        stem = str(n["hero_kill_map"])
        xy = n["hero_kill_xy"]
        npc_points[(stem.casefold(), int(xy["x"]), int(xy["y"]))].append(int(n["current_npc_index"]))
        map_row = maps.get(stem.casefold())
        map_path = Path(map_row["zircon_map_file"]) if map_row and map_row.get("zircon_map_file") else None
        if map_path is None or not map_path.exists():
            errors.append(f"NPC {n['current_npc_index']}: target map missing {stem}")
            continue
        actual, _ = flag(map_path, int(xy["x"]), int(xy["y"]))
        if actual != n["walkable"]["target"]:
            errors.append(f"NPC {n['current_npc_index']}: builder walkable={n['walkable']['target']} independent={actual}")
        if not (n.get("non_position_fields_untouched") is True):
            errors.append(f"NPC {n['current_npc_index']}: missing non-position invariant")
        if n.get("apply_status") == "delete":
            errors.append(f"NPC {n['current_npc_index']}: deletion status violates goal")
    overlaps = {key: ids for key, ids in npc_points.items() if len(ids) > 1}
    if overlaps:
        warnings.append(f"NPC target overlaps: {len(overlaps)} cells / {sum(len(v) for v in overlaps.values())} rows")
    respawn_checks = Counter()
    for r in data["monster_respawns"]:
        old = r["old_respawn"]
        if old.get("xy") is None:
            respawn_checks["pending"] += 1
            continue
        map_row = maps.get(str(old["map"]).casefold())
        path = Path(map_row["zircon_map_file"]) if map_row and map_row.get("zircon_map_file") else None
        if path is None or not path.exists():
            respawn_checks["pending"] += 1
            continue
        try:
            actual, _ = flag(path, int(old["xy"]["x"]), int(old["xy"]["y"]))
        except ValueError as exc:
            format_issues.append(f"Respawn {old['index']}: {exc}")
            respawn_checks["pending"] += 1
            continue
        respawn_checks[actual] += 1
        if actual != r["walkable"]:
            errors.append(f"Respawn {old['index']}: builder walkable={r['walkable']} independent={actual}")
        if r.get("new_respawn") is not None:
            errors.append(f"Respawn {old['index']}: pending source has unexpected new target")
        if r.get("apply_status") not in {"blocked", "pending-review"}:
            errors.append(f"Respawn {old['index']}: unsafe apply status {r.get('apply_status')}")
    map_checks = Counter()
    for m in data["maps"]:
        path = Path(m["zircon_map_file"]) if m.get("zircon_map_file") else None
        if path is None or not path.exists():
            map_checks["missing"] += 1
            continue
        try:
            w, h, _, _ = read_map(path)
            expected = m["size"]["zircon"]
            if expected["width"] != w or expected["height"] != h:
                errors.append(f"Map {m['original_map']}: manifest dimensions disagree")
            map_checks[m["relation"]] += 1
        except ValueError as exc:
            format_issues.append(str(exc))
    result = {
        "manifest": str(args.manifest),
        "independent_parser": "pass" if not errors else "fail",
        "error_count": len(errors),
        "format_issue_count": len(format_issues),
        "warning_count": len(warnings),
        "map_checks": dict(map_checks),
        "npc_target_rows": len(npc_points),
        "npc_overlap_cells": len(overlaps),
        "respawn_walkable_checks": dict(respawn_checks),
        "errors": errors,
        "format_issues": format_issues,
        "warnings": warnings,
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
