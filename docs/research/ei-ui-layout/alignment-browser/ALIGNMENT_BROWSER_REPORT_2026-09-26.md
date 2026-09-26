# Zircon ↔ mir2ei 双向差异对照网页报告

生成时间：2026-09-26 09:19 UTC
入口：`docs/research/ei-ui-layout/alignment-browser/index.html`
数据版本：`MIR3-ALIGNMENT-BROWSER-2026.09.26`

## 本次结论

网页不再把所有未解决项折叠为 `pending`。生成器为每条记录写入统一字段：

- `entity_type`
- `zircon.exists / index / name / fields / source`
- `mir2ei.exists / id / name / fields / source`
- `direction`: `both`、`mir2ei-only`、`zircon-only`
- `conclusion`: `resolved`、`partial`、`conflict`、`pending-evidence`、`retain-current`、`production-applied`，以及方向性结论
- `dimensions`: 身份、名称、图片、属性、地图、坐标、刷新、掉落、任务关联
- `reason`、`evidence`、`current_usage`、`next_action`

结论文案固定为：

| 结论 | 页面文案 |
|---|---|
| `mir2ei-only` | mir2ei 有，Zircon 当前没有安全对应项 |
| `zircon-only` | Zircon 有，mir2ei 当前没有对应标准记录 |
| `conflict` | 双方有候选，但身份或资源冲突 |
| `pending-evidence` | 证据不足，暂不覆盖当前 Zircon |
| `resolved` | 身份和结论已闭合 |
| `partial` | 双方身份已确认，但名称/图片/地图/刷新仍不同 |
| `production-applied` | 已应用到生产双库 |
| `retain-current` | 有证据但按当前决定保留 Zircon |

`retain-current` 只允许在双方实体都存在、且有明确保留当前 Zircon 的证据时出现。单纯没有资料站逐项对应的记录统一显示为 `zircon-only`，不会再把“资料范围外”误报为已确认保留。

## 双向方向数量

所有生成记录逐条计数；每类均断言 `mir2ei-only + zircon-only + both = total`，重复使用同一 Zircon Index 的候选全部保留并升级为 `conflict`，不静默覆盖。

| 分类 | mir2ei-only | zircon-only | 双方都有 | 记录总数 |
|---|---:|---:|---:|---:|
| 怪物 | 87 | 373 | 67 | 527 |
| NPC | 0 | 106 | 188 | 294 |
| 物品 | 324 | 1,031 | 47 | 1,402 |
| 技能 | 2 | 115 | 59 | 176 |
| 地图 | 0 | 450 | 22 | 472 |
| 刷新 | 0 | 2,058 | 417 | 2,475 |
| 任务 | 62 | 0 | 0 | 62 |
| **合计** | **475** | **4,133** | **800** | **5,408** |

方向数量只覆盖当前 manifest / candidate / Index 能表达的记录范围，不把 website 数量与 Zircon 表行数做差后臆造实体匹配。

## 结论数量

| 结论 | 数量 |
|---|---:|
| `mir2ei-only` | 475 |
| `zircon-only` | 4,133 |
| `resolved` | 546 |
| `conflict` | 116 |
| `partial` | 47 |
| `pending-evidence` | 0 |
| `production-applied` | 91 |
| `retain-current` | 0 |

本轮输入范围中没有单独满足 `pending-evidence` 或 `retain-current` 的双方候选记录；这两个筛选项仍保留在页面和数据模型中，后续新增证据不会退回旧的 `pending` 总类。`production-applied=91` 包含批准的 NPC 73 条与 RespawnInfo 18 条。

## 分类别结论抽样

- **怪物 resolved**：`website:mob-0`，Zircon `Index=8 / Chicken`，mir2ei 标准名 `鸡`；来源为 `monster-manifest.tsv`、workspace `MonsterInfo.json` 与 website monsters 数据。
- **怪物 mir2ei-only**：怪物 manifest 中没有可靠 Zircon Index 的 87 条，页面显示“mir2ei 有，Zircon 当前没有安全对应项”，不会按名称猜索引。
- **怪物 conflict**：同一 Zircon Index 被多个 manifest 候选使用或原始 manifest 标为冲突的 12 条，全部保留为独立记录。
- **NPC partial / production-applied**：NPC manifest 的地图、身份、坐标证据分维度显示；73 条批准计划进入 `production-applied`，其余身份或位置差异不会被生产状态掩盖。
- **物品 mir2ei-only**：371 条 website item manifest 中 324 条没有安全 Zircon Index；Zircon 1,031 条没有资料站逐项对应，显示为 `zircon-only`。
- **技能 resolved**：59 条 manifest 候选闭合；另外 2 条资料站记录和 115 条 Zircon 技能保持方向性记录，不用 61 vs 174 的数量差匹配。
- **地图 partial / conflict**：22 个 website map family 区域图映射到候选 MapInfo；网站地图图不是 627 张逐图 MapInfo，因此未匹配的 450 条保留为 `zircon-only`。
- **刷新 conflict / production-applied**：RespawnInfo 2,475 条逐项保留；89 条原始 conflict，18 条批准应用，2,058 条仅有当前 Zircon 刷新记录。
- **任务 mir2ei-only**：当前 24 条 website mission cross-reference 展开为 62 条记录；没有安全 QuestInfo 名称闭合的记录不会伪装成 resolved。Zircon QuestInfo 的 38 条当前记录仍逐项保留在同一记录清单中；任务来源是 mission cross-reference，不是 website 总条数差值。

