#!/usr/bin/env python3
"""Build the static Zircon ↔ mir2ei alignment browser.

The builder deliberately keeps source records in JSON and only renders small
summaries in the browser.  It never writes a database or mutates a source
checkout.
"""
from __future__ import annotations

import csv
import hashlib
import json
import shutil
from collections import Counter, defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[3]
WORKSPACE = REPO / "Tools/dbeditor/workspace"
ARTIFACT = REPO / "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26"
WEBSITE = Path("/home/tetsuya/development/mir3-website")
WEBSITE_DATA = WEBSITE / "data"
OUTPUT_DATA = HERE / "data"
IMAGE_ROOT = OUTPUT_DATA / "images"

WORKSPACE_FILES = [
    "ItemInfo", "MonsterInfo", "MagicInfo", "NPCInfo", "MapInfo", "MapRegion",
    "RespawnInfo", "QuestInfo", "DropInfo", "ItemInfoStat", "MonsterInfoStat",
]


def load_json(path: Path, default: Any = None) -> Any:
    if not path.exists():
        return default
    return json.loads(path.read_text(encoding="utf-8"))


def rows(name: str) -> list[dict[str, Any]]:
    payload = load_json(WORKSPACE / f"{name}.json", {"rows": []})
    return payload.get("rows", [])


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for block in iter(lambda: f.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def parse_tsv(path: Path) -> list[dict[str, Any]]:
    with path.open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f, delimiter="\t"))


def json_cell(value: Any) -> Any:
    if value in (None, "", "null"):
        return None
    if isinstance(value, (dict, list, int, float, bool)):
        return value
    try:
        return json.loads(value)
    except (TypeError, json.JSONDecodeError):
        return value


def source(source_type: str, path: str, source_id: str | None = None, **extra: Any) -> dict[str, Any]:
    item = {"source_type": source_type, "source_path": path, "source_id": source_id}
    item.update(extra)
    return item


def copy_image(original: str | None, key: str) -> str | None:
    """Copy only known website evidence into the static bundle."""
    if not original:
        return None
    candidate = Path(original)
    if not candidate.is_absolute():
        candidate = WEBSITE / original.removeprefix("../")
    try:
        candidate = candidate.resolve()
        candidate.relative_to(WEBSITE.resolve())
    except (ValueError, OSError):
        return None
    if not candidate.is_file():
        return None
    relative = Path("images/website") / key / candidate.name
    dest = OUTPUT_DATA / relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    if not dest.exists() or dest.stat().st_size != candidate.stat().st_size:
        shutil.copy2(candidate, dest)
    return "data/" + relative.as_posix()


def image_from_evidence(evidence: Any, key: str) -> tuple[str | None, dict[str, Any] | None]:
    if isinstance(evidence, dict):
        path = evidence.get("path")
        return copy_image(path, key), evidence
    return None, None


def map_by(rows_: list[dict[str, Any]], field: str = "Index") -> dict[Any, dict[str, Any]]:
    return {row.get(field): row for row in rows_}


def relation_index(value: Any) -> Any:
    if isinstance(value, dict):
        return value.get("Index")
    return value


def raw_summary(value: Any, limit: int = 1200) -> Any:
    """Keep detail-on-demand raw data bounded when a source field is huge."""
    if isinstance(value, str) and len(value) > limit:
        return value[:limit] + "…"
    if isinstance(value, list):
        return [raw_summary(v, limit) for v in value]
    if isinstance(value, dict):
        return {k: raw_summary(v, limit) for k, v in value.items()}
    return value


def record(kind: str, record_id: str, left: Any, right: Any, conclusion: dict[str, Any], evidence: list[dict[str, Any]], raw: Any = None) -> dict[str, Any]:
    return {
        "kind": kind,
        "id": record_id,
        "left": left,
        "right": right if right is not None else {"direct_correspondence": False, "label": "无直接对应"},
        "conclusion": conclusion,
        "evidence": evidence,
        "raw": raw if raw is not None else {"left": raw_summary(left), "right": raw_summary(right)},
    }


def conclusion(status: str, title: str, rationale: str, current: str | None = None, proposed: str | None = None, applied: str | None = None) -> dict[str, Any]:
    return {
        "status": status,
        "title": title,
        "rationale": rationale,
        "current_actual": current,
        "proposed_standard": proposed,
        "applied": applied,
    }
