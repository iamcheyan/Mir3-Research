# NPC + 怪物全地图对齐报告（2026-09-25）

> 状态：**离线 manifest / dry-run 阶段，未写 System.db**。本报告不把缺失的 Hero-kill `Mon_Def/*.gen`/`MonGen` 配置伪装成已完成对齐。

## 1. 交付物和状态

| 交付物 | 状态 | 路径 |
|---|---|---|
| MAP-BASELINE | 已生成 | `MAP_HERO_KILL_BASELINE_2026-09-25.md` + `artifacts/.../map_manifest.{json,tsv}` |
| NPC 全量 manifest | 已生成 dry-run | `artifacts/.../npc_manifest.{json,tsv}` |
| 怪物身份 manifest | 已生成，绝大多数 pending | `artifacts/.../monster_identity_manifest.{json,tsv}` |
| 怪物刷新 manifest | 已盘点 Zircon 旧刷新，并接入 recovered EI import plan；缺少原始 Mon_Def/MonGen range | `artifacts/.../monster_respawn_manifest.{json,tsv}` |
| 怪物缺口清单 | YXS-only、Zircon-only、coordinate conflict 均已列出；不作为删除建议 | `artifacts/.../monster_gap_manifest.json` |
| 独立校验 | 逻辑通过；发现 50 个 malformed/truncated 地图文件 | `artifacts/.../independent-verification.json` |
| sandbox overlay | 已生成 | `artifacts/.../sandbox/sandbox-*.png` |

## 2. 地图对应与坐标变换

- MapInfo=627；关系统计 `{"variant":12,"exact":526,"replacement":6,"renamed":12,"pending":71}`。
- exact/renamed：坐标变换为 identity logical-grid，但每个实体点仍检查范围与 `flag&3==3`。
- variant/replacement：禁止直接复用英雄杀坐标；使用 Region/城镇/安全区/入口锚点生成候选，apply_status 保持 pending-review。
- pending：不删除实体、不写目标坐标；只输出候选和人工复核状态。
- 比奇、边境、银杏、Banya、盟重、沙巴克和 D202/D1105/D203 均在 sandbox index 中；沙巴克 `3` 是 replacement（Hero 400×600 vs Zircon 350×350），不能按同坐标认定同图。

## 3. NPC 全量流水线

- NPC 总数 **294**；匹配方法 `{"semantic-audit":58,"pending":36,"exact-script-name":96,"exact-script-name-map":34,"hero-kill-extra":70}`。
- 地图关系 `{"variant":78,"exact":165,"replacement":19,"renamed":6,"pending":26}`；target walkable `{"pass":294}`；apply status `{"pending-review":123,"dry-run":171}`；重叠行 **0**。
- 每条记录保留 `current_npc_index/name`、old map/xy、original identity/map/xy、Hero-kill target map/xy、match method、rule、confidence、walkable、overlap、apply_status。
- `non_position_fields_untouched=true`；没有删除状态；不改 NPCName、EntryPage、GoodsIndex、Image、FaceImage、对话/商店业务。
- Merchant 坐标源：`source present: docs/research/ei-ui-layout/sources/mir2ei-report-full-merchants-2026-09-25.json (318 Merchant coordinates)`；脚本/坐标唯一匹配 **130** 条。其余仍按 audit/语义/候选规则处理；123 条进入人工复核，不能直接写库。

### NPC 全量来源

- 权威全量：`artifacts/npc-monster-alignment-2026-09-25/npc_manifest.json` 和 TSV；旧 `Tools/NpcMover/build_goal_manifest.py` 保留未覆盖，仅作为历史审计工具。

## 4. 怪物身份流水线

- 当前 Zircon MonsterInfo **434**；英雄杀解码定义 **432**（记录 0 为占位头，不计入）。可靠映射 **6**，pending **426**，Zircon-only identity **428**。
- 资料库第二权威已接入：Legacy Atlas `catalog-mud3.html` / `monster.json` 共 **432** 条非占位英雄杀定义，版本标签 `old-only=229`、`unverified=197`、`changed=6`；`monsters.html` 是 309 条当前百科快照，不能覆盖 workspace 中包含变体/附加实体的 434 条 `MonsterInfo`。`monsters_zircon.json` 提供当前百科属性，`MonsterInfo.json` 提供当前业务 Index/Image/Stats，`LibraryCore/Enum.cs` + `GodotClient/Formats/MonsterLookup.cs` 提供 MonsterImage 数值、图库和 shape。四方证据写入 `monster_four_way_evidence.{json,tsv}`，不是只按中文字符串或当前 MonsterInfo 猜测。

### 资料库四方对应（重点案例）

