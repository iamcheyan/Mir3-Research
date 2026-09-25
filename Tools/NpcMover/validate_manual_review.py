#!/usr/bin/env python3
"""Validate human review decisions before any database write."""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path


DECISIONS = {"approve", "retain-current", "reject", "needs-evidence"}
APPROVAL_FIELDS = (
    "approved_map",
    "approved_x",
    "approved_y",
    "approved_count",
    "approved_range",
    "approved_interval",
)
REQUIRED_COLUMNS = {
    "kind",
    "status",
    "review_class",
    "index",
    "review_decision",
    "approved_map",
    "approved_x",
    "approved_y",
    "approved_count",
    "approved_range",
    "approved_interval",
    "review_note",
}


def text(row: dict[str, str], key: str) -> str:
    return (row.get(key) or "").strip()


def integer(value: str, field: str, key: tuple[str, str], errors: list[str]) -> int | None:
    try:
        number = int(value)
    except ValueError:
        errors.append(f"{key[0]}#{key[1]}.{field}: expected integer, got {value!r}")
        return None
    if number < 0:
        errors.append(f"{key[0]}#{key[1]}.{field}: expected non-negative integer, got {number}")
        return None
    return number


def expected_rows(manifest: dict) -> dict[tuple[str, str], str]:
    expected: dict[tuple[str, str], str] = {}
    for row in manifest["npcs"]:
        if row["apply_status"] == "pending-review":
            expected[("npc", str(row["current_npc_index"]))] = row["apply_status"]
    for row in manifest["monster_respawns"]:
        if row["apply_status"] in {"blocked", "pending-review"}:
            expected[("respawn", str(row["old_respawn"]["index"]))] = row["apply_status"]
    return expected


def map_targets(manifest: dict) -> dict[str, dict]:
    targets: dict[str, dict] = {}
    for item in manifest.get("maps", []):
        info = item.get("zircon_map_info") or {}
        map_name = text({"value": info.get("file")}, "value")
        if not map_name:
            continue
        size = (item.get("size") or {}).get("zircon") or {}
        candidate = {
            "map_index": info.get("index"),
            "map_file": map_name,
            "width": size.get("width"),
            "height": size.get("height"),
        }
        key = map_name.casefold()
        previous = targets.get(key)
        if previous and previous != candidate:
            targets[key] = {"ambiguous": True, "map_file": map_name}
        else:
            targets[key] = candidate
    return targets


def check_target(
    row: dict[str, str],
    key: tuple[str, str],
    approved: dict[str, str],
    targets: dict[str, dict],
    errors: list[str],
) -> None:
    map_name = approved["approved_map"]
    target = targets.get(map_name.casefold())
    if target is None:
        errors.append(f"{key[0]}#{key[1]}.approved_map: unknown Zircon map {map_name!r}")
        return
    if target.get("ambiguous"):
        errors.append(f"{key[0]}#{key[1]}.approved_map: ambiguous Zircon map {map_name!r}")
        return
    if target.get("map_index") is None:
        errors.append(f"{key[0]}#{key[1]}.approved_map: missing MapInfo Index for {map_name!r}")
    try:
        x = int(approved["approved_x"])
        y = int(approved["approved_y"])
    except ValueError:
        return
    width, height = target.get("width"), target.get("height")
    if isinstance(width, int) and not 0 <= x < width:
        errors.append(f"{key[0]}#{key[1]}.approved_x: {x} outside {map_name} width {width}")
    if isinstance(height, int) and not 0 <= y < height:
        errors.append(f"{key[0]}#{key[1]}.approved_y: {y} outside {map_name} height {height}")


