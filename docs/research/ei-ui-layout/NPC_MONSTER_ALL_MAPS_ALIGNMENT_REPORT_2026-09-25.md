# NPC + 怪物全地图对齐报告（2026-09-25）

> 状态：**离线 manifest + 审批计划阶段，生产 System.db 未写入**。18 条刷新变更已通过独立 Hero-kill/Zircon 可行走检查并进入离线批准计划；其余 NPC、冲突和缺少源地图的刷新仍保守保持不写入。

## 1. 交付物和状态

| 交付物 | 状态 | 路径 |
|---|---|---|
| MAP-BASELINE | 已生成 | `MAP_HERO_KILL_BASELINE_2026-09-25.md` + `artifacts/.../map_manifest.{json,tsv}` |
| NPC 全量 manifest | 已生成 dry-run | `artifacts/.../npc_manifest.{json,tsv}` |
| 怪物身份 manifest | 已生成，绝大多数 pending | `artifacts/.../monster_identity_manifest.{json,tsv}` |
| 怪物刷新 manifest | 已接入 Hero-kill/YXS `Mon_Def/*.gen`；保留 range/count/interval、源文件和源行号；逐点唯一匹配仍需复核 | `artifacts/.../monster_respawn_manifest.{json,tsv}` |
| 怪物缺口清单 | YXS-only、Zircon-only、coordinate conflict 均已列出；不作为删除建议 | `artifacts/.../monster_gap_manifest.json` |
| 独立校验 | 逻辑通过；地图文件格式/截断发现 0 个 | `artifacts/.../independent-verification.json` |
| dry-run 应用计划 | 仅列候选变更和前置条件，不写数据库 | `artifacts/.../dry-run-apply-plan.json` |
| 人工复核队列 | 190 条 NPC、328 条匹配刷新、2147 条阻塞刷新；当前决定 `{"needs-evidence":589,"retain-current":2058,"approve":18}`，批准 Respawn **18** 条 | `artifacts/.../manual-review-summary.json`；逐条记录 `artifacts/.../manual-review-summary.tsv`；批准计划 `approved-offline-plan.json` |
| sandbox overlay | 已生成 | `artifacts/.../sandbox/sandbox-*.png` |

## 2. 地图对应与坐标变换

- MapInfo=627；关系统计 `{"variant":12,"exact":526,"replacement":6,"renamed":12,"pending":71}`。
- exact/renamed：坐标变换为 identity logical-grid，但每个实体点仍检查范围与 `flag&3==3`。
- variant/replacement：禁止直接复用英雄杀坐标；使用 Region/城镇/安全区/入口锚点生成候选，apply_status 保持 pending-review。
- pending：不删除实体、不写目标坐标；只输出候选和人工复核状态。
- 比奇、边境、银杏、Banya、盟重、沙巴克和 D202/D1105/D203 均在 sandbox index 中；沙巴克 `3` 是 replacement（Hero 400×600 vs Zircon 350×350），不能按同坐标认定同图。

## 3. NPC 全量流水线

- NPC 总数 **294**；匹配方法 `{"semantic-audit":58,"pending":36,"exact-script-name":96,"exact-script-name-map":34,"hero-kill-extra":70}`。
- 地图关系 `{"variant":78,"exact":165,"replacement":19,"renamed":6,"pending":26}`；target walkable `{"pass":223,"fail":71}`；apply status `{"pending-review":190,"dry-run":104}`；重叠行 **0**。
- 每条记录保留 `current_npc_index/name`、old map/xy、original identity/map/xy、Hero-kill target map/xy、match method、rule、confidence、walkable、overlap、apply_status。
- `non_position_fields_untouched=true`；没有删除状态；不改 NPCName、EntryPage、GoodsIndex、Image、FaceImage、对话/商店业务。
- Merchant 坐标源：`source present: docs/research/ei-ui-layout/sources/mir2ei-report-full-merchants-2026-09-25.json (318 Merchant coordinates)`；脚本/坐标唯一匹配 **130** 条。其余仍按 audit/语义/候选规则处理；190 条进入人工复核，不能直接写库。

