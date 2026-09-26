# NPC + 怪物 + 技能 + 地图网站标准对齐报告（2026-09-26）

> 本报告是只读 dry-run 证据。未写入真实 System.db；网站 checkout 未修改。

## 1. 来源与硬闸门

- 标准资料站：`/home/tetsuya/development/mir3-website`（`data/monsters.json`=154，`data/skills.json`=61，地图区域图=22）。
- Zircon 当前快照：MonsterInfo=434，MagicInfo=174，NPCInfo=294，MapInfo=627，RespawnInfo=2475。
- 7000 检查：运行时由阶段 0 记录为监听；因此本报告只读，写库闸门未开启。
- 数据库写入：`database_write=false`；没有删除、创建或重排 MonsterInfo/NPCInfo/MagicInfo/MapInfo。
- Mir3-Research 最终生成时：HEAD=e28758c5619834ee351bb0fc232fe4fb42bdd8fd；origin/ei-ui-audit-2026-09-24=f81709d5a5d4f2f529e88e27fa3f5b7749066ae6；工作树 dirty=True。
- Zircon 最终生成时：HEAD=7d7943f79965690adc7c41fc9e35737dd22d8fa7；origin/ui/legacy-layout-lab=16240b373f9a36fc5371533b2686ef3a40a37801；工作树 dirty=True。
- mir3-website 只读证据 checkout：HEAD=02fdb6cd16c8009cf10f3aae6a21327b765a64bd；origin/main=02fdb6cd16c8009cf10f3aae6a21327b765a64bd；工作树 dirty=False；未提交路径=[]；本 Goal 未修改。
- 当前未提交路径保护：Mir3-Research 无关 WIP=["Tools/NpcMover/write_alignment_reports.py", "Tools/SystemDbProbe/Program.cs", "Tools/maps/mapedit/api.py", "Tools/maps/mapedit/data.py", "Tools/maps/mapedit/map_links_v2.json", "Tools/maps/mapedit/npcedit.py"]；Zircon 无关 WIP=[".artifacts/npc-f1100-acceptance-2026-09-25/", ".artifacts/ui-acceptance-2026-09-24/status-badge-guard-character-button.png", ".artifacts/ui-acceptance-2026-09-24/status-badge-guard-final.png", ".artifacts/ui-acceptance-2026-09-24/status-badge-guard-open-q.png", ".artifacts/ui-acceptance-2026-09-24/status-badge-guard-open.png", ".artifacts/ui-acceptance-2026-09-24/status-no-highlight-current.png"]；本 Goal 仅提交自身脚本/报告/manifest。

## 2. 网站索引和图片证据

- 网站怪物：154；分类数=21；技能：61。
- 怪物状态：confirmed=67，investigate=29，pending=58，unmatched=0；独立验证审计 87 条未闭合行，其中 source exact=69、legacy exact=69。
- 技能状态：confirmed=59，investigate=2，pending=0；MIcon header present=59。
- 每条网站记录保留页面路径、原始图片路径、sha256、字节数、尺寸、来源描述；重复图片组见 `website-index.json`。

## 3. 怪物全量匹配

- `confirmed` 只表示已有稳定 Zircon MonsterInfo 候选且 MonsterLookup/Mon-*.Zl 帧探针可复现；它是显示名计划，不是写库批准。
- `investigate` 保留一对多、同图不同名、资源别名但当前快照缺行等冲突；不得自动覆盖。
- `pending` 不是“网站没有对应”。每个未闭合行同时保存 Hero-kill exact/后缀族、Legacy Atlas exact/后缀族、MonsterInfo/资源别名、MonsterLookup/Mon-*.Zl、0/1-based frame probe 和重复图冲突审计；未闭合只表示当前证据仍不足以安全选 Index。
- 白野猪、半兽人、祖玛卫士、Boss/变体等高风险样例均保留候选与冲突，不模糊改索引。
- 白野猪当前新增可复现资源候选：网站 `images/mob/pic/40.gif` 与 Zircon `MonsterInfo.Index=128 / Tusk Lord / MonsterImage=TuskLord / MonsterLookup shape=8 / Mon-8.Zl`；该证据仅提升为 `investigate`，不产生 Index 或显示名写入计划。对照图见 `white-boar-resource-contact-sheet.png`。
- 当前保留 21 条资源别名候选（其中 5 条只有 MonsterLookup/Mon-*.Zl 资源候选、没有当前 MonsterInfo 行）；候选统一保持 `investigate`，不创建 Index。对照图见 `resource-alias-candidate-contact-sheet.png`；资源候选不是身份确认。

