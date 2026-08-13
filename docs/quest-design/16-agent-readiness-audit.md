# Mir3 任务系统 Agent 落地完备性审计

> 审计日期：2026-08-14  
> 审计对象：`docs/quest-design/` 全部 01–16 文档及 `data/`，并以 `/tmp/mir2ei/data/wiki_all.json`、`~/development/zircon` 源码交叉核对。  
> 审计问题：一个没有项目上下文的 agent，能否仅凭这些资料把设计任务转换为可玩的 `System.db QuestInfo`？

## 一、结论摘要

**结论：资料足以让 agent 理解设计和写出配置草稿，但不足以可靠完成“可玩落地”。当前整体落地率约 25%–30%，更接近 30% 的上限，而不是已经达到 30% 的可验收状态。**

设计层是成品，数据/工程落地层仍是半成品。现有 `wiki_all.json` 中已经有 **34 个 QuestInfo、42 个 QuestTask、58 个 QuestRequirement、34 个 QuestReward**，但设计文档规划的是 **341 个新任务**；这不是“已有任务可直接复用”，而是既有少量原版样例可供格式参考，设计任务尚未入库。

### Top 5 缺口

1. **中文语义到 DB 对象的机器可用映射表**：任务里的中文 NPC、怪物、地图、技能、物品，不能直接作为 `QuestInfo` 引用；需要 `zh ↔ _identity/Index` 的带唯一性和置信度映射。
2. **任务链和依赖的正式 manifest**：341 个 ID、前置、职业分支、环序尚未成为可导入的结构化数据；`HaveCompleted` 不能引用尚不存在的对象。
3. **剧情地点/MapRegion 登记**：`望海楼`在 3803 个 `MapRegion` 中不存在，VisitRegion 没有可绑定对象；地图级名称不等于可触发区域。
4. **新增任务物品及资产规格**：`船歌谣·残片`、`船长吊坠`等不在 1078 条 `ItemInfo` 中，不能作为 `QuestTask.ItemParameter` 或 `QuestReward.Item`；还缺 ItemInfo 完整字段、图标帧和导入方案。
5. **System.db 安全写入/回滚/验证闭环**：目前资料指导“读”和设计 JSON，但没有仓库内稳定的任务专用 JSON→MirDB 导入器、引用校验、服务端/客户端双库写入、round-trip 和游戏内验收脚本。

## 二、资料盘点：文档作用与含金量

评级：**A=可直接作为设计输入；B=结构完整但需要转换/核验；C=研究或叙事参考，不能直接配置。**