### NPC 全量来源

- 权威全量：`artifacts/npc-monster-alignment-2026-09-25/npc_manifest.json` 和 TSV；旧 `Tools/NpcMover/build_goal_manifest.py` 保留未覆盖，仅作为历史审计工具。

## 4. 怪物身份流水线

- 当前 Zircon MonsterInfo **434**；英雄杀解码定义 **432**（记录 0 为占位头，不计入）。可靠映射 **41**，pending **391**，Zircon-only identity **394**。
- 现阶段只使用精确脚本名、现有已验证快照 ID 和明确别名；不按模糊中文名或数字 ID 自动迁移业务引用。MonsterInfo.Index 保持稳定；显示翻译独立记录。

### 高风险冲突案例

| Hero-kill 名称 | Zircon 候选 | 方法/置信度 | 处理 |
|---|---|---|---|
| 半兽人 | Oma (22)；Oma Warrior (18) 是备选 | verified-alias / medium | 只记录候选，不改 MonsterInfo 业务 |
| 祖玛教主 | Zuma King (81) | verified-alias / high | 记录 identity，不按名称覆盖索引 |
| 白野猪 | 无直接可靠 Zircon 名称 | conflict-no-direct-zircon-name / pending | pending，禁止模糊映射 |
| Boss/变体 | 多种同族模板 | attributes/resource/drop/spawn evidence 尚未齐全 | conflict/pending |

- 全量来源：`monster_identity_manifest.json/tsv`；冲突列表位于 manifest `conflicts`。目前没有自动删除、创建或改写 MonsterInfo。
- 四方证据覆盖：Legacy Atlas、Hero-kill `monster.dat`、当前 `MonsterInfo`、当前 `monsters_zircon.json`；资源 shape 证据与业务身份分开记录。


## 5. 怪物刷新流水线

- 当前 Zircon RespawnInfo **2475** 条；旧地图中心点独立检查 `{"fail":917,"pass":1510,"pending":48}`；apply status `{"blocked":2147,"pending-review":328}`；match status `{"zircon-only":2058,"conflict":89,"matched":328}`。
- Hero-kill/YXS 源：source present: docs/research/ei-ui-layout/sources/hero-kill-mud3-2026-09-25/yxs/Envir (17 active Mon_Def files; 679 parsed rows; parse_warnings=1)；Mud3 secondary raw source=present。解析行 **679**，唯一匹配当前 RespawnInfo **328**。
- 刷新缺口：Hero-kill/YXS-only **307**，Zircon-only **2058**，coordinate conflict **44**；这些清单只用于人工复核，不是删除建议。
- `PointRegion.Size` 不能替代 Hero-kill range；manifest 保留 `range_note`，不推断写入半径。

## 6. 独立范围/可行走/重叠检查

- 独立 parser logical errors=0；NPC target rows=294；NPC overlap cells=0。
- 发现 **0** 个 malformed/truncated Zircon `.map` 解析事件；受影响刷新点保持 pending/旧点记录，不把 fail/pending 误标 pass。
- NPC 与怪物目标之间的联合重叠检查为 pending，因为没有 Hero-kill 怪物目标点；NPC-only overlap 已为 0。
- sandbox 使用橙色 Hero-kill/original NPC、蓝色当前 Zircon NPC、绿色候选目标 NPC、洋红色当前 Zircon monster respawn；不是游戏截图。

## 7. dry-run、写库、round-trip和游戏验收