## 4. 技能

- 61 条技能逐条由网站名称/职业/描述、Legacy Atlas 技能交叉目录、MagicInfo、MIcon.Zl header 复核。
- `catalog-skills.html` 的 old-only 行（例如凝血离魂、移花接玉）保持 investigate/pending；不把“无直接对应”当成最终结论，不改施法逻辑。

## 5. 地图与 NPC

- 网站地图共 17 个迷宫区域图 + 世界地图 + 神舰 4 层；没有把它们当成 627 张逐图清单。
- `map_family_manifest.json` 按网站区域名称列出 MapInfo 候选、文件名、描述；具体地图 walkable/尺寸/入口证据复用现有独立 manifest。
- NPC 全量和候选位置：`docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/npc-manifest.json`，行数=294；保留 current_name/current_map/current_xy、website 证据、map_match、coordinate_evidence、walkable、overlap、confidence、apply_status、skip_reason。
- NPC 统计：match_method={"semantic-audit": 58, "pending": 36, "exact-script-name": 96, "exact-script-name-map": 34, "hero-kill-extra": 70}；map_relation={"variant": 78, "exact": 165, "replacement": 19, "renamed": 6, "pending": 26}；walkable={"pass": 223, "fail": 71}；apply={"pending-review": 190, "dry-run": 104}；overlap_rows=0。
- NPC 没有可靠位置时保持 retain-current，并在既有 manifest 的 candidate/skip_reason 中记录；不删除 NPC。
- 地图统计：MapInfo=627；relation={"variant": 12, "exact": 526, "replacement": 6, "renamed": 12, "pending": 71}；coordinate_reuse={"blocked": 89, "allowed-after-point-check": 538}。
- NPC 原始行与完整候选证据仍可追溯至 `/home/tetsuya/development/Mir3-Research/docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json`；本 Goal 不覆盖外部 canonical manifest。

## 6. 刷新点 dry-run

- 刷新全量：旧 RespawnInfo=2475；Hero-kill parsed=679；matched=328；YXS-only=307；Zircon-only=2058；conflict=44。
- Respawn 旧/新清单：`docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/respawn-manifest.json`，行数=2475；walkable={"fail": 917, "pass": 1510, "pending": 48}；apply={"blocked": 2147, "pending-review": 328}。
- 独立刷新重建：`docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/refresh-audit`；重新解析 679 个 active .gen 刷新行，旧 RespawnInfo 全量 2475 行，未写库。
- Website identity is separate from refresh position: website standard supplies identity/display-name evidence; GB18030 Hero-kill/Mud3 supplies refresh coordinates/count/range.

## 7. 独立验证与关键样例

- 独立验证脚本：`Tools/NpcMover/verify_website_alignment.py`，不导入网站匹配生成器；检查 JSON 数量、图片文件/尺寸/hash、MonsterLookup/Mon-*.Zl、MIcon、未闭合行逐项证据、manifest 状态和索引稳定性。
- 关键样例：半兽人、祖玛教主、祖玛卫士、白野猪、Boss；技能火球术/基本剑术/凝血离魂；NPC 至少 3 行；结果见 `verification.json`。
- 独立范围审计：NPC/Respawn schema-or-target-coordinate failures=0/0；旧来源坐标超出 Zircon 目标尺寸=2/4（保留为旧坐标证据，不作为新坐标写入）；NPC/Respawn overlap rows=0/0。

## 8. 写库闸门与未提交文件保护

- 7000 当前有监听；未满足停服、用户 dry-run 审核、备份、临时副本 round-trip、双库同步、游戏内验收条件，因此本 Goal 阶段不写真实库。
- 未决风险与必须审核项登记于 `docs/research/ei-ui-layout/DECISIONS_PENDING.md`；Mir3-Research 与 Zircon 的阶段 0 工作树状态保存于 `baseline-repo-state.json`；无关 WIP 保留，不纳入本 Goal 文件。
- 真实库、Users.db、资料站内容均未修改。