| 文档 | 作用 | 现状/含金量 | 对 Agent 落地的判断 |
|---|---|---|---|
| 01-世界观与人物.md | 世界观、角色、章节和任务设计原则 | **C+/A-**：叙事基准完整，字段级配置少 | 能解释“为什么做”，不能确定 DB 引用 |
| 02-主线任务详解-三线序章.md | 战士/法师/道士序章、M3M 任务、汇合点 | **A-（设计成品）**：任务字段、文本、分支意图较完整；含 `M3M_EP1_CONVERGE` | 最适合做首个转换样本，但中文地点/前置 OR 仍不可直接入库 |
| 03-主线任务详解-共享主线.md | 汇合后的共享主线和章节链 | **A-（设计成品）**：剧情和任务链丰富 | 仍缺统一结构化 manifest、对象 ID、MapRegion 坐标 |
| 04-主线任务详解-技能觉醒.md | 224 个 M3K 技能觉醒任务，25 条史诗链 | **A-（内容成品）/B（配置半成品）**：难度、环数、职业、声望、已学三态写得很完整 | 设计规模最大；每环若没有唯一任务记录、怪物/地图/材料 ID，agent 只能重解析自然语言 |
| 05-副线任务详解.md | 57 个 M3S 副线、日常/周常、区域补足 | **A-（设计成品）/B（工程输入）** | 可作为批量生成来源，但循环重置、重复奖励等需逐条核对 |
| 06-DataList标记登记表.md | 剧情旗标、数值、命名防冲突 | **B+（半成品但很有价值）**：覆盖分支语义和命名 | 有助于生成 NPCAction/NPCCheck；缺字段化的作用域、写入页、读取页、初值和互斥规则 |
| 07-任务总表.md | 全部任务 ID、分类、统计和快速索引 | **B+（索引成品）** | 适合作为 manifest 初稿；不是 DB 导入格式，且须与 02–05、12 同步校验 |
| 08-伏笔呼应关系图.md | 伏笔埋设/回收、奖励转移 | **A-（叙事成品）** | 支持分支设计，不提供 QuestInfo/NPCPage 级落点 |
| 09-剧情小说.md | 将全部任务串成可阅读剧情，分线并行、情感节奏 | **C+/A-（叙事成品）** | 可供 agent 写台词；不是配置数据，且小说中的地点/道具仍需事实校验 |
| 10-情感与分值总览.md | 三值体系、情感节点、好感恩惠 | **B+（设计成品）** | DataValue/NPCAction 的语义来源；好感折扣等仍超出当前引擎能力 |
| 11-多人任务详解.md | 16 个 M3P，多人规模/周期/奖励 | **A-（设计成品）/B（引擎半成品）** | `QuestInfo` 本身缺组队人数条件；必须扩展或接受“solo 可做”降级 |
| 12-剧情大纲速览.md | 十分钟快速理解全剧情、D1–D29、伏笔表 | **B+（导航成品）** | 对冷启动 agent 很有用，但与 02 中个别道具叙述存在冲突 |
| 13-NPC总表.md | 新增/复用/改造 NPC、中文武侠名、精灵索引和位置基准 | **B（重要半成品）** | 已解决“选谁”的大部分问题；缺可直接引用的 NPCInfo Index、唯一实例键和 System.db 写入状态 |
| 14-任务系统实现调查报告.md | QuestInfo 字段、3 种步骤、NPCCheck/NPCAction/DataList、生命周期 | **A（研究成品）** | 引擎能力边界的权威入口；个别“奖励可发金币/经验”的概括应以当前源码为准 |
| 15-智能体自主创建任务-资料缺口与规划.md | 上一轮冷启动 `M3M_EP1_CONVERGE` 测试、4 类硬缺口、准备路线 | **A（研究成品）** | 已正确指出核心卡点；本报告增量是逐字段重走并扩展到数据质量、批量落地和验证闭环 |
| 16-道具图册.md | 道具选择指南和图册入口 | **C+/B-（半成品）**：文件仍写“生成中”、正文无逐道具列表 | `data/item_catalog.json` 已比正文先进，正文不能作为完整资产索引 |

### 资料层的总体判断

- **设计成品**：02、03、04、05、08、09、10、11、12，叙事内容和任务意图基本完成。
- **工程半成品**：06、07、13、16。它们已经是很好的人工参考，但还不是机器可消费的 schema/manifest。
- **研究成品**：14、15。对边界和失败原因的判断基本可靠；没有替代导入器、坐标登记和资产定义。
- **研究笔记/叙事参考**：01、09 的主要价值是语境，不应让 agent 直接从自由文本猜 DB 对象。

## 三、data/ 数据盘点与质量

### 3.1 当前文件

| 文件 | 规模 | 质量判断 |
|---|---:|---|
| `item_catalog.json` | **1078 条**，246,420 bytes；1078 条均有 `en/zh/type/image/icon/desc/type_guess/desc_source` 字段；925 条有 icon 路径，全部有描述 | **B+**。数量与 Zircon `ItemInfo` 1078 条对齐，中文覆盖完整；925 条视觉描述已生成，但描述与 `ItemInfo.Image` 的语义绑定仍需抽检，且不能解决新增剧情物品 |
| `item_list.html` | 244,515 bytes，静态图册页面 | **C+/B-**。便于人工浏览，不是稳定输入格式；无可依赖的关系字段 |
| `item-icons-web/` | 593 个 PNG | **C+/B**。是展示子集，不是完整 1078 条资产；需要声明图片 ID 与 `ItemInfo.Image/Index` 的对应规则 |
| `vision_batches/` | 94 个文件（47 JSON + 47 PNG） | **B**。有批次证据、可追溯；属于生成过程产物，不是任务语义数据，不能代替人工资产验收 |

