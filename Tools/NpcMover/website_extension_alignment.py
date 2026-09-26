#!/usr/bin/env python3
"""Read-only alignment evidence for items, missions, skills and cross-references.

This is intentionally separate from the NPC/monster refresh converter.  It reads
website JSON/HTML-derived JSON and exported Zircon workspace snapshots only; it
never opens System.db and never writes a database.
"""
from __future__ import annotations

import argparse
import hashlib
import csv
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WEBSITE = Path("/home/tetsuya/development/mir3-website")
ZIRCON = Path("/home/tetsuya/development/zircon")
WORKSPACE = ROOT / "Tools/dbeditor/workspace"
OUT_DEFAULT = ROOT / "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26"
TRANSLATIONS = ZIRCON / "GodotClient/translations/db_names.json"


def load(path: Path, default: Any = None) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def rows(name: str) -> list[dict[str, Any]]:
    value = load(WORKSPACE / f"{name}.json", [])
    return value.get("rows", value) if isinstance(value, dict) else value


def norm(value: Any) -> str:
    return re.sub(r"[\s·•・'‘’\"“”()（）【】\[\]{}、，,.:：!！?？/\\_-]+", "", str(value or "")).casefold()


def source_image(path_value: str | None) -> dict[str, Any]:
    if not path_value:
        return {"present": False, "path": None}
    path = (WEBSITE / path_value.replace("../", "")).resolve()
    out: dict[str, Any] = {"present": path.exists(), "path": str(path)}
    if not path.exists():
        return out
    raw = path.read_bytes()
    out.update({"bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()})
    try:
        with Image.open(path) as image:
            out.update({"width": image.width, "height": image.height, "format": image.format, "frames": getattr(image, "n_frames", 1)})
    except Exception as exc:
        out["decode_error"] = str(exc)
    return out


def translated_index(kind: str, current: list[dict[str, Any]], translations: dict[str, Any]) -> dict[str, list[dict[str, Any]]]:
    index: dict[str, list[dict[str, Any]]] = defaultdict(list)
    table = translations.get(kind, {})
    for row in current:
        key = row.get("ItemName") if kind == "items" else row.get("Name")
        zh = table.get(key, {}).get("zh") if isinstance(table.get(key), dict) else None
        if zh:
            index[norm(zh)].append(row)
    return index


def image_header(zl_path: Path, frame: Any) -> dict[str, Any]:
    try:
        from Tools.common.zlsdk import ZlLibrary
        library = ZlLibrary(str(zl_path))
        header = library.header(int(frame))
        return {"present": header is not None, "frame": int(frame), "header": header}
    except Exception as exc:
        return {"present": False, "frame": frame, "error": str(exc)}


def build_items(website_items: list[dict[str, Any]], current: list[dict[str, Any]], translations: dict[str, Any], zircon_data: Path, legacy_records: list[dict[str, Any]] | None = None) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    index = translated_index("items", current, translations)
    legacy_index: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for legacy in legacy_records or []:
        if legacy.get("Name"):
            legacy_index[norm(legacy["Name"])].append(legacy)
    by_image: dict[Any, list[dict[str, Any]]] = defaultdict(list)
    for row in current:
        by_image[row.get("Image")].append(row)
    category_types = {"武器": {"Weapon"}, "盔甲": {"Armour"}, "戒指": {"Ring"}, "手镯": {"Bracelet"}, "项链": {"Necklace"}, "头盔": {"Helmet"}, "鞋子": {"Shoes"}}
    out: list[dict[str, Any]] = []
    for website_row in website_items:
        candidates = index.get(norm(website_row.get("name")), [])
        legacy_candidates = legacy_index.get(norm(website_row.get("name")), [])
        compatible = [r for r in candidates if not category_types.get(website_row.get("category")) or r.get("ItemType") in category_types[website_row.get("category")]]
        # Website durability is points; Zircon stores durability in hundredths.
        attr = {}
        if compatible:
            r = compatible[0]
            attr = {"weight_equal": str(website_row.get("重量", "")).strip() in {"", "-", str(r.get("Weight"))}, "required_level_equal": str(website_row.get("等级", "")).strip() in {"", "-", str(r.get("RequiredAmount"))}, "category_compatible": r in compatible}
        status = "confirmed-name" if len(compatible) == 1 else ("name-conflict" if len(candidates) > 1 else ("legacy-source-only" if legacy_candidates else "pending-legacy-name"))
        out.append({
            "website_name": website_row.get("name"), "website_category": website_row.get("category"),
            "website_fields": website_row, "website_image": source_image(website_row.get("image")),
            "zircon_candidates": [{"index": r.get("Index"), "name": r.get("ItemName"), "item_type": r.get("ItemType"), "image": r.get("Image"), "weight": r.get("Weight"), "durability": r.get("Durability"), "required_amount": r.get("RequiredAmount")} for r in candidates],
            "category_compatible_candidates": [{"index": r.get("Index"), "name": r.get("ItemName"), "item_type": r.get("ItemType"), "image": r.get("Image")} for r in compatible],
            "legacy_source_candidates": [{"index": r.get("Index"), "name": r.get("Name"), "need_level": r.get("NeedLevel"), "weight": r.get("Weight"), "dura_max": r.get("DuraMax"), "price": r.get("Price"), "tag": r.get("tag"), "tag_note": r.get("tag_note")} for r in legacy_candidates[:5]],
            "icon_evidence": [image_header(zircon_data / "Storeitems.Zl", r.get("Image")) for r in compatible[:3]],
            "attribute_evidence": attr,
            "status": status,
            "skip_reason": None if compatible else ("旧版 stditem 名称可见但尚未闭合 Zircon ItemInfo Index；不猜测业务 Index。" if legacy_candidates else "网站中文名未在当前 ItemInfo 本地化名称或旧版 stditem 名称中唯一闭合；不猜测业务 Index。"),
        })
    stats = Counter(row["status"] for row in out)
    return out, {"website_record_count": len(out), "status_counts": dict(stats), "image_present_count": sum(r["website_image"].get("present", False) for r in out), "unique_name_match_count": sum(r["status"] == "confirmed-name" for r in out)}


def build_skills(website_skills: list[dict[str, Any]], current: list[dict[str, Any]], translations: dict[str, Any], zircon_data: Path) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    index = translated_index("magics", current, translations)
    out = []
    for website_row in website_skills:
        candidates = index.get(norm(website_row.get("name")), [])
        out.append({"website_name": website_row.get("name"), "website_class": website_row.get("class"), "description": website_row.get("description"), "website_image": source_image(website_row.get("image")), "zircon_candidates": [{"index": r.get("Index"), "name": r.get("Name"), "class": r.get("Class"), "icon": r.get("Icon"), "description": r.get("Description")} for r in candidates], "icon_evidence": [image_header(zircon_data / "MIcon.Zl", r.get("Icon")) for r in candidates[:3]], "status": "confirmed" if len(candidates) == 1 else ("conflict" if candidates else "investigate"), "skip_reason": None if candidates else "中文名未在 MagicInfo 翻译索引唯一闭合。"})
    stats = Counter(row["status"] for row in out)
    return out, {"website_record_count": len(out), "status_counts": dict(stats), "icon_present_count": sum(bool(r["icon_evidence"] and r["icon_evidence"][0].get("present")) for r in out)}


def all_text(value: Any) -> str:
    if isinstance(value, dict):
        return " ".join(all_text(v) for v in value.values())
    if isinstance(value, list):
        return " ".join(all_text(v) for v in value)
    return str(value or "")


def references(text: str, names_by_kind: dict[str, list[str]]) -> dict[str, list[str]]:
    result: dict[str, list[str]] = {}
    for kind, names in names_by_kind.items():
        hits = []
        for name in sorted(names, key=len, reverse=True):
            if len(norm(name)) < 2:
                continue
            if norm(name) in norm(text):
                hits.append(name)
        result[kind] = sorted(set(hits), key=norm)
    return result


def build_missions(missions: list[dict[str, Any]], current_quests: list[dict[str, Any]], translations: dict[str, Any], website_items: list[dict[str, Any]], website_skills: list[dict[str, Any]], website_monsters: list[dict[str, Any]], website_npcs: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    names_by_kind = {
        "npc": [v.get("zh") for v in translations.get("npcs", {}).values() if isinstance(v, dict) and v.get("zh")],
        "skill": [r.get("name") for r in website_skills],
        "item": [r.get("name") for r in website_items],
        "monster": [r.get("name") for r in website_monsters],
    }
    quest_name_set = set()
    for quest in current_quests:
        start = quest.get("StartNPC")
        if isinstance(start, dict):
            raw_name = str(start.get("Name") or "").split("/")[-1].strip()
            zh = translations.get("npcs", {}).get(raw_name, {})
            quest_name_set.add(norm(zh.get("zh") if isinstance(zh, dict) else raw_name))
        elif start:
            quest_name_set.add(norm(start))
    out = []
    for mission in missions:
        text = all_text(mission)
        refs = references(text, names_by_kind)
        steps = mission.get("steps", [])
        explicit_npcs = sorted(set(s.get("NPC") for s in steps if s.get("NPC") and s.get("NPC") not in {"NPC名字", "顺序"}))
        out.append({"website_id": mission.get("id"), "category": mission.get("category"), "title": mission.get("title"), "region": mission.get("region"), "raw_step_count": len(steps), "raw_quest_count": len(mission.get("quests", [])), "references": refs, "explicit_step_npcs": explicit_npcs, "current_quest_start_name_hits": sum(bool(norm(n) in quest_name_set for n in explicit_npcs) for n in explicit_npcs), "notes": ["初级任务页面首行包含导航/说明文本，保留原始字段，不把排版噪声当作任务步骤。"] if steps and steps[0].get("顺序", "").startswith("初级任务(") else []})
    stats = {"website_record_count": len(out), "step_count": sum(r["raw_step_count"] for r in out), "wanshitong_quest_count": sum(r["raw_quest_count"] for r in out), "reference_counts": {kind: sum(len(r["references"].get(kind, [])) for r in out) for kind in names_by_kind}, "current_questinfo_count": len(current_quests)}
    return out, stats


def map_ecology(maps: list[dict[str, Any]], map_manifest: dict[str, Any] | None) -> dict[str, Any]:
    families = []
    current = (map_manifest or {}).get("map_families", []) if isinstance(map_manifest, dict) else (map_manifest or [])
    for group in maps:
        areas = []
        for area in group.get("areas", []):
            name = area.get("name")
            tokens = [t for t in re.split(r"[、，和与及 /]+", name or "") if len(norm(t)) >= 2]
            candidates = [x for x in current if any(norm(t) in norm(all_text(x)) for t in tokens)]
            areas.append({"website_area": name, "website_image": source_image(area.get("image")), "zircon_family_candidates": candidates[:30], "status": "candidate" if candidates else "pending-family-review"})
        families.append({"website_group": group.get("id"), "title": group.get("title"), "areas": areas})
    return {"website_group_count": len(maps), "website_area_count": sum(len(x.get("areas", [])) for x in maps), "families": families}


def merge_existing_skill_manifest(skill_rows: list[dict[str, Any]], path: Path) -> dict[str, int]:
    if not path.exists():
        return {}
    legacy = {}
    with path.open(encoding="utf-8", newline="") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            legacy[row.get("website_skill_name", "")] = row
    counts = Counter()
    for row in skill_rows:
        old = legacy.get(row.get("website_name", ""))
        if not old:
            counts["missing-from-legacy-manifest"] += 1
            continue
        row["legacy_alignment_evidence"] = {
            "zircon_index": old.get("zircon_index") or None,
            "zircon_name": old.get("zircon_name") or None,
            "zircon_class": old.get("zircon_class") or None,
            "catalog_evidence": old.get("catalog_evidence") or None,
            "icon": old.get("icon") or None,
            "icon_evidence": old.get("icon_evidence") or None,
            "match_method": old.get("match_method") or None,
            "confidence": old.get("confidence") or None,
            "status": old.get("status") or None,
        }
        if old.get("status") == "confirmed":
            row["status"] = "confirmed-legacy-evidence"
            row["skip_reason"] = None
            counts["confirmed-legacy-evidence"] += 1
        else:
            counts[f"legacy-{old.get('status') or 'unknown'}"] += 1
    return dict(counts)


def main() -> int:
    global WEBSITE, WORKSPACE
    parser = argparse.ArgumentParser()
    parser.add_argument("--website-root", type=Path, default=WEBSITE)
    parser.add_argument("--workspace", type=Path, default=WORKSPACE)
    parser.add_argument("--out", type=Path, default=OUT_DEFAULT)
    args = parser.parse_args()
    WEBSITE, WORKSPACE = args.website_root, args.workspace
    out = args.out; out.mkdir(parents=True, exist_ok=True)
    translations = load(TRANSLATIONS, {})
    website_items = load(WEBSITE / "data/items.json", [])
    website_skills = load(WEBSITE / "data/skills.json", [])
    website_missions = load(WEBSITE / "data/missions.json", [])
    website_monsters = load(WEBSITE / "data/monsters.json", [])
    website_npcs = load(WEBSITE / "data/npcs.json", [])
    website_maps = load(WEBSITE / "data/maps.json", [])
    current_items, current_magic, current_quests = rows("ItemInfo"), rows("MagicInfo"), rows("QuestInfo")
    legacy_items = load(ROOT / "docs/research/mud3-dat-decoded/stditem.json", {}).get("records", [])
    item_rows, item_stats = build_items(website_items, current_items, translations, ZIRCON / "Debug/Client/Data", legacy_items)
    skill_rows, skill_stats = build_skills(website_skills, current_magic, translations, ZIRCON / "Debug/Client/Data")
    skill_stats["legacy_manifest_merge"] = merge_existing_skill_manifest(skill_rows, out / "skill-manifest.tsv")
    mission_rows, mission_stats = build_missions(website_missions, current_quests, translations, website_items, website_skills, website_monsters, website_npcs)
    map_manifest = load(ROOT / "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/map-family-manifest.json", {})
    ecology = map_ecology(website_maps, map_manifest)
    manifest = {"manifest_id": "MIR3-WEBSITE-EXTENSION-2026-09-26", "mode": "read-only-dry-run", "database_write": False, "sources": {"website": str(WEBSITE), "zircon_workspace": str(WORKSPACE), "translations": str(TRANSLATIONS)}, "current_counts": {"ItemInfo": len(current_items), "MagicInfo": len(current_magic), "QuestInfo": len(current_quests)}, "item_stats": item_stats, "skill_stats": skill_stats, "mission_stats": mission_stats, "map_ecology": {k: v for k, v in ecology.items() if k != "families"}, "items": item_rows, "skills": skill_rows, "missions": mission_rows, "map_ecology_detail": ecology, "policy": ["网站名称/图片是标准证据；未唯一闭合的名称保留 pending，不猜测 Index。", "扩展审计不修改 ItemInfo/MagicInfo/QuestInfo/NPCPage/NPCInfo/MonsterInfo 或任何数据库。", "任务页面原始 JSON 全量保留；导航噪声只作 notes，不静默删除。"]}
    (out / "extension-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out / "item-manifest.json").write_text(json.dumps(item_rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out / "skill-detail-manifest.json").write_text(json.dumps(skill_rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out / "mission-cross-reference.json").write_text(json.dumps(mission_rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (out / "map-ecology-manifest.json").write_text(json.dumps(ecology, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"out": str(out), "item_stats": item_stats, "skill_stats": skill_stats, "mission_stats": mission_stats, "map_ecology": {k: v for k, v in ecology.items() if k != "families"}}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
