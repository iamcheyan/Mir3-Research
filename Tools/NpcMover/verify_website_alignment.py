#!/usr/bin/env python3
"""Independent checks for the mir3-website alignment manifest.

This verifier deliberately does not import website_alignment.py or the NPC/monster
production converter.  It re-reads source JSON, parses lookup text independently,
and checks resource headers, image files, status invariants, and the server gate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import socket
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
WEBSITE = Path("/home/tetsuya/development/mir3-website")
ZIRCON = Path("/home/tetsuya/development/zircon")
WORKSPACE = ROOT / "Tools/dbeditor/workspace"
EXTERNAL = ROOT / "docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json"


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def image_path(root: Path, value: str) -> Path:
    while value.startswith("../"):
        value = value[3:]
    return root / value


def image_fingerprint(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    with Image.open(path) as im:
        return {"sha256": hashlib.sha256(raw).hexdigest(), "bytes": len(raw),
                "width": im.width, "height": im.height, "format": im.format}


def check_image_records(root: Path, records: list[dict[str, Any]], errors: list[str]) -> dict[str, Any]:
    hashes: dict[str, list[str]] = defaultdict(list)
    missing = 0
    invalid = 0
    for row in records:
        path = image_path(root, row["image"])
        try:
            meta = image_fingerprint(path)
            hashes[meta["sha256"]].append(row["id"])
            if meta["width"] <= 0 or meta["height"] <= 0:
                invalid += 1
                errors.append(f"invalid image dimensions: {row['id']}")
        except Exception as exc:
            missing += 1
            errors.append(f"image decode missing/error {row['id']}: {path}: {exc}")
    return {"records": len(records), "missing_or_decode_error": missing, "invalid_dimensions": invalid,
            "duplicate_groups": {k: v for k, v in hashes.items() if len(v) > 1}}


def parse_lookup(path: Path) -> dict[str, tuple[int, int]]:
    text = path.read_text(encoding="utf-8")
    return {name: (int(lib), int(shape)) for name, lib, shape in re.findall(
        r"MonsterImage\.([A-Za-z0-9_]+), \(LibraryFile\.Mon_(\d+), (\d+)\)", text
    )}


def resource_header_check(data_root: Path, lookup: dict[str, tuple[int, int]], confirmed: list[dict[str, Any]], errors: list[str]) -> dict[str, Any]:
    from Tools.common.zlsdk import ZlLibrary
    library_cache: dict[int, Any] = {}
    checked = 0
    missing = 0
    for row in confirmed:
        for candidate in row.get("zircon_candidates", []):
            image = candidate.get("image")
            if image not in lookup:
                missing += 1
                errors.append(f"confirmed MonsterInfo image absent from lookup: {image}")
                continue
            lib, shape = lookup[image]
            try:
                library_cache.setdefault(lib, ZlLibrary(str(data_root / f"Mon-{lib}.Zl")))
                library = library_cache[lib]
                if not any(library.header(shape * 1000 + draw) for draw in range(100)):
                    missing += 1
                    errors.append(f"no body frame in probe: {image} shape={shape}")
                checked += 1
            except Exception as exc:
                missing += 1
                errors.append(f"Zl probe error {image}: {exc}")
    return {"confirmed_candidates_checked": checked, "resource_failures": missing}


def check_key_samples(manifest: dict[str, Any], external: dict[str, Any], errors: list[str]) -> dict[str, Any]:
    names = {row["website_monster_name"]: row for row in manifest["monster_identity"]}
    required_monsters = ["半兽人", "祖玛教主", "祖玛卫士", "白野猪", "赤月恶魔"]
    monster_result = {name: names.get(name, {}).get("status") for name in required_monsters}
    for name, status in monster_result.items():
        if status is None:
            errors.append(f"missing key monster sample: {name}")
    skills = {row["website_skill_name"]: row for row in manifest["skills"]}
    required_skills = ["基本剑术", "火球术", "凝血离魂"]
    skill_result = {name: skills.get(name, {}).get("status") for name in required_skills}
    for name, status in skill_result.items():
        if status is None:
            errors.append(f"missing key skill sample: {name}")
    npc_rows = external.get("npcs", [])
    npc_result = []
    for row in npc_rows[:3]:
        required = ("current_npc_index", "old_map", "old_xy", "walkable", "apply_status")
        missing = [key for key in required if key not in row]
        if "current_name" not in row and "current_npc_name" not in row:
            missing.append("current_name/current_npc_name")
        if missing:
            errors.append(f"NPC sample {row.get('current_npc_index')} missing fields: {missing}")
        npc_result.append({
            "index": row.get("current_npc_index"),
            "name": row.get("current_name", row.get("current_npc_name")),
            "missing": missing,
        })
    return {"monsters": monster_result, "skills": skill_result, "npcs": npc_result}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--website-root", type=Path, default=WEBSITE)
    parser.add_argument("--zircon-root", type=Path, default=ZIRCON)
    parser.add_argument("--workspace", type=Path, default=WORKSPACE)
    parser.add_argument("--external", type=Path, default=EXTERNAL)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    manifest = load(args.manifest)
    website_monsters = load(args.website_root / "data/monsters.json")
    website_skills = load(args.website_root / "data/skills.json")
    website_maps = load(args.website_root / "data/maps.json")
    external = load(args.external)
    errors: list[str] = []

    monster_ids = [row["id"] for row in website_monsters]
    skill_ids = [row["id"] for row in website_skills]
    if len(monster_ids) != len(set(monster_ids)):
        errors.append("duplicate website monster ids")
    if len(skill_ids) != len(set(skill_ids)):
        errors.append("duplicate website skill ids")
    if manifest["website_counts"]["monsters"] != len(website_monsters):
        errors.append("manifest/source monster count mismatch")
    if manifest["website_counts"]["skills"] != len(website_skills):
        errors.append("manifest/source skill count mismatch")
    if manifest["website_counts"]["map_areas"] != sum(len(g.get("areas", [])) for g in website_maps):
        errors.append("manifest/source map area count mismatch")

    monster_image_audit = check_image_records(args.website_root, website_monsters, errors)
    skill_image_audit = check_image_records(args.website_root, website_skills, errors)
    lookup = parse_lookup(args.zircon_root / "GodotClient/Formats/MonsterLookup.cs")
    current_monsters = {int(row["Index"]): row for row in load(args.workspace / "MonsterInfo.json")["rows"]}
    current_magic = {int(row["Index"]): row for row in load(args.workspace / "MagicInfo.json")["rows"]}
    statuses = Counter(row.get("status") for row in manifest["monster_identity"])
    allowed = {"confirmed", "investigate", "pending", "unmatched"}
    for row in manifest["monster_identity"]:
        if row.get("status") not in allowed:
            errors.append(f"invalid monster status {row.get('status')} for {row.get('website_monster_name')}")
        if row.get("status") == "confirmed":
            index = row.get("zircon_index")
            if index not in current_monsters:
                errors.append(f"confirmed monster index absent: {row.get('website_monster_name')} -> {index}")
            if not row.get("match_evidence"):
                errors.append(f"confirmed monster has no evidence: {row.get('website_monster_name')}")
        if row.get("status") in {"investigate", "pending", "unmatched"} and not row.get("skip_reason"):
            errors.append(f"unclosed monster row has no skip_reason: {row.get('website_monster_name')}")
    skill_statuses = Counter(row.get("status") for row in manifest["skills"])
    for row in manifest["skills"]:
        if row.get("status") == "confirmed":
            index = row.get("zircon_index")
            if index not in current_magic:
                errors.append(f"confirmed skill index absent: {row.get('website_skill_name')} -> {index}")
            if row.get("icon_evidence", {}).get("status") != "present":
                errors.append(f"confirmed skill icon absent: {row.get('website_skill_name')}")
        if row.get("status") in {"investigate", "pending", "unmatched"} and not row.get("skip_reason"):
            errors.append(f"unclosed skill row has no skip_reason: {row.get('website_skill_name')}")

    resource_audit = resource_header_check(args.zircon_root / "Debug/Client/Data", lookup,
                                           [row for row in manifest["monster_identity"] if row.get("status") == "confirmed"], errors)
    samples = check_key_samples(manifest, external, errors)
    try:
        with socket.create_connection(("127.0.0.1", 7000), timeout=1):
            server_listening = True
    except OSError:
        server_listening = False
    if not server_listening:
        errors.append("port 7000 is not listening; baseline expected active service gate")

    result = {
        "verifier": "independent-website-alignment-v1",
        "database_write": False,
        "server_gate": {"port": 7000, "listening": server_listening, "write_allowed": not server_listening},
        "source_counts": {"monsters": len(website_monsters), "skills": len(website_skills),
                           "map_groups": len(website_maps), "map_areas": sum(len(g.get("areas", [])) for g in website_maps)},
        "manifest_counts": {"monsters": len(manifest["monster_identity"]), "skills": len(manifest["skills"]),
                             "map_families": len(manifest["map_families"]), "npc": len(external.get("npcs", [])),
                             "respawns": len(external.get("monster_respawns", []))},
        "image_audit": {"monsters": monster_image_audit, "skills": skill_image_audit},
        "lookup_count": len(lookup), "monster_statuses": dict(statuses), "skill_statuses": dict(skill_statuses),
        "resource_audit": resource_audit, "key_samples": samples, "errors": errors,
        "result": "PASS" if not errors else "FAIL",
    }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
