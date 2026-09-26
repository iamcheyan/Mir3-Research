#!/usr/bin/env python3
"""Independent checks for website_extension_alignment.py outputs."""
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def load(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    manifest = load(args.manifest)
    errors: list[str] = []
    items = manifest.get("items", [])
    skills = manifest.get("skills", [])
    missions = manifest.get("missions", [])
    if len(items) != 371:
        errors.append(f"items count {len(items)} != 371")
    if len(skills) != 61:
        errors.append(f"skills count {len(skills)} != 61")
    if len(missions) != 24:
        errors.append(f"missions count {len(missions)} != 24")
    for kind, records, key in [("item", items, "website_name"), ("skill", skills, "website_name"), ("mission", missions, "website_id")]:
        ids = [r.get(key) for r in records]
        if kind != "item" and len(ids) != len(set(ids)):
            errors.append(f"duplicate {kind} identities")
        for row in records:
            if kind == "item" and row.get("status") == "pending-legacy-name" and not row.get("skip_reason"):
                errors.append(f"{kind} pending without skip reason: {row.get(key)}")
            if kind == "skill" and row.get("status") == "investigate" and not row.get("skip_reason"):
                errors.append(f"{kind} investigate without skip reason: {row.get(key)}")
    item_images = sum(bool(r.get("website_image", {}).get("present")) for r in items)
    skill_images = sum(bool(r.get("website_image", {}).get("present")) for r in skills)
    if item_images != 361:
        errors.append(f"item image-present count {item_images} != 361")
    if skill_images != 61:
        errors.append(f"skill image-present count {skill_images} != 61")
    if manifest.get("database_write") is not False:
        errors.append("database_write must be false")
    result = {
        "verifier": "independent-website-extension-v1",
        "manifest": str(args.manifest),
        "counts": {"items": len(items), "skills": len(skills), "missions": len(missions)},
        "status_counts": {"items": dict(Counter(r.get("status") for r in items)), "skills": dict(Counter(r.get("status") for r in skills))},
        "errors": errors,
        "result": "PASS" if not errors else "FAIL",
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