def validate(manifest: dict, review_path: Path) -> tuple[dict, int, dict[tuple[str, str], dict[str, str]]]:
    expected = expected_rows(manifest)
    targets = map_targets(manifest)
    errors: list[str] = []
    rows: dict[tuple[str, str], dict[str, str]] = {}
    with review_path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        columns = set(reader.fieldnames or [])
        missing_columns = sorted(REQUIRED_COLUMNS - columns)
        if missing_columns:
            errors.append(f"missing columns: {', '.join(missing_columns)}")
        for line_number, row in enumerate(reader, start=2):
            key = (text(row, "kind"), text(row, "index"))
            if key in rows:
                errors.append(f"line {line_number}: duplicate review key {key[0]}#{key[1]}")
                continue
            rows[key] = row
            if key not in expected:
                errors.append(f"line {line_number}: unexpected review key {key[0]}#{key[1]}")
                continue
            if text(row, "status") != expected[key]:
                errors.append(
                    f"line {line_number}: status mismatch for {key[0]}#{key[1]} "
                    f"({text(row, 'status')!r} != {expected[key]!r})"
                )
            decision = text(row, "review_decision")
            if decision not in DECISIONS:
                errors.append(f"line {line_number}: invalid review_decision {decision!r}")
                continue
            note = text(row, "review_note")
            if not note:
                errors.append(f"line {line_number}: review_note is required for {decision}")
            approved = {field: text(row, field) for field in APPROVAL_FIELDS}
            if decision == "approve":
                if key[0] == "respawn" and text(row, "review_class") == "zircon-only":
                    errors.append(f"line {line_number}: zircon-only respawn cannot be approved")
                required = ["approved_map", "approved_x", "approved_y"]
                if key[0] == "respawn":
                    required += ["approved_count", "approved_range", "approved_interval"]
                for field in required:
                    if not approved[field]:
                        errors.append(f"line {line_number}: {field} is required for approve")
                parsed: dict[str, int | None] = {}
                for field in ("approved_x", "approved_y", "approved_count", "approved_range", "approved_interval"):
                    if approved[field]:
                        parsed[field] = integer(approved[field], field, key, errors)
                if approved["approved_map"] and approved["approved_x"] and approved["approved_y"]:
                    check_target(row, key, approved, targets, errors)
            elif any(approved.values()):
                errors.append(f"line {line_number}: approval fields must be blank for {decision}")

    missing = sorted(set(expected) - set(rows))
    for kind, index in missing:
        errors.append(f"missing review row {kind}#{index}")

    decision_counts: dict[str, int] = {}
    for row in rows.values():
        decision = text(row, "review_decision") or "unresolved"
        decision_counts[decision] = decision_counts.get(decision, 0) + 1
    result = {
        "database_write": False,
        "review_file": str(review_path),
        "expected_rows": len(expected),
        "review_rows": len(rows),
        "decision_counts": decision_counts,
        "approved_npc": sum(text(row, "kind") == "npc" and text(row, "review_decision") == "approve" for row in rows.values()),
        "approved_respawn": sum(text(row, "kind") == "respawn" and text(row, "review_decision") == "approve" for row in rows.values()),
        "known_zircon_maps": len(targets),
        "errors": errors,
        "status": "pass" if not errors else "blocked",
    }
    return result, 0 if not errors else 2, rows


def approved_plan(manifest: dict, rows: dict[tuple[str, str], dict[str, str]], review_path: Path) -> dict:
    targets = map_targets(manifest)
    npc_moves = []
    respawn_updates = []
    retained = rejected = 0
    for (kind, index), row in sorted(rows.items()):
        decision = text(row, "review_decision")
        if decision == "approve":
            target = targets[text(row, "approved_map").casefold()]
            if kind == "npc":
                npc_moves.append({
                    "npc_index": int(index),
                    "map_index": int(target["map_index"]),
                    "map": text(row, "approved_map"),
                    "x": int(text(row, "approved_x")),
                    "y": int(text(row, "approved_y")),
                    "review_note": text(row, "review_note"),
                })
            else:
                respawn_updates.append({
                    "respawn_index": int(index),
                    "map_index": int(target["map_index"]),
                    "map": text(row, "approved_map"),
                    "x": int(text(row, "approved_x")),
                    "y": int(text(row, "approved_y")),
                    "count": int(text(row, "approved_count")),
                    "range": int(text(row, "approved_range")),
                    "interval": int(text(row, "approved_interval")),
                    "review_note": text(row, "review_note"),
                })
        elif decision == "retain-current":
            retained += 1
        elif decision in {"reject", "needs-evidence"}:
            rejected += 1
    return {
        "mode": "approved-offline-plan",
        "database_write": False,
        "manifest_id": manifest.get("manifest_id"),
        "review_file": str(review_path),
        "scope": {
            "npc_position_fields": ["NPCInfo.Region", "MapRegion.Map", "MapRegion.PointRegion"],
            "respawn_position_fields": ["RespawnInfo.Region", "MapRegion.Map", "MapRegion.PointRegion", "MapRegion.Size", "RespawnInfo.Count", "RespawnInfo.Delay"],
            "monster_info_business_fields": "untouched",
        },
        "npc_moves": npc_moves,
        "respawn_updates": respawn_updates,
        "decision_summary": {
            "approved_npc": len(npc_moves),
            "approved_respawn": len(respawn_updates),
            "retained": retained,
            "rejected_or_evidence": rejected,
        },
        "prerequisites": [
            "run independent plan/map walkability verification",
            "stop ServerCore and verify TCP port 7000 is not listening",
            "backup server and client System.db",
            "apply NPC and RespawnInfo changes separately",
            "run round-trip verification before client acceptance",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--review", type=Path, required=True)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--plan-out", type=Path, help="write approved plan only when validation passes")
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    result, code, rows = validate(manifest, args.review)
    if args.plan_out:
        if code:
            print("approved plan not written: manual review is blocked", file=sys.stderr)
        else:
            plan = approved_plan(manifest, rows, args.review)
            args.plan_out.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            result["approved_plan"] = str(args.plan_out)
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.out:
        args.out.write_text(output, encoding="utf-8")
    print(output, end="")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