### 3.2 外部但实际必须依赖的数据

`wiki_all.json` 不在本仓库 `data/`，但 agent 按现有说明需要从 `/tmp/mir2ei` 获取。其规模实测：`ItemInfo 1078`、`MagicInfo 174`、`MonsterInfo 309`、`MapInfo 544`、`MapRegion 3803`、`NPCInfo 222`、`NPCPage 302`、`MovementInfo 964`、`RespawnInfo 1833`、`QuestInfo 34`、`QuestTask 42`、`QuestRequirement 58`、`QuestReward 34`、`QuestTaskMonsterDetails 54`。这是足够的原始数据，但存在三项机器消费风险：

1. 每表引用格式不统一：有的关联是整数 Index，有的是 `_identity` 字符串。
2. 中文显示名、英文 DB identity、地图文件名、地图描述不是同一命名空间；`MapRegion._identity=Description` 在不同地图上可重复。
3. 网站页面数不能替代 DB 行数。`item_catalog` 1078 与站点 2203 页面不同，后者包含老版 DAT 超集；只有 DB 行才可直接成为奖励引用。

## 四、模拟落地路径

### 样本 A：`M3M_EP1_CONVERGE`（望海楼之约）

设计来源是 02 第 55 行附近的 5.1 节，配合 06、07、13、14。按 `QuestInfo` 模型转换，实际步骤如下：

1. **创建任务身份**：`QuestName=M3M_EP1_CONVERGE`，`QuestType=Story`。字段可确定。
2. **写四段文本**：Accept/Progress/Completed/Archive。文档有台词和叙事意图，能人工整理，但没有“哪些文本应进入 QuestInfo，哪些进入 NPCPage.Say”的结构边界。
3. **绑定 StartNPC/FinishNPC**：文档写“万事通（比奇城·望海楼）”。`wiki_all.NPCInfo` 中实测有两个“万事通”：边境城市 `(01)` 和银杏山谷 `(02)`，分别是不同 NPC identity/Index；按中文名查会撞车。13 号表也没有给导入器可直接使用的唯一 Index。
4. **绑定前置 Requirements**：`MinLevel=13` 可以直接转；三个 `HaveCompleted` 是 `M3M_PW4_MINERESCUE / M3M_PM4_MAPCAVE / M3M_PT4_MINESPIRIT`，但当前 DB 只有 34 个原版 QuestInfo，设计任务一个都没有。这三个引用是悬空对象。更严重的是设计表达“职业三线其一”，而 `PlayerObject.QuestCanAccept` 在 `ServerLibrary/Models/PlayerObject.cs:3529-3571` 逐条遍历 Requirements，任何一条失败即 `return false`；`HaveCompleted` 在 3543-3546 行、`Class` 在 3551-3567 行，全部是 AND 语义。三行前置会要求三线全完成，而不是 OR。
5. **绑定 VisitRegion**：`QuestTask.Task=VisitRegion`、`Amount=1`、`RegionParameter` 必须是一个真实 `MapRegion`。`wiki_all` 的 3803 条 `MapRegion` 中没有 `望海楼`；因此“比奇城·望海楼”只能作为地图级叙事，不能直接触发任务完成。即使采用地图级降级，也要人工选一个现有区域或新增 PointRegion 坐标。
6. **绑定 GainItem**：`ItemParameter=船歌谣·残片`。在 `ItemInfo` 1078 条中不存在该物品；`item_catalog.json` 是现有物品目录，不会凭空创建 ItemInfo。该步骤无法序列化。
7. **配置奖励**：设计写金币、声望、吊坠升级、船歌谣残片。`QuestReward` 模型在 `LibraryCore/SystemModels/QuestInfo.cs:157-273` 只有 `Item/Amount/Choice/Bound/Duration/Class`，没有金币、声望、强化或 DataList 字段；`PlayerObject.cs:3593-3628` 逐条构造 `ItemCheck(reward.Item, reward.Amount, ...)`，说明 QuestReward 只能直接发 Item。金币/声望/升级必须拆到 NPCPage 的 NPCAction：当前源码 `ServerLibrary/Models/NPCObject.cs:129-157` 有 GiveGold/GiveItem，`:193-217` 有 SpecialRefine/PromoteFame/GiveCurrency。文档没有为交付页提供逐动作序列和失败/重复执行策略。
8. **接入 NPC 对话**：需要 NPCInfo.StartQuests/FinishQuests、EntryPage、按钮及 DataList 标记。`NPCObject.cs:619-651` 确认 CheckDataList/CheckDataValue 语义；文档写“`M3_SHIP_HINT ≥1`”但 CheckDataList 是存在性判断，三档情报不能靠一个计数表达，需三个标记或 DataValue。此处可设计，但不能无歧义自动生成。