| 英雄杀/Legacy Atlas | 版本标签与老版属性（Lv/HP/DC/Exp） | 当前 MonsterInfo（Index/Name/Image/Lv） | `monsters_zircon.json` 当前属性 | 图片/shape 证据 |
|---|---|---|---|---|
| 半兽人 | `changed`；13/30/4-8/30 | `22 / Oma / Oma / 13` | HP25/DC3-8/Exp59 | 老版 `Appr=83 → Mon-8.wil#3040`；当前 `MonsterImage.Oma=33 → Mon_3 shape=3`；id18 Oma Warrior 共享同一 Image/shape，不能靠图片单独消歧，采用 Atlas changed→id22 |
| 祖玛教主 | `changed`；94/14000/70-175/10500 | `81 / Zuma King / ZumaKing / 250` | HP21000/DC255-360/Exp780000 | `Appr=102 → Mon-10.wil#2040`；`MonsterImage.ZumaKing=95 → Mon_9 shape=5` |
| 白野猪 | `old-only`；75/4500/44-66/1250 | 无可靠对应 | 无可靠对应 | `Appr=208 → Mon-20.wil#8040`；无当前 MonsterImage/shape 对应，保持 pending；不把 Wild Boar 等模糊候选写成身份 |
| 赤月恶魔 | `changed`；93/13000/90-180/9750 | `75 / Red Moon The Fallen / RedMoonTheFallen / 250` | HP19500/DC240-345/Exp487500 | `Appr=115 → Mon-11.wil#5040`；`MonsterImage.RedMoonTheFallen=114 → Mon_11 shape=4` |
| 沃玛教主 | `changed`；90/8000/99-143/6000 | `65 / Uma King / UmaKing / 250` | HP13500/DC210-315/Exp195000 | `Appr=92 → Mon-9.wil#2040`；`MonsterImage.UmaKing=55 → Mon_5 shape=5` |
| 骷髅教主 | `changed`；91/10000/121-187/7500 | `121 / Arch Lich Taedu / ArchLichTaedu / 250` | HP15000/DC225-330/Exp370500 | `Appr=225 → Mon-22.wil#5040`；`MonsterImage.ArchLichTaedu=151 → Mon_15 shape=1` |
| 霸王教主 | `changed`；96/20000/145-245/12000 | `115 / Emperor Sa'Woo / EmperorSaWoo / 250` | HP21000/DC255-360/Exp585000 | `Appr=226 → Mon-22.wil#6040`；`MonsterImage.EmperorSaWoo=149 → Mon_14 shape=9` |

- 该表同时保留老版 `monster.dat` 定义、Legacy Atlas 标签、当前 `MonsterInfo` 业务实体、当前资料库属性和两套资源坐标；老版 `Appr/frame` 与 Zircon `MonsterImage/LibraryFile/shape` 是不同资源系统，不能直接把帧号当作 Zircon shape。
- 其余 426 条保持 pending；229 条 `old-only` 和 197 条 `unverified` 不因同名、等级或资源帧相似而自动迁移。

### 高风险冲突案例

| Hero-kill 名称 | Zircon 候选 | 方法/置信度 | 处理 |
|---|---|---|---|
| 半兽人 | Oma (22)；Oma Warrior (18) 是备选 | verified-alias / medium | 只记录候选，不改 MonsterInfo 业务 |
| 祖玛教主 | Zuma King (81) | verified-alias / high | 记录 identity，不按名称覆盖索引 |
| 白野猪 | 无直接可靠 Zircon 名称 | conflict-no-direct-zircon-name / pending | pending，禁止模糊映射 |
| Boss/变体 | 多种同族模板 | attributes/resource/drop/spawn evidence 尚未齐全 | conflict/pending |

- 全量来源：`monster_identity_manifest.json/tsv` 与 `monster_four_way_evidence.json/tsv`；冲突列表位于 manifest `conflicts`。目前没有自动删除、创建或改写 MonsterInfo。

## 5. 怪物刷新流水线

