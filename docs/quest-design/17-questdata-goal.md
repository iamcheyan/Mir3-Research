# 任务系统落地资料补齐（semantic_map + quest_manifest + 导入器）— 完整任务目标

## 一、背景

任务设计 341 个（M3M_44/M3S_57/M3K_224/M3P_16）已成文档，但 agent 落地审计
（docs/quest-design/16-agent-readiness-audit.md）判定可靠落库率仅 25-30%，
Top5 缺口中三个可工程化补齐——本 goal 就是补这三个，完成后落地率应到 70%+。

zdocs 代码文档库（zircon/docs/codebase/ 23 篇）已就绪，任务引擎约束先读它。

## 二、三件交付

### D1 semantic_map.json（中文名↔DB 语义映射表）⭐最优先
脚本 `Tools/questdata/gen_semantic_map.py`（mir3-venv）：
- 输入：dbeditor workspace/*.json（ItemInfo 1078/MonsterInfo 434/MagicInfo 174/
  NPCInfo 294/MapInfo 627/MapRegion 5009）+ db_names.json（中文名）+
  docs/quest-design/data/item_catalog.json（1078 物品 zh）
- 输出 `docs/quest-design/data/semantic_map.json`：
  ```json
  {"items": {"烈火剑法书": {"Index": 42, "Name": "FlamingSwordBook", "type":"Book"},
             "治疗药水": {...}},
   "monsters": {"沃玛战士": {...}}, "magics": {...}, "npcs": {...},
   "maps": {"比奇县": {"Index": 0, "FileName": "0"}, "regions": {"比奇县/望海楼": {...}}},
   "stats": {"DC": "MaxDC", ...}}
  ```
- 生成规则：英文名/中文名双索引；别名表（沃玛=Oma、沙巴克=Sabuk 等常见叫法，
  参考 NAMING_RULES 文档的光通译名）；**每个词条标 confidence**
  （exact 唯一命中=1.0 / 多候选=0.5 列出候选 / 未命中=0 进 orphans 清单）
- 输出统计报告：各表覆盖率、orphans（设计文档用到但库里没有的名词——
  这正是缺口 4 剧情物品清单的自动生成器）
- 验收：物品/怪物/魔法/NPC/地图五表覆盖率 ≥95%（指库内条目被索引）；
  抽查 20 个任务文档高频名词能查到

### D2 quest_manifest.json（341 任务机器可读清单）
脚本 `Tools/questdata/gen_quest_manifest.py`：
- 解析 docs/quest-design/02-05/07/12 六篇文档的任务表格（markdown 表格→结构化），
  每任务产出：`id(M3M_..)/类型/名称/职业线/等级段/环数/前置任务id/涉及NPC/
  涉及地图/涉及怪物/涉及物品/奖励/情感点/两难抉择(D 编号)`
- 缺失字段标 null 不编造；解析不了的行进 parse_errors 清单人工看
- 用 D1 的 semantic_map 把涉及 NPC/怪物/物品/地图的中文名尝试绑 DB Index
  （绑上的填 index，绑不上的保持中文名+confidence 0）
- 输出统计：341 任务全进 manifest 了吗、parse_errors 数、字段完整度矩阵
- 验收：manifest 覆盖 ≥330/341；每任务至少 id/名称/类型/等级段/环数五字段非空

### D3 QuestInfo 导入器（走 dbeditor 纪律）
`Tools/questdata/import_quest.py` + dbeditor 新端点：
- 输入：单任务的 QuestInfo 配置 JSON（先手工/agent 起草 2 个样板：
  M3M_EP1 拆三职业版 + 一个简单 M3K_）→ 写入 dbeditor workspace/QuestInfo.json
  及 QuestTask 等子表（尊重 AND 语义/QuestReward 只发物品等引擎约束——
  约束表直接从 16 号审计报告抄）
- dbeditor 端 POST /api/quest_apply：校验（前置任务存在/物品存在/区域存在/
  Index 不冲突）→ 写 workspace + git 留痕 → 用户仍走「同步到数据库」按钮落库
- **不做批量 341 全导入**——本 goal 只交付管线+2 个样板任务真入库
  （同步+无头客户端进游戏接任务截图证明端到端）
- 验收：2 个样板任务游戏内可见可接（截图）；悬空引用被校验器拒绝的演示

## 三、边界

- 写库只经 dbeditor workspace+sync.sh，绝不直写 System.db
- 服务端可能被 webclient goal 占用做验证——测试前 pgrep 查，冲突就先做 D1/D2
- 端口/目录全部在 Mir3-Research；zircon 只读
- 完成后更新 16 号审计报告的状态列（缺口1/2/5 标记已补齐）

## 四、执行顺序

D1（1-2h，纯脚本）→ D2（依赖 D1）→ D3（管线+样板）→ 更新审计报告 →
commit+push（中文信息）
