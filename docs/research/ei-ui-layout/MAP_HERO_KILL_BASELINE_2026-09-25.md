# MAP-HERO-KILL-BASELINE-2026-09-25

> 离线基准。`hero_kill_*` 指本地 `/home/tetsuya/mir2ei/Map`，`zircon_*` 指当前 Zircon ServerCore 地图和 MapInfo。所有坐标为逻辑地图格；本报告和 manifest 均未写数据库。

## 结论

- MapInfo **627** 条；英雄杀地图文件 **544**；Zircon 地图文件 **794**。
- 对应关系：`{"variant":12,"exact":526,"replacement":6,"renamed":12,"pending":71}`；坐标复用：`{"blocked":89,"allowed-after-point-check":538}`。
- `exact/renamed` 仅在独立范围/可行走检查后允许 identity transform；`variant/replacement/pending` 禁止盲拷坐标，目标只能进入人工复核。
- `map_manifest.json`/`map_manifest.tsv` 是全量机器清单；以下表格保留每个 MapInfo 的尺寸、关系、地标、walkable parser 状态。

## 关键地图抽查

| Map | Description | Hero 尺寸 | Zircon 尺寸 | relation | transform | Hero walkable | Zircon walkable | landmarks |
|---|---|---:|---:|---|---|---|---|---|
| 0 | Bichon Town | 800×800 | 800×800 | variant | pending landmark mapping; no blind coordinate reuse | pass | pass | 0 / Town Area, 0 / Bug Cave Entrance, 0 / Ant Cave Entrance, 0 / Bichon Castle Entrance, 0 / Bichon Caves Entrance, 0 / Deserted Mines Entrance |
| 2 | Banya Village | 400×400 | 400×400 | exact | identity logical-grid coordinates | pass | pass | 2 / Town Area, 2 / Player Spawns, 2 / 2 / Teleport Stone, 2 / Teleport Landing, 2 / 2 / Weapon Store, 2 / 2 / Armour Store |
| 3 | Sabuk Keep | 400×600 | 350×350 | replacement | pending landmark mapping; no blind coordinate reuse | pass | pass | 3 / Sabuk Area, 3 / Flag Area, 3 / Teleport Area Left, 3 / Teleport Stone Left, 3 / Teleport Landing Left, 3 / Bichon Town Door |
| 4 | Numa Village | 800×800 | 800×800 | exact | identity logical-grid coordinates | pass | pass | 4 / Safe Zone, 4 / Player Spawn Area, 4 / 4 / Teleport Stone, 4 / Teleport Landing, 4 / 4 / Potion Store, 4 / 4 / Collector Store |
| 5 | Desert Mud Fortress | 400×400 | 350×350 | replacement | pending landmark mapping; no blind coordinate reuse | pass | pass | 5 / Teleport Area, 5 / 5 / Teleport Stone Left, 5 / Teleport Landing Left, 5 / 5 / Teleport Stone Castle, 5 / Teleport Landing Castle, 5 / 5 / Weapon Store |
| D1105 | Zuma Temple Lv 5 | 300×300 | 300×300 | exact | identity logical-grid coordinates | pass | pass | D1105 / Respawn Area 1, D1105 / Respawn Area 2, D1105 / Respawn Area 3, D1105 / Respawn Area 4, D1105 / Respawn Area 5 |
| D202 | Deserted Mine Lv 2 | 300×300 | 200×200 | replacement | pending landmark mapping; no blind coordinate reuse | pass | pass | D202 / Respawn Area 1, D202 / Respawn Area 3 |
| D203 | Deserted Mine Lv 3 | 300×300 | 300×300 | exact | identity logical-grid coordinates | pass | pass | D203 / Respawn Area 1 |
| 01 | 边境城市 | 600×600 | 600×600 | exact | identity logical-grid coordinates | pass | pass | 01 / Safe Zone, 01 / Safe Zone, 01 / 肉店金老板, 01 / Chestnut Tree Spawn, 01 / Chestnut Tree Spawn, 01 / Chestnut Tree Spawn |
| 02 | 银杏山谷 | 600×600 | 600×600 | exact | identity logical-grid coordinates | pass | pass | 02 / Safe Zone, 02 / Safe Zone, 02 / 布店晓芙, 02 / Chestnut Tree Spawn, 02 / Chestnut Tree Spawn, 02 / Chestnut Tree Spawn |
| 74 | 盟重县 | 600×600 | 600×600 | exact | identity logical-grid coordinates | pass | pass | 74 / Safe Zone, 74 / Armoured Ant Spawn, 74 / Centipede Spawn, 74 / Armoured Ant Spawn, 74 / Shinsu Spawn, 74 / Larva Spawn |

## 全量机器数据

- `artifacts/npc-monster-alignment-2026-09-25/map_manifest.json`：全量 JSON，含尺寸、sha256、入口/出口邻接、城镇/安全区/商店/仓库/传送地标样本和 walkable 统计。
- `artifacts/npc-monster-alignment-2026-09-25/map_manifest.tsv`：同一清单的 TSV 导出。

## 解析器发现

- 独立解析器：`pass`；逻辑错误 **0**；地图文件格式/截断发现 **0**。格式发现保留在 `independent-verification.json`，不能当作可走性通过。
- map 记录格式按 28-byte header、x-major 13-byte cell records、`flag & 3 == 3` 通行规则独立读取；13-byte 步长与 Zircon `BotRunner/BotMap.cs` 的 `ReadBytes(13)` 一致；malformed 文件保持 pending，不降级为可走。

## 来源与边界

- Zircon `MapInfo/MapRegion` 来自 `Tools/dbeditor/workspace`；英雄杀地图来自本地 `/home/tetsuya/mir2ei/Map`。
- `map_links_v2.json` 只提供地图邻接，不被当作坐标证据；Merchant 坐标源状态：`source present: docs/research/ei-ui-layout/sources/mir2ei-report-full-merchants-2026-09-25.json (318 Merchant coordinates)`。
