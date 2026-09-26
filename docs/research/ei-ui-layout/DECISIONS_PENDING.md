# 网站标准对齐写库前未决事项（2026-09-26）

本文件只登记会改变产品/数据写入决策的风险；当前不执行写库。

## 必须先确认

1. **用户审核 dry-run manifest**：`artifacts/website-alignment-2026-09-26/manifest.json`。
2. **怪物未闭合项**：154 条网站记录中 67 条 confirmed、11 条 investigate、76 条 pending；pending 不是“网站无对应”，每行已记录 Hero-kill/Legacy Atlas/MonsterInfo/MonsterLookup/Zl frame/重复图路径，不能自动选择 Index。
3. **同图/一对多冲突**：网站重复图片组和 `candidate_conflict_count=10` 必须人工确认后才允许名称显示映射。
4. **NPC 位置**：294 行中保留 current 与候选位置；walkable fail=71、pending-review=190，不能盲目移动或删除 NPC。
5. **刷新点**：旧 RespawnInfo=2475；Hero-kill active refresh=679；matched=328、YXS-only=307、Zircon-only=2058、conflict=44；坐标范围/可行走/数量/范围需要按确认身份逐项审批。

## 当前硬闸门

- 7000 正在监听（阶段记录：127.0.0.1:7000，dotnet）；`database_write=false`。
- 不改服务端/客户端 `System.db`，不改 `Users.db`，不删除/创建/重排 MonsterInfo、NPCInfo、MagicInfo、MapInfo。
- mir3-website 只读；其既有未提交路径保留且未修改。
- 只有 manifest 审核、停服、双库备份、副本 round-trip、双库同步和游戏内验收全部完成后，才可进入实际应用阶段。

## 可继续而不依赖审批

- 补充未闭合怪物的独立视觉/帧证据并缩小候选集。
- 审核技能 2 条 investigate、NPC walkable fail、刷新冲突。
- 更新 manifest/report/verification；不得把 pending 直接提升为 confirmed。

## 扩展实体审核

- 网站物品 371 条中仅 47 条按当前 `db_names.json` 中文名+分类唯一闭合到 Zircon `ItemInfo`；266 条只有旧版 `stditem.json` 名称证据，58 条仍需名称/图像/属性复核。`legacy-source-only` 不得直接转成 Zircon Index。
- 网站技能 61 条的既有综合证据为 confirmed=59、investigate=2；扩展脚本的直接翻译索引较窄，不能用单一路径覆盖 Legacy Atlas 结论。2 条 investigate 继续人工复核。
- 网站任务 24 条、163 个步骤、109 个万事通子任务已生成交叉引用；任务页面首行存在导航/说明噪声，任何 QuestInfo/NPCPage 写入必须先人工核对原始页面语义。

## 用户当前决定

- 2026-09-26：用户选择“继续只读审核”；不进入写库阶段。
- 在下一次明确批准前，保持 `database_write=false`，不停止服务、不备份后写库、不修改任何 `System.db`/`Users.db`，pending/investigate 项保持原状。