**样本 A 结论：** 文本和任务意图约 80% 可理解；可直接入 `QuestInfo` 的字段不到一半。硬阻塞为地点、物品、前置 OR、NPC 实例和奖励动作。

### 样本 B：`M3K_WAR_FLAME`（烈火剑法觉醒链）

04 的史诗总表给出：战士、等级 32、链前缀 `M3K_WAR_FLAME`、6 环、16 步、3 张地图、1 个 BOSS、声望门槛 6、C3 火灵试炼 60%、已学处理“精通”。这比样本 A 更像可批量生成的规格，但仍有以下卡点：

1. **链级信息不是环级记录**：表只给 6 环/16 步的聚合数，agent 仍需从后文自由文本推断每一环的 QuestName、顺序、StartNPC、FinishNPC、每个 Task 的 Amount、Chance、DropSet、地图和交付动作。缺少标准的“一行一个 QuestInfo”数据。
2. **技能映射可查但中文对不上**：`MagicInfo` 只有 174 条英文 identity/`Name`；文档写“烈火剑法”，必须通过语义映射找到确切 `Magic`/`Index`。奖励技能书还要查现有 `ItemInfo` 是否存在对应英文书名；不能因为 `item_catalog` 有“Book”分类就认定存在目标书。
3. **试炼怪和地图是多个外键**：`QuestTaskMonsterDetails` 要求真实 `MonsterInfo`、可选 `MapInfo`、`Chance`、`Amount`、`DropSet`（模型字段见 `QuestInfo.cs:453-548`）。设计的“火灵/BOSS/3 张地图”如果只是中文名或剧情称呼，无法自动选择唯一 DB 对象；同名/别名必须人工确认。
4. **声望门槛位置不一致**：QuestRequirement 枚举只有 `MinLevel/MaxLevel/NotAccepted/HaveCompleted/HaveNotCompleted/Class`（`LibraryCore/Enum.cs:1971-1979`），没有 Fame；14 号调查也说明声望检查走 NPC 对话 `NPCCheck.CheckFame`。因此“CheckFame≥6”必须转换成接取页 NPCCheck/NPCRequirement 的具体对象和页跳转，而不是写进 QuestInfo.Requirements。
5. **“已学三态/精通”不在 QuestInfo 奖励字段**：当前引擎没有 HasMagic 任务条件或 LevelMagic 任务动作；设计中的换奖/精通/剧情专属跳过，要么人工降级为普通技能书/对话分支，要么开发服务端扩展。14 号文档已列为缺口，但 04 仍按设计语义描述，agent 不能自行决定产品行为。
6. **高频任务资产不完整**：16 环步骤通常会产生大量“火灵材料/碑文/魂契”等叙事物品。它们不在现有 `item_catalog` 即意味着必须新增 ItemInfo，而不是在配置中写中文名称。
7. **递送和对话不是 QuestTask 类型**：14 号确认 QuestTask 只有 KillMonster/GainItem/VisitRegion（`LibraryCore/Enum.cs:1981-1986`）；04 中“TakeItem/GiveItem 双 NPC”是 NPCPage Actions 流程，需要明确 NPCPage、按钮 ID、TakeItem/GiveItem 顺序。

