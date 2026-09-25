#!/usr/bin/env python3
"""离线生成 MAP-NPC goal manifest；只读 workspace/.map，不写数据库。"""
from __future__ import annotations
import argparse, hashlib, json, re, struct
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

COORD_RE = re.compile(r"(?P<map>[^()|\s]+)\((?P<x>-?\d+),(?P<y>-?\d+)\)")
TABLE_RE = re.compile(r"^\|\s*(?P<idx>\d+)\s*\|\s*(?P<name>.*?)\s*\|\s*(?P<method>.*?)\s*\|\s*(?P<old>.*?)\s*\|\s*(?P<new>.*?)\s*\|\s*(?P<note>.*?)\s*\|\s*(?P<source>.*?)\s*\|\s*(?P<remark>.*?)\s*\|\s*$")


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def file_index(root: Path) -> dict[str, Path]:
    return {p.stem.casefold(): p for p in root.glob("*.map")}


def meta(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {"present": False, "width": None, "height": None, "bytes": None, "sha256": None}
    raw = path.read_bytes()
    width = height = None
    if len(raw) >= 28:
        width, height = struct.unpack_from("<HH", raw, 22)
    return {"present": True, "path": str(path), "width": width, "height": height,
            "bytes": len(raw), "sha256": hashlib.sha256(raw).hexdigest()}


def grid(path: Path | None) -> tuple[int, int, bytearray] | None:
    if path is None:
        return None
    raw = path.read_bytes()
    if len(raw) < 28:
        return None
    width, height = struct.unpack_from("<HH", raw, 22)
    offset = 28 + (width // 2) * (height // 2) * 3
    if offset + width * height * 14 > len(raw):
        return None
    cells = bytearray(width * height)
    for x in range(width):
        base = offset + x * height * 14
        for y in range(height):
            # Checked independently against Zircon/BotRunner/BotMap.cs.
            cells[x * height + y] = int((raw[base + y * 14] & 3) == 3)
    return width, height, cells


def walkable(g: tuple[int, int, bytearray] | None, x: int | None, y: int | None) -> str:
    if g is None or x is None or y is None:
        return "pending"
    width, height, cells = g
    if not (0 <= x < width and 0 <= y < height):
        return "fail"
    return "pass" if cells[x * height + y] else "fail"


def coord(text: str | None) -> tuple[str, int, int] | None:
    m = COORD_RE.search(text or "")
    return None if not m else (m.group("map"), int(m.group("x")), int(m.group("y")))


def audit_rows(path: Path) -> dict[int, dict[str, str]]:
    rows = {}
    if not path.exists():
        return rows
    for line in path.read_text(encoding="utf-8").splitlines():
        m = TABLE_RE.match(line)
        if m:
            row = m.groupdict(); rows[int(row["idx"])] = row
    return rows


def merchant_rows(path: Path | None) -> tuple[list[dict[str, Any]], str]:
    if path is None or not path.exists():
        return [], "pending: Merchant.txt/parsed Merchant snapshot unavailable"
    try:
        data = read_json(path)
    except (OSError, ValueError) as exc:
        return [], f"pending: Merchant source parse failed: {exc}"
    if isinstance(data, dict): data = data.get("rows", [])
    out = []
    for row in data if isinstance(data, list) else []:
        script = row.get("script", row.get("stem"))
        if script is None or row.get("map") is None or row.get("x") is None or row.get("y") is None:
            continue
        out.append({"script": str(script), "map": str(row["map"]), "x": int(row["x"]), "y": int(row["y"]), "name": row.get("name", "")})
    return out, f"source: {path} ({len(out)} rows)"


def relation(target: Path | None, legacy: Path | None, legacy_hashes: dict[str, list[str]]) -> tuple[str, str]:
    t, o = meta(target), meta(legacy)
    if not t["present"] or not o["present"]:
        if t["present"] and legacy_hashes.get(t["sha256"]):
            return "renamed", f"target bytes match legacy stem(s): {', '.join(legacy_hashes[t['sha256']])}"
        return "pending", "target or original comparison map missing"
    if t["sha256"] == o["sha256"]:
        return "exact", "same local map bytes"
    if (t["width"], t["height"]) == (o["width"], o["height"]):
        return "variant", "same stem/dimensions, different map bytes"
    return "replacement", "same stem, different dimensions and bytes"


def landmark_info(row: dict[str, Any], links: dict[str, Any], stem: str) -> dict[str, Any]:
    regions = row.get("Regions") or []; guards = row.get("Guards") or []
    labels = [str(x.get("Name", "")) for x in regions]
    words = ("town", "store", "warehouse", "gate", "entrance", "exit", "teleport", "spawn", "safe", "area", "村", "店", "仓", "门", "入口", "出口", "传送", "城")
    sample = [x for x in labels if any(w.casefold() in x.casefold() for w in words)]
    neighbours = set()
    for edge in links.get("links", []):
        if isinstance(edge, list) and len(edge) == 2:
            if edge[0] == stem: neighbours.add(edge[1])
            if edge[1] == stem: neighbours.add(edge[0])
    return {"guard_count": len(guards), "guard_samples": [str(x.get("Name", "")) for x in guards[:8]],
            "region_count": len(regions), "region_landmark_samples": sample[:20],
            "connected_maps": sorted(neighbours),
            "entrance_exit_coordinate_evidence": "pending: link snapshot has no coordinate rows"}


def build_maps(mapinfo: list[dict[str, Any]], target_root: Path, legacy_root: Path, links: dict[str, Any]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    targets, originals = file_index(target_root), file_index(legacy_root)
    hashes = defaultdict(list)
    for stem, path in originals.items(): hashes[meta(path)["sha256"]].append(path.stem)
    rows = []
    for m in mapinfo:
        stem = str(m["FileName"]); tp = targets.get(stem.casefold()); op = originals.get(stem.casefold())
        rel, evidence = relation(tp, op, hashes); tm, om = meta(tp), meta(op)
        direct = rel in {"exact", "renamed"}
        rows.append({"original_map": stem, "original_map_name": m.get("Description", ""),
            "hero_kill_map": stem if tm["present"] else None, "hero_kill_file": tm.get("path"),
            "zircon_map_info": {"index": m.get("Index"), "file": stem, "description": m.get("Description", "")},
            "target_dimensions": {"width": tm["width"], "height": tm["height"]},
            "original_dimensions": {"width": om["width"], "height": om["height"]},
            "map_relation": rel, "coordinate_reuse": "pass" if direct else "fail" if rel in {"variant", "replacement"} else "pending",
            "landmarks": landmark_info(m, links, stem),
            "confidence": "high" if rel == "exact" else "medium" if rel == "renamed" else "low",
            "evidence": {"relation": evidence, "target_sha256": tm["sha256"], "original_sha256": om["sha256"], "target_bytes": tm["bytes"], "original_bytes": om["bytes"]}})
    return rows, {"mapinfo_count": len(mapinfo), "target_map_file_count": len(targets), "legacy_map_file_count": len(originals),
        "relation_counts": dict(Counter(x["map_relation"] for x in rows)), "coordinate_reuse_counts": dict(Counter(x["coordinate_reuse"] for x in rows))}


def infer_rule(name: str, region: str, entry: str, identity: str | None) -> tuple[str, list[str], str]:
    text = " ".join(x for x in (name, region, entry, identity or "") if x).casefold()
    if any(k in text for k in ("weapon", "armor", "potion", "book", "grocery", "accessory", "material", "shoe", "store", "shop", "inn")):
        return "same-store-cluster", ["NPC/Entry/Region contains shop type"], "shop street or same-function region"
    if any(k in text for k in ("move", "teleport", "transport", "portal", "传送", "入口", "gate")):
        return "town-entrance-teleporter", ["NPC/Entry/Region contains movement/entrance type"], "town entrance, route gate, or teleport cluster"
    if any(k in text for k in ("notice", "board", "公告")):
        return "town-center-notice", ["NPC/Entry/Region identifies notice/board"], "town center near service cluster"
    if any(k in text for k in ("quest", "doctor", "mentor", "companion", "manager", "任务", "接待")):
        return "town-safezone-service", ["NPC/Entry/Region identifies quest/service role"], "safe zone or task-area entrance"
    return "town-safezone-extra", ["no direct Merchant anchor; preserve business category"], "safe zone independent walkable point"


def candidate_points(g: tuple[int, int, bytearray] | None, anchors: list[tuple[int, int]], occupied: set[tuple[int, int]], limit: int = 3) -> list[dict[str, Any]]:
    if g is None or not anchors: return []
    width, height, cells = g; candidates = []
    for ax, ay in anchors:
        radius = max(width, height) if len(anchors) == 1 and (ax, ay) == anchors[0] else 24
        for dx in range(-radius, radius + 1):
            for dy in range(-radius, radius + 1):
                x, y = ax + dx, ay + dy
                if x < 3 or y < 3 or x >= width - 3 or y >= height - 3 or not (0 <= x < width and 0 <= y < height): continue
                if not cells[x * height + y] or (x, y) in occupied: continue
                distance = abs(dx) + abs(dy)
                separation = min((abs(x - ox) + abs(y - oy) for ox, oy in occupied), default=12)
                score = distance - min(separation, 12) * 0.65
                candidates.append((score, -separation, x, y, ax, ay))
    candidates.sort()
    seen = set(); out = []
    for score, negsep, x, y, ax, ay in candidates:
        if (x, y) in seen: continue
        seen.add((x, y)); out.append({"x": x, "y": y, "score": round(score, 2), "anchor": {"x": ax, "y": ay}, "separation": -negsep})
        if len(out) >= limit: break
    return out


def build_npcs(npcs: list[dict[str, Any]], regions: list[dict[str, Any]], maps: list[dict[str, Any]], mapinfo: list[dict[str, Any]], target_root: Path, audits: dict[int, dict[str, str]], merchants: list[dict[str, Any]], merchant_status: str) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    rby = {int(x["Index"]): x for x in regions}; mby = {x["original_map"].casefold(): x for x in maps}; info_by_stem = {str(x["FileName"]).casefold(): x for x in mapinfo}
    files = file_index(target_root); grids = {stem: grid(path) for stem, path in files.items()}
    merchant_by = defaultdict(list)
    for row in merchants: merchant_by[row["script"]].append(row)
    # Existing points are blocked first, then successfully selected target points.
    occupied = defaultdict(set)
    current_by_map = defaultdict(list)
    for n in npcs:
        r = rby.get(int(n["Region"]["Index"])); mp = str(((r or {}).get("Map") or {}).get("Name", "")); p = (r or {}).get("PointRegion") or {}
        if p.get("CenterX") is not None: current_by_map[mp.casefold()].append((int(p["CenterX"]), int(p["CenterY"])))
    for stem, pts in current_by_map.items(): occupied[stem].update(pts)
    output = []
    for n in npcs:
        idx = int(n["Index"]); r = rby.get(int(n["Region"]["Index"])); map_obj = (r or {}).get("Map") or {}; cmap = str(map_obj.get("Name", "")); point = (r or {}).get("PointRegion") or {}; cx, cy = point.get("CenterX"), point.get("CenterY")
        audit = audits.get(idx, {}); method = audit.get("method", ""); old, new = coord(audit.get("old")), coord(audit.get("new")); source = audit.get("source", "")
        script = re.search(r"(?:Mud3|YXS):([^\s|]+)", source); exact = n["NPCName"] if re.match(r"^\d{2}[A-Za-z]", str(n["NPCName"])) else None
        original_identity = original_map = None; ox = oy = None; match = "pending"; identity_status = "pending"; confidence = "low"; identity_source = merchant_status
        if merchant_by.get(str(n["NPCName"])):
            q = merchant_by[str(n["NPCName"])][0]; original_identity, original_map, ox, oy = q["script"], q["map"], q["x"], q["y"]; match, identity_status, confidence = "exact-name", "merchant-source", "high"
        elif "A-精确" in method and exact and old:
            original_identity, original_map, ox, oy = exact, old[0], old[1], old[2]; match, identity_status, confidence = "exact-name", "audit-reconstructed", "medium"; identity_source = "NpcMover/audit-report.md"
        elif "C-语义" in method and script and new:
            original_identity, original_map, ox, oy = script.group(1), new[0], new[1], new[2]; match, identity_status, confidence = "semantic", "audit-reconstructed", "low"; identity_source = "NpcMover/audit-report.md"
        elif "B-英雄杀" in method:
            identity_status, confidence, identity_source = "yxs-extra", "medium", "NpcMover/audit-report.md"
        elif method:
            identity_status, identity_source = "no-original-anchor", "NpcMover/audit-report.md"
        map_row = mby.get(cmap.casefold()); rel = map_row["map_relation"] if map_row else "pending"; g = grids.get(cmap.casefold()); current_walk = walkable(g, cx, cy)
        rule, basis, area = infer_rule(str(n.get("NPCName", "")), str(r.get("Description", "") if r else ""), str((n.get("EntryPage") or {}).get("Name", "")), original_identity)
        # Region centers and current NPCs provide evidence-based topology anchors.
        anchors = []
        for rr in regions:
            mm = (rr.get("Map") or {}).get("Name", "")
            if str(mm).casefold() != cmap.casefold(): continue
            label = " ".join(str(rr.get(k, "")) for k in ("_Identity", "Description")).casefold(); pp = rr.get("PointRegion") or {}
            if pp.get("CenterX") is None: continue
            if rule == "same-store-cluster" and any(k in label for k in ("store", "shop", "weapon", "armor", "potion", "book", "grocery", "accessory", "material", "inn", "店", "仓")): anchors.append((pp["CenterX"], pp["CenterY"]))
            elif rule == "town-entrance-teleporter" and any(k in label for k in ("entrance", "exit", "gate", "teleport", "landing", "入口", "出口", "门", "传送")): anchors.append((pp["CenterX"], pp["CenterY"]))
            elif rule in {"town-center-notice", "town-safezone-service", "town-safezone-extra"} and any(k in label for k in ("town", "safe", "spawn", "area", "center", "村", "城", "安全")): anchors.append((pp["CenterX"], pp["CenterY"]))
        if not anchors: anchors = current_by_map.get(cmap.casefold(), [])[:]
        if not anchors and cx is not None and cy is not None: anchors = [(cx, cy)]
        hero_map, hx, hy, hero_walk = None, None, None, "pending"; target_reason = ""; delete_reason = None; delete_source = None
        if rel == "pending":
            # A current map without a reliable original/EI counterpart is a deletion
            # candidate, never an auto-placement target.
            delete_reason = "旧版/EI 不存在可靠对应地图，旧版不存在该地图/该 NPC 无目标地图"
            delete_source = f"map_manifest:{cmap} relation=pending; target={map_row and map_row['evidence'].get('target_sha256')}; original={map_row and map_row['evidence'].get('original_sha256')}"
            candidates = []; target_reason = "delete candidate: no reliable original map target"; status = "blocked"
        elif identity_status in {"yxs-extra", "no-original-anchor"} or (original_identity and rel not in {"exact", "renamed"}):
            candidates = candidate_points(g, anchors, occupied[cmap.casefold()])
            if candidates:
                hx, hy = candidates[0]["x"], candidates[0]["y"]; hero_map = cmap; hero_walk = walkable(g, hx, hy); occupied[cmap.casefold()].add((hx, hy)); target_reason = "auto-placement from walkable grid, topology anchors, and overlap exclusion"
            else:
                candidates = []; target_reason = "no walkable candidate from available topology anchors"
        elif original_identity and original_map and original_map.casefold() == cmap.casefold():
            hx, hy, hero_map = ox, oy, cmap; hero_walk = walkable(g, hx, hy); candidates = [{"x": hx, "y": hy, "score": 0, "anchor": {"x": hx, "y": hy}, "separation": 0}]; occupied[cmap.casefold()].add((hx, hy)); target_reason = "direct original coordinate reuse"
        else:
            candidates = []; target_reason = "original identity/map binding pending"
        overlap = []
        if hx is not None:
            for prior in output:
                p = prior.get("hero_kill_xy")
                if p and (prior.get("hero_kill_map") or "").casefold() == cmap.casefold() and p["x"] == hx and p["y"] == hy: overlap.append(prior["current_npc_index"])
        warns = ([] if hero_walk != "fail" else ["target coordinate outside map or blocked"])
        if overlap: warns.append("target coordinate overlaps another NPC")
        if rel in {"variant", "replacement", "pending"} and original_identity: warns.append("map relation blocks blind original-coordinate write")
        if delete_reason: warns.append(delete_reason)
        auto_conf = "high" if candidates and rule != "town-safezone-extra" and len(anchors) >= 2 else "medium" if candidates else "low"
        if identity_status == "yxs-extra" and candidates: confidence = auto_conf
        if delete_reason: status = "blocked"
        else: status = "dry-run" if hx is not None and hero_walk == "pass" and not overlap else "blocked"
        output.append({"current_npc_index": idx, "current_npc_name": n.get("NPCName", ""), "current_map": cmap, "current_xy": {"x": cx, "y": cy},
            "original_identity": original_identity, "original_map": original_map, "original_xy": {"x": ox, "y": oy} if ox is not None else None,
            "hero_kill_map": hero_map, "hero_kill_xy": {"x": hx, "y": hy} if hx is not None else None,
            "match_method": match, "identity_status": identity_status, "map_relation": rel, "confidence": confidence,
            "walkable_check": hero_walk, "current_walkable_check": current_walk, "visual_check": "pending", "apply_status": status,
            "delete_candidate": bool(delete_reason), "delete_reason": delete_reason, "delete_source": delete_source,
            "auto_placement_rule": rule, "auto_placement_basis": basis + [area], "auto_placement_candidates": candidates,
            "topology_anchors": [{"x": x, "y": y} for x, y in anchors[:20]], "target_reason": target_reason,
            "region": {"index": r.get("Index") if r else None, "name": r.get("_Identity") if r else None, "description": r.get("Description") if r else None},
            "entry_page": (n.get("EntryPage") or {}).get("Name"), "identity_source": identity_source, "warnings": warns,
            "historical_audit": {"method": method, "old": audit.get("old"), "new": audit.get("new"), "note": audit.get("note"), "source": source}})
        output.append({"current_npc_index": idx, "current_npc_name": n.get("NPCName", ""), "current_map": cmap, "current_xy": {"x": cx, "y": cy},
            "original_identity": original_identity, "original_map": original_map, "original_xy": {"x": ox, "y": oy} if ox is not None else None,
            "hero_kill_map": hero_map, "hero_kill_xy": {"x": hx, "y": hy} if hx is not None else None,
            "match_method": match, "identity_status": identity_status, "map_relation": rel, "confidence": confidence,
            "walkable_check": hero_walk, "current_walkable_check": current_walk, "visual_check": "pending", "apply_status": status,
            "auto_placement_rule": rule, "auto_placement_basis": basis + [area], "auto_placement_candidates": candidates,
            "topology_anchors": [{"x": x, "y": y} for x, y in anchors[:20]], "target_reason": target_reason,
            "region": {"index": r.get("Index") if r else None, "name": r.get("_Identity") if r else None, "description": r.get("Description") if r else None},
            "entry_page": (n.get("EntryPage") or {}).get("Name"), "identity_source": identity_source, "warnings": warns,
            "historical_audit": {"method": method, "old": audit.get("old"), "new": audit.get("new"), "note": audit.get("note"), "source": source}})
    stats = {"npc_count": len(output), "match_method_counts": dict(Counter(x["match_method"] for x in output)), "identity_status_counts": dict(Counter(x["identity_status"] for x in output)), "map_relation_counts": dict(Counter(x["map_relation"] for x in output)), "walkable_counts": dict(Counter(x["walkable_check"] for x in output)), "apply_status_counts": dict(Counter(x["apply_status"] for x in output)), "auto_rule_counts": dict(Counter(x["auto_placement_rule"] for x in output)), "merchant_source": merchant_status, "audit_row_count": len(audits)}
    return output, stats


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workspace", type=Path, default=Path(__file__).parents[1] / "dbeditor/workspace")
    ap.add_argument("--target-map-dir", type=Path, default=Path("/home/tetsuya/development/zircon/Debug/ServerCore/Map"))
    ap.add_argument("--legacy-map-dir", type=Path, default=Path("/home/tetsuya/mir2ei/Map"))
    ap.add_argument("--audit", type=Path, default=Path(__file__).with_name("audit-report.md"))
    ap.add_argument("--merchant", type=Path, default=None)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args(); args.out.mkdir(parents=True, exist_ok=True)
    maps_info = read_json(args.workspace / "MapInfo.json")["rows"]; region_rows = read_json(args.workspace / "MapRegion.json")["rows"]; npc_rows = read_json(args.workspace / "NPCInfo.json")["rows"]
    links_path = Path(__file__).parents[1] / "maps/map_links_v2.json"; links = read_json(links_path) if links_path.exists() else {"links": []}
    map_rows, map_stats = build_maps(maps_info, args.target_map_dir, args.legacy_map_dir, links)
    merchants, merchant_status = merchant_rows(args.merchant); audits = audit_rows(args.audit)
    npc_out, npc_stats = build_npcs(npc_rows, region_rows, map_rows, maps_info, args.target_map_dir, audits, merchants, merchant_status)
    manifest = {"manifest_id": "MAP-NPC-2026-09-25", "mode": "offline-dry-run", "database_write": False, "sources": {"workspace": str(args.workspace), "target_maps": str(args.target_map_dir), "legacy_maps": str(args.legacy_map_dir), "audit": str(args.audit), "merchant": str(args.merchant) if args.merchant else None, "merchant_status": merchant_status, "map_links": str(links_path)}, "map_stats": map_stats, "npc_stats": npc_stats, "maps": map_rows, "npcs": npc_out}
    (args.out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    (args.out / "map_manifest.json").write_text(json.dumps({"manifest_id": manifest["manifest_id"], "stats": map_stats, "maps": map_rows}, ensure_ascii=False, indent=2), encoding="utf-8")
    (args.out / "npc_manifest.json").write_text(json.dumps({"manifest_id": manifest["manifest_id"], "stats": npc_stats, "npcs": npc_out}, ensure_ascii=False, indent=2), encoding="utf-8")
    (args.out / "summary.json").write_text(json.dumps({"manifest_id": manifest["manifest_id"], "map_stats": map_stats, "npc_stats": npc_stats}, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"out": str(args.out), "map_stats": map_stats, "npc_stats": npc_stats}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