ENTITY_TYPES = ("monster", "npc", "item", "skill", "map", "respawn", "quest")
DIMENSION_NAMES = ("identity", "display_name", "image", "stats", "map", "coordinate", "respawn", "drops", "quest_links")
CANONICAL_TITLES = {
    "mir2ei-only": "mir2ei 有，Zircon 当前没有安全对应项",
    "zircon-only": "Zircon 有，mir2ei 当前没有对应标准记录",
    "conflict": "双方有候选，但身份或资源冲突",
    "pending-evidence": "证据不足，暂不覆盖当前 Zircon",
    "resolved": "身份和结论已闭合",
    "partial": "双方身份已确认，但名称/图片/地图/刷新仍不同",
    "production-applied": "已应用到生产双库",
    "retain-current": "有证据但按当前决定保留 Zircon",
}


def _left_name(kind: str, value: dict[str, Any] | None) -> str | None:
    if not value:
        return None
    if kind == "quest":
        matches = value.get("matches") or []
        return ", ".join(str(row.get("QuestName", "")) for row in matches if row.get("QuestName")) or None
    return next((value.get(key) for key in ("MonsterName", "NPCName", "ItemName", "Name", "Description", "_Identity") if value.get(key)), None)


def _right_name(kind: str, value: dict[str, Any] | None) -> str | None:
    if not value:
        return None
    return next((value.get(key) for key in ("standard_name", "title", "website_name", "area", "map_family", "group") if value.get(key) and value.get(key) != "无直接对应"), None)


def _has_mir2ei_evidence(kind: str, value: dict[str, Any] | None) -> bool:
    if not value:
        return False
    if kind == "npc":
        return bool(value.get("website_page") or value.get("website_image") or value.get("matched_identity") or _right_name(kind, value))
    if kind == "respawn":
        return value.get("match_status") in {"matched", "conflict"} or value.get("apply_status") == "production-applied"
    return bool(_right_name(kind, value) or value.get("website_id") or value.get("website_skill_id") or value.get("website_group"))


def _has_zircon_entity(kind: str, value: dict[str, Any] | None) -> bool:
    if not value:
        return False
    if kind == "quest":
        return bool(value.get("matches"))
    return value.get("Index") is not None


def _side_source(value: dict[str, Any] | None) -> list[dict[str, Any]]:
    if not value:
        return []
    item = value.get("source")
    if isinstance(item, dict):
        return [item]
    return []


def _canonical_side(kind: str, value: dict[str, Any] | None, exists: bool, side: str, record_id: str, evidence: list[dict[str, Any]]) -> dict[str, Any]:
    if not exists:
        return {"exists": False, "index": None, "id": None, "name": None, "fields": {}, "source": []}
    value = value or {}
    if side == "zircon":
        matches = value.get("matches") or []
        index = value.get("Index") if value.get("Index") is not None else (matches[0].get("Index") if len(matches) == 1 else None)
        name = _left_name(kind, value)
    else:
        index = None
        name = _right_name(kind, value)
    source_items = _side_source(value) or [item for item in evidence if item.get("source_type") not in {"zircon-workspace"}]
    return {
        "exists": True,
        "index": index,
        "id": record_id if side == "mir2ei" and index is None else (value.get("website_id") or value.get("website_skill_id") or value.get("website_group") or record_id if side == "mir2ei" else None),
        "name": name,
        "fields": raw_summary(value, 4000),
        "source": source_items,
    }


def _dimension_value(name: str, kind: str, record: dict[str, Any], zircon: dict[str, Any], mir2ei: dict[str, Any], legacy_status: str, duplicate: bool) -> str:
    if not zircon["exists"] or not mir2ei["exists"]:
        return "unknown"
    if name == "identity":
        if duplicate or legacy_status in {"conflict", "replacement", "icon-conflict"}:
            return "different"
        if legacy_status in {"confirmed", "confirmed-name", "exact", "matched", "position-applied", "production-applied"}:
            return "same"
        return "unknown"
    if name == "display_name":
        left = (zircon.get("name") or "").strip().casefold()
        right = (mir2ei.get("name") or "").strip().casefold()
        return "same" if left and right and left == right else ("different" if left and right else "unknown")
    if name == "image":
        left = (record.get("left") or {}).get("Image") or (record.get("left") or {}).get("image") or (record.get("right") or {}).get("image") or (record.get("right") or {}).get("website_image")
        right = (record.get("right") or {}).get("image") or (record.get("right") or {}).get("website_image")
        return "same" if left and right and str(left) == str(right) else ("different" if left or right else "not-available")
    if name == "map":
        right = record.get("right") or {}
        if kind == "npc":
            match = right.get("map_match")
            return "same" if match in {"exact", "same"} else ("different" if match in {"different", "conflict"} else "unknown")
        if kind == "map":
            return "same" if zircon.get("index") in ((record.get("right") or {}).get("candidates") or []) else "unknown"
        if kind == "respawn":
            return "same" if legacy_status in {"matched", "production-applied"} else ("different" if legacy_status == "conflict" else "unknown")
    if name == "coordinate" and kind in {"npc", "respawn"}:
        return "same" if legacy_status in {"position-applied", "production-applied"} else ("different" if legacy_status == "conflict" else "unknown")
    if name == "respawn" and kind == "respawn":
        return "same" if legacy_status in {"matched", "production-applied"} else ("different" if legacy_status == "conflict" else "unknown")
    return "unknown"


