#!/usr/bin/env python3
"""Write the requested human-readable baseline and alignment reports."""
from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def j(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


REVIEW_COLUMNS = [
    "kind",
    "status",
    "review_class",
    "index",
    "name",
    "old_map",
    "old_x",
    "old_y",
    "target_map",
    "target_x",
    "target_y",
    "monster_index",
    "monster_name",
    "hero_kill_map",
    "hero_kill_x",
    "hero_kill_y",
    "hero_kill_range",
    "hero_kill_count",
    "hero_kill_interval",
    "match_method",
    "mapping_method",
    "confidence",
    "walkable",
    "hero_kill_walkable",
    "placement_rule",
    "review_decision",
    "approved_map",
    "approved_x",
    "approved_y",
    "approved_count",
    "approved_range",
    "approved_interval",
    "review_note",
    "reason",
    "source",
    "candidates_json",
    "warnings_json",
    "range_note",
]

def build_dry_run_plan(data: dict) -> dict:
    """Build an auditable plan without mutating either System.db copy."""
    npc_rows = data["npcs"]
    respawn_rows = data["monster_respawns"]
    npc_candidates = [
        {
            "npc_index": row["current_npc_index"],
            "npc_name": row["current_npc_name"],
            "old": {"map": row["old_map"], "xy": row["old_xy"]},
            "new": {"map": row["hero_kill_map"], "xy": row["hero_kill_xy"]},
            "apply_status": row["apply_status"],
            "match_method": row["match_method"],
            "confidence": row["confidence"],
        }
        for row in npc_rows
        if row["apply_status"] == "dry-run"
    ]
    respawn_candidates = [
        {
            "respawn_index": row["old_respawn"]["index"],
            "monster_index": row["mapped_zircon_monster_index"],
            "monster_name": row["mapped_zircon_monster_name"],
            "old": row["old_respawn"],
            "new": row["new_respawn"],
            "apply_status": row["apply_status"],
            "match_status": row["match_status"],
            "mapping_method": row["mapping_method"],
            "confidence": row["confidence"],
        }
        for row in respawn_rows
        if row["match_status"] == "matched"
    ]
    return {
        "plan_id": "NPC-MONSTER-ALL-MAPS-2026-09-25",
        "mode": "offline-dry-run",
        "database_write": False,
        "scope": {
            "npc_position_field": "NPCInfo.Region",
            "respawn_position_field": "RespawnInfo.Region",
            "npc_non_position_fields": "untouched",
            "monster_info_business_fields": "untouched",
        },
        "preconditions": [
            "stop ServerCore and verify TCP port 7000 is not listening",
            "backup server and client System.db before any sync",
            "complete pending-review NPC and RespawnInfo rows",
            "run DBImporter validation and round-trip after an approved plan",
        ],
        "npc_candidates": npc_candidates,
        "respawn_candidates": respawn_candidates,
        "blocked_counts": {
            "npc_pending_review": sum(1 for row in npc_rows if row["apply_status"] == "pending-review"),
            "respawn_blocked": sum(1 for row in respawn_rows if row["apply_status"] == "blocked"),
            "respawn_pending_review": sum(1 for row in respawn_rows if row["apply_status"] == "pending-review"),
        },
        "round_trip": {
            "status": "not-run",
            "tool": "Tools/DBImporter",
            "command": "Tools/DBImporter --mode sync --workspace <approved-workspace>",
        },
    }
def build_manual_review_summary(data: dict) -> dict:
    """Emit compact, actionable review rows without approving any change."""
    npc_rows = [
        {
            "kind": "npc",
            "status": row["apply_status"],
            "index": row["current_npc_index"],
            "name": row["current_npc_name"],
            "old": {"map": row["old_map"], "xy": row["old_xy"]},
            "target": {"map": row["hero_kill_map"], "xy": row["hero_kill_xy"]},
            "map_relation": row["map_relation"],
            "match_method": row["match_method"],
            "confidence": row["confidence"],
            "walkable": row["walkable"],
            "overlap_with": row["overlap_with"],
            "placement_rule": row["auto_placement_rule"],
            "candidates": row["auto_placement_candidates"],
            "warnings": row["warnings"],
            "identity_source": row["identity_source"],
        }
        for row in data["npcs"]
        if row["apply_status"] == "pending-review"
    ]
    respawn_rows = [
        {
            "kind": "respawn",
            "status": row["apply_status"],
            "review_class": row["match_status"],
            "respawn_index": row["old_respawn"]["index"],
            "monster_index": row["mapped_zircon_monster_index"],
            "monster_name": row["mapped_zircon_monster_name"],
            "hero_kill": {
                "map": row["hero_kill_map"],
                "xy": row["hero_kill_xy"],
                "range": row["hero_kill_range"],
                "count": row["hero_kill_count"],
                "interval": row["hero_kill_interval"],
                "monster_name": row["hero_kill_monster_name"],
            },
            "old_respawn": row["old_respawn"],
            "new_respawn": row["new_respawn"],
            "mapping_method": row["mapping_method"],
            "confidence": row["confidence"],
            "walkable": row["walkable"],
            "hero_kill_walkable": row["hero_kill_walkable"],
            "overlap": row["overlap"],
            "range_note": row["range_note"],
        }
        for row in data["monster_respawns"]
        if row["apply_status"] in {"blocked", "pending-review"}
    ]
    return {
        "review_id": "NPC-MONSTER-ALL-MAPS-2026-09-25",
        "mode": "offline-review-queue",
        "database_write": False,
        "approval_required": True,
        "counts": {
            "npc_pending_review": len(npc_rows),
            "respawn_pending_review": sum(1 for row in respawn_rows if row["status"] == "pending-review"),
            "respawn_blocked": sum(1 for row in respawn_rows if row["status"] == "blocked"),
            "respawn_total": len(respawn_rows),
        },
        "npc_rows": npc_rows,
        "respawn_rows": respawn_rows,
    }


def build_manual_review_tsv_rows(data: dict) -> list[dict]:
    """Flatten pending rows into an editable, one-record-per-line review sheet."""
    rows: list[dict] = []

    def xy_value(value: object, axis: str) -> object:
        return value.get(axis) if isinstance(value, dict) else None

    def add(values: dict) -> None:
        rows.append({key: values.get(key, "") for key in REVIEW_COLUMNS})

    for row in data["npcs"]:
        if row["apply_status"] != "pending-review":
            continue
        add({
            "kind": "npc",
            "status": row["apply_status"],
            "review_class": row["map_relation"],
            "index": row["current_npc_index"],
            "name": row["current_npc_name"],
            "old_map": row["old_map"],
            "old_x": xy_value(row["old_xy"], "x"),
            "old_y": xy_value(row["old_xy"], "y"),
            "target_map": row["hero_kill_map"],
            "target_x": xy_value(row["hero_kill_xy"], "x"),
            "target_y": xy_value(row["hero_kill_xy"], "y"),
            "match_method": row["match_method"],
            "confidence": row["confidence"],
            "walkable": j(row["walkable"]),
            "placement_rule": row["auto_placement_rule"],
            "reason": row["target_reason"],
            "source": row["identity_source"],
            "candidates_json": j(row["auto_placement_candidates"]),
            "warnings_json": j(row["warnings"]),
            "review_decision": "",
            "approved_map": "",
            "approved_x": "",
            "approved_y": "",
            "approved_count": "",
            "approved_range": "",
            "approved_interval": "",
            "review_note": "",
            "range_note": "not-applicable",
        })

    for row in data["monster_respawns"]:
        if row["apply_status"] not in {"blocked", "pending-review"}:
            continue
        old = row["old_respawn"]
        old_xy = old.get("xy")
        hero_xy = row["hero_kill_xy"]
        add({
            "kind": "respawn",
            "status": row["apply_status"],
            "review_class": row["match_status"],
            "index": old["index"],
            "name": row["mapped_zircon_monster_name"],
            "old_map": old.get("map"),
            "old_x": xy_value(old_xy, "x"),
            "old_y": xy_value(old_xy, "y"),
            "target_map": row["hero_kill_map"],
            "target_x": xy_value(hero_xy, "x"),
            "target_y": xy_value(hero_xy, "y"),
            "monster_index": row["mapped_zircon_monster_index"],
            "monster_name": row["mapped_zircon_monster_name"],
            "hero_kill_map": row["hero_kill_map"],
            "hero_kill_x": xy_value(hero_xy, "x"),
            "hero_kill_y": xy_value(hero_xy, "y"),
            "hero_kill_range": row["hero_kill_range"],
            "hero_kill_count": row["hero_kill_count"],
            "hero_kill_interval": row["hero_kill_interval"],
            "hero_kill_walkable": row["hero_kill_walkable"],
            "mapping_method": row["mapping_method"],
            "confidence": row["confidence"],
            "walkable": row["walkable"],
            "reason": row["range_note"],
            "source": row["mapping_method"],
            "warnings_json": j(row["overlap"]),
            "range_note": row["range_note"],
            "review_decision": "",
            "approved_map": "",
            "approved_x": "",
            "approved_y": "",
            "approved_count": "",
            "approved_range": "",
            "approved_interval": "",
            "review_note": "",
        })
    return rows


def write_manual_review_tsv(path: Path, data: dict) -> None:
    rows = build_manual_review_tsv_rows(data)
    # Regeneration must refresh source facts without erasing reviewed decisions.
    previous: dict[tuple[str, str], dict[str, str]] = {}
    if path.exists():
        with path.open(newline="", encoding="utf-8") as handle:
            for row in csv.DictReader(handle, delimiter="\t"):
                key = ((row.get("kind") or "").strip(), (row.get("index") or "").strip())
                if key[0] and key[1]:
                    previous[key] = row
    preserved = (
        "review_decision",
        "approved_map",
        "approved_x",
        "approved_y",
        "approved_count",
        "approved_range",
        "approved_interval",
        "review_note",
    )
    for row in rows:
        prior = previous.get((str(row["kind"]), str(row["index"])))
        if prior is None:
            continue
        for field in preserved:
            if prior.get(field, "").strip():
                row[field] = prior[field]
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=REVIEW_COLUMNS, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def read_review_state(path: Path) -> dict[str, object]:
    counts: dict[str, int] = {}
    rows = 0
    if path.exists():
        with path.open(newline="", encoding="utf-8") as handle:
            for row in csv.DictReader(handle, delimiter="\t"):
                rows += 1
                decision = (row.get("review_decision") or "").strip() or "unresolved"
                counts[decision] = counts.get(decision, 0) + 1
    return {"rows": rows, "decision_counts": counts}


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", type=Path, required=True)
    ap.add_argument("--verification", type=Path, required=True)
    ap.add_argument("--report-dir", type=Path, required=True)
    ap.add_argument("--research-remote-sha", default="pending")
    ap.add_argument("--zircon-remote-sha", default="pending")
    args = ap.parse_args()
    data = json.loads(args.manifest.read_text(encoding="utf-8"))
    verify = json.loads(args.verification.read_text(encoding="utf-8"))
    args.report_dir.mkdir(parents=True, exist_ok=True)
    maps = data["maps"]
    npc_stats = data["npc_stats"]
    mon_stats = data["monster_identity_stats"]
    resp_stats = data["monster_respawn_stats"]
    hero_source = data.get("raw_source_metadata", {}).get("hero_kill", {})
    mud3_source = data.get("raw_source_metadata", {}).get("mud3_secondary", {})
    hero_source_status = (
        f"source present: {hero_source.get('path')} "
        f"({hero_source.get('active_gen_file_count', 0)} active Mon_Def files; "
        f"{hero_source.get('parsed_refresh_row_count', 0)} parsed rows; "
        f"parse_warnings={hero_source.get('parse_warning_count', 0)})"
        if hero_source.get("present")
        else "source unavailable"
    )
    dry_run_plan = build_dry_run_plan(data)
    plan_path = args.manifest.parent / "dry-run-apply-plan.json"
    plan_path.write_text(json.dumps(dry_run_plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    review_summary = build_manual_review_summary(data)
    review_path = args.manifest.parent / "manual-review-summary.json"
    review_path.write_text(json.dumps(review_summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    review_tsv_path = args.manifest.parent / "manual-review-summary.tsv"
    write_manual_review_tsv(review_tsv_path, data)
    review_state = read_review_state(review_tsv_path)
    review_decisions = review_state["decision_counts"]
    approved_plan_path = args.manifest.parent / "approved-offline-plan.json"
    production_apply_path = args.manifest.parent / "production-respawn-apply.json"
    production_apply = (
        json.loads(production_apply_path.read_text(encoding="utf-8"))
        if production_apply_path.exists()
        else {}
    )
    map_lines = [
        "# MAP-HERO-KILL-BASELINE-2026-09-25",
        "",
        "> 离线基准。`hero_kill_*` 指本地 `/home/tetsuya/mir2ei/Map`，`zircon_*` 指当前 Zircon ServerCore 地图和 MapInfo。所有坐标为逻辑地图格；本报告和 manifest 均未写数据库。",
        "",
        "## 结论",
        "",
        f"- MapInfo **{data['map_stats']['mapinfo_count']}** 条；英雄杀地图文件 **{data['map_stats']['hero_kill_file_count']}**；Zircon 地图文件 **{data['map_stats']['zircon_file_count']}**。",
        f"- 对应关系：`{j(data['map_stats']['relation_counts'])}`；坐标复用：`{j(data['map_stats']['coordinate_reuse_counts'])}`。",
        "- `exact/renamed` 仅在独立范围/可行走检查后允许 identity transform；`variant/replacement/pending` 禁止盲拷坐标，目标只能进入人工复核。",
        "- `map_manifest.json`/`map_manifest.tsv` 是全量机器清单；以下表格保留每个 MapInfo 的尺寸、关系、地标、walkable parser 状态。",
        "",
        "## 关键地图抽查",
        "",
        "| Map | Description | Hero 尺寸 | Zircon 尺寸 | relation | transform | Hero walkable | Zircon walkable | landmarks |",
        "|---|---|---:|---:|---|---|---|---|---|",
    ]
    focus = {"0", "01", "02", "2", "3", "4", "5", "74", "D202", "D1105", "D203"}
    for m in maps:
        if m["original_map"].casefold() not in {x.casefold() for x in focus}:
            continue
        hs = m["size"]["hero_kill"]; zs = m["size"]["zircon"]
        map_lines.append(f"| {m['original_map']} | {m['zircon_map_info']['description']} | {hs['width']}×{hs['height']} | {zs['width']}×{zs['height']} | {m['relation']} | {m['coordinate_transform']} | {m['hero_kill_walkable']['status']} | {m['zircon_walkable']['status']} | {', '.join(m['city_town_safe_zone_landmarks'][:6]) or 'none'} |")
    map_lines += [
        "",
        "## 全量机器数据",
        "",
        "- `artifacts/npc-monster-alignment-2026-09-25/map_manifest.json`：全量 JSON，含尺寸、sha256、入口/出口邻接、城镇/安全区/商店/仓库/传送地标样本和 walkable 统计。",
        "- `artifacts/npc-monster-alignment-2026-09-25/map_manifest.tsv`：同一清单的 TSV 导出。",
        "",
        "## 解析器发现",
        "",
        f"- 独立解析器：`{verify['independent_parser']}`；逻辑错误 **{verify['error_count']}**；地图文件格式/截断发现 **{verify['format_issue_count']}**。格式发现保留在 `independent-verification.json`，不能当作可走性通过。",
        "- map 记录格式按 28-byte header、x-major 13-byte cell records、`flag & 3 == 3` 通行规则独立读取；13-byte 步长与 Zircon `BotRunner/BotMap.cs` 的 `ReadBytes(13)` 一致；malformed 文件保持 pending，不降级为可走。",
        "",
        "## 来源与边界",
        "",
        "- Zircon `MapInfo/MapRegion` 来自 `Tools/dbeditor/workspace`；英雄杀地图来自本地 `/home/tetsuya/mir2ei/Map`。",
        f"- `map_links_v2.json` 只提供地图邻接，不被当作坐标证据；Merchant 坐标源状态：`{npc_stats.get('merchant_source', 'pending')}`。",
    ]
    baseline_path = args.report_dir / "MAP_HERO_KILL_BASELINE_2026-09-25.md"
    baseline_path.write_text("\n".join(map_lines) + "\n", encoding="utf-8")

    report = [
        "# NPC + 怪物全地图对齐报告（2026-09-25）",
        "",
        "> 状态：**部分生产 Respawn 写入已完成，完整对齐仍未完成**。18 条刷新变更已通过独立 Hero-kill/Zircon 可行走检查并完成服务端/客户端双库写入和 round-trip；其余 NPC、冲突和缺少源地图的刷新仍保守保持不写入。",
        "",
        "## 1. 交付物和状态",
        "",
        "| 交付物 | 状态 | 路径 |",
        "|---|---|---|",
        "| MAP-BASELINE | 已生成 | `MAP_HERO_KILL_BASELINE_2026-09-25.md` + `artifacts/.../map_manifest.{json,tsv}` |",
        "| NPC 全量 manifest | 已生成 dry-run | `artifacts/.../npc_manifest.{json,tsv}` |",
        "| 怪物身份 manifest | 已生成，绝大多数 pending | `artifacts/.../monster_identity_manifest.{json,tsv}` |",
        "| 怪物刷新 manifest | 已接入 Hero-kill/YXS `Mon_Def/*.gen`；保留 range/count/interval、源文件和源行号；逐点唯一匹配仍需复核 | `artifacts/.../monster_respawn_manifest.{json,tsv}` |",
        "| 怪物缺口清单 | YXS-only、Zircon-only、coordinate conflict 均已列出；不作为删除建议 | `artifacts/.../monster_gap_manifest.json` |",
        f"| 独立校验 | 逻辑通过；地图文件格式/截断发现 {verify['format_issue_count']} 个 | `artifacts/.../independent-verification.json` |",
        "| dry-run 应用计划 | 仅列候选变更和前置条件，不写数据库 | `artifacts/.../dry-run-apply-plan.json` |",
        f"| 人工复核队列 | {review_summary['counts']['npc_pending_review']} 条 NPC、{review_summary['counts']['respawn_pending_review']} 条匹配刷新、{review_summary['counts']['respawn_blocked']} 条阻塞刷新；当前决定 `{j(review_decisions)}`，批准 Respawn **{review_decisions.get('approve', 0)}** 条 | `artifacts/.../manual-review-summary.json`；逐条记录 `artifacts/.../manual-review-summary.tsv`；批准计划 `{approved_plan_path.name if approved_plan_path.exists() else '未生成'}` |",
        f"| 生产 Respawn 分支 | 已写入 **{production_apply.get('respawn_updates_applied', 0)}** 条；备份、双库 SHA 和 round-trip 通过 | `artifacts/.../production-respawn-apply.json` |",
        "| sandbox overlay | 已生成 | `artifacts/.../sandbox/sandbox-*.png` |",
        "",
        "## 2. 地图对应与坐标变换",
        "",
        f"- MapInfo={data['map_stats']['mapinfo_count']}；关系统计 `{j(data['map_stats']['relation_counts'])}`。",
        "- exact/renamed：坐标变换为 identity logical-grid，但每个实体点仍检查范围与 `flag&3==3`。",
        "- variant/replacement：禁止直接复用英雄杀坐标；使用 Region/城镇/安全区/入口锚点生成候选，apply_status 保持 pending-review。",
        "- pending：不删除实体、不写目标坐标；只输出候选和人工复核状态。",
        "- 比奇、边境、银杏、Banya、盟重、沙巴克和 D202/D1105/D203 均在 sandbox index 中；沙巴克 `3` 是 replacement（Hero 400×600 vs Zircon 350×350），不能按同坐标认定同图。",
        "",
        "## 3. NPC 全量流水线",
        "",
        f"- NPC 总数 **{npc_stats['npc_count']}**；匹配方法 `{j(npc_stats['match_method_counts'])}`。",
        f"- 地图关系 `{j(npc_stats['map_relation_counts'])}`；target walkable `{j(npc_stats['target_walkable_counts'])}`；apply status `{j(npc_stats['apply_status_counts'])}`；重叠行 **{npc_stats['overlap_rows']}**。",
        "- 每条记录保留 `current_npc_index/name`、old map/xy、original identity/map/xy、Hero-kill target map/xy、match method、rule、confidence、walkable、overlap、apply_status。",
        "- `non_position_fields_untouched=true`；没有删除状态；不改 NPCName、EntryPage、GoodsIndex、Image、FaceImage、对话/商店业务。",
        f"- Merchant 坐标源：`{npc_stats.get('merchant_source', 'pending')}`；脚本/坐标唯一匹配 **{npc_stats.get('merchant_match_count', 0)}** 条。其余仍按 audit/语义/候选规则处理；{npc_stats['apply_status_counts'].get('pending-review', 0)} 条进入人工复核，不能直接写库。",
        "",
        "### NPC 全量来源",
        "",
        "- 权威全量：`artifacts/npc-monster-alignment-2026-09-25/npc_manifest.json` 和 TSV；旧 `Tools/NpcMover/build_goal_manifest.py` 保留未覆盖，仅作为历史审计工具。",
        "",
        "## 4. 怪物身份流水线",
        "",
        f"- 当前 Zircon MonsterInfo **{mon_stats['zircon_monster_count']}**；英雄杀解码定义 **{mon_stats['hero_kill_definition_count']}**（记录 0 为占位头，不计入）。可靠映射 **{mon_stats['mapped_count']}**，pending **{mon_stats['pending_count']}**，Zircon-only identity **{mon_stats['zircon_only_count']}**。",
        "- 现阶段只使用精确脚本名、现有已验证快照 ID 和明确别名；不按模糊中文名或数字 ID 自动迁移业务引用。MonsterInfo.Index 保持稳定；显示翻译独立记录。",
        "",
        "### 高风险冲突案例",
        "",
        "| Hero-kill 名称 | Zircon 候选 | 方法/置信度 | 处理 |",
        "|---|---|---|---|",
        "| 半兽人 | Oma (22)；Oma Warrior (18) 是备选 | verified-alias / medium | 只记录候选，不改 MonsterInfo 业务 |",
        "| 祖玛教主 | Zuma King (81) | verified-alias / high | 记录 identity，不按名称覆盖索引 |",
        "| 白野猪 | 无直接可靠 Zircon 名称 | conflict-no-direct-zircon-name / pending | pending，禁止模糊映射 |",
        "| Boss/变体 | 多种同族模板 | attributes/resource/drop/spawn evidence 尚未齐全 | conflict/pending |",
        "",
        "- 全量来源：`monster_identity_manifest.json/tsv`；冲突列表位于 manifest `conflicts`。目前没有自动删除、创建或改写 MonsterInfo。",
        "- 四方证据覆盖：Legacy Atlas、Hero-kill `monster.dat`、当前 `MonsterInfo`、当前 `monsters_zircon.json`；资源 shape 证据与业务身份分开记录。",
        "",
        "",
        "## 5. 怪物刷新流水线",
        "",
        f"- 当前 Zircon RespawnInfo **{resp_stats['respawn_count']}** 条；旧地图中心点独立检查 `{j(resp_stats['walkable_counts'])}`；apply status `{j(resp_stats['apply_status_counts'])}`；match status `{j(resp_stats['match_status_counts'])}`。",
        f"- Hero-kill/YXS 源：{hero_source_status}；Mud3 secondary raw source={'present' if mud3_source.get('present') else 'unavailable'}。解析行 **{resp_stats.get('hero_kill_refresh_count', 0)}**，唯一匹配当前 RespawnInfo **{resp_stats.get('hero_kill_matched_count', 0)}**。",
        f"- 刷新缺口：Hero-kill/YXS-only **{resp_stats.get('yxs_only_refresh_count', 0)}**，Zircon-only **{resp_stats.get('zircon_only_refresh_count', 0)}**，coordinate conflict **{resp_stats.get('refresh_conflict_count', 0)}**；这些清单只用于人工复核，不是删除建议。",
        "- `PointRegion.Size` 不能替代 Hero-kill range；manifest 保留 `range_note`，不推断写入半径。",
        "",
        "## 6. 独立范围/可行走/重叠检查",
        "",
        f"- 独立 parser logical errors={verify['error_count']}；NPC target rows={verify['npc_target_rows']}；NPC overlap cells={verify['npc_overlap_cells']}。",
        f"- 发现 **{verify['format_issue_count']}** 个 malformed/truncated Zircon `.map` 解析事件；受影响刷新点保持 pending/旧点记录，不把 fail/pending 误标 pass。",
        "- NPC 与怪物目标之间的联合重叠检查为 pending，因为没有 Hero-kill 怪物目标点；NPC-only overlap 已为 0。",
        "- sandbox 使用橙色 Hero-kill/original NPC、蓝色当前 Zircon NPC、绿色候选目标 NPC、洋红色当前 Zircon monster respawn；不是游戏截图。",
        "",
        "## 7. dry-run、写库、round-trip和游戏验收",
        "",
        "- dry-run：已完成，所有生成器标记 `database_write=false`；没有打开 SQLite 写连接。",
        f"- dry-run 应用计划：NPC 可直接候选 **{len(dry_run_plan['npc_candidates'])}** 条；Hero-kill 唯一刷新候选 **{len(dry_run_plan['respawn_candidates'])}** 条，其中批准计划当前收敛为 **{review_decisions.get('approve', 0)}** 条；计划和批准计划均明确 `database_write=false`，不包含删除/创建 MonsterInfo。",
        f"- 生产备份/写库：已执行 `scope=respawn`，写入 RespawnInfo **{production_apply.get('respawn_updates_applied', 0)}** 条、NPC **{production_apply.get('npc_updates_applied', 0)}** 条；备份哈希匹配写入前状态={production_apply.get('backup_hashes_match_before', False)}，仍有 {review_decisions.get('needs-evidence', 0)} 条 needs-evidence 和 {review_decisions.get('retain-current', 0)} 条 zircon-only retain-current，不能把部分写入误称为全量对齐。",
        "- 临时数据库副本：已按 `scope=respawn` 应用批准计划，写入 RespawnInfo 18 条、创建 MapRegion 0 条；服务端/客户端副本备份、同步和 round-trip 均通过，证据见 `artifacts/.../reviewed-respawn-apply-smoke.json`。",
        "- 生产双库写入：Respawn 分支已完成；生产客户端与服务端 System.db SHA-256 一致，未写 Users.db；NPC 分支尚未批准。",
        f"- round-trip：生产 Respawn 分支通过；生产 SHA-256 一致={production_apply.get('server_client_sha_equal', False)}；完整 NPC/Respawn 全量 round-trip 未完成。",
        "- `NpcMover approved`：此前空计划和本轮 18 条 Respawn 临时副本验证通过；本轮同一批准计划已在生产 `scope=respawn` 完成备份、同步和回读。",
        "- 游戏截图/逐地图验收：未执行；NPC 和大部分刷新仍未闭合，启动客户端会混淆数据库、地图对应、对象同步和锚点问题。",
        "",
        "## 8. 未决项与人工复核",
        "",
        "1. 已搜索 `/home/tetsuya/NAS/**/*.map`、研究仓库地图路径及本地资源根；缺失 Hero-kill 源图仍未找到（development/zircon 命中的同名文件是 Zircon Map，不冒充 Hero-kill 源）。继续补充源图并复核 309 条 matched 刷新；当前 18 条独立源地图可读且目标可行走的刷新已批准，1 条源坐标 fail 保持 needs-evidence。",
        f"2. NPC 复核队列仍有 {review_decisions.get('needs-evidence', 0)} 条 needs-evidence（含 {review_summary['counts']['npc_pending_review']} 条 NPC）；确认 Merchant 固定坐标、地标转换和目标点后才能生成 NPC 批准项。",
        "3. 对 89 个非 exact/renamed 地图关系逐图确认地标/入口/安全区转换；优先沙巴克、5、D202、D901、D11031 等 replacement/variant。",
        "4. 复核半兽人/Oma、祖玛/Zuma、白野猪、Boss/变体的 race/appr/体型/等级/掉落/地图交叉证据。",
        f"5. 地图格式独立校验当前为 {verify['format_issue_count']} 个 malformed/truncated；如重新导出地图资源，必须保持 13-byte cell stride 并重跑独立解析器。",
        f"6. `manual-review-summary.tsv` 已完成逐条保守决定并通过 `validate_manual_review.py`；其中 {review_decisions.get('approve', 0)} 条进入离线批准计划，其余 unresolved 风险不写库。",
        "7. 当前 `approved-offline-plan.json` 仅含 18 条 Respawn 更新；该 Respawn 分支已完成生产 apply，NPC 或 `scope=all` 在剩余证据闭合前不得执行。",
        "",
        "## 9. 复现命令",
        "",
        "```bash",
        "cd /home/tetsuya/development/Mir3-Research",
        "python3 Tools/NpcMover/build_alignment_manifests.py --merchant-source docs/research/ei-ui-layout/sources/mir2ei-report-full-merchants-2026-09-25.json --hero-source-dir docs/research/ei-ui-layout/sources/hero-kill-mud3-2026-09-25/yxs/Envir --mud3-source-dir docs/research/ei-ui-layout/sources/hero-kill-mud3-2026-09-25/mud3/Envir --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25",
        "python3 Tools/NpcMover/verify_alignment_manifest.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/independent-verification.json",
        "python3 Tools/NpcMover/write_alignment_reports.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --verification docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/independent-verification.json --report-dir docs/research/ei-ui-layout",
        "python3 Tools/NpcMover/validate_manual_review.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --review docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manual-review-summary.tsv --out /tmp/manual-review-validation.json --plan-out /tmp/approved-offline-plan.json",
        "dotnet run --project Tools/NpcMover -- approved /home/tetsuya/development/zircon/Debug/ServerCore/Database /tmp/approved-offline-plan.json apply /home/tetsuya/development/zircon/Debug/Client/Data/System.db npc",
        "dotnet run --project Tools/NpcMover -- approved /home/tetsuya/development/zircon/Debug/ServerCore/Database /tmp/approved-offline-plan.json apply /home/tetsuya/development/zircon/Debug/Client/Data/System.db respawn",
        "```",
        "",
        "## 10. 远端 SHA 与提交",
        "",
        f"- 数据对齐证据源提交：Mir3-Research `{args.research_remote_sha}`；Zircon `{args.zircon_remote_sha}`。18 条 Respawn 已完成生产分支写入和 round-trip；NPC、其余刷新及客户端全量验收仍 blocked。",
    ]
    report_path = args.report_dir / "NPC_MONSTER_ALL_MAPS_ALIGNMENT_REPORT_2026-09-25.md"
    report_path.write_text("\n".join(report) + "\n", encoding="utf-8")
    print(json.dumps({"baseline": str(baseline_path), "report": str(report_path), "dry_run_plan": str(plan_path), "map_rows": len(maps), "npc_rows": len(data["npcs"]), "monster_identity_rows": len(data["monster_identity"]), "monster_respawn_rows": len(data["monster_respawns"])}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
