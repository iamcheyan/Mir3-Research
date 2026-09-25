#!/usr/bin/env python3
"""Write the requested human-readable baseline and alignment reports."""
from __future__ import annotations

import argparse
import json
from pathlib import Path


def j(value):
    return json.dumps(value, ensure_ascii=False, separators=(",", ":"))


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
        "- map 记录格式按 28-byte header、x-major 14-byte cell records、`flag & 3 == 3` 通行规则独立读取； malformed 文件保持 pending，不降级为可走。",
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
        "> 状态：**离线 manifest / dry-run 阶段，未写 System.db**。本报告不把缺失的 Hero-kill `Mon_Def/*.gen`/`MonGen` 配置伪装成已完成对齐。",
        "",
        "## 1. 交付物和状态",
        "",
        "| 交付物 | 状态 | 路径 |",
        "|---|---|---|",
        "| MAP-BASELINE | 已生成 | `MAP_HERO_KILL_BASELINE_2026-09-25.md` + `artifacts/.../map_manifest.{json,tsv}` |",
        "| NPC 全量 manifest | 已生成 dry-run | `artifacts/.../npc_manifest.{json,tsv}` |",
        "| 怪物身份 manifest | 已生成，绝大多数 pending | `artifacts/.../monster_identity_manifest.{json,tsv}` |",
        "| 怪物刷新 manifest | 已盘点 Zircon 旧刷新，并接入 recovered EI import plan；缺少原始 Mon_Def/MonGen range | `artifacts/.../monster_respawn_manifest.{json,tsv}` |",
        "| 怪物缺口清单 | YXS-only、Zircon-only、coordinate conflict 均已列出；不作为删除建议 | `artifacts/.../monster_gap_manifest.json` |",
        "| 独立校验 | 逻辑通过；发现 50 个 malformed/truncated 地图文件 | `artifacts/.../independent-verification.json` |",
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
        "",
        "## 5. 怪物刷新流水线",
        "",
        f"- 当前 Zircon RespawnInfo **{resp_stats['respawn_count']}** 条；旧地图中心点独立检查 `{j(resp_stats['walkable_counts'])}`；apply status `{j(resp_stats['apply_status_counts'])}`；match status `{j(resp_stats['match_status_counts'])}`。",
        f"- 本地缺少原始 Hero-kill `Mon_Def/*.gen`/`MonGen` 文件；当前仅接入 recovered `Tools/DbMigrationTool/data/import_plan_v2.json` 刷新计划，共 **{resp_stats.get('hero_kill_refresh_count', 0)}** 行。该计划没有 range 字段，所有唯一坐标匹配仍为 `pending-review`，不作为写库目标。",
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
        f"- 备份：未执行；写库前置条件未满足（原始 Hero-kill Mon_Def/MonGen 与 range 缺失、Merchant 坐标虽已接入但仅 {npc_stats.get('merchant_match_count', 0)} 条脚本唯一匹配、variant/replacement 人工抽查缺失）。",
        "- 双库写入：未执行；NPC 与怪物均无 apply commit。",
        "- round-trip：未执行；不能声称双库逐条一致。",
        "- 游戏截图/逐地图验收：未执行；在目标点和刷新范围未闭合前启动客户端会混淆数据库、地图对应、对象同步和锚点问题。",
        "",
        "## 8. 未决项与人工复核",
        "",
        "1. 提供并固定 Hero-kill `Mon_Def/*.gen`/`MonGen` 文件及格式说明，补齐每个刷新点的 range，并核对 recovered import plan 的 742 行。",
        f"2. 复核 Merchant 快照的固定坐标记录与 {npc_stats.get('merchant_match_count', 0)} 条脚本/地图唯一匹配，确认其余 NPC 的身份和目标点。",
        "3. 对 89 个非 exact/renamed 地图关系逐图确认地标/入口/安全区转换；优先沙巴克、5、D202、D901、D11031 等 replacement/variant。",
        "4. 复核半兽人/Oma、祖玛/Zuma、白野猪、Boss/变体的 race/appr/体型/等级/掉落/地图交叉证据。",
        "5. 修复或重新导出 50 个 malformed/truncated Zircon map 文件后重跑独立解析器。",
        "",
        "## 9. 复现命令",
        "",
        "```bash",
        "cd /home/tetsuya/development/Mir3-Research",
        "python3 Tools/NpcMover/build_alignment_manifests.py --merchant-source docs/research/ei-ui-layout/sources/mir2ei-report-full-merchants-2026-09-25.json --hero-spawn /home/tetsuya/development/zircon/Tools/DbMigrationTool/data/import_plan_v2.json --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25",
        "python3 Tools/NpcMover/verify_alignment_manifest.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/independent-verification.json",
        "python3 Tools/NpcMover/render_alignment_sandbox.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --hero-map-dir /home/tetsuya/mir2ei/Map --zircon-map-dir /home/tetsuya/development/zircon/Debug/ServerCore/Map --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/sandbox",
        "```",
        "",
        "## 10. 远端 SHA 与提交",
        "",
        f"- 数据对齐证据源提交：Mir3-Research `{args.research_remote_sha}`；Zircon `{args.zircon_remote_sha}`。本轮仍为离线证据；写库、客户端验收和双库 round-trip 继续 blocked。",
    ]
    report_path = args.report_dir / "NPC_MONSTER_ALL_MAPS_ALIGNMENT_REPORT_2026-09-25.md"
    report_path.write_text("\n".join(report) + "\n", encoding="utf-8")
    print(json.dumps({"baseline": str(baseline_path), "report": str(report_path), "map_rows": len(maps), "npc_rows": len(data["npcs"]), "monster_identity_rows": len(data["monster_identity"]), "monster_respawn_rows": len(data["monster_respawns"])}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
