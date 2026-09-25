#!/usr/bin/env python3
"""Validate human review decisions before any database write."""
from __future__ import annotations

import argparse
import csv
import json
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


def validate(manifest: dict, review_path: Path) -> tuple[dict, int]:
    expected = expected_rows(manifest)
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
                for field in ("approved_x", "approved_y", "approved_count", "approved_range", "approved_interval"):
                    if approved[field]:
                        integer(approved[field], field, key, errors)
            else:
                if any(approved.values()):
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
        "errors": errors,
        "status": "pass" if not errors else "blocked",
    }
    return result, 0 if not errors else 2


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--review", type=Path, required=True)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    result, code = validate(manifest, args.review)
    output = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.out:
        args.out.write_text(output, encoding="utf-8")
    print(output, end="")
    return code


if __name__ == "__main__":
    raise SystemExit(main())