def normalize_records(payloads: dict[str, list[dict[str, Any]]]) -> dict[str, dict[str, int]]:
    duplicate_keys: dict[str, Counter[Any]] = {}
    for kind, records in payloads.items():
        keys = []
        for item in records:
            left = item.get("left") or {}
            if _has_zircon_entity(kind.rstrip("s"), left):
                keys.append(left.get("Index") or ((left.get("matches") or [{}])[0].get("Index") if len(left.get("matches") or []) == 1 else None))
        duplicate_keys[kind] = Counter(key for key in keys if key is not None)
    coverage: dict[str, dict[str, int]] = {}
    for kind_plural, records in payloads.items():
        kind = kind_plural.rstrip("s")
        counts = Counter()
        direction_counts = Counter()
        for item in records:
            left = item.get("left") or {}
            right = item.get("right") or {}
            z_exists = _has_zircon_entity(kind, left)
            m_exists = _has_mir2ei_evidence(kind, right)
            direction = "both" if z_exists and m_exists else ("zircon-only" if z_exists else "mir2ei-only")
            legacy_status = item.get("conclusion", {}).get("status", "pending")
            z_index = left.get("Index") or ((left.get("matches") or [{}])[0].get("Index") if len(left.get("matches") or []) == 1 else None)
            duplicate = z_index is not None and duplicate_keys[kind_plural][z_index] > 1
            if direction == "both":
                if duplicate or legacy_status in {"conflict", "replacement", "icon-conflict"}:
                    status = "conflict"
                elif legacy_status in {"position-applied", "production-applied"}:
                    status = "production-applied"
                elif legacy_status in {"confirmed", "confirmed-name", "exact", "matched"}:
                    status = "resolved"
                elif legacy_status in {"variant", "renamed"}:
                    status = "partial"
                elif legacy_status == "retain-current":
                    status = "retain-current"
                else:
                    status = "pending-evidence"
            else:
                status = direction
            zircon = _canonical_side(kind, left, z_exists, "zircon", item["id"], item.get("evidence", []))
            mir2ei = _canonical_side(kind, right, m_exists, "mir2ei", item["id"], item.get("evidence", []))
            dimensions = {name: _dimension_value(name, kind, item, zircon, mir2ei, legacy_status, duplicate) for name in DIMENSION_NAMES}
            current = zircon.get("name") if zircon["exists"] else None
            next_action = {
                "mir2ei-only": "补齐 Zircon 安全 Index 与业务关联",
                "zircon-only": "补充 mir2ei/资料站逐项证据，不按数量差猜测",
                "conflict": "人工复核身份、资源与业务关系，禁止静默覆盖",
                "pending-evidence": "补充 manifest、资源、地图或业务证据",
                "resolved": "保持证据链，进入回归检查",
                "partial": "逐维度决定名称、图片、地图、坐标或刷新值",
                "production-applied": "保留双库 round-trip 与游戏内验收记录",
                "retain-current": "继续使用当前 Zircon 值，等待更强证据",
            }[status]
            item["entity_type"] = kind
            item["zircon"] = zircon
            item["mir2ei"] = mir2ei
            item["direction"] = direction
            item["conclusion"] = {
                **item.get("conclusion", {}),
                "legacy_status": legacy_status,
                "status": status,
                "title": CANONICAL_TITLES[status],
                "rationale": CANONICAL_TITLES[status] + "。原始状态=" + legacy_status + "；来源范围按 manifest 保留。",
                "current_actual": current,
                "current_usage": current or "无当前 Zircon 实体",
                "next_action": next_action,
            }
            item["dimensions"] = dimensions
            item["reason"] = item["conclusion"]["rationale"]
            item["evidence"] = item.get("evidence", [])
            item["current_usage"] = current or "无当前 Zircon 实体"
            item["next_action"] = next_action
            direction_counts[direction] += 1
            counts[status] += 1
        for direction, count in direction_counts.items():
            counts[direction] = count
        counts["total"] = len(records)
        assert direction_counts["mir2ei-only"] + direction_counts["zircon-only"] + direction_counts["both"] == counts["total"], f"{kind}: direction coverage lost"
        coverage[kind] = dict(counts)
    return coverage


