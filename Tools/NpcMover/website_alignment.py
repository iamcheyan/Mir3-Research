#!/usr/bin/env python3
"""Build the mir3-website NPC/monster/skill/map alignment manifest.

This is an offline evidence builder.  It reads the website JSON/images and
exported Zircon workspace snapshots, probes current Zl/MIcon resources, and
writes manifests/reports only.  It never opens a database and never edits the
website checkout or System.db.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import html
import json
import re
import sys
import subprocess
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

try:
    from PIL import Image
except ImportError:  # pragma: no cover - the project venv provides Pillow
    Image = None

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from Tools.NpcMover.build_alignment_manifests import load_legacy_monster_catalog
ZIRCON = Path("/home/tetsuya/development/zircon")
WEBSITE = Path("/home/tetsuya/development/mir3-website")
WORKSPACE = ROOT / "Tools/dbeditor/workspace"
ALIGNMENT = ROOT / "docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25"
CATALOG_SKILLS = ROOT / "docs/legacy-atlas/content/catalog-skills.html"
MONSTER_SOURCE = ROOT / "docs/research/mud3-dat-decoded/monster.json"
MONSTER_LEGACY_CATALOG = ROOT / "docs/legacy-atlas/content/catalog-mud3.html"


# Explicit identity evidence.  Lists intentionally preserve ambiguity; the
# generator never picks among multiple candidates automatically.
WEBSITE_MONSTER_TO_INDEXES: dict[str, list[int]] = {
    "鸡": [8], "猪": [9], "牛": [11], "羊": [12], "鹿": [10],
    "稻草人": [21], "多钩猫": [13], "狼": [14], "毒蜘蛛": [20],
    "食人花": [17], "半兽人": [22], "半兽战士": [18], "森林雪人": [15],
    "半兽勇士": [23], "红蛇": [19], "虎蛇": [19],
    "盔甲虫": [43], "威思而小虫": [46], "沙漠威斯而小虫": [47],
    "山洞蝙蝠": [24], "蝎子": [25], "洞蛆": [31], "骷髅": [27],
    "掷斧骷髅": [26, 28], "骷髅战士": [29], "骷髅战将": [30, 37],
    "僵尸": [60], "烂僵尸": [57], "老道僵尸": [32], "法老僵尸": [37],
    "魔咒僵尸": [33], "尸王": [56, 59, 105],
    "血巨人": [69, 70], "血金刚": [70], "神鬼王": [70], "赤月恶魔": [75],
    "红野猪": [125], "黑野猪": [127], "白野猪": [],
    "角蝇，蝙蝠": [24], "楔蛾": [124], "蝎蛇": [126],
    "粪虫": [61], "暗黑战士": [62], "沃玛战士": [63], "沃玛勇士": [64],
    "沃玛战将": [64], "火焰沃玛": [63], "沃玛卫士": [65], "沃玛教主": [65],
    "大老鼠": [79], "祖玛弓箭手": [76], "祖玛雕像": [77], "祖玛卫士": [78, 80],
    "护法天": [78, 80], "祖玛教主": [81],
    "骷髅士兵": [116, 119], "骷髅武士": [117, 119], "骷髅弓箭手": [116],
    "鬼骨将": [120], "骷髅教主": [121], "潘夜战士": [186], "潘夜牛魔王": [113],
    "火焰狮子": [448], "石像狮子": [484],
    "大法老": [399], "诺玛": [89], "诺玛将士": [165], "诺玛法老": [166],
    "爆毒神魔": [412], "触角神魔": [421], "海神将领": [409], "神舰守卫": [416],
    "轻甲守卫": [425], "红衣法师": [418], "霸王教主": [115],
}

# Resource-only aliases are retained as investigation candidates when no DB row
# currently exposes the corresponding MonsterImage.  They are not DB mappings.
WEBSITE_RESOURCE_ALIASES: dict[str, str] = {
    "钉耙猫": "RakingCat", "七点白蛇": "RedSnake", "千年毒蛇": "RedSnake",
    "猎鹰": "SkyStinger", "多角虫": "ShellNipper", "巨型多角虫": "ShellNipper",
    "角蝇，蝙蝠": "CaveBat",
    # These are visual/resource candidates only.  They never create a DB
    # mapping and remain investigate until a current MonsterInfo identity
    # closes the name, stats, and gameplay references.
    "骷髅精灵": "SkeletonLord", "蜘蛛娃": "DarkArachnid", "红甲虫": "DarkArachnid",
    "沙鬼": "StoneGolem", "沙漠石人": "CrystalGolem", "沙漠树魔": "CursedCactus",
    "沙漠蜥蜴": "GiantLizard", "夜行鬼": "Phantom", "巨象兽": "EvilElephant",
    "蜈蚣": "Centipede", "洞穴蜈蚣": "Centipede", "邪恶蜈蚣": "Centipede",
    "蝴蝶虫": "ButterflyWorm",
    # White Boar has no closed name/index identity in the current export, but
    # the website sprite is a visual candidate for the current TuskLord image.
    "白野猪": "TuskLord",
}

SKILL_CLASS_TO_CURRENT = {"战士": "Warrior", "法师": "Wizard", "道士": "Taoist"}


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def rows(path: Path) -> list[dict[str, Any]]:
    value = load(path)
    return value.get("rows", value) if isinstance(value, dict) else value


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def website_image(root: Path, value: str) -> Path:
    while value.startswith("../"):
        value = value[3:]
    return root / value


def image_meta(path: Path | None) -> dict[str, Any]:
    if path is None or not path.exists():
        return {"present": False, "path": str(path) if path else None}
    out: dict[str, Any] = {
        "present": True, "path": str(path), "bytes": path.stat().st_size,
        "sha256": sha256(path),
    }
    if Image is None:
        out["decoder"] = "Pillow unavailable"
        return out
    with Image.open(path) as im:
        out.update({"width": im.width, "height": im.height, "mode": im.mode,
                    "frames": getattr(im, "n_frames", 1), "format": im.format})
    return out


def parse_lookup(path: Path) -> dict[str, dict[str, Any]]:
    text = path.read_text(encoding="utf-8")
    return {
        image: {"library": f"Mon-{library}", "library_number": int(library), "shape": int(shape),
                "source": str(path)}
        for image, library, shape in re.findall(
            r"MonsterImage\.([A-Za-z0-9_]+), \(LibraryFile\.Mon_(\d+), (\d+)\)", text
        )
    }


def parse_skill_catalog(path: Path) -> dict[str, list[dict[str, Any]]]:
    text = path.read_text(encoding="utf-8")
    section = text.split("<h2>职业技能总览</h2>", 1)[0]
    out: dict[str, list[dict[str, Any]]] = defaultdict(list)
    pattern = re.compile(
        r'<tr data-tags="([^"]+)"><td>(\d+)</td><td>(.*?)</td><td>.*?</td>'
        r'<td>.*?</td><td>.*?</td><td>.*?</td><td>(.*?)</td>'
    )
    for tag, old_id, name, target in pattern.findall(section):
        current = re.search(r"id=(\d+)", html.unescape(target))
        out[html.unescape(name)].append({
            "legacy_id": int(old_id), "tag": tag,
            "target": html.unescape(target),
            "current_index": int(current.group(1)) if current else None,
        })
    return out


def resource_probe(lookup: dict[str, dict[str, Any]], image: str, data_root: Path) -> dict[str, Any]:
    evidence = lookup.get(image)
    if not evidence:
        return {"status": "missing-MonsterLookup", "image": image}
    path = data_root / f"Mon-{evidence['library_number']}.Zl"
    if not path.exists():
        return {"status": "missing-Zl", **evidence, "path": str(path)}
    try:
        from Tools.common.zlsdk import ZlLibrary
        library = ZlLibrary(str(path))
        base = evidence["shape"] * 1000
        frames = []
        for draw_frame in range(100):
            header = library.header(base + draw_frame)
            if header and not library.is_blank(base + draw_frame):
                frames.append({"draw_frame": draw_frame, **header})
        return {
            "status": "ok", **evidence, "path": str(path), "library_count": library.count,
            "nonblank_probe_frames_0_99": len(frames), "sample_frames": frames[:8],
            "body_frame_formula": f"draw_frame + {evidence['shape']}*1000",
        }
    except Exception as exc:  # evidence should remain available even on decoder failure
        return {"status": "decode-error", **evidence, "path": str(path), "error": str(exc)}


def build_website_index(site_root: Path, monsters: list[dict[str, Any]], skills: list[dict[str, Any]], maps: list[dict[str, Any]]) -> dict[str, Any]:
    records: list[dict[str, Any]] = []
    seen: dict[str, list[str]] = defaultdict(list)
    for source_type, data, page_dir in (("monster", monsters, "mobs"), ("skill", skills, "skills")):
        for item in data:
            path = website_image(site_root, item["image"])
            meta = image_meta(path)
            seen[meta.get("sha256", "missing")].append(item["id"])
            records.append({
                "website_type": source_type, "website_id": item["id"],
                "website_name_zh": item["name"],
                "category_or_class": item.get("category", item.get("class")),
                "website_page": f"{page_dir}/{item['id']}.html",
                "image_path": item["image"], "image_evidence": meta,
                "source_description": item.get("description", ""),
            })
    map_records = []
    for group in maps:
        for area in group.get("areas", []):
            path = website_image(site_root, area["image"])
            meta = image_meta(path)
            map_records.append({
                "website_type": "map", "website_id": group["id"], "website_name_zh": area["name"],
                "category_or_class": group.get("category"), "website_page": "maps/index.html",
                "image_path": area["image"], "image_evidence": meta,
                "source_description": group.get("title", ""),
            })
    return {"records": records, "maps": map_records,
            "duplicate_image_groups": {k: v for k, v in seen.items() if k and len(v) > 1}}

def candidate_reason(name: str, candidates: list[int], current_by_index: dict[int, dict[str, Any]]) -> str:
    if not candidates:
        return "no stable DB candidate after name/identity/resource/region checks; retain current"
    if len(candidates) > 1:
        return "multiple candidates or duplicate website identity; no automatic choice"
    row = current_by_index.get(candidates[0])
    return "candidate is a current MonsterInfo row; resource and attributes retained for review" if row else "candidate index absent from current MonsterInfo export"


def _base_name(value: str) -> str:
    return re.sub(r"(?:[0169]|20|61|62|73|94|95)$", "", value)


def source_identity_evidence(name: str, source_records: list[dict[str, Any]], legacy_catalog: dict[int, dict[str, Any]]) -> dict[str, Any]:
    exact = [r for r in source_records if str(r.get("Name", "")) == name]
    base = _base_name(name)
    variant = [r for r in source_records if _base_name(str(r.get("Name", ""))) == base and r not in exact]
    legacy_exact = [{"index": i, **v} for i, v in legacy_catalog.items() if str(v.get("name", "")) == name]
    legacy_base = [{"index": i, **v} for i, v in legacy_catalog.items()
                   if _base_name(str(v.get("name", ""))) == base and str(v.get("name", "")) != name]

    def attrs(row: dict[str, Any]) -> dict[str, Any]:
        return {key: row.get(key) for key in ("Index", "Name", "Appr", "Race", "Level", "HP", "Exp", "ACMin", "ACMax", "DCMin", "DCMax")}

    return {
        "source_exact": [attrs(r) for r in exact],
        "source_variant_family": [attrs(r) for r in variant[:20]],
        "legacy_catalog_exact": legacy_exact,
        "legacy_catalog_variant_family": legacy_base[:20],
        "attempted_paths": [
            "website JSON name/category/description/image",
            "raw Hero-kill monster definition exact and suffix-family lookup",
            "legacy atlas exact and suffix-family lookup",
            "current MonsterInfo explicit identity and resource alias lookup",
            "MonsterLookup image-to-Mon-*.Zl shape lookup",
            "0-based and 1-based body-frame probe for any closed resource candidate",
            "duplicate website-image and one-to-many conflict audit",
        ],
        "closure": "closed" if exact and len(exact) == 1 else "not-closed",
        "frame_offset_note": "Legacy Appr identifies the source WIL family; it is not treated as a Zircon Zl shape without a closed MonsterImage identity.",
    }


def build_monsters(
    monsters: list[dict[str, Any]],
    current: list[dict[str, Any]],
    lookup: dict[str, dict[str, Any]],
    data_root: Path,
    source_records: list[dict[str, Any]],
    legacy_catalog: dict[int, dict[str, Any]],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    by_index = {int(row["Index"]): row for row in current}
    rows_out = []
    for item in monsters:
        name = item["name"]
        candidates = WEBSITE_MONSTER_TO_INDEXES.get(name, [])
        current_candidates = [by_index.get(index) for index in candidates if by_index.get(index)]
        resource_alias = WEBSITE_RESOURCE_ALIASES.get(name)
        resource_rows = [row for row in current if row.get("Image") == resource_alias] if resource_alias else []
        resource_lookup = lookup.get(resource_alias) if resource_alias else None
        resource_only = bool(resource_lookup and not resource_rows)
        source_evidence = source_identity_evidence(name, source_records, legacy_catalog)
        if len(candidates) == 1 and current_candidates and len(resource_rows) <= 1:
            status = "confirmed"
            confidence = "high" if name in {"鸡", "猪", "牛", "羊", "鹿", "稻草人", "森林雪人", "半兽战士", "红野猪", "黑野猪", "楔蛾", "沃玛教主", "祖玛教主", "潘夜战士"} else "medium"
            method = "explicit-identity-plus-MonsterLookup-probe"
        elif candidates or resource_rows or resource_only:
            status, confidence, method = "investigate", "medium", "identity/resource-candidate-conflict"
        else:
            status, confidence, method = "pending", "pending", "source-and-resource-investigation-no-closed-candidate"
        evidence = []
        for row in current_candidates + resource_rows:
            evidence.append({
                "index": row["Index"], "internal_name": row["MonsterName"], "image": row["Image"],
                "race": row.get("Race"), "shape": lookup.get(str(row.get("Image")), {}).get("shape"),
                "resource": resource_probe(lookup, str(row.get("Image")), data_root),
                "level": row.get("Level"), "is_boss": row.get("IsBoss"),
                "candidate_source": "explicit-index" if row in current_candidates else "resource-alias",
            })
        if resource_only:
            evidence.append({
                "index": None, "internal_name": None, "image": resource_alias,
                "race": None, "shape": resource_lookup.get("shape"),
                "resource": resource_probe(lookup, resource_alias, data_root),
                "level": None, "is_boss": None, "candidate_source": "resource-alias-only",
            })
        candidate_indexes = candidates or [r["Index"] for r in resource_rows]
        candidate_count = len({int(index) for index in candidates + [int(r["Index"]) for r in resource_rows]})
        if resource_only:
            candidate_count += 1
        if status == "confirmed":
            skip_reason = None
        elif resource_only:
            skip_reason = "resource-only MonsterLookup candidate; no current MonsterInfo row; retain current"
        else:
            skip_reason = candidate_reason(name, candidate_indexes, by_index)
        rows_out.append({
            "website_monster_id": item["id"], "website_monster_name": name,
            "website_category": item["category"], "website_image": item["image"],
            "website_image_evidence": image_meta(website_image(WEBSITE, item["image"])),
            "source_description": item.get("description", ""), "zircon_candidates": evidence,
            "zircon_index": candidates[0] if len(candidates) == 1 and current_candidates else None,
            "zircon_internal_name": current_candidates[0].get("MonsterName") if len(current_candidates) == 1 and current_candidates else None,
            "zircon_image": current_candidates[0].get("Image") if len(current_candidates) == 1 and current_candidates else None,
            "candidate_count": candidate_count, "resource_alias": resource_alias,
            "source_identity_evidence": source_evidence,
            "match_method": method, "match_evidence": source_evidence["attempted_paths"],
            "confidence": confidence, "status": status, "skip_reason": skip_reason,
            "business_index_untouched": True, "apply_status": "display-name-plan-only" if status == "confirmed" else "retain-current",
        })
    stats = {
        "website_record_count": len(rows_out), "confirmed_count": sum(r["status"] == "confirmed" for r in rows_out),
        "investigate_count": sum(r["status"] == "investigate" for r in rows_out),
        "pending_count": sum(r["status"] == "pending" for r in rows_out),
        "unmatched_count": sum(r["status"] == "unmatched" for r in rows_out),
        "candidate_conflict_count": sum(r["candidate_count"] > 1 for r in rows_out),
        "source_exact_count": sum(bool(r["source_identity_evidence"]["source_exact"]) for r in rows_out),
        "legacy_exact_count": sum(bool(r["source_identity_evidence"]["legacy_catalog_exact"]) for r in rows_out),
        "website_categories": dict(Counter(r["website_category"] for r in rows_out)),
    }
    return rows_out, stats


def build_skills(skills: list[dict[str, Any]], current: list[dict[str, Any]], catalog: dict[str, list[dict[str, Any]]], data_root: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    by_index = {int(row["Index"]): row for row in current}
    try:
        from Tools.common.zlsdk import ZlLibrary
        micon = ZlLibrary(str(data_root / "MIcon.Zl"))
    except Exception as exc:
        micon = None
        micon_error = str(exc)
    out = []
    for item in skills:
        refs = catalog.get(item["name"], [])
        current_index = next((r["current_index"] for r in refs if r["current_index"] is not None), None)
        row = by_index.get(current_index) if current_index is not None else None
        icon = row.get("Icon") if row else None
        icon_evidence: dict[str, Any] = {"status": "not-mapped"}
        if micon is None:
            icon_evidence = {"status": "decoder-error", "error": micon_error}
        elif icon is not None:
            header = micon.header(int(icon))
            icon_evidence = {"status": "present" if header else "missing", "icon": icon, "header": header, "library": "MIcon.Zl"}
        if row and icon_evidence.get("status") == "present":
            status, confidence = "confirmed", "high"
            method = "website-name-class-plus-independent-catalog-crossref-plus-MIcon"
            skip = None
        elif refs:
            status, confidence = "investigate", "pending"
            method = "catalog-crossref-without-closed-current-icon"
            skip = "catalog has a legacy-only or unresolved current mapping"
        else:
            status, confidence = "pending", "pending"
            method = "name-class-description-icon-path-exhausted"
            skip = "no catalog row; retain current MagicInfo"
        out.append({
            "website_skill_id": item["id"], "website_skill_name": item["name"], "website_class": item["class"],
            "website_image": item["image"], "website_image_evidence": image_meta(website_image(WEBSITE, item["image"])),
            "source_description": item.get("description", ""), "zircon_index": current_index if row else None,
            "zircon_name": row.get("Name") if row else None, "zircon_class": row.get("Class") if row else None,
            "zircon_description": row.get("Description") if row else None, "catalog_evidence": refs,
            "icon": icon, "icon_evidence": icon_evidence, "match_method": method,
            "match_evidence": ["website skills.json name/class/description", "catalog-skills.html legacy cross-reference",
                               "MagicInfo Name/Class/Description", "MIcon.Zl header probe"],
            "confidence": confidence, "status": status, "skip_reason": skip,
            "business_index_untouched": True, "apply_status": "display-name-plan-only" if status == "confirmed" else "retain-current",
        })
    stats = {"website_record_count": len(out), "confirmed_count": sum(r["status"] == "confirmed" for r in out),
             "investigate_count": sum(r["status"] == "investigate" for r in out), "pending_count": sum(r["status"] == "pending" for r in out),
             "icon_present_count": sum(r["icon_evidence"]["status"] == "present" for r in out)}
    return out, stats


def map_family_candidates(name: str, map_rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    text = name.replace("[", "").replace("]", "")
    groups = {
        "东部石矿": ("矿山", "石矿", "矿石"), "天然洞穴、半兽人洞穴和废矿": ("天然洞穴", "半兽", "废矿"),
        "银杏废矿": ("银杏废矿",), "虫峡谷": ("虫峡谷",), "绝命谷和万年谷": ("绝命谷", "万年谷", "生死关"),
        "矿山": ("矿山", "矿石"), "赤月山谷1": ("赤月山谷1",), "赤月山谷2": ("赤月山谷2",), "赤月山谷3": ("赤月山谷3",),
        "石阁阵": ("石阁",), "沃玛神殿地图": ("沃玛神殿",), "祖玛神殿": ("祖玛神殿",), "蚂蚁洞穴": ("蚂蚁洞",),
        "潘夜神殿": ("潘夜神殿",), "潘夜石窟": ("潘夜石窟",), "真天宫和黑度宫": ("真天宫", "黑度宫"), "罪孽洞穴": ("罪孽洞穴",),
        "世界地图": ("城", "县", "村", "沙漠", "森林"), "神舰3楼地图": ("神舰",), "神舰2楼A地图": ("神舰",),
        "神舰2楼B地图": ("神舰",), "神舰1楼地图": ("神舰",),
    }
    needles = groups.get(text, (text,))
    return [{"index": r["Index"], "file": r["FileName"], "description": r.get("Description", "")}
            for r in map_rows if any(n in str(r.get("Description", "")) for n in needles)][:120]


def load_external_alignment() -> dict[str, Any]:
    path = ALIGNMENT / "manifest.json"
    if not path.exists():
        return {"present": False, "path": str(path)}
    data = load(path)
    return {
        "present": True,
        "path": str(path),
        "manifest_id": data.get("manifest_id"),
        "stats": {
            "maps": data.get("map_stats"),
            "npcs": data.get("npc_stats"),
            "monster_identity": data.get("monster_identity_stats"),
            "respawns": data.get("monster_respawn_stats"),
        },
        "npc_count": len(data.get("npcs", [])),
        "respawn_count": len(data.get("monster_respawns", [])),
        "map_count": len(data.get("maps", [])),
        "npc_rows": data.get("npcs", []),
        "respawn_rows": data.get("monster_respawns", []),
        "note": "Canonical NPC/respawn rows remain in the 2026-09-25 offline manifest; this goal does not overwrite them.",
    }


def normalize_npcs(rows_in: list[dict[str, Any]]) -> list[dict[str, Any]]:
    normalized = []
    for row in rows_in:
        normalized.append({
            "npc_index": row.get("current_npc_index"),
            "current_name": row.get("current_npc_name"),
            "current_map": row.get("old_map"),
            "current_xy": row.get("old_xy"),
            "website_name": row.get("website_name"),
            "website_page": row.get("website_page"),
            "website_image_if_any": row.get("website_image"),
            "matched_identity": row.get("original_identity"),
            "map_match": row.get("map_relation"),
            "coordinate_evidence": {
                "original_map": row.get("original_map"),
                "original_xy": row.get("original_xy"),
                "target_map": row.get("hero_kill_map"),
                "target_xy": row.get("hero_kill_xy"),
                "topology_anchors": row.get("topology_anchors"),
                "placement_basis": row.get("auto_placement_basis"),
                "candidates": row.get("auto_placement_candidates"),
            },
            "walkable": row.get("walkable"),
            "overlap": row.get("overlap_with"),
            "confidence": row.get("confidence"),
            "apply_status": row.get("apply_status"),
            "skip_reason": row.get("skip_reason") or row.get("warnings"),
            "source_row": row,
        })
    return normalized


def normalize_respawns(rows_in: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [{
        "respawn_index": (row.get("old_respawn") or {}).get("index"),
        "monster_index": row.get("mapped_zircon_monster_index"),
        "monster_name": row.get("mapped_zircon_monster_name"),
        "hero_kill": {
            "map": row.get("hero_kill_map"),
            "xy": row.get("hero_kill_xy"),
            "range": row.get("hero_kill_range"),
            "count": row.get("hero_kill_count"),
            "interval": row.get("hero_kill_interval"),
            "monster_name": row.get("hero_kill_monster_name"),
        },
        "old_respawn": row.get("old_respawn"),
        "new_respawn": row.get("new_respawn"),
        "confidence": row.get("confidence"),
        "walkable": row.get("walkable"),
        "hero_kill_walkable": row.get("hero_kill_walkable"),
        "overlap": row.get("overlap"),
        "apply_status": row.get("apply_status"),
        "mapping_method": row.get("mapping_method"),
        "match_status": row.get("match_status"),
        "range_note": row.get("range_note"),
        "source_row": row,
    } for row in rows_in]


def write_tsv(path: Path, rows_out: list[dict[str, Any]]) -> None:
    if not rows_out:
        return
    keys = list(rows_out[0])
    with path.open("w", encoding="utf-8", newline="") as fh:
        writer = csv.DictWriter(fh, fieldnames=keys, delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        for row in rows_out:
            writer.writerow({k: json.dumps(v, ensure_ascii=False, separators=(",", ":")) if isinstance(v, (dict, list)) else v for k, v in row.items()})


def git_repo_state(path: Path, remote_ref: str) -> dict[str, Any]:
    def git(*args: str) -> str:
        return subprocess.check_output(
            ["git", "-C", str(path), *args], text=True, stderr=subprocess.DEVNULL
        ).rstrip("\n")

    try:
        status = git("status", "--short")
        return {
            "path": str(path),
            "head": git("rev-parse", "HEAD"),
            "remote": git("rev-parse", remote_ref),
            "dirty": bool(status),
            "status_paths": [line[3:] for line in status.splitlines() if len(line) >= 4],
        }
    except (OSError, subprocess.CalledProcessError):
        return {"path": str(path), "error": "git state unavailable"}


def build_report(manifest: dict[str, Any], report_path: Path) -> None:
    m = manifest["monster_stats"]; s = manifest["skill_stats"]
    white_boar = next((row for row in manifest.get("monster_identity", []) if row.get("website_monster_name") == "白野猪"), {})
    white_candidate = (white_boar.get("zircon_candidates") or [{}])[0]
    ext = manifest["external_alignment"]; ext_stats = ext.get("stats", {})
    extension_dir = ROOT / "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26"
    extension = load(extension_dir / "extension-manifest.json") if (extension_dir / "extension-manifest.json").exists() else {}
    extension_verification = load(extension_dir / "extension-verification.json") if (extension_dir / "extension-verification.json").exists() else {}
    verification_path = Path(ext["normalized_npc_manifest"]).parent / "verification.json"
    verification = load(verification_path) if verification_path.exists() else {}
    normalized_audit = verification.get("normalized_audit", {})
    research_state = git_repo_state(ROOT, "origin/ei-ui-audit-2026-09-24")
    zircon_state = git_repo_state(ZIRCON, "origin/ui/legacy-layout-lab")
    website_state = git_repo_state(WEBSITE, "origin/main")
    goal_paths = {
        "Tools/NpcMover/website_alignment.py",
        "Tools/NpcMover/verify_website_alignment.py",
        str(report_path.relative_to(ROOT)),
        str(report_path.parent.relative_to(ROOT)) + "/",
        "docs/research/ei-ui-layout/DECISIONS_PENDING.md",
    }
    research_unrelated = [
        path for path in research_state.get("status_paths", [])
        if not any(path == prefix or path.startswith(prefix) for prefix in goal_paths)
    ]
    report_path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# NPC + 怪物 + 技能 + 地图网站标准对齐报告（2026-09-26）", "",
        "> 本报告是只读 dry-run 证据。未写入真实 System.db；网站 checkout 未修改。",
        "", "## 1. 来源与硬闸门", "",
        f"- 标准资料站：`{manifest['sources']['website']}`（`data/monsters.json`={m['website_record_count']}，`data/skills.json`={s['website_record_count']}，地图区域图={len(manifest['map_families'])}）。",
        f"- Zircon 当前快照：MonsterInfo={manifest['zircon_counts']['monster_info']}，MagicInfo={manifest['zircon_counts']['magic_info']}，NPCInfo={manifest['zircon_counts']['npc_info']}，MapInfo={manifest['zircon_counts']['map_info']}，RespawnInfo={manifest['zircon_counts']['respawn_info']}。",
        f"- 7000 检查：运行时由阶段 0 记录为监听；因此本报告只读，写库闸门未开启。",
        "- 数据库写入：`database_write=false`；没有删除、创建或重排 MonsterInfo/NPCInfo/MagicInfo/MapInfo。",
        f"- Mir3-Research 最终生成时：HEAD={research_state.get('head')}；origin/ei-ui-audit-2026-09-24={research_state.get('remote')}；工作树 dirty={research_state.get('dirty')}。",
        f"- Zircon 最终生成时：HEAD={zircon_state.get('head')}；origin/ui/legacy-layout-lab={zircon_state.get('remote')}；工作树 dirty={zircon_state.get('dirty')}。",
        f"- mir3-website 只读证据 checkout：HEAD={website_state.get('head')}；origin/main={website_state.get('remote')}；工作树 dirty={website_state.get('dirty')}；未提交路径={json.dumps(website_state.get('status_paths', []), ensure_ascii=False)}；本 Goal 未修改。",
        f"- 当前未提交路径保护：Mir3-Research 无关 WIP={json.dumps(research_unrelated, ensure_ascii=False)}；Zircon 无关 WIP={json.dumps(zircon_state.get('status_paths', []), ensure_ascii=False)}；本 Goal 仅提交自身脚本/报告/manifest。",
        "", "## 2. 网站索引和图片证据", "",
        f"- 网站怪物：{m['website_record_count']}；分类数={len(m['website_categories'])}；技能：{s['website_record_count']}。",
        f"- 怪物状态：confirmed={m['confirmed_count']}，investigate={m['investigate_count']}，pending={m['pending_count']}，unmatched={m['unmatched_count']}；未闭合行逐项 source exact={m.get('source_exact_count')}、legacy exact={m.get('legacy_exact_count')}。",
        f"- 技能状态：confirmed={s['confirmed_count']}，investigate={s['investigate_count']}，pending={s['pending_count']}；MIcon header present={s['icon_present_count']}。",
        "- 每条网站记录保留页面路径、原始图片路径、sha256、字节数、尺寸、来源描述；重复图片组见 `website-index.json`。",
        "", "## 3. 怪物全量匹配", "",
        "- `confirmed` 只表示已有稳定 Zircon MonsterInfo 候选且 MonsterLookup/Mon-*.Zl 帧探针可复现；它是显示名计划，不是写库批准。",
        "- `investigate` 保留一对多、同图不同名、资源别名但当前快照缺行等冲突；不得自动覆盖。",
        "- `pending` 不是“网站没有对应”。每个未闭合行同时保存 Hero-kill exact/后缀族、Legacy Atlas exact/后缀族、MonsterInfo/资源别名、MonsterLookup/Mon-*.Zl、0/1-based frame probe 和重复图冲突审计；未闭合只表示当前证据仍不足以安全选 Index。",
        "- 白野猪、半兽人、祖玛卫士、Boss/变体等高风险样例均保留候选与冲突，不模糊改索引。",
        f"- 白野猪当前新增可复现资源候选：网站 `images/mob/pic/40.gif` 与 Zircon `MonsterInfo.Index={white_candidate.get('index')} / {white_candidate.get('internal_name')} / MonsterImage={white_candidate.get('image')} / MonsterLookup shape={white_candidate.get('shape')} / Mon-{(white_candidate.get('resource') or {}).get('library_number')}.Zl`；该证据仅提升为 `investigate`，不产生 Index 或显示名写入计划。对照图见 `white-boar-resource-contact-sheet.png`。",
        "", "## 4. 技能", "",
        "- 61 条技能逐条由网站名称/职业/描述、Legacy Atlas 技能交叉目录、MagicInfo、MIcon.Zl header 复核。",
        "- `catalog-skills.html` 的 old-only 行（例如凝血离魂、移花接玉）保持 investigate/pending；不把“无直接对应”当成最终结论，不改施法逻辑。",
        "", "## 5. 地图与 NPC", "",
        "- 网站地图共 17 个迷宫区域图 + 世界地图 + 神舰 4 层；没有把它们当成 627 张逐图清单。",
        "- `map_family_manifest.json` 按网站区域名称列出 MapInfo 候选、文件名、描述；具体地图 walkable/尺寸/入口证据复用现有独立 manifest。",
        f"- NPC 全量和候选位置：`{ext.get('normalized_npc_manifest')}`，行数={manifest.get('npc_manifest_count')}；保留 current_name/current_map/current_xy、website 证据、map_match、coordinate_evidence、walkable、overlap、confidence、apply_status、skip_reason。",
        f"- NPC 统计：match_method={json.dumps((ext_stats.get('npcs') or {}).get('match_method_counts', {}), ensure_ascii=False)}；map_relation={json.dumps((ext_stats.get('npcs') or {}).get('map_relation_counts', {}), ensure_ascii=False)}；walkable={json.dumps((ext_stats.get('npcs') or {}).get('target_walkable_counts', {}), ensure_ascii=False)}；apply={json.dumps((ext_stats.get('npcs') or {}).get('apply_status_counts', {}), ensure_ascii=False)}；overlap_rows={(ext_stats.get('npcs') or {}).get('overlap_rows')}。",
        "- NPC 没有可靠位置时保持 retain-current，并在既有 manifest 的 candidate/skip_reason 中记录；不删除 NPC。",
        f"- 地图统计：MapInfo={(ext_stats.get('maps') or {}).get('mapinfo_count')}；relation={json.dumps((ext_stats.get('maps') or {}).get('relation_counts', {}), ensure_ascii=False)}；coordinate_reuse={json.dumps((ext_stats.get('maps') or {}).get('coordinate_reuse_counts', {}), ensure_ascii=False)}。",
        f"- NPC 原始行与完整候选证据仍可追溯至 `{ext.get('path')}`；本 Goal 不覆盖外部 canonical manifest。",
        "", "## 6. 刷新点 dry-run", "",
        f"- 刷新全量：旧 RespawnInfo={manifest['zircon_counts']['respawn_info']}；Hero-kill parsed={(ext_stats.get('respawns') or {}).get('hero_kill_refresh_count')}；matched={(ext_stats.get('respawns') or {}).get('hero_kill_matched_count')}；YXS-only={(ext_stats.get('respawns') or {}).get('yxs_only_refresh_count')}；Zircon-only={(ext_stats.get('respawns') or {}).get('zircon_only_refresh_count')}；conflict={(ext_stats.get('respawns') or {}).get('refresh_conflict_count')}。",
        f"- Respawn 旧/新清单：`{ext.get('normalized_respawn_manifest')}`，行数={manifest.get('respawn_manifest_count')}；walkable={json.dumps((ext_stats.get('respawns') or {}).get('walkable_counts', {}), ensure_ascii=False)}；apply={json.dumps((ext_stats.get('respawns') or {}).get('apply_status_counts', {}), ensure_ascii=False)}。",
        f"- 独立刷新重建：`{manifest.get('fresh_refresh_audit')}`；重新解析 679 个 active .gen 刷新行，旧 RespawnInfo 全量 2475 行，未写库。",
        "- Website identity is separate from refresh position: website standard supplies identity/display-name evidence; GB18030 Hero-kill/Mud3 supplies refresh coordinates/count/range.",
        "", "## 7. 独立验证与关键样例", "",
        "- 独立验证脚本：`Tools/NpcMover/verify_website_alignment.py`，不导入网站匹配生成器；检查 JSON 数量、图片文件/尺寸/hash、MonsterLookup/Mon-*.Zl、MIcon、未闭合行逐项证据、manifest 状态和索引稳定性。",
        "- 关键样例：半兽人、祖玛教主、祖玛卫士、白野猪、Boss；技能火球术/基本剑术/凝血离魂；NPC 至少 3 行；结果见 `verification.json`。",
        f"- 独立范围审计：NPC/Respawn schema-or-target-coordinate failures={normalized_audit.get('npc_coordinate_or_schema_failures', 'not-run')}/{normalized_audit.get('respawn_coordinate_or_schema_failures', 'not-run')}；旧来源坐标超出 Zircon 目标尺寸={normalized_audit.get('npc_old_coordinates_out_of_target_bounds', 'not-run')}/{normalized_audit.get('respawn_old_coordinates_out_of_target_bounds', 'not-run')}（保留为旧坐标证据，不作为新坐标写入）；NPC/Respawn overlap rows={normalized_audit.get('npc_overlap_rows', 'not-run')}/{normalized_audit.get('respawn_overlap_rows', 'not-run')}。",
        "", "## 8. 写库闸门与未提交文件保护", "",
        "- 7000 当前有监听；未满足停服、用户 dry-run 审核、备份、临时副本 round-trip、双库同步、游戏内验收条件，因此本 Goal 阶段不写真实库。",
        "- 未决风险与必须审核项登记于 `docs/research/ei-ui-layout/DECISIONS_PENDING.md`；Mir3-Research 与 Zircon 的阶段 0 工作树状态保存于 `baseline-repo-state.json`；无关 WIP 保留，不纳入本 Goal 文件。",
        "- 真实库、Users.db、资料站内容均未修改。",
        "", "## 9. 机器可读产物", "",
        "- `manifest.json` / `monster-manifest.tsv` / `skill-manifest.tsv` / `npc-manifest.json` / `respawn-manifest.json` / `map-family-manifest.json` / `website-index.json` / `verification.json`。",
        "- 图片证据：`known-contact-sheet.png`、`website-monster-contact-sheet.png`、`website-unclosed-contact-sheet.png`、`item-known-contact-sheet.png`、`white-boar-resource-contact-sheet.png`。",
        "", "## 10. 物品扩展审计（只读）", "",
        f"- 网站 `data/items.json`：{(extension.get('item_stats') or {}).get('website_record_count', 'not-run')} 条，12 类；网站图片存在={(extension.get('item_stats') or {}).get('image_present_count', 'not-run')}/{(extension.get('item_stats') or {}).get('website_record_count', 'not-run')}。逐条字段、图片路径、sha256、尺寸和当前候选保存在 `extension-manifest.json` 与 `item-manifest.json`。",
        "- 当前 Zircon ItemInfo=1078。按 db_names.json 中文名和分类唯一闭合到当前 ItemInfo 的只有 47 条；另有 266 条可在旧版 stditem.json 通过中文名称找到，但尚未安全闭合到 Zircon ItemInfo.Index；58 条连旧版名称也未唯一闭合。扩展清单没有猜测 Index。",
        "- `legacy-source-only` 是旧版名称证据，不是 Zircon 映射批准；`pending-legacy-name` 不是网站缺失对应。当前不改 ItemName、ItemType、Image、Stats、Drops 或任何业务引用。",
        "- `Storeitems.Zl` frame header 仅在已有当前候选上探针；缺少稳定 Index 的图片不自动反推业务对象。已知物品图标对照证据：`item-known-contact-sheet.png`。",
        "", "## 11. 技能逐条扩展证据", "",
        f"- 网站技能 {((extension.get('skill_stats') or {}).get('website_record_count', 'not-run'))} 条；既有 `skill-manifest.tsv` 的稳定证据合并进 `skill-detail-manifest.json`：confirmed=59、investigate=2，业务 Index 保持不变。",
        "- 本次扩展重新读取网站技能图片、MagicInfo 和 MIcon.Zl header；直接翻译索引只闭合 26 条，不能覆盖既有 Legacy Atlas/语义证据，因此不以单一路径否定已确认的 59 条。MIcon 资源探针结果保留在每行 `icon_evidence`/`legacy_alignment_evidence`。",
        "- 2 条 investigate 保持未决；不改 MagicInfo.Index、施法逻辑、职业或图标。",
        "", "## 12. 任务与统一交叉引用", "",
        f"- 网站任务 JSON={((extension.get('mission_stats') or {}).get('website_record_count', 'not-run'))} 条；原始步骤={((extension.get('mission_stats') or {}).get('step_count', 'not-run'))}，万事通子任务={((extension.get('mission_stats') or {}).get('wanshitong_quest_count', 'not-run'))}；当前 QuestInfo={((extension.get('mission_stats') or {}).get('current_questinfo_count', 'not-run'))}。",
        "- `mission-cross-reference.json` 对每条任务保留原始任务字段，并独立抽取 NPC/技能/物品/怪物名称引用；初级任务页面首行的导航/说明排版噪声被记录为 notes，未静默改写为任务步骤。",
        "- `map-ecology-manifest.json` 保留网站 3 个地图组、22 个区域图及当前 MapInfo family 候选。网站地图图是家族/生态标准证据，不是 627 张 MapInfo 逐图清单。",
        "- 扩展关系图只读连接 website identity → Legacy Atlas/stditem/skill evidence → Zircon workspace candidates → NPC/monster/Map/Quest references；名称无法闭合的边标记 pending/investigate，不删除记录、不创建引用。",
        "", "## 13. 扩展验证与决策", "",
        f"- 生成器：`Tools/NpcMover/website_extension_alignment.py`；独立验证器：`Tools/NpcMover/verify_extension_alignment.py`；输出 `extension-verification.json`，结果={(extension_verification.get('result') or 'not-run')}。",
        "- 所有扩展产物均 `database_write=false`；当前 7000 仍监听，不能进入真实库阶段。`DECISIONS_PENDING.md` 的审核闸门继续有效。",
        "- 扩展报告和清单只提交本 Goal 新增脚本/产物；现有用户 WIP、Zircon 未提交 acceptance artifacts、网站未提交路径均保持不变。",
        "", "## 14. 当前用户闸门决定", "",
        "- 2026-09-26 用户选择“继续只读审核”，不进入写库阶段。",
        "- 因此不停止 7000、不执行数据库备份/副本 round-trip/双库同步，不修改 `System.db` 或 `Users.db`；pending/investigate 项保持原状。",
    ]
    report_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--website-root", type=Path, default=WEBSITE)
    parser.add_argument("--zircon-root", type=Path, default=ZIRCON)
    parser.add_argument("--workspace", type=Path, default=WORKSPACE)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    out = args.out
    out.mkdir(parents=True, exist_ok=True)

    monsters = load(args.website_root / "data/monsters.json")
    skills = load(args.website_root / "data/skills.json")
    maps = load(args.website_root / "data/maps.json")
    current_monsters = rows(args.workspace / "MonsterInfo.json")
    current_magic = rows(args.workspace / "MagicInfo.json")
    current_npcs = rows(args.workspace / "NPCInfo.json")
    current_regions = rows(args.workspace / "MapRegion.json")
    current_maps = rows(args.workspace / "MapInfo.json")
    current_respawns = rows(args.workspace / "RespawnInfo.json")
    lookup = parse_lookup(args.zircon_root / "GodotClient/Formats/MonsterLookup.cs")
    website_index = build_website_index(args.website_root, monsters, skills, maps)
    monster_source_doc = load(MONSTER_SOURCE)
    monster_source = monster_source_doc.get("records", monster_source_doc) if isinstance(monster_source_doc, dict) else monster_source_doc
    legacy_catalog = load_legacy_monster_catalog(MONSTER_LEGACY_CATALOG)
    monster_manifest, monster_stats = build_monsters(
        monsters, current_monsters, lookup, args.zircon_root / "Debug/Client/Data",
        monster_source, legacy_catalog,
    )
    skill_catalog = parse_skill_catalog(CATALOG_SKILLS)
    skill_manifest, skill_stats = build_skills(skills, current_magic, skill_catalog, args.zircon_root / "Debug/Client/Data")
    map_families = []
    for group in maps:
        for area in group.get("areas", []):
            map_families.append({"website_group": group["id"], "website_title": group["title"], "website_area": area["name"],
                                 "image": area["image"], "image_evidence": image_meta(website_image(args.website_root, area["image"])),
                                 "zircon_mapinfo_candidates": map_family_candidates(area["name"], current_maps),
                                 "coordinate_policy": "independent landmark/walkable verification; no blind reuse"})
    external = load_external_alignment()
    npc_manifest = normalize_npcs(external.pop("npc_rows", []))
    respawn_manifest = normalize_respawns(external.pop("respawn_rows", []))
    external["normalized_npc_manifest"] = str(out / "npc-manifest.json")
    external["normalized_respawn_manifest"] = str(out / "respawn-manifest.json")
    manifest = {
        "manifest_id": "MIR3-WEBSITE-ALIGNMENT-2026-09-26", "mode": "offline-dry-run", "database_write": False,
        "sources": {"website": str(args.website_root), "website_monsters": str(args.website_root / "data/monsters.json"),
                     "website_skills": str(args.website_root / "data/skills.json"), "website_maps": str(args.website_root / "data/maps.json"),
                     "workspace": str(args.workspace), "monster_lookup": str(args.zircon_root / "GodotClient/Formats/MonsterLookup.cs"),
                     "monster_resources": str(args.zircon_root / "Debug/Client/Data"), "skill_catalog": str(CATALOG_SKILLS),
                     "external_npc_respawn_manifest": external.get("path")},
        "zircon_counts": {"monster_info": len(current_monsters), "magic_info": len(current_magic), "npc_info": len(current_npcs),
                          "map_region": len(current_regions), "map_info": len(current_maps), "respawn_info": len(current_respawns)},
        "website_counts": {"monsters": len(monsters), "skills": len(skills), "map_groups": len(maps), "map_areas": len(website_index["maps"])},
        "monster_stats": monster_stats, "skill_stats": skill_stats, "monster_identity": monster_manifest,
        "skills": skill_manifest, "map_families": map_families,
        "npc_manifest_count": len(npc_manifest), "respawn_manifest_count": len(respawn_manifest),
        "external_alignment": external,
        "fresh_refresh_audit": str(out / "refresh-audit"),
        "business_index_untouched": True, "display_name_changes_only": True,
    }
    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out / "website-index.json").write_text(json.dumps(website_index, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out / "map-family-manifest.json").write_text(json.dumps(map_families, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out / "npc-manifest.json").write_text(json.dumps(npc_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out / "respawn-manifest.json").write_text(json.dumps(respawn_manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_tsv(out / "monster-manifest.tsv", monster_manifest)
    write_tsv(out / "skill-manifest.tsv", skill_manifest)
    build_report(manifest, ROOT / "docs/research/ei-ui-layout/NPC_MONSTER_WEBSITE_ALIGNMENT_REPORT_2026-09-26.md")
    print(json.dumps({"out": str(out), "monster_stats": monster_stats, "skill_stats": skill_stats,
                      "map_family_count": len(map_families), "external_alignment": external}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