- dry-run：已完成，所有生成器标记 `database_write=false`；没有打开 SQLite 写连接。
- dry-run 应用计划：NPC 可直接候选 **104** 条；Hero-kill 唯一刷新候选 **328** 条，其中批准计划当前收敛为 **18** 条；计划和批准计划均明确 `database_write=false`，不包含删除/创建 MonsterInfo。
- 生产备份/写库：未执行；仍有 589 条 needs-evidence（NPC/冲突/缺少 Hero-kill 地图）和 2058 条 zircon-only retain-current，不能把离线批准误称为全量对齐。
- 临时数据库副本：已按 `scope=respawn` 应用批准计划，写入 RespawnInfo 18 条、创建 MapRegion 0 条；服务端/客户端副本备份、同步和 round-trip 均通过，证据见 `artifacts/.../reviewed-respawn-apply-smoke.json`。
- 生产双库写入：未执行；生产 ServerCore 数据库和客户端 System.db 未作为 apply 目标。
- round-trip：临时副本 Respawn 分支通过；生产库 round-trip 未执行。
- `NpcMover approved`：此前 NPC/Respawn 空计划烟测通过；本轮 18 条审批 Respawn 临时副本验证通过。
- 游戏截图/逐地图验收：未执行；NPC 和大部分刷新仍未闭合，启动客户端会混淆数据库、地图对应、对象同步和锚点问题。

## 8. 未决项与人工复核

1. 继续补充缺少的 Hero-kill 地图文件并复核 309 条 matched 刷新；当前 18 条独立源地图可读且目标可行走的刷新已批准，1 条源坐标 fail 保持 needs-evidence。
2. NPC 复核队列仍有 589 条 needs-evidence（含 190 条 NPC）；确认 Merchant 固定坐标、地标转换和目标点后才能生成 NPC 批准项。
3. 对 89 个非 exact/renamed 地图关系逐图确认地标/入口/安全区转换；优先沙巴克、5、D202、D901、D11031 等 replacement/variant。
4. 复核半兽人/Oma、祖玛/Zuma、白野猪、Boss/变体的 race/appr/体型/等级/掉落/地图交叉证据。
5. 地图格式独立校验当前为 0 个 malformed/truncated；如重新导出地图资源，必须保持 13-byte cell stride 并重跑独立解析器。
6. `manual-review-summary.tsv` 已完成逐条保守决定并通过 `validate_manual_review.py`；其中 18 条进入离线批准计划，其余 unresolved 风险不写库。
7. 当前 `approved-offline-plan.json` 仅含 18 条 Respawn 更新；在独立地图检查、停服、备份和人工/证据复核完成前不得对生产库加 `apply`。

## 9. 复现命令

```bash
cd /home/tetsuya/development/Mir3-Research
python3 Tools/NpcMover/build_alignment_manifests.py --merchant-source docs/research/ei-ui-layout/sources/mir2ei-report-full-merchants-2026-09-25.json --hero-source-dir docs/research/ei-ui-layout/sources/hero-kill-mud3-2026-09-25/yxs/Envir --mud3-source-dir docs/research/ei-ui-layout/sources/hero-kill-mud3-2026-09-25/mud3/Envir --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25
python3 Tools/NpcMover/verify_alignment_manifest.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/independent-verification.json
python3 Tools/NpcMover/write_alignment_reports.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --verification docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/independent-verification.json --report-dir docs/research/ei-ui-layout
python3 Tools/NpcMover/validate_manual_review.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --review docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manual-review-summary.tsv --out /tmp/manual-review-validation.json --plan-out /tmp/approved-offline-plan.json
dotnet run --project Tools/NpcMover -- approved /home/tetsuya/development/zircon/Debug/ServerCore/Database /tmp/approved-offline-plan.json apply /home/tetsuya/development/zircon/Debug/Client/Data/System.db npc
dotnet run --project Tools/NpcMover -- approved /home/tetsuya/development/zircon/Debug/ServerCore/Database /tmp/approved-offline-plan.json apply /home/tetsuya/development/zircon/Debug/Client/Data/System.db respawn
```

## 10. 远端 SHA 与提交

- 数据对齐证据源提交：Mir3-Research `c217f2bedf51f37b7b15d1ec55267e37e45e5a8a`；Zircon `bc09b73d703fe8e2817979392d0c6f432c6e52fd`。本轮仍为离线证据；写库、客户端验收和双库 round-trip 继续 blocked。