**样本 B 结论：** 史诗链总览对策划很有含金量，但对导入器而言仍是“聚合规格+自然语言”，必须先转成结构化环级 manifest，并补全技能/怪物/地图/物品外键。

## 五、缺口清单（按优先级）

### P0：没有这些就不能让 agent 可靠产出可玩配置

| 缺什么（具体文件/字段） | 实际卡点 | 建议补法 |
|---|---|---|
| `quest_manifest.json`：每任务一行 `QuestName/Type/StartNPC/FinishNPC/Requirements/Tasks/Rewards/DialogueRefs/Status`；每环唯一 ID 和 `PrevQuest` | 当前 DB 34 个 QuestInfo，设计 341 个；M3K_WAR_FLAME 只有 6 环聚合统计，无法无歧义生成 6 个 QuestInfo | **脚本生成初稿 + 人工审定**；从 02–07、11 抽取，再做数量/ID/链完整性检查 |
| `semantic_map.json`：`zh, en_identity, table, Index, confidence, aliases, source`，覆盖地图/区域/NPC/怪物/物品/技能 | “万事通”命中两个 NPC；“烈火剑法”不是 DB 的直接 identity；地图中文名、英文名、文件名是多命名空间 | **脚本从 wiki_all/item_catalog 批量生成候选，人工处理歧义**；这是最高优先级自动化资料 |
| 剧情地点登记表：`LocationId, zh, MapInfo.Index/_identity, MapRegion.Index, PointRegion, trigger_mode, verified_by` | `望海楼`在 3803 个 MapRegion 中不存在，VisitRegion 无法配置；地图级降级仍缺正式触发点 | **地图/区域候选脚本生成，剧情坐标和最终 PointRegion 必须人工/游戏内验证** |
| 现有任务/新任务依赖图：每个 `HaveCompleted` 的目标、职业分支、是否 OR、替代方案 | `M3M_EP1_CONVERGE` 的三线其一被当前 AND 语义强制变三线全完成 | **人工拍板 OR 策略**（推荐拆成 3 个 QuestName）；脚本验证 DAG、孤儿和环序 |
| System.db 导入器和验证器 | 现有资料能读 JSON，但不能把 341 个对象安全写成 MirDB；手写或直接写运行库风险高 | **脚本开发**：JSON→DB 对象、引用校验、dry-run、备份、双库写入、round-trip；游戏内验收人工完成 |

### P1：可以写配置但会导致内容错误/不可玩

| 缺口 | 例子/原因 | 建议补法 |
|---|---|---|
| 新 ItemInfo 清单及字段：ItemName、ItemType、Shape、Image、RequiredClass/Amount、StackSize、Description、绑定/可交易策略 | `船歌谣·残片/船长吊坠`不存在；现有 `item_catalog` 只有 1078 个现存物品，不能充当新物品定义 | **人工确定语义和经济属性；脚本生成模板；美术/客户端验证图标帧** |
| NPC 实例注册表：唯一 identity、NPCInfo Index、MapInfo、PointRegion、Image/FaceImage、Start/Finish 任务归属 | 两个“万事通”同名；13 号表的人名/位置尚未等同于 DB 对象 | **脚本从 wiki_all/NPC 页面生成候选；人工决定复用/新增；游戏内验证坐标与可见性** |
| 任务动作表：每个交付页的 `NPCPage`、Button、Checks、Actions 顺序及 flag/data scope | 金币/声望/强化不能写 QuestReward；`NPCObject.cs:129-217` 才是可执行落点 | **agent 可生成草稿，必须人工审查顺序、失败页、幂等性** |
| 怪物/地图/掉率/DropSet 外键表 | M3K 的“火灵”“BOSS”“3 张地图”不能直接转 `MonsterInfo`/`MapInfo`；Chance/DropSet 对玩家体验影响大 | **脚本候选匹配+统计；策划人工选定，游戏内掉落验证** |
| 技能与技能书映射：中文技能→MagicInfo，技能→ItemInfo 书，HasMagic/精通策略 | 04 的“已学三态”超出当前 QuestInfo；MagicInfo 仅 174 条英文数据 | **脚本生成现有映射；产品人工决定降级还是扩展源码；技能学习必须游戏内验收** |
| 地图名称/版本单一真相表 | 02 的“比奇城·望海楼”和 wiki 的“边境城市/比奇县”等命名空间可能混用 | **脚本生成 ID 表；人工批准设计世界地图命名** |
| 14/04 引擎能力差异登记 | `CheckFame` 是 NPC 页检查，不是 QuestRequirement；QuestTask 只有三类；多人组队、HasMagic、Mail、好感折扣未原生支持 | **维护一份机器可读 capability matrix；脚本在导入前阻止非法字段** |

