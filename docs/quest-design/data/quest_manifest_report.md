# quest_manifest 生成报告

- 输出：`docs/quest-design/data/quest_manifest.json`
- 任务总数：**341/341**（验收线 ≥330）
- 分布：M3K_ 224、M3M_ 44、M3P_ 16、M3S_ 57
- 核心五字段（id/名称/类型/等级段/环数）齐全：**341/341**
- 两难绑定：45 个任务
- parse_errors：0

## 字段完整度矩阵

| 字段 | 非空数 | 占比 |
|---|---|---|
| id | 341 | 100.0% |
| name | 341 | 100.0% |
| type | 341 | 100.0% |
| class_line | 243 | 71.3% |
| level_range | 341 | 100.0% |
| rings | 341 | 100.0% |
| prev_quests | 238 | 69.8% |
| npcs | 127 | 37.2% |
| maps | 123 | 36.1% |
| monsters | 227 | 66.6% |
| items | 187 | 54.8% |
| rewards_raw | 341 | 100.0% |
| emotion_points | 198 | 58.1% |
| dilemma | 35 | 10.3% |

## DB 绑定率（semantic_map）

| 字段 | 绑上 Index | 总提及 | 绑定率 |
|---|---|---|---|
| npcs | 28 | 145 | 19.3% |
| maps | 38 | 123 | 30.9% |
| monsters | 113 | 260 | 43.5% |
| items | 33 | 210 | 15.7% |
| regions | 0 | 107 | 0.0% |