#!/usr/bin/env python3
"""Build offline MAP/NPC/monster alignment manifests.

The command is deliberately read-only: it consumes exported System.db JSON and
local map files and writes manifests/reports only.  It never opens SQLite and
never mutates a database.  Hero-kill spawn configuration is optional; when it
is absent the monster refresh side stays explicitly pending instead of
inventing coordinates.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import re
import struct
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

COORD_RE = re.compile(r"(?P<map>[^()|\s]+)\((?P<x>-?\d+),(?P<y>-?\d+)\)")
TABLE_RE = re.compile(r"^\|\s*(?P<idx>\d+)\s*\|\s*(?P<name>.*?)\s*\|\s*(?P<method>.*?)\s*\|\s*(?P<old>.*?)\s*\|\s*(?P<new>.*?)\s*\|\s*(?P<note>.*?)\s*\|\s*(?P<source>.*?)\s*\|\s*(?P<remark>.*?)\s*\|\s*$")


def load(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def rows(path: Path) -> list[dict[str, Any]]:
    data = load(path)
    return data.get("rows", data) if isinstance(data, dict) else data


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def map_meta(path: Path | None) -> dict[str, Any]:
    if path is None or not path.exists():
        return {"present": False, "path": None, "width": None, "height": None, "bytes": None, "sha256": None}
    raw = path.read_bytes()
    if len(raw) < 28:
        return {"present": True, "path": str(path), "width": None, "height": None, "bytes": len(raw), "sha256": sha256(path), "parse": "invalid-header"}
    width, height = struct.unpack_from("<HH", raw, 22)
    base = 28 + (width // 2) * (height // 2) * 3
    expected = base + width * height * 14
    return {"present": True, "path": str(path), "width": width, "height": height, "bytes": len(raw), "sha256": sha256(path), "cell_base": base, "expected_bytes": expected, "parse": "ok" if expected <= len(raw) else "truncated"}


def map_files(root: Path) -> dict[str, Path]:
    return {p.stem.casefold(): p for p in root.glob("*.map")}


def cell_flags(path: Path | None) -> tuple[dict[str, Any], bytes] | None:
    if path is None or not path.exists():
        return None
    raw = path.read_bytes()
    if len(raw) < 28:
        return None
    width, height = struct.unpack_from("<HH", raw, 22)
    base = 28 + (width // 2) * (height // 2) * 3
    if base + width * height * 14 > len(raw):
        return None
    return {"width": width, "height": height, "base": base}, raw


def walkable(path: Path | None, x: int | None, y: int | None) -> str:
    parsed = cell_flags(path)
    if parsed is None or x is None or y is None:
        return "pending"
    meta, raw = parsed
    if not (0 <= x < meta["width"] and 0 <= y < meta["height"]):
        return "fail"
    off = meta["base"] + (x * meta["height"] + y) * 14
    return "pass" if raw[off] & 3 == 3 else "fail"


def walk_summary(path: Path | None) -> dict[str, Any]:
    parsed = cell_flags(path)
    if parsed is None:
        return {"status": "pending", "walkable_cells": None, "total_cells": None, "walkable_ratio": None}
    meta, raw = parsed
    flags = [raw[meta["base"] + (x * meta["height"] + y) * 14] for x in range(meta["width"]) for y in range(meta["height"])]
    count = sum(1 for flag in flags if flag & 3 == 3)
    return {"status": "pass", "walkable_cells": count, "total_cells": len(flags), "walkable_ratio": round(count / len(flags), 6) if flags else None}


def coord(value: str | None) -> tuple[str, int, int] | None:
    match = COORD_RE.search(value or "")
    return None if not match else (match.group("map"), int(match.group("x")), int(match.group("y")))


def audit_rows(path: Path) -> dict[int, dict[str, str]]:
    out: dict[int, dict[str, str]] = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        match = TABLE_RE.match(line)
        if match:
            row = match.groupdict()
            out[int(row["idx"])] = row
    return out


def relation(hero: Path | None, zircon: Path | None, hero_hashes: dict[str, list[str]]) -> tuple[str, str]:
    h, z = map_meta(hero), map_meta(zircon)
    if not h["present"] or not z["present"]:
        if z["present"] and hero_hashes.get(z["sha256"]):
            return "renamed", f"Zircon bytes match hero-kill stem(s): {', '.join(hero_hashes[z['sha256']])}"
        return "pending", "hero-kill or Zircon map file missing"
    if h["sha256"] == z["sha256"]:
        return "exact", "same local map bytes"
    if (h["width"], h["height"]) == (z["width"], z["height"]):
        return "variant", "same dimensions, different map bytes"
    return "replacement", "different dimensions and bytes"


def landmark_info(info: dict[str, Any], links: dict[str, Any], stem: str) -> dict[str, Any]:
    regions = info.get("Regions") or []
    guards = info.get("Guards") or []
    words = ("town", "store", "warehouse", "gate", "entrance", "exit", "teleport", "spawn", "safe", "area", "center", "村", "店", "仓", "门", "入口", "出口", "传送", "城", "安全")
    labels = [str(x.get("Name", "")) for x in regions]
    landmark = [x for x in labels if any(w.casefold() in x.casefold() for w in words)]
    neighbour: set[str] = set()
    for edge in links.get("links", []):
        if isinstance(edge, list) and len(edge) == 2:
            if edge[0] == stem:
                neighbour.add(str(edge[1]))
            if edge[1] == stem:
                neighbour.add(str(edge[0]))
    return {
        "region_count": len(regions),
        "region_landmark_samples": landmark[:40],
        "guard_count": len(guards),
        "guard_samples": [str(x.get("Name", "")) for x in guards[:12]],
        "connected_maps": sorted(neighbour),
        "coordinate_evidence": "MapRegion PointRegion centers; no Merchant coordinate snapshot available",
    }


def build_maps(mapinfo: list[dict[str, Any]], hero_root: Path, zircon_root: Path, links: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    hero = map_files(hero_root)
    zircon = map_files(zircon_root)
    hero_hashes: dict[str, list[str]] = defaultdict(list)
    for stem, path in hero.items():
        hero_hashes[map_meta(path)["sha256"]].append(path.stem)
    out = []
    for info in mapinfo:
        stem = str(info["FileName"])
        hp, zp = hero.get(stem.casefold()), zircon.get(stem.casefold())
        rel, evidence = relation(hp, zp, hero_hashes)
        hm, zm = map_meta(hp), map_meta(zp)
        direct = rel in {"exact", "renamed"}
        out.append({
            "original_map": stem,
            "hero_kill_map": stem if hp else None,
            "map_file": hm["path"],
            "hero_kill_file": hm["path"],
            "zircon_map_info": {"index": info.get("Index"), "file": stem, "description": info.get("Description", "")},
            "zircon_map_file": zm["path"],
            "relation": rel,
            "size": {"hero_kill": {"width": hm["width"], "height": hm["height"]}, "zircon": {"width": zm["width"], "height": zm["height"]}},
            "entrances_exits": landmark_info(info, links, stem),
            "city_town_safe_zone_landmarks": landmark_info(info, links, stem)["region_landmark_samples"],
            "hero_kill_walkable": walk_summary(hp),
            "zircon_walkable": walk_summary(zp),
            "coordinate_transform": "identity logical-grid coordinates" if direct else "pending landmark mapping; no blind coordinate reuse",
            "coordinate_reuse": "allowed-after-point-check" if direct else "blocked",
            "confidence": "high" if rel == "exact" else "medium" if rel == "renamed" else "low",
            "evidence": {"relation": evidence, "hero_kill_sha256": hm["sha256"], "zircon_sha256": zm["sha256"]},
        })
    stats = {"mapinfo_count": len(mapinfo), "hero_kill_file_count": len(hero), "zircon_file_count": len(zircon), "relation_counts": dict(Counter(x["relation"] for x in out)), "coordinate_reuse_counts": dict(Counter(x["coordinate_reuse"] for x in out))}
    return out, stats


def infer_rule(name: str, region: str, entry: str, identity: str | None) -> tuple[str, list[str], str]:
    text = " ".join(x for x in (name, region, entry, identity or "") if x).casefold()
    if any(k in text for k in ("weapon", "armor", "potion", "book", "grocery", "accessory", "material", "shoe", "store", "shop", "inn", "店", "仓")):
        return "same-store-cluster", ["NPC/Entry/Region contains shop type"], "shop street or same-function region"
    if any(k in text for k in ("move", "teleport", "transport", "portal", "entrance", "gate", "传送", "入口", "门")):
        return "town-entrance-teleporter", ["NPC/Entry/Region contains movement/entrance type"], "town entrance, route gate, or teleport cluster"
    if any(k in text for k in ("notice", "board", "公告")):
        return "town-center-notice", ["NPC/Entry/Region identifies notice/board"], "town center near service cluster"
    if any(k in text for k in ("quest", "doctor", "mentor", "companion", "manager", "任务", "接待")):
        return "town-safezone-service", ["NPC/Entry/Region identifies quest/service role"], "safe zone or task-area entrance"
    return "town-safezone-extra", ["no direct Merchant anchor; preserve business category"], "safe-zone independent walkable point"


def candidate_points(path: Path | None, anchors: list[tuple[int, int]], occupied: set[tuple[int, int]], limit: int = 3) -> list[dict[str, Any]]:
    parsed = cell_flags(path)
    if parsed is None or not anchors:
        return []
    meta, raw = parsed
    width, height = meta["width"], meta["height"]
    candidates: list[tuple[float, int, int, int, int, int]] = []
    for ax, ay in anchors[:20]:
        for radius in (24, 48, 96):
            for dx in range(-radius, radius + 1):
                for dy in range(-radius, radius + 1):
                    x, y = ax + dx, ay + dy
                    if not (3 <= x < width - 3 and 3 <= y < height - 3):
                        continue
                    off = meta["base"] + (x * height + y) * 14
                    if not (raw[off] & 3 == 3) or (x, y) in occupied:
                        continue
                    separation = min((abs(x - ox) + abs(y - oy) for ox, oy in occupied), default=12)
                    score = abs(dx) + abs(dy) - min(separation, 12) * 0.65
                    candidates.append((score, -separation, x, y, ax, ay))
            if candidates:
                break
    candidates.sort()
    seen: set[tuple[int, int]] = set()
    out = []
    for score, negsep, x, y, ax, ay in candidates:
        if (x, y) in seen:
            continue
        seen.add((x, y))
        out.append({"x": x, "y": y, "score": round(score, 2), "anchor": {"x": ax, "y": ay}, "separation": -negsep})
        if len(out) == limit:
            break
    return out


def build_npcs(npc_rows: list[dict[str, Any]], region_rows: list[dict[str, Any]], maps: list[dict[str, Any]], zircon_root: Path, audit: dict[int, dict[str, str]], merchant_source: str) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    rby = {int(r["Index"]): r for r in region_rows}
    mby = {m["original_map"].casefold(): m for m in maps}
    zfiles = map_files(zircon_root)
    occupied: dict[str, set[tuple[int, int]]] = defaultdict(set)
    current: dict[str, list[tuple[int, int]]] = defaultdict(list)
    for n in npc_rows:
        region = rby.get(int((n.get("Region") or {}).get("Index", -1)), {})
        p = region.get("PointRegion") or {}
        cmap = str((region.get("Map") or {}).get("Name", ""))
        if p.get("CenterX") is not None:
            xy = (int(p["CenterX"]), int(p["CenterY"]))
            current[cmap.casefold()].append(xy)
            occupied[cmap.casefold()].add(xy)
    out = []
    for n in sorted(npc_rows, key=lambda x: int(x["Index"])):
        idx = int(n["Index"])
        region = rby.get(int((n.get("Region") or {}).get("Index", -1)), {})
        cmap = str((region.get("Map") or {}).get("Name", ""))
        point = region.get("PointRegion") or {}
        cx, cy = point.get("CenterX"), point.get("CenterY")
        audit_row = audit.get(idx, {})
        old, new = coord(audit_row.get("old")), coord(audit_row.get("new"))
        method = audit_row.get("method", "pending")
        source = audit_row.get("source", "")
        original_identity = None
        original_map = old[0] if old else None
        ox, oy = (old[1], old[2]) if old else (None, None)
        if "A-精确" in method and re.match(r"^\d{2}[A-Za-z]", str(n.get("NPCName", ""))):
            original_identity = str(n["NPCName"])
            match_method = "exact-script-name"
            confidence = "medium"
        elif "C-语义" in method:
            m = re.search(r"(?:Mud3|YXS):([^\s|]+)", source)
            original_identity = m.group(1) if m else None
            match_method = "semantic-audit"
            confidence = "low"
        elif "B-英雄杀" in method:
            match_method = "hero-kill-extra"
            confidence = "medium"
        else:
            match_method = "pending"
            confidence = "low"
        mrow = mby.get(cmap.casefold())
        rel = mrow["relation"] if mrow else "pending"
        zmap = zfiles.get(cmap.casefold())
        current_walk = walkable(zmap, int(cx) if cx is not None else None, int(cy) if cy is not None else None)
        rule, basis, area = infer_rule(str(n.get("NPCName", "")), str(region.get("Description", "")), str((n.get("EntryPage") or {}).get("Name", "")), original_identity)
        anchors = []
        for rr in region_rows:
            if str((rr.get("Map") or {}).get("Name", "")).casefold() != cmap.casefold():
                continue
            label = " ".join(str(rr.get(k, "")) for k in ("_Identity", "Description")).casefold()
            pp = rr.get("PointRegion") or {}
            if pp.get("CenterX") is None:
                continue
            if rule == "same-store-cluster" and any(k in label for k in ("store", "shop", "weapon", "armor", "potion", "book", "grocery", "accessory", "material", "inn", "店", "仓")):
                anchors.append((int(pp["CenterX"]), int(pp["CenterY"])))
            elif rule == "town-entrance-teleporter" and any(k in label for k in ("entrance", "exit", "gate", "teleport", "landing", "入口", "出口", "门", "传送")):
                anchors.append((int(pp["CenterX"]), int(pp["CenterY"])))
            elif rule in {"town-center-notice", "town-safezone-service", "town-safezone-extra"} and any(k in label for k in ("town", "safe", "spawn", "area", "center", "村", "城", "安全")):
                anchors.append((int(pp["CenterX"]), int(pp["CenterY"])))
        if not anchors:
            anchors = current.get(cmap.casefold(), [])[:20]
        if not anchors and cx is not None and cy is not None:
            anchors = [(int(cx), int(cy))]
        target_xy = None
        target_reason = "pending target coordinate"
        candidates: list[dict[str, Any]] = []
        if new and new[0].casefold() == cmap.casefold() and rel in {"exact", "renamed"}:
            target_xy = {"x": new[1], "y": new[2]}
            candidates = [{"x": new[1], "y": new[2], "score": 0, "anchor": {"x": new[1], "y": new[2]}, "separation": 0}]
            target_reason = "audit target coordinate reused only for exact/renamed map relation"
            occupied[cmap.casefold()].add((new[1], new[2]))
        else:
            candidates = candidate_points(zmap, anchors, occupied[cmap.casefold()])
            if candidates:
                target_xy = {"x": candidates[0]["x"], "y": candidates[0]["y"]}
                occupied[cmap.casefold()].add((target_xy["x"], target_xy["y"]))
                target_reason = "walkable topology candidate; manual review required"
        target_walk = walkable(zmap, target_xy["x"], target_xy["y"]) if target_xy else "pending"
        overlap = [prior["current_npc_index"] for prior in out if prior.get("hero_kill_map", "").casefold() == cmap.casefold() and prior.get("hero_kill_xy") == target_xy and target_xy]
        warnings = []
        if target_walk == "fail":
            warnings.append("target coordinate outside map or blocked")
        if overlap:
            warnings.append("target coordinate overlaps another NPC")
        if rel in {"variant", "replacement", "pending"}:
            warnings.append("map relation does not permit blind original-coordinate reuse")
        apply_status = "dry-run" if target_xy and target_walk == "pass" and not overlap and rel in {"exact", "renamed"} else "pending-review"
        out.append({
            "current_npc_index": idx,
            "current_npc_name": n.get("NPCName", ""),
            "old_map": cmap,
            "old_xy": {"x": cx, "y": cy} if cx is not None else None,
            "original_identity": original_identity,
            "original_map": original_map,
            "original_xy": {"x": ox, "y": oy} if ox is not None else None,
            "hero_kill_map": cmap if target_xy else None,
            "hero_kill_xy": target_xy,
            "match_method": match_method,
            "map_relation": rel,
            "confidence": confidence if apply_status == "dry-run" else "low",
            "walkable": {"old": current_walk, "target": target_walk},
            "overlap_with": overlap,
            "apply_status": apply_status,
            "auto_placement_rule": rule,
            "auto_placement_basis": basis + [area],
            "auto_placement_candidates": candidates,
            "target_reason": target_reason,
            "topology_anchors": [{"x": x, "y": y} for x, y in anchors[:20]],
            "identity_source": merchant_source if original_identity is None else ("NpcMover/audit-report.md" if audit_row else merchant_source),
            "warnings": warnings,
            "non_position_fields_untouched": True,
            "historical_audit": audit_row,
        })
    stats = {"npc_count": len(out), "match_method_counts": dict(Counter(x["match_method"] for x in out)), "map_relation_counts": dict(Counter(x["map_relation"] for x in out)), "target_walkable_counts": dict(Counter(x["walkable"]["target"] for x in out)), "apply_status_counts": dict(Counter(x["apply_status"] for x in out)), "overlap_rows": sum(1 for x in out if x["overlap_with"]), "merchant_source": merchant_source, "audit_row_count": len(audit)}
    return out, stats

# Explicit semantic anchors for high-risk names.  No fuzzy Chinese-name rule is
# allowed to map these families to a different identity.
EXPLICIT_MONSTER_MAP = {
    "祖玛教主": (81, "Zuma King", "verified-alias", "high"),
    "赤月恶魔": (75, "Red Moon The Fallen", "verified-alias", "high"),
    "沃玛教主": (65, "Uma King", "verified-alias", "high"),
    "骷髅教主": (121, "Arch Lich Taedu", "verified-alias", "medium"),
    "霸王教主": (115, "Emperor Sa'Woo", "verified-alias", "medium"),
    "半兽人": (22, "Oma", "verified-alias", "medium"),
    "白野猪": (None, None, "conflict-no-direct-zircon-name", "pending"),
}


def norm_name(value: str) -> str:
    return re.sub(r"[^a-z0-9]", "", value.casefold())


def stat_value(monster: dict[str, Any], key: str) -> int | None:
    for row in monster.get("Stats") or []:
        if row.get("Stat") == key:
            try:
                return int(row.get("Value"))
            except (TypeError, ValueError):
                return None
    return None


def build_monster_identity(monsters: list[dict[str, Any]], source_records: list[dict[str, Any]], snapshot: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    by_name = {norm_name(str(m.get("MonsterName", ""))): m for m in monsters}
    old_by_name = {norm_name(str(m.get("name", ""))): m for m in snapshot}
    rows_out = []
    used: dict[int, list[str]] = defaultdict(list)
    source_nonempty = [r for r in source_records if int(r.get("Index", 0)) != 0]
    for source in source_nonempty:
        name = str(source.get("Name", ""))
        mapping = EXPLICIT_MONSTER_MAP.get(name)
        method, confidence, mapped = "pending", "pending", None
        if mapping:
            mapped = next((m for m in monsters if m.get("Index") == mapping[0]), None) if mapping[0] is not None else None
            method, confidence = mapping[2], mapping[3]
        else:
            exact = by_name.get(norm_name(name))
            if exact:
                mapped, method, confidence = exact, "exact-script-name", "high"
            elif norm_name(name) in old_by_name:
                old = old_by_name[norm_name(name)]
                mapped = next((m for m in monsters if int(m.get("Index", -1)) == int(old.get("id", -2))), None)
                method, confidence = "existing-zircon-snapshot-id", "medium" if mapped else "pending"
        if mapped:
            idx = int(mapped["Index"])
            used[idx].append(name)
        rows_out.append({
            "hero_kill_monster_id": source.get("Index"),
            "hero_kill_monster_name": name,
            "hero_kill_attributes": {k: source.get(k) for k in ("Appr", "Race", "Level", "HP", "Exp", "ACMin", "ACMax", "MAC", "DCMin", "DCMax", "DropTable")},
            "mapped_zircon_monster_index": mapped.get("Index") if mapped else None,
            "mapped_zircon_monster_name": mapped.get("MonsterName") if mapped else None,
            "mapping_method": method,
            "confidence": confidence,
            "display_name_note": "identity mapping is separate from display translation",
            "status": "mapped" if mapped else "pending-review",
        })
    conflicts = []
    for idx, names in used.items():
        if len(names) > 1:
            conflicts.append({"zircon_monster_index": idx, "zircon_monster_name": next(m["MonsterName"] for m in monsters if int(m["Index"]) == idx), "hero_kill_names": names, "reason": "multiple source identities map to one Zircon index"})
    mapped_ids = set(used)
    zircon_only = [{"zircon_monster_index": m.get("Index"), "zircon_monster_name": m.get("MonsterName"), "reason": "no reliable hero-kill identity mapping"} for m in monsters if int(m.get("Index", -1)) not in mapped_ids]
    stats = {"zircon_monster_count": len(monsters), "hero_kill_definition_count": len(source_nonempty), "mapped_count": sum(1 for r in rows_out if r["status"] == "mapped"), "pending_count": sum(1 for r in rows_out if r["status"] != "mapped"), "conflict_count": len(conflicts), "zircon_only_count": len(zircon_only)}
    return rows_out, {"stats": stats, "conflicts": conflicts, "zircon_only": zircon_only}


def build_respawns(respawns: list[dict[str, Any]], regions: list[dict[str, Any]], monsters: list[dict[str, Any]], maps: list[dict[str, Any]], zircon_root: Path, source_status: str) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    rby = {int(r["Index"]): r for r in regions}
    mby = {int(m["Index"]): m for m in monsters}
    mapby = {m["original_map"].casefold(): m for m in maps}
    zfiles = map_files(zircon_root)
    out = []
    for r in sorted(respawns, key=lambda x: int(x["Index"])):
        region = rby.get(int((r.get("Region") or {}).get("Index", -1)), {})
        map_name = str((region.get("Map") or {}).get("Name", ""))
        p = region.get("PointRegion") or {}
        x, y = p.get("CenterX"), p.get("CenterY")
        size = region.get("Size", p.get("PointCount"))
        approx_range = round(math.sqrt(max(int(size or 0), 0) / math.pi), 2) if size is not None else None
        monster = mby.get(int((r.get("Monster") or {}).get("Index", -1)), {})
        zfile = zfiles.get(map_name.casefold())
        walk = walkable(zfile, int(x) if x is not None else None, int(y) if y is not None else None)
        out.append({
            "hero_kill_map": None,
            "hero_kill_xy": None,
            "hero_kill_range": None,
            "hero_kill_count": None,
            "hero_kill_monster_name": None,
            "mapped_zircon_monster_index": monster.get("Index"),
            "mapped_zircon_monster_name": monster.get("MonsterName"),
            "old_respawn": {"index": r.get("Index"), "map": map_name, "xy": {"x": x, "y": y} if x is not None else None, "region_index": region.get("Index"), "region_name": region.get("_Identity"), "region_size": size, "count": r.get("Count"), "delay": r.get("Delay"), "respawn_index": r.get("RespawnIndex")},
            "new_respawn": None,
            "mapping_method": "hero-kill-refresh-source-unavailable",
            "confidence": "pending",
            "walkable": walk,
            "overlap": [],
            "apply_status": "blocked",
            "source_status": source_status,
            "range_note": "approximate radius derived from PointRegion size; not a write target",
        })
    return out, {"respawn_count": len(out), "source_status": source_status, "walkable_counts": dict(Counter(x["walkable"] for x in out)), "apply_status_counts": dict(Counter(x["apply_status"] for x in out))}


def write_tsv(path: Path, records: list[dict[str, Any]]) -> None:
    if not records:
        path.write_text("\n", encoding="utf-8")
        return
    keys = list(records[0])
    with path.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=keys, delimiter="\t", extrasaction="ignore")
        writer.writeheader()
        for record in records:
            writer.writerow({k: json.dumps(record[k], ensure_ascii=False) if isinstance(record[k], (dict, list)) else record[k] for k in keys})


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workspace", type=Path, default=Path(__file__).parents[1] / "dbeditor/workspace")
    ap.add_argument("--hero-map-dir", type=Path, default=Path("/home/tetsuya/mir2ei/Map"))
    ap.add_argument("--zircon-map-dir", type=Path, default=Path("/home/tetsuya/development/zircon/Debug/ServerCore/Map"))
    ap.add_argument("--audit", type=Path, default=Path(__file__).with_name("audit-report.md"))
    ap.add_argument("--monster-source", type=Path, default=Path(__file__).parents[2] / "docs/research/mud3-dat-decoded/monster.json")
    ap.add_argument("--monster-snapshot", type=Path, default=Path(__file__).parents[2] / "docs/research/mud3-dat-decoded/monsters_zircon.json")
    ap.add_argument("--hero-spawn", type=Path, default=None)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    mapinfo = rows(args.workspace / "MapInfo.json")
    regions = rows(args.workspace / "MapRegion.json")
    npcs = rows(args.workspace / "NPCInfo.json")
    monsters = rows(args.workspace / "MonsterInfo.json")
    respawns = rows(args.workspace / "RespawnInfo.json")
    links_path = Path(__file__).parents[1] / "maps/map_links_v2.json"
    links = load(links_path) if links_path.exists() else {"links": []}
    maps, map_stats = build_maps(mapinfo, args.hero_map_dir, args.zircon_map_dir, links)
    npc_manifest, npc_stats = build_npcs(npcs, regions, maps, args.zircon_map_dir, audit_rows(args.audit), "pending: Merchant.txt/parsed Merchant snapshot unavailable")
    source_records = load(args.monster_source)["records"] if args.monster_source.exists() else []
    snapshot = load(args.monster_snapshot) if args.monster_snapshot.exists() else []
    monster_identity, identity_meta = build_monster_identity(monsters, source_records, snapshot)
    if args.hero_spawn and args.hero_spawn.exists():
        spawn_status = f"source present but parser not enabled for unknown format: {args.hero_spawn}"
    else:
        spawn_status = "pending: Hero-kill Mon_Def/*.gen/MonGen source unavailable locally; no refresh coordinates invented"
    monster_respawns, respawn_stats = build_respawns(respawns, regions, monsters, maps, args.zircon_map_dir, spawn_status)
    manifest = {
        "manifest_id": "NPC-MONSTER-ALL-MAPS-2026-09-25",
        "mode": "offline-dry-run",
        "database_write": False,
        "coordinate_unit": "logical map grid",
        "sources": {"workspace": str(args.workspace), "hero_kill_maps": str(args.hero_map_dir), "zircon_maps": str(args.zircon_map_dir), "npc_audit": str(args.audit), "hero_kill_monster_definitions": str(args.monster_source), "hero_kill_refresh": str(args.hero_spawn) if args.hero_spawn else None},
        "map_stats": map_stats,
        "npc_stats": npc_stats,
        "monster_identity_stats": identity_meta["stats"],
        "monster_respawn_stats": respawn_stats,
        "maps": maps,
        "npcs": npc_manifest,
        "monster_identity": monster_identity,
        "monster_respawns": monster_respawns,
        "monster_conflicts": identity_meta["conflicts"],
        "zircon_only_monsters": identity_meta["zircon_only"],
        "missing_yxs_refresh": [],
        "missing_yxs_refresh_status": "pending: hero-kill refresh configuration unavailable; cannot classify YXS-only versus Zircon-only refresh rows",
        "shared_checks": {"npc_monster_overlap": "pending: no target monster coordinates", "independent_parser": "this tool parses map cell records independently; verifier runs a second implementation"},
    }
    (args.out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.out / "map_manifest.json").write_text(json.dumps({"manifest_id": manifest["manifest_id"], "stats": map_stats, "maps": maps}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.out / "npc_manifest.json").write_text(json.dumps({"manifest_id": manifest["manifest_id"], "stats": npc_stats, "npcs": npc_manifest}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.out / "monster_gap_manifest.json").write_text(json.dumps({"manifest_id": manifest["manifest_id"], "yxs_only_refresh": None, "yxs_only_status": manifest["missing_yxs_refresh_status"], "zircon_only_identity": identity_meta["zircon_only"], "conflicts": identity_meta["conflicts"], "refresh_source": spawn_status}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    (args.out / "monster_respawn_manifest.json").write_text(json.dumps({"manifest_id": manifest["manifest_id"], "stats": respawn_stats, "respawns": monster_respawns}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    write_tsv(args.out / "map_manifest.tsv", maps)
    write_tsv(args.out / "npc_manifest.tsv", npc_manifest)
    write_tsv(args.out / "monster_identity_manifest.tsv", monster_identity)
    write_tsv(args.out / "monster_respawn_manifest.tsv", monster_respawns)
    print(json.dumps({"out": str(args.out), "map_stats": map_stats, "npc_stats": npc_stats, "monster_identity_stats": identity_meta["stats"], "monster_respawn_stats": respawn_stats}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