### P2：不阻止首批任务，但阻止完整 341 任务体验

- M3P 组队人数与职业协作：当前无 `GroupCount` 条件，需服务端扩展或明确 solo 降级。
- NPC 来信、好感折扣、称号/纪念物/场景痕迹、多周目：需要 MailInfo/动作/持久化等产品级决定，不能只凭剧情文档生成。
- `DILEMMA_*`、三值 DataValue 的作用域、初值、累加上限、结局阈值需要结构化登记；`NPCObject.cs:619-651` 显示 DataList 用 `{flag}_NameList`，DataValue 用裸 category，命名错误会读不到同一状态。
- NPCPage 的按钮文本和 ID 对照表：服务端通过 `[Text:ID]` 解析，文本可翻译但 ID 不能猜；需要生成/校验按钮图。
- 自动化验收 fixtures：角色职业/等级/前置、地图坐标、怪物刷点、任务物品库存、奖励背包空间和重复接取情形。

## 六、可自动生成 vs 必须人工

### 可脚本批量生成（但要报告歧义，不可盲写）

1. 从 `wiki_all.json` 生成所有表的 `Index/_identity` 索引、字段 schema、引用反向索引。
2. 从 `item_catalog.json` 生成现有 1078 物品的 `zh→ItemInfo.Index/ItemName` 映射；可将 925 个 icon、1078 个描述和来源字段纳入候选报告。
3. 从 `wiki_all` 生成 NPC/怪物/魔法/地图/MapRegion 的中文、英文、Index、Map、坐标候选，以及同名冲突报告（如两个万事通）。
4. 解析 02–07、11 的任务 ID、任务类型、前置词、技能/怪物/物品/地图提及，生成 `quest_manifest.json` 初稿。
5. 生成任务 DAG、孤儿前置、重复 ID、引用不存在、职业和数量字段缺失检查。
6. 将 Reward 中“金币/声望/吊坠升级”分类为 `QuestRewardItem` 或 `NPCActionRequired`，阻止把非 Item 写入 `QuestReward`。
7. 根据 `QuestInfo.cs` 与 `Enum.cs` 生成能力校验：只允许三种 QuestTask；Requirement 只允许六种；检查 Reward 必须有 Item；检查 `Chance/Amount/DropSet` 类型和范围。
8. 批量生成新物品/NPC/MapRegion 的**待审模板**、System.db 备份清单、round-trip 对照报告。

### 必须人工拍板或游戏内验证

1. 三线 OR 的产品方案：推荐 3 个任务 ID（零改引擎），不能由 agent 默默选择。
2. 剧情地点的最终地图、坐标、触发半径和视觉合理性；`望海楼`尤其需要人工确认。
3. 新物品的真实用途、经济价值、可交易/绑定策略、外观和图标帧；技能书是否复用现有 Book 图标不能代替语义确认。
4. 同名 NPC 复用还是新增、武侠中文名、台词人格、实际贴图和站位。
5. 任务掉率、BOSS、DropSet、任务长度和奖励经济；脚本只能查表，不能替策划决定体验。
6. 已学技能三态是普通奖励替换、技能经验/精通，还是跳过；如果选精通/跳过，需要服务端实现和测试。
7. 多人任务是否强制组队、人数、职业组合和失败重试。
8. System.db 写入后的服务端+客户端双库一致性、重启加载、NPC 可见、任务进度、奖励领取和重复交付的游戏内验收。

