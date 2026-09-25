# NPC + 怪物全地图对齐报告（2026-09-25）

> 状态：**离线 manifest / dry-run 阶段，未写 System.db**。Hero-kill/YXS 文本源已固定并保留 SHA；本报告不把未唯一匹配的刷新点伪装成已完成对齐。

## 1. 交付物和状态

| 交付物 | 状态 | 路径 |
|---|---|---|
| MAP-BASELINE | 已生成 | `MAP_HERO_KILL_BASELINE_2026-09-25.md` + `artifacts/.../map_manifest.{json,tsv}` |
| NPC 全量 manifest | 已生成 dry-run | `artifacts/.../npc_manifest.{json,tsv}` |
| 怪物身份 manifest | 已生成，绝大多数 pending | `artifacts/.../monster_identity_manifest.{json,tsv}` |
| 怪物刷新 manifest | 已接入 Hero-kill/YXS `Mon_Def/*.gen`；保留 range/count/interval、源文件和源行号；逐点唯一匹配仍需复核 | `artifacts/.../monster_respawn_manifest.{json,tsv}` |
| 怪物缺口清单 | YXS-only、Zircon-only、coordinate conflict 均已列出；不作为删除建议 | `artifacts/.../monster_gap_manifest.json` |
| 独立校验 | 逻辑通过；发现 50 个 malformed/truncated 地图文件 | `artifacts/.../independent-verification.json` |
| dry-run 应用计划 | 仅列候选变更和前置条件，不写数据库 | `artifacts/.../dry-run-apply-plan.json` |
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
- dry-run 应用计划：NPC 可直接候选 **104** 条；Hero-kill 唯一刷新匹配 **328** 条但仍为 pending-review；计划明确 `database_write=false`，不包含删除/创建 MonsterInfo。
- 备份：未执行；写库前置条件未满足（Hero-kill/YXS 仍有 307 条 YXS-only 与 44 条冲突、NPC 仍有 190 条人工复核、variant/replacement 人工抽查缺失）。
- 双库写入：未执行；NPC 与怪物均无 apply commit。
- round-trip：未执行；不能声称双库逐条一致。
- 游戏截图/逐地图验收：未执行；在目标点和刷新范围未闭合前启动客户端会混淆数据库、地图对应、对象同步和锚点问题。

## 8. 未决项与人工复核

1. 复核 Hero-kill/YXS 679 条 active refresh 与当前 RespawnInfo 的身份、地图、坐标、range/count/interval；处理 1 条 malformed name 警告和所有 YXS-only/conflict。
2. 复核 Merchant 快照的固定坐标记录与 130 条脚本/地图唯一匹配，确认其余 NPC 的身份和目标点。
3. 对 89 个非 exact/renamed 地图关系逐图确认地标/入口/安全区转换；优先沙巴克、5、D202、D901、D11031 等 replacement/variant。
4. 复核半兽人/Oma、祖玛/Zuma、白野猪、Boss/变体的 race/appr/体型/等级/掉落/地图交叉证据。
5. 修复或重新导出 50 个 malformed/truncated Zircon map 文件后重跑独立解析器。

## 9. 复现命令

```bash
cd /home/tetsuya/development/Mir3-Research
python3 Tools/NpcMover/build_alignment_manifests.py --merchant-source docs/research/ei-ui-layout/sources/mir2ei-report-full-merchants-2026-09-25.json --hero-source-dir docs/research/ei-ui-layout/sources/hero-kill-mud3-2026-09-25/yxs/Envir --mud3-source-dir docs/research/ei-ui-layout/sources/hero-kill-mud3-2026-09-25/mud3/Envir --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25
python3 Tools/NpcMover/verify_alignment_manifest.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/independent-verification.json
python3 Tools/NpcMover/write_alignment_reports.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --verification docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/independent-verification.json --report-dir docs/research/ei-ui-layout
python3 Tools/NpcMover/render_alignment_sandbox.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --hero-map-dir /home/tetsuya/mir2ei/Map --zircon-map-dir /home/tetsuya/development/zircon/Debug/ServerCore/Map --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/sandbox
```

## 10. 远端 SHA 与提交

- 数据对齐证据源提交：Mir3-Research `e480aef`；Zircon `e60bd8f3`。本轮仍为离线证据；写库、客户端验收和双库 round-trip 继续 blocked。