- 当前 Zircon RespawnInfo **2475** 条；旧地图中心点独立检查 `{"pass":1464,"fail":952,"pending":59}`；apply status `{"blocked":1958,"pending-review":517}`；match status `{"zircon-only":1825,"conflict":133,"matched":517}`。
- 本轮外部源审计：当前工作站 `/home/tetsuya/NAS` 为空，无法读取原始 Mud3 `Envir/Mon_Def`；`iamcheyan/mir2ei` `main` 的递归 Git tree 仅公开 `data/report_full.json`（Git blob `3f7cff6218853e4809c8a13bd4a3c47632e2bffe`，来源 URL `https://raw.githubusercontent.com/iamcheyan/mir2ei/main/data/report_full.json`）及百科派生数据，未发现 `Mon_Def`、`MonGen` 或逐点 range 文件。重新解析该快照确认只有 544 张 EI 地图、3221 条地图级刷新汇总、293 张有刷新地图和 312 个怪物种类，没有逐点 x/y/range；不能替代原始刷新点范围。另从 `https://www.mirfiles.co.uk/resources/mir3/MSRF%20EI%20Mud3.exe` 下载到 `/tmp/msrf-ei-mud3.exe`（SHA-256 `7763eaef02b24c655bc2efd31d9bacfc4f08c68c727cc2838978d79630501c27`），包内有 56 个 `Mon_def/*.gen`、`MonGen.txt`，独立解析得到 5517 条刷新行、312 个怪物名、279 张地图；但内置 `Readme 2.9BETA.txt` 表明它是旧版 beta 配置，不是当前 EI 3.0 英雄杀刷新源，且与 recovered 742 行计划仅有 22 张地图名交集、12 个地图坐标交集；仅作为格式/历史语义证据，不能解除目标源门禁。
- recovered `Tools/DbMigrationTool/data/import_plan_v2.json` 仍含 **742** 行刷新计划，但没有 range 字段；其 `notes.mapSources` 只记录预期来源 `EI client Map/ + hero server Mud3/Map/`，当前工作站没有对应的英雄服务器 `Mud3/Map/` 原始目录；该文件仅作为坐标审计输入，不是 Hero-kill 原始刷新源，不能解除 `range` 门禁。
- 刷新缺口：Hero-kill/YXS-only **124**，Zircon-only **1825**，coordinate conflict **101**；这些清单只用于人工复核，不是删除建议。
- `PointRegion.Size` 不能替代 Hero-kill range；manifest 保留 `range_note`，不推断写入半径。

## 6. 独立范围/可行走/重叠检查

- 独立 parser logical errors=0；NPC target rows=294；NPC overlap cells=0。
- 发现 **50** 个 malformed/truncated Zircon `.map` 解析事件；受影响刷新点保持 pending/旧点记录，不把 fail/pending 误标 pass。
- NPC 与怪物目标之间的联合重叠检查为 pending，因为没有 Hero-kill 怪物目标点；NPC-only overlap 已为 0。
- sandbox 使用橙色 Hero-kill/original NPC、蓝色当前 Zircon NPC、绿色候选目标 NPC、洋红色当前 Zircon monster respawn；不是游戏截图。

## 7. dry-run、写库、round-trip和游戏验收

- dry-run：已完成，所有生成器标记 `database_write=false`；没有打开 SQLite 写连接。
- 备份：未执行；写库前置条件未满足（原始 Hero-kill Mon_Def/MonGen 与 range 缺失、Merchant 坐标虽已接入但仅 130 条脚本唯一匹配、variant/replacement 人工抽查缺失）。
- 双库写入：未执行；NPC 与怪物均无 apply commit。
- round-trip：未执行；不能声称双库逐条一致。
- 游戏截图/逐地图验收：未执行；在目标点和刷新范围未闭合前启动客户端会混淆数据库、地图对应、对象同步和锚点问题。

## 8. 未决项与人工复核

1. 提供并固定 Hero-kill `Mon_Def/*.gen`/`MonGen` 文件及格式说明，补齐每个刷新点的 range，并核对 recovered import plan 的 742 行。
2. 复核 Merchant 快照的固定坐标记录与 130 条脚本/地图唯一匹配，确认其余 NPC 的身份和目标点。
3. 对 89 个非 exact/renamed 地图关系逐图确认地标/入口/安全区转换；优先沙巴克、5、D202、D901、D11031 等 replacement/variant。
4. 复核半兽人/Oma、祖玛/Zuma、白野猪、Boss/变体的 race/appr/体型/等级/掉落/地图交叉证据。
5. 修复或重新导出 50 个 malformed/truncated Zircon map 文件后重跑独立解析器。

## 9. 复现命令

```bash
cd /home/tetsuya/development/Mir3-Research
python3 Tools/NpcMover/build_alignment_manifests.py --merchant-source docs/research/ei-ui-layout/sources/mir2ei-report-full-merchants-2026-09-25.json --hero-spawn /home/tetsuya/development/zircon/Tools/DbMigrationTool/data/import_plan_v2.json --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25
python3 Tools/NpcMover/verify_alignment_manifest.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/independent-verification.json
python3 Tools/NpcMover/render_alignment_sandbox.py --manifest docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json --hero-map-dir /home/tetsuya/mir2ei/Map --zircon-map-dir /home/tetsuya/development/zircon/Debug/ServerCore/Map --out docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/sandbox
```

## 10. 远端 SHA 与提交

- 数据对齐证据基线：Mir3-Research `df53b7c0a59875462b7e6e5168815d2f735673a9`；本轮外部刷新源审计提交及推送基线：Mir3-Research `9a045232799feec24c11fb80236778c358458bc8`；Zircon 当前远端：`965d0537c64f4a492eee40896a78669f8a70a86a`。本轮仍为离线证据；写库、客户端验收和双库 round-trip 继续 blocked。