## 七、补齐路线图与工作量估计

以下按 1 名熟悉 C#/Python/MirDB 的工程师，另有策划/游戏内验证协作估算；工作量是首次打通，不是 341 个任务逐条内容创作时间。

### 第 0 步：冻结决策（0.5–1 人日，人工）

- 拍板 M3M 汇合 OR 方案，建议拆 3 个 QuestName。
- 统一比奇/边境城市/银杏/白日门的地图命名和版本口径。
- 列出“必须新增资产”和“必须服务端扩展”的范围。

### 第 1 步：生成数据索引与语义映射（1–2 人日，脚本+人工抽检）

- 生成 `semantic_map.json`、同名冲突报告、MapInfo/MapRegion/NPC/Monster/Magic/Item 索引。
- 用 `item_catalog.json` 覆盖现存物品；把 2203 页面与 1078 DB 行明确分层。
- 先抽检 100 个任务高频词，不要等待 341 个任务全部完成。

### 第 2 步：任务结构化 manifest（2–4 人日，脚本初稿+策划审核）

- 将 02–07、11 转成一行一个任务/一行一个 Task/Reward/Action 的 JSON。
- 生成 DAG、数量、前置、职业和外键报告。
- 首批只做 M3M 序章 12 个任务 + 一条 M3K 6 环链，建立可复用模板。

### 第 3 步：地点、NPC、资产登记（2–5 人日，人工/游戏内）

- 地图级候选可脚本化；PointRegion、剧情建筑、NPC 站位和复用关系必须人工确认。
- 为船歌谣/吊坠以及首批技能材料制作 ItemInfo 草稿、图标帧和中文显示名。
- 先验证 `M3M_EP1_CONVERGE`，再扩展所有稀有任务物品。

### 第 4 步：QuestInfo 导入器与 dry-run（2–4 人日，工程）

- JSON→MirDB 对象，解决关联对象按 Index/identity 的写入；生成前置、任务、奖励、NPCPage。
- 必须具备：不修改运行库的 dry-run、引用校验、备份、服务端/客户端双库写入、round-trip 导出对比。
- 参考现有 MirDB Session 写入约定，但不要把任务数据直接写到正在运行的服务器。

### 第 5 步：首批游戏内闭环（1–2 人日，游戏内验证）

- 真实完成一个战士/法师/道士序章任务和 `M3M_EP1_CONVERGE` 的一个职业变体。
- 验证接取、杀怪/拾取/到达、NPC 对话、DataList、奖励、重启后持久化和重复接取。
- 再验证 `M3K_WAR_FLAME` 第一环，确认掉率和技能书奖励路径。

### 第 6 步：批量扩展与能力补丁（5–15+ 人日，依内容量浮动）

- 批量导入剩余主线/副线/技能链，逐批生成失败报告。
- 对 HasMagic、精通、GroupCount、Mail、好感折扣等逐项做服务端扩展或设计降级。
- 每批仍需抽样游戏内验证，不能以 JSON 导入成功代替可玩性。

**推荐顺序：先 0→1→2，再用一个小闭环验证 3→5，最后才批量 341 个任务。** 若反过来先写全量内容，最终会得到大量无法解析的中文外键、悬空前置和不存在的奖励物品。

## 八、最终判定

现有资料对“写出有剧情、有任务 ID、有步骤意图的设计草稿”已经足够；对“零上下文 agent 自动产出并导入可玩的 QuestInfo”还不够。**按完整 341 任务范围，我判断当前资料约能支持 25%–30% 的落地工作：任务语义和引擎理解接近完成，真正的对象映射、外键、地点、资产、导入和验证链尚未闭环。**

换句话说：**达到“30% 设计落地率”可以；达到“30% 可玩任务已经可靠落库”还不可以。** 先补齐 Top 5，尤其是 `semantic_map.json + quest_manifest.json + 地点/NPC登记 + 新物品定义 + 导入/验证器`，才会从“会写草稿”进入“能稳定交付”。