## 页面行为

- 总览新增 8 张双向结论卡：`mir2ei-only`、`zircon-only`、`both-resolved`、`both-conflict`、`pending-evidence`、`partial`、`production-applied`、`retain-current`；卡片可进入全站过滤。
- “差异清单”入口分成 `mir2ei 有 / Zircon 没有` 与 `Zircon 有 / mir2ei 没有` 两个大区，按怪物、NPC、物品、技能、地图、刷新、任务分组，支持搜索与当前过滤 JSON 导出。
- 每个实体分类拥有统一结论筛选：全部、已解决、mir2ei-only、Zircon-only、双方都有但不同、待证据、已应用、保留当前 Zircon。
- 列表行显示方向、结论、两侧名称/Index/ID、当前使用名、差异维度、原因、下一步。
- 详情抽屉左右并排显示 Zircon 与 mir2ei/website 真实字段；下方显示维度矩阵、证据路径、规范化记录和 raw manifest。

## Scope 限制

1. website 怪物 154 条不是 Zircon 434 条 MonsterInfo 全量；本页只把 monster manifest 中有证据的 154 条逐条展开。
2. website 技能 61 条不是 Zircon 174 条 MagicInfo 全量；技能仅按 `skill-manifest.tsv` 的 Index / catalog / icon 证据闭合。
3. website 物品 371 条不是 Zircon 1,078 条 ItemInfo 全量；只有 `item-manifest.json` candidate 允许的 Index 才进入双方候选。
4. 资料站地图是 3 组 / 22 个 map family 区域图，不是 627 张 MapInfo 逐图清单；地图 `zircon_mapinfo_candidates` 仅表示候选范围。
5. 任务记录来自 24 条 mission cross-reference 及当前 QuestInfo 名称命中；网页步骤噪声或没有安全命中时必须保持方向性结论。
6. `mir2ei-only` 表示当前资料范围有记录且没有安全 Zircon 对应项，不表示 Zircon 世界一定缺少同一业务实体；`zircon-only` 表示当前 Zircon 有记录且当前资料范围没有对应标准记录，不表示资料站全网不存在它。
7. 图片、属性、地图、坐标、刷新、掉落和任务关联只有在来源字段足够时才升级为 `same` / `different`；否则显示 `unknown` 或 `not-available`。
8. 生产应用仍只认 approved offline plan、双库 round-trip、备份和游戏 smoke 证据；页面不会因为候选名称相似而写库。

## 输入规模

### Zircon workspace

| 表 | 行数 |
|---|---:|
| ItemInfo | 1,078 |
| MonsterInfo | 434 |
| MagicInfo | 174 |
| NPCInfo | 294 |
| MapInfo | 627 |
| MapRegion | 5,009 |
| RespawnInfo | 2,475 |
| QuestInfo | 38 |
| DropInfo | 10,382 |
| ItemInfoStat | 3,196 |
| MonsterInfoStat | 4,117 |

### website / 资料站

| 数据 | 条数 |
|---|---:|
| items | 371 |
| monsters | 154 |
| skills | 61 |
| missions | 24 |
| map groups | 3 |
| map family areas | 22 |

## 生成与验证

- 生成器：`/home/tetsuya/mir3-venv/bin/python docs/research/ei-ui-layout/alignment-browser/build_alignment_browser.py`，成功重建 `data/*.json` 与图片副本；每类方向完整性断言通过。
- `python3 -m py_compile docs/research/ei-ui-layout/alignment-browser/build_alignment_browser.py`：通过。
- `node --check docs/research/ei-ui-layout/alignment-browser/app.js`：通过。
- `favicon.svg` HTTP 200；`meta.json` 与 7 个分类 JSON HTTP 200。
- `app.js` 使用 `cache: no-store` 加载静态 JSON，`AbortError` 单次重试且不会作为页面致命 console 错误；`index.html`、`style.css`、`app.js` cache-bust 版本为 `20260926.3`。
- 静态页面不引入 npm / build system；服务绑定 8890，仅读静态文件。
- 本报告和数据只修改 `docs/research/ei-ui-layout/alignment-browser/`；不写 System.db、Users.db、workspace、Zircon、mir3-website 或 mapedit。