## 9. 机器可读产物

- `manifest.json` / `monster-manifest.tsv` / `skill-manifest.tsv` / `npc-manifest.json` / `respawn-manifest.json` / `map-family-manifest.json` / `website-index.json` / `verification.json`。
- 图片证据：`known-contact-sheet.png`、`website-monster-contact-sheet.png`、`website-unclosed-contact-sheet.png`、`item-known-contact-sheet.png`、`white-boar-resource-contact-sheet.png`、`resource-alias-candidate-contact-sheet.png`。

## 10. 物品扩展审计（只读）

- 网站 `data/items.json`：371 条，12 类；网站图片存在=361/371。逐条字段、图片路径、sha256、尺寸和当前候选保存在 `extension-manifest.json` 与 `item-manifest.json`。
- 当前 Zircon ItemInfo=1078。按 db_names.json 中文名和分类唯一闭合到当前 ItemInfo 的只有 47 条；另有 266 条可在旧版 stditem.json 通过中文名称找到，但尚未安全闭合到 Zircon ItemInfo.Index；58 条连旧版名称也未唯一闭合。扩展清单没有猜测 Index。
- `legacy-source-only` 是旧版名称证据，不是 Zircon 映射批准；`pending-legacy-name` 不是网站缺失对应。当前不改 ItemName、ItemType、Image、Stats、Drops 或任何业务引用。
- `Storeitems.Zl` frame header 仅在已有当前候选上探针；缺少稳定 Index 的图片不自动反推业务对象。已知物品图标对照证据：`item-known-contact-sheet.png`。

## 11. 技能逐条扩展证据

- 网站技能 61 条；既有 `skill-manifest.tsv` 的稳定证据合并进 `skill-detail-manifest.json`：confirmed=59、investigate=2，业务 Index 保持不变。
- 本次扩展重新读取网站技能图片、MagicInfo 和 MIcon.Zl header；直接翻译索引只闭合 26 条，不能覆盖既有 Legacy Atlas/语义证据，因此不以单一路径否定已确认的 59 条。MIcon 资源探针结果保留在每行 `icon_evidence`/`legacy_alignment_evidence`。
- 2 条 investigate 保持未决；不改 MagicInfo.Index、施法逻辑、职业或图标。

## 12. 任务与统一交叉引用

- 网站任务 JSON=24 条；原始步骤=163，万事通子任务=109；当前 QuestInfo=38。
- `mission-cross-reference.json` 对每条任务保留原始任务字段，并独立抽取 NPC/技能/物品/怪物名称引用；初级任务页面首行的导航/说明排版噪声被记录为 notes，未静默改写为任务步骤。
- `map-ecology-manifest.json` 保留网站 3 个地图组、22 个区域图及当前 MapInfo family 候选。网站地图图是家族/生态标准证据，不是 627 张 MapInfo 逐图清单。
- 扩展关系图只读连接 website identity → Legacy Atlas/stditem/skill evidence → Zircon workspace candidates → NPC/monster/Map/Quest references；名称无法闭合的边标记 pending/investigate，不删除记录、不创建引用。

## 13. 扩展验证与决策

- 生成器：`Tools/NpcMover/website_extension_alignment.py`；独立验证器：`Tools/NpcMover/verify_extension_alignment.py`；输出 `extension-verification.json`，结果=PASS。
- 所有扩展产物均 `database_write=false`；当前 7000 仍监听，不能进入真实库阶段。`DECISIONS_PENDING.md` 的审核闸门继续有效。
- 扩展报告和清单只提交本 Goal 新增脚本/产物；现有用户 WIP、Zircon 未提交 acceptance artifacts、网站未提交路径均保持不变。

## 14. 当前用户闸门决定

- 2026-09-26 用户选择“继续只读审核”，不进入写库阶段。
- 因此不停止 7000、不执行数据库备份/副本 round-trip/双库同步，不修改 `System.db` 或 `Users.db`；pending/investigate 项保持原状。