def build_monsters(ws: dict[str, list[dict[str, Any]]], metadata: dict[str, Any]) -> list[dict[str, Any]]:
    current = map_by(ws["MonsterInfo"])
    stats = defaultdict(list)
    for row in ws["MonsterInfoStat"]:
        stats[relation_index(row.get("Monster"))].append(row)
    respawns = defaultdict(list)
    for row in ws["RespawnInfo"]:
        respawns[relation_index(row.get("Monster"))].append(row)
    drops = defaultdict(list)
    for row in ws["DropInfo"]:
        drops[relation_index(row.get("Monster"))].append(row)
    out: list[dict[str, Any]] = []
    tsv = parse_tsv(ARTIFACT / "monster-manifest.tsv")
    seen: set[int] = set()
    for item in tsv:
        idx = int(item["zircon_index"]) if item.get("zircon_index", "").isdigit() else None
        left = current.get(idx) if idx is not None else None
        if idx is not None:
            seen.add(idx)
        image, image_ev = image_from_evidence(json_cell(item.get("website_image_evidence")), "monster")
        right = {
            "website_id": item.get("website_monster_id"), "standard_name": item.get("website_monster_name"),
            "category": item.get("website_category"), "image": image or item.get("website_image"),
            "description": item.get("source_description"), "candidate_count": int(item.get("candidate_count") or 0),
            "resource_alias": json_cell(item.get("resource_alias")), "identity_evidence": json_cell(item.get("source_identity_evidence")),
            "match_method": item.get("match_method"), "match_evidence": json_cell(item.get("match_evidence")),
            "confidence": item.get("confidence"), "status": item.get("status"), "apply_status": item.get("apply_status"),
            "image_evidence": image_ev,
            "source": source("mir3-website + alignment-manifest", "/home/tetsuya/development/mir3-website/data/monsters.json", item.get("website_monster_id"), page=item.get("website_image")),
        }
        status = item.get("status") or "pending"
        title = {"confirmed": "same identity", "investigate": "investigate", "pending": "pending"}.get(status, status)
        cur_name = left.get("MonsterName") if left else None
        out.append(record("monster", f"website:{item.get('website_monster_id')}", {
            **(left or {}), "MonsterInfoStats": stats.get(idx, []), "RespawnInfo": respawns.get(idx, []), "DropInfo": drops.get(idx, []),
            "source": source("zircon-workspace", "Tools/dbeditor/workspace/MonsterInfo.json", str(idx) if idx is not None else None),
        } if left else None, right, conclusion(status, title, f"manifest status={status}; candidate_count={item.get('candidate_count') or 0}; evidence is retained below", cur_name, item.get("website_monster_name"), item.get("apply_status")), [source("zircon-workspace", "Tools/dbeditor/workspace/MonsterInfo.json", str(idx) if idx is not None else None), source("alignment-manifest", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/monster-manifest.tsv", item.get("website_monster_id")), source("mir2-website", "/home/tetsuya/development/mir3-website/data/monsters.json", item.get("website_monster_id"))], {"manifest": item, "workspace": left, "stats": stats.get(idx, []), "respawns": respawns.get(idx, []), "drops": drops.get(idx, [])}))
    for idx, left in current.items():
        if idx in seen:
            continue
        out.append(record("monster", f"zircon:{idx}", {**left, "MonsterInfoStats": stats.get(idx, []), "RespawnInfo": respawns.get(idx, []), "DropInfo": drops.get(idx, []), "source": source("zircon-workspace", "Tools/dbeditor/workspace/MonsterInfo.json", str(idx))}, None, conclusion("retain-current", "retain-current", "没有 website/manifest 的直接对应；不根据名称猜测业务索引", left.get("MonsterName"), None, "not-applied"), [source("zircon-workspace", "Tools/dbeditor/workspace/MonsterInfo.json", str(idx))]))
    return out


def build_skills(ws: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    current = map_by(ws["MagicInfo"])
    out: list[dict[str, Any]] = []
    seen: set[int] = set()
    for item in parse_tsv(ARTIFACT / "skill-manifest.tsv"):
        idx = int(item["zircon_index"]) if item.get("zircon_index", "").isdigit() else None
        left = current.get(idx) if idx is not None else None
        if idx is not None: seen.add(idx)
        image, image_ev = image_from_evidence(json_cell(item.get("website_image_evidence")), "skill")
        right = {"website_id": item.get("website_skill_id"), "standard_name": item.get("website_skill_name"), "class": item.get("website_class"), "image": image or item.get("website_image"), "description": item.get("source_description"), "catalog_evidence": json_cell(item.get("catalog_evidence")), "icon_evidence": json_cell(item.get("icon_evidence")), "match_method": item.get("match_method"), "match_evidence": json_cell(item.get("match_evidence")), "confidence": item.get("confidence"), "status": item.get("status"), "image_evidence": image_ev, "source": source("mir3-website + legacy-atlas alignment", "/home/tetsuya/development/mir3-website/data/skills.json", item.get("website_skill_id"), page=item.get("website_image"))}
        status = item.get("status") or "pending"
        out.append(record("skill", f"website:{item.get('website_skill_id')}", {**(left or {}), "source": source("zircon-workspace", "Tools/dbeditor/workspace/MagicInfo.json", str(idx) if idx is not None else None)} if left else None, right, conclusion(status, status, "直接名称闭合与 Legacy Atlas 多来源证据分别保留，不因 lookup 失败否定语义证据", left.get("Name") if left else None, item.get("website_skill_name"), item.get("apply_status")), [source("zircon-workspace", "Tools/dbeditor/workspace/MagicInfo.json", str(idx) if idx is not None else None), source("alignment-manifest", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/skill-manifest.tsv", item.get("website_skill_id")), source("legacy-atlas", "docs/legacy-atlas/content/catalog-skills.html", item.get("website_skill_id"))], {"manifest": item, "workspace": left}))
    for idx, left in current.items():
        if idx in seen: continue
        out.append(record("skill", f"zircon:{idx}", {**left, "source": source("zircon-workspace", "Tools/dbeditor/workspace/MagicInfo.json", str(idx))}, None, conclusion("retain-current", "retain-current", "网站 61 条不是 Zircon 174 条技能全量", left.get("Name"), None, "not-applied"), [source("zircon-workspace", "Tools/dbeditor/workspace/MagicInfo.json", str(idx))]))
    return out


def build_items(ws: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    current = map_by(ws["ItemInfo"])
    stats = defaultdict(list)
    for row in ws["ItemInfoStat"]: stats[relation_index(row.get("Item"))].append(row)
    out: list[dict[str, Any]] = []
    seen: set[int] = set()
    manifest = load_json(ARTIFACT / "item-manifest.json", [])
    for n, item in enumerate(manifest):
        candidates = item.get("zircon_candidates") or []
        idx = candidates[0].get("index") if candidates else None
        left = current.get(idx) if idx is not None else None
        if idx is not None: seen.add(idx)
        ev = item.get("website_image") or {}
        image, image_ev = image_from_evidence(ev, "item")
        right = {"standard_name": item.get("website_name"), "category": item.get("website_category"), "fields": item.get("website_fields", {}), "image": image or item.get("website_fields", {}).get("image"), "image_evidence": image_ev, "candidates": candidates, "status": item.get("status") or ("current-candidate" if left else "no-safe-index"), "source": source("mir3-website + item-manifest", "/home/tetsuya/development/mir3-website/data/items.json", str(n), page=item.get("website_fields", {}).get("image"))}
        status = right["status"]
        out.append(record("item", f"website:{n}", {**(left or {}), "ItemInfoStats": stats.get(idx, []), "source": source("zircon-workspace", "Tools/dbeditor/workspace/ItemInfo.json", str(idx) if idx is not None else None)} if left else None, right, conclusion(status, status, "名称对应与业务 ItemInfo.Index 分开；manifest candidate 才可作为证据", left.get("ItemName") if left else None, item.get("website_name"), None), [source("zircon-workspace", "Tools/dbeditor/workspace/ItemInfo.json", str(idx) if idx is not None else None), source("alignment-manifest", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/item-manifest.json", str(n)), source("mir3-website", "/home/tetsuya/development/mir3-website/data/items.json", str(n))], {"manifest": item, "workspace": left}))
    for idx, left in current.items():
        if idx in seen: continue
        out.append(record("item", f"zircon:{idx}", {**left, "ItemInfoStats": stats.get(idx, []), "source": source("zircon-workspace", "Tools/dbeditor/workspace/ItemInfo.json", str(idx))}, None, conclusion("retain-current", "retain-current", "网站 371 条不是 Zircon 1078 条全量", left.get("ItemName"), None, "not-applied"), [source("zircon-workspace", "Tools/dbeditor/workspace/ItemInfo.json", str(idx))]))
    return out


def build_npcs(ws: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    current = map_by(ws["NPCInfo"])
    regions = map_by(ws["MapRegion"])
    manifest = load_json(ARTIFACT / "npc-manifest.json", [])
    approved_plan = load_json(REPO / "docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/approved-offline-plan.json", {})
    approved = {row.get("npc_index"): row for row in approved_plan.get("npc_moves", [])}
    out: list[dict[str, Any]] = []
    for item in manifest:
        idx = item.get("npc_index")
        left = current.get(idx)
        region = regions.get(relation_index(left.get("Region")) if left else None)
        coordinate = item.get("coordinate_evidence") or {}
        applied_row = approved.get(idx)
        applied = "production-applied" if applied_row else (item.get("apply_status") or "pending")
        status = "position-applied" if applied_row else (item.get("map_match") or "candidate")
        right = {"standard_name": item.get("website_name") or "无直接对应", "website_page": item.get("website_page"), "website_image": item.get("website_image_if_any"), "matched_identity": item.get("matched_identity"), "map_match": item.get("map_match"), "coordinate_source": coordinate, "approved_target": applied_row, "no_exact_coordinate_source": not bool(item.get("website_page")), "source": source("alignment-manifest + npc-monster evidence", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/npc-manifest.json", str(idx), page=item.get("website_page"))}
        out.append(record("npc", f"zircon:{idx}", {**(left or {}), "current_region": region, "source": source("zircon-workspace", "Tools/dbeditor/workspace/NPCInfo.json", str(idx))} if left else None, right, conclusion(status, "已应用" if applied_row else status, "73 条 approved NPC 坐标已应用；其余保持 pending/candidate，不显示为完成", left.get("NPCName") if left else None, right.get("standard_name"), applied), [source("zircon-workspace", "Tools/dbeditor/workspace/NPCInfo.json", str(idx)), source("zircon-workspace", "Tools/dbeditor/workspace/MapRegion.json", str(relation_index(left.get("Region")) if left else None)), source("alignment-manifest", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/npc-manifest.json", str(idx)), source("approved-offline-plan", "docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/approved-offline-plan.json", str(idx))], {"manifest": item, "workspace": left, "region": region, "approved_target": applied_row}))
    return out


def build_respawns(ws: dict[str, list[dict[str, Any]]]) -> list[dict[str, Any]]:
    regions = map_by(ws["MapRegion"])
    manifest = load_json(ARTIFACT / "respawn-manifest.json", [])
    approved_plan = load_json(REPO / "docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/approved-offline-plan.json", {})
    approved = {row.get("respawn_index"): row for row in approved_plan.get("respawn_updates", [])}
    out: list[dict[str, Any]] = []
    for item in manifest:
        old = item.get("old_respawn") or {}
        idx = item.get("respawn_index")
        left = next((r for r in ws["RespawnInfo"] if r.get("Index") == idx), None)
        region = regions.get(relation_index(left.get("Region")) if left else old.get("region_index"))
        approved_row = approved.get(idx)
        status = "production-applied" if approved_row else (item.get("match_status") or item.get("confidence") or "pending")
        right = {"hero_kill": item.get("hero_kill"), "old_respawn": old, "new_respawn": item.get("new_respawn"), "approved_target": approved_row, "confidence": item.get("confidence"), "walkable": item.get("walkable"), "overlap": item.get("overlap"), "match_status": item.get("match_status"), "apply_status": "production-applied" if approved_row else item.get("apply_status"), "range_note": item.get("range_note"), "source": source("alignment-manifest + Mud3/Hero-kill", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/respawn-manifest.json", str(idx))}
        out.append(record("respawn", f"zircon:{idx}", {**(left or {}), "region_detail": region, "source": source("zircon-workspace", "Tools/dbeditor/workspace/RespawnInfo.json", str(idx))} if left else None, right, conclusion(status, "已应用" if approved_row else status, "保留 Zircon-only、YXS-only、conflict；没有精确计划时不推断写入目标", left.get("_Identity") if left else None, approved_row, "production-applied" if approved_row else item.get("apply_status")), [source("zircon-workspace", "Tools/dbeditor/workspace/RespawnInfo.json", str(idx)), source("alignment-manifest", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/respawn-manifest.json", str(idx)), source("approved-offline-plan", "docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/approved-offline-plan.json", str(idx)), source("Mud3/Hero-kill evidence", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/refresh-audit/manifest.json", str(idx))], {"manifest": item, "workspace": left, "region": region, "approved_target": approved_row}))
    return out




def build_maps(ws: dict[str, list[dict[str, Any]]], website_maps: list[dict[str, Any]]) -> list[dict[str, Any]]:
    current = map_by(ws["MapInfo"])
    regions = defaultdict(list)
    for row in ws["MapRegion"]: regions[relation_index(row.get("Map"))].append(row)
    map_manifest = load_json(ARTIFACT / "map-family-manifest.json", [])
    out: list[dict[str, Any]] = []
    for n, item in enumerate(map_manifest):
        candidates = item.get("zircon_mapinfo_candidates", [])
        image, image_ev = image_from_evidence(item.get("image_evidence"), "map")
        right = {"group": item.get("website_group"), "title": item.get("website_title"), "area": item.get("website_area"), "image": image or item.get("image"), "image_evidence": image_ev, "map_family": item.get("map_family"), "topology_evidence": item.get("topology_evidence"), "candidates": candidates, "source": source("mir3-website + map-family manifest", "/home/tetsuya/development/mir3-website/data/maps.json", item.get("website_group"), page=item.get("image"))}
        first = candidates[0] if candidates else None
        idx = first.get("index") if first else None
        left = current.get(idx) if idx is not None else None
        out.append(record("map", f"website:{item.get('website_group')}:{n}", {**(left or {}), "MapRegions": regions.get(idx, []), "source": source("zircon-workspace", "Tools/dbeditor/workspace/MapInfo.json", str(idx) if idx is not None else None)} if left else None, right, conclusion(item.get("match_status") or "variant", item.get("match_status") or "variant", "网站地图图是 map family/区域图，不等于 627 张逐图 MapInfo；具体 Index 逐项保留", left.get("Description") if left else None, item.get("website_title"), None), [source("zircon-workspace", "Tools/dbeditor/workspace/MapInfo.json", str(idx) if idx is not None else None), source("zircon-workspace", "Tools/dbeditor/workspace/MapRegion.json", str(idx) if idx is not None else None), source("alignment-manifest", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/map-family-manifest.json", str(n)), source("mir3-website", "/home/tetsuya/development/mir3-website/data/maps.json", item.get("website_group"))], {"manifest": item, "workspace": left, "regions": regions.get(idx, [])}))
    linked = {c.get("index") for item in map_manifest for c in item.get("zircon_mapinfo_candidates", [])}
    for idx, left in current.items():
        if idx in linked: continue
        out.append(record("map", f"zircon:{idx}", {**left, "MapRegions": regions.get(idx, []), "source": source("zircon-workspace", "Tools/dbeditor/workspace/MapInfo.json", str(idx))}, None, conclusion("retain-current", "retain-current", "网站区域图不覆盖所有 Zircon MapInfo；保留当前逐图数据", left.get("Description"), None, "not-applied"), [source("zircon-workspace", "Tools/dbeditor/workspace/MapInfo.json", str(idx)), source("zircon-workspace", "Tools/dbeditor/workspace/MapRegion.json", str(idx))]))
    return out


def build_quests(ws: dict[str, list[dict[str, Any]]], website_missions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    current = map_by(ws["QuestInfo"])
    cross = load_json(ARTIFACT / "mission-cross-reference.json", [])
    out: list[dict[str, Any]] = []
    for item in cross:
        website = next((x for x in website_missions if x.get("id") == item.get("website_id")), None)
        left_hits = [q for q in ws["QuestInfo"] if any(item.get("title", "").split("（")[0] in str(q.get("QuestName", "")) for _ in [0])]
        right = {"website_id": item.get("website_id"), "category": item.get("category"), "title": item.get("title"), "region": item.get("region"), "raw_step_count": item.get("raw_step_count"), "raw_quest_count": item.get("raw_quest_count"), "references": item.get("references"), "explicit_step_npcs": item.get("explicit_step_npcs"), "current_quest_start_name_hits": item.get("current_quest_start_name_hits"), "notes": item.get("notes"), "website_record": website, "source": source("mir3-website + mission cross-reference", "/home/tetsuya/development/mir3-website/data/missions.json", item.get("website_id"))}
        out.append(record("quest", item.get("website_id"), {"matches": left_hits, "source": source("zircon-workspace", "Tools/dbeditor/workspace/QuestInfo.json", None)}, right, conclusion("investigate" if item.get("notes") else "pending", "investigate", "任务页面含排版噪声；保留原始 steps、NPC/物品/怪物/技能/地图引用，不假造闭合", ", ".join(q.get("QuestName", "") for q in left_hits) or None, item.get("title"), None), [source("zircon-workspace", "Tools/dbeditor/workspace/QuestInfo.json"), source("mir3-website", "/home/tetsuya/development/mir3-website/data/missions.json", item.get("website_id")), source("alignment-manifest", "docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/mission-cross-reference.json", item.get("website_id"))], {"cross_reference": item, "website": website, "zircon_matches": left_hits}))
    for q in ws["QuestInfo"]:
        if not any(q.get("Index") == z.get("Index") for r in out for z in (r["raw"].get("zircon_matches") or [])):
            out.append(record("quest", f"zircon:{q.get('Index')}", {**q, "source": source("zircon-workspace", "Tools/dbeditor/workspace/QuestInfo.json", str(q.get("Index")))}, None, conclusion("retain-current", "retain-current", "无 website 任务直接闭合", q.get("QuestName"), None, "not-applied"), [source("zircon-workspace", "Tools/dbeditor/workspace/QuestInfo.json", str(q.get("Index")))]))
    return out


def build_meta(ws: dict[str, list[dict[str, Any]]], website: dict[str, list[dict[str, Any]]], counts: dict[str, Any], coverage: dict[str, dict[str, int]]) -> dict[str, Any]:
    production = load_json(ARTIFACT / "production-apply-evidence-20260926.json", {})
    target = load_json(ARTIFACT / "final-production-targets-20260926.json", {})
    verification = load_json(ARTIFACT / "verification.json", {})
    source_files = {"alignment_manifest": ARTIFACT / "manifest.json", "production_evidence": ARTIFACT / "production-apply-evidence-20260926.json", "final_targets": ARTIFACT / "final-production-targets-20260926.json", "website_index": ARTIFACT / "website-index.json"}
    source_files["approved_offline_plan"] = REPO / "docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/approved-offline-plan.json"
    for name in WORKSPACE_FILES:
        source_files[f"workspace_{name}"] = WORKSPACE / f"{name}.json"
    for name in ["items", "monsters", "skills", "missions", "maps"]:
        source_files[f"website_{name}"] = WEBSITE_DATA / f"{name}.json"
    hashes = {name: sha256(path) for name, path in source_files.items() if path.exists()}
    statuses = Counter()
    for kind in ENTITY_TYPES:
        for status, count in coverage.get(kind, {}).items():
            if status not in {"mir2ei-only", "zircon-only", "both", "total"}:
                statuses[status] += count
    return {"generated_at": datetime.now(timezone.utc).isoformat(), "data_version": "MIR3-ALIGNMENT-BROWSER-2026.09.26", "source_hashes": hashes, "counts": {"workspace": {name: len(value) for name, value in ws.items()}, "website": {name: len(value) for name, value in website.items()}, "status": dict(statuses), "coverage": coverage}, "production": {"approved_npc": 73, "approved_respawn": 18, "monster_info_changed": 0, "magic_info_changed": 0, "users_db_written": production.get("production_apply", {}).get("users_db_written", False), "server_sha256": production.get("production_apply", {}).get("server_sha256"), "client_sha256": production.get("production_apply", {}).get("client_sha256"), "server_client_sha_equal": production.get("production_apply", {}).get("server_client_sha_equal"), "backup_paths": [production.get("production_apply", {}).get("server_backup_created_by_npcmover"), production.get("production_apply", {}).get("client_backup_created_by_npcmover")], "last_verified": production.get("recorded_at"), "game_acceptance": production.get("game_acceptance")}, "final_targets": target, "verification": verification, "notes": ["网站 61 技能不是 Zircon 174 条技能全量。", "网站 154 怪物不是 Zircon 434 条全量。", "网站 371 物品不是 Zircon 1078 条全量。", "网站地图为 3 组/22 区域图，不是 627 张逐图 MapInfo。", "Users.db 未写入。"]}

def main() -> None:
    OUTPUT_DATA.mkdir(parents=True, exist_ok=True)
    for child in IMAGE_ROOT.glob("**/*") if IMAGE_ROOT.exists() else []:
        if child.is_file(): child.unlink()
    ws = {name: rows(name) for name in WORKSPACE_FILES}
    website = {name: load_json(WEBSITE_DATA / f"{name}.json", []) for name in ["items", "monsters", "skills", "missions", "maps"]}
    monsters = build_monsters(ws, {})
    skills = build_skills(ws)
    items = build_items(ws)
    npcs = build_npcs(ws)
    respawns = build_respawns(ws)
    maps = build_maps(ws, website["maps"])
    quests = build_quests(ws, website["missions"])
    payloads = {"monsters": monsters, "npcs": npcs, "items": items, "skills": skills, "maps": maps, "respawns": respawns, "quests": quests}
    coverage = normalize_records(payloads)
    counts: dict[str, Any] = {"workspace": {name: len(value) for name, value in ws.items()}, "website": {name: len(value) for name, value in website.items()}}
    counts.update({f"{name}_records": value for name, value in payloads.items()})
    meta = build_meta(ws, website, counts, coverage)
    meta["counts"]["summary_status"] = {key: meta["counts"]["status"].get(key, 0) for key in CANONICAL_TITLES}
    meta["counts"]["source_record_totals"] = {kind: len(records) for kind, records in payloads.items()}
    counts.pop("monsters_records", None); counts.pop("npcs_records", None); counts.pop("items_records", None); counts.pop("skills_records", None); counts.pop("maps_records", None); counts.pop("respawns_records", None); counts.pop("quests_records", None)
    meta["counts"] = {**meta["counts"], **counts}
    (OUTPUT_DATA / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    for name, value in payloads.items():
        (OUTPUT_DATA / f"{name}.json").write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"generated_at": meta["generated_at"], "workspace": counts["workspace"], "website": counts["website"], "records": {k: len(v) for k, v in payloads.items()}, "coverage": coverage, "status": meta["counts"]["status"]}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
