# NPC + 怪物 + 技能 + 地图网站标准对齐报告（2026-09-26）

> 本报告是只读 dry-run 证据。未写入真实 System.db；网站 checkout 未修改。

## 1. 来源与硬闸门

- 标准资料站：`/home/tetsuya/development/mir3-website`（`data/monsters.json`=154，`data/skills.json`=61，地图区域图=22）。
- Zircon 当前快照：MonsterInfo=434，MagicInfo=174，NPCInfo=294，MapInfo=627，RespawnInfo=2475。
- 7000 检查：运行时由阶段 0 记录为监听；因此本报告只读，写库闸门未开启。
- 数据库写入：`database_write=false`；没有删除、创建或重排 MonsterInfo/NPCInfo/MagicInfo/MapInfo。

## 2. 网站索引和图片证据

- 网站怪物：154；分类数=21；技能：61。
- 怪物状态：confirmed=67，investigate=11，pending=76，unmatched=0。
- 技能状态：confirmed=59，investigate=2，pending=0；MIcon header present=59。
- 每条网站记录保留页面路径、原始图片路径、sha256、字节数、尺寸、来源描述；重复图片组见 `website-index.json`。

## 3. 怪物全量匹配

- `confirmed` 只表示已有稳定 Zircon MonsterInfo 候选且 MonsterLookup/Mon-*.Zl 帧探针可复现；它是显示名计划，不是写库批准。
- `investigate` 保留一对多、同图不同名、资源别名但当前快照缺行等冲突；不得自动覆盖。
- `pending` 不是“网站没有对应”。每行的 `match_evidence` 记录了名称/别名、MonsterInfo/属性、MonsterLookup、Mon-*.Zl 帧、重复图片与区域路径；需在获得更强证据后闭合。
- 白野猪、半兽人、祖玛卫士、Boss/变体等高风险样例均保留候选与冲突，不模糊改索引。

## 4. 技能

- 61 条技能逐条由网站名称/职业/描述、Legacy Atlas 技能交叉目录、MagicInfo、MIcon.Zl header 复核。
- `catalog-skills.html` 的 old-only 行（例如凝血离魂、移花接玉）保持 investigate/pending；不把“无直接对应”当成最终结论，不改施法逻辑。

## 5. 地图与 NPC

- 网站地图共 17 个迷宫区域图 + 世界地图 + 神舰 4 层；没有把它们当成 627 张逐图清单。
- `map_family_manifest.json` 按网站区域名称列出 MapInfo 候选、文件名、描述；具体地图 walkable/尺寸/入口证据复用现有独立 manifest。
- NPC 全量和候选位置：复用 `/home/tetsuya/development/Mir3-Research/docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/manifest.json`，行数=294；NPC 与怪物身份/写入状态分开。
- NPC 统计：match_method={"semantic-audit": 58, "pending": 36, "exact-script-name": 96, "exact-script-name-map": 34, "hero-kill-extra": 70}；map_relation={"variant": 78, "exact": 165, "replacement": 19, "renamed": 6, "pending": 26}；walkable={"pass": 223, "fail": 71}；apply={"pending-review": 190, "dry-run": 104}；overlap_rows=0。
- NPC 没有可靠位置时保持 retain-current，并在既有 manifest 的 candidate/skip_reason 中记录；不删除 NPC。
- 地图统计：MapInfo=627；relation={"variant": 12, "exact": 526, "replacement": 6, "renamed": 12, "pending": 71}；coordinate_reuse={"blocked": 89, "allowed-after-point-check": 538}。
- NPC 全量字段和候选位置行位于外部机器 manifest；本 Goal 不复制/覆盖其内容。

## 6. 刷新点 dry-run

- 刷新全量：旧 RespawnInfo=2475；Hero-kill parsed=679；matched=328；YXS-only=307；Zircon-only=2058；conflict=44。
- Respawn walkable={"fail": 917, "pass": 1510, "pending": 48}；apply={"blocked": 2147, "pending-review": 328}；旧/新逐行清单仍在外部 manifest。
- Website identity is separate from refresh position: website standard supplies identity/display-name evidence; GB18030 Hero-kill/Mud3 supplies refresh coordinates/count/range.

## 7. 独立验证与关键样例

- 独立验证脚本：`Tools/NpcMover/verify_website_alignment.py`，不导入生产转换器；检查 JSON 数量、图片文件/尺寸/hash、MonsterLookup/Mon-*.Zl、MIcon、manifest 状态和索引稳定性。
- 关键样例：半兽人、祖玛、祖玛卫士、白野猪、Boss；技能火球术/基本剑术；NPC 至少 3 行；结果见 `verification.json`。

## 8. 写库闸门与未提交文件保护

- 7000 当前有监听；未满足停服、用户 dry-run 审核、备份、临时副本 round-trip、双库同步、游戏内验收条件，因此本 Goal 阶段不写真实库。
- Mir3-Research 与 Zircon 的阶段 0 工作树状态保存于 `baseline-repo-state.json`；无关 WIP 保留，不纳入本 Goal 文件。
- 真实库、Users.db、资料站内容均未修改。

## 9. 机器可读产物

- `manifest.json` / `monster-manifest.tsv` / `skill-manifest.tsv` / `map-family-manifest.json` / `website-index.json` / `verification.json`。
