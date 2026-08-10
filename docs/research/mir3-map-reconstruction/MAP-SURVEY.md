# Mir3 EI 地图逐图勘察 — MAP SURVEY

> 原版 EI 3.0 客户端 `Map/` 目录逐图勘察记录（objective §9）。
> 主数据源：`catalog/map-catalog.json`（544 图，build_map_catalog.py 生成）、`map-audit.json`（audit_mir3_maps.py）、
> `resource-consistency.json`（EI vs ZL 库对照）、`minimap-server-crossref.json`（服务端 MiniMap.txt 交叉引用）。
> 每条记录字段：文件名 / 中文名 / W×H / Back-Middle-Front 各层库#格数 / anomaly / evidence_level。
> 库表槽号解析 = v 变换（C2）；帧引用为 map 文件内的库槽 + 帧 id，格计数 = 引用次数（refcount）。

## 0. 全局统计

| 指标 | 值 |
|---|---|
| 地图总数 | 544 |
| legacy 13B/cell 格式 | 39（Snow/Forest 主题，D3） |
| 尺寸不符（size_mismatch） | 0 |
| 含 anomaly 的地图 | 34 |
| anomaly 总数 | 5723 |
| 最大图（800×800） | 0.map 比奇城 / 4.map 诺马村 / 6.map / 8.map 冰雪村 |
| 次大（600×600） | 01 / 02 / 1.map 失乐园 / 74 |

00.map：**不存在**。目录中无 `00.map`（0.map 为比奇城主城，`01.map`/`02.map` 为相邻区域）。

## 1. 城镇地图

| map | 中文名 | W×H | Back 库#格 | Middle 库#格 | Front 库#格 | anomaly | evidence |
|---|---|---|---|---|---|---|---|
| 0.map | 比奇城 | 800×800 | tilesc#58275 / tiles30c#97521 / tiles5c#4201 | smtilesc#2112 / housesc#2936 / cliffsc#86182 / furnituresc#19 / wallsc#1942 / smobjectsc#46587 / animationsc#4277 / object1c#27 / object2c#36 / wood_smobjectsc#131 | housesc#25 / cliffsc#734 / furnituresc#4 / wallsc#6 / smobjectsc#11249 / animationsc#1032 / object2c#5 / wood_smobjectsc#13 | 3 | confirmed |
| 01.map | 01 | 600×600 | tilesc#22489 / tiles30c#52845 / tiles5c#14461 / wood_tilesc#205 | smtilesc#52 / housesc#641 / cliffsc#36780 / wallsc#44 / smobjectsc#15805 / animationsc#1114 / wood_smobjectsc#350 | housesc#3 / cliffsc#994 / wallsc#3 / smobjectsc#3655 / animationsc#227 / wood_smobjectsc#10 | 0 | derived |
| 02.map | 02 | 600×600 | tilesc#13498 / tiles30c#76502 | smtilesc#33 / housesc#676 / cliffsc#47846 / wallsc#451 / smobjectsc#14324 / animationsc#485 / wood_smobjectsc#67 | housesc#9 / cliffsc#538 / wallsc#11 / smobjectsc#3092 / animationsc#225 / wood_smobjectsc#5 | 0 | derived |
| 1.map | 失乐园 | 600×600 | tilesc#31348 / tiles30c#51451 / tiles5c#6292 / wood_tilesc#902 | smtilesc#244 / housesc#455 / cliffsc#45444 / wallsc#57 / smobjectsc#22289 / animationsc#2694 / object1c#6 / object2c#1726 / wood_smobjectsc#62 / wood_animationsc#184 | housesc#10 / cliffsc#3993 / wallsc#2 / smobjectsc#6179 / animationsc#778 / object1c#1 / object2c#2 / wood_smobjectsc#6 / wood_animationsc#24 | 7 | derived |
| 12.map | 潘夜岛 | 400×500 | tilesc#3252 / tiles30c#46748 | smtilesc#8921 / cliffsc#42029 / smobjectsc#13196 / animationsc#651 / object2c#647 | cliffsc#53 / smobjectsc#3730 / animationsc#274 / object2c#528 | 0 | derived |
| 3.map | 沙巴克城 | 400×600 | tilesc#8655 / tiles30c#50908 / tiles5c#34 / wood_tilesc#403 | smtilesc#607 / housesc#156 / cliffsc#25075 / smobjectsc#6161 / animationsc#29 / object1c#4 / wood_housesc#1143 / wood_wallsc#3384 / wood_smobjectsc#2765 | housesc#9 / cliffsc#342 / smobjectsc#927 / animationsc#4 / wood_housesc#94 / wood_wallsc#191 / wood_smobjectsc#501 | 3255 | confirmed |
| 4.map | 诺马村 | 800×800 | tilesc#12899 / tiles30c#138135 / tiles5c#149 / sand_tilesc#8817 | smtilesc#243 / housesc#494 / cliffsc#60835 / innersc#1 / smobjectsc#12844 / animationsc#217 / sand_smobjectsc#111 | housesc#120 / cliffsc#9731 / smobjectsc#21247 / animationsc#172 / sand_smobjectsc#8 | 0 | derived |
| 5.map | 沙漠土城 | 400×400 | tilesc#6396 / tiles30c#31041 / tiles5c#1 / sand_tilesc#2562 | housesc#2194 / cliffsc#26087 / wallsc#3099 / smobjectsc#2071 / animationsc#228 / object2c#1 / sand_smobjectsc#222 | housesc#1202 / cliffsc#4749 / wallsc#735 / smobjectsc#18467 / animationsc#1280 / sand_smobjectsc#4 | 0 | derived |
| 8.map | 冰雪村 | 800×800 | tilesc#42651 / tiles30c#30347 / tiles5c#85200 / wood_tilesc#1800 | smtilesc#96 / cliffsc#23426 / smobjectsc#14385 / animationsc#577 / wood_housesc#796 / wood_smobjectsc#1723 | cliffsc#39 / smobjectsc#1817 / animationsc#36 / wood_housesc#1 / wood_smobjectsc#91 | 2 | derived |
| 74.map | 74 | 600×600 | tilesc#6451 / tiles30c#73465 / sand_tilesc#9994 | housesc#90 / cliffsc#42049 / smobjectsc#15464 / animationsc#7 / sand_housesc#409 / sand_wallsc#937 / sand_smobjectsc#2473 | housesc#1 / cliffsc#220 / smobjectsc#2395 / sand_wallsc#7 / sand_smobjectsc#205 | 90 | derived |

城镇层结构共性：Back 层以 `tilesc`/`tiles30c`（+主题 `wood_tilesc`/`sand_tilesc`）为主；Middle 层几乎全部城镇图以 `cliffsc`（悬崖/城墙）为最大引用（0.map 86,182 格、4.map 60,835 格），其次 `smobjectsc`（小物件）；Front 层 `smobjectsc`/`cliffsc` 为主，少量 `animationsc` 动画。
0.map 为唯一 confirmed 城镇（800×800 全图渲染与 catalog 对齐 + 反汇编锚点，C14/C4）。

## 2. 室内/建筑地图（house/wall/cliff 系）

| map | 中文名 | W×H | Back 库#格 | Middle 库#格 | Front 库#格 | anomaly | evidence |
|---|---|---|---|---|---|---|---|
| 0_000.map | 市政厅 | 70×70 | tiles5c#1225 | wood_innersc#1714 | wood_innersc#58 | 19 | derived |
| 0_001.map | 左翼 | 30×30 | tilesc#17 / tiles5c#208 | innersc#20 / furnituresc#29 | furnituresc#15 | 0 | derived |
| 0_002.map | 右翼 | 20×20 | tilesc#12 / tiles5c#88 | wood_innersc#1 / wood_furnituresc#1 / snow_smtilesc#1 / snow_housesc#3 / snow_cliffsc#3 / snow_animationsc#1 / forest_innersc#1 | — | 3 | derived |
| 0_003.map | 0_003 | 60×100 | tilesc#599 / tiles30c#764 | housesc#344 / furnituresc#2 / wallsc#323 / smobjectsc#195 / animationsc#29 / object1c#1 | housesc#4 / smobjectsc#10 / animationsc#8 | 137 | pending |
| 5_0013.map | 5_0013 | 68×68 | tilesc#52 / tiles5c#1037 | innersc#44 / furnituresc#50 | furnituresc#28 | 67 | pending |
| 50_001.map | 50_001 | 70×70 | tiles5c#1225 | wood_innersc#1714 | wood_innersc#58 | 19 | derived |
| 0_0011.map | 0_0011 | 30×30 | tilesc#17 / tiles5c#208 | 多主题 1 格探针（见下） | — | 8 | derived |

室内图特征：
- 市政厅（0_000/50_001）Back 层 `tiles5c` 满格 + Middle `wood_innersc`（木内景），Front `wood_innersc` 少量 → **library-id = 室内库（innersc/furnituresc），帧集中在室内物件**。
- 0_003 / 5_0013 的 anomaly 全部为 `ground_not_drawn`（137/67 格）——室内地面引用黑/空帧，与 ZL `MapInfo.Background` 机制同类（D4/K2，pending P2）。
- 0_0011/0_002 等 18×22/20×20 微型图 Middle 层出现「多主题各 1 格探针」模式（wood_/sand_/snow_/forest_ 每库 1 格），疑为建图工具的占位/模板残留（candidate）。
- 0_000/50_001 的 19 格 anomaly = `front_lib22_frame_oob`（front 层 lib22 帧越界，库帧数 < 地图引用，C11 同类）。

## 3. 半兽洞穴 / 天然洞穴（D00x 系）

| map | 中文名 | W×H | Back 库#格 | Middle 库#格 | Front 库#格 | anomaly | evidence |
|---|---|---|---|---|---|---|---|
| D001.map | 幽灵森林 | 400×400 | tiles5c#40000 | object1c#22986 | — | 0 | derived |
| D001_001.map | D001_001 | 30×30 | tiles5c#225 | object1c#136 / object2c#34 | — | 0 | derived |
| D002.map | 沙漠（半兽洞穴2层） | 400×400 | tiles5c#40000 | object1c#13030 | — | 0 | derived |
| D002_001.map | D002_001 | 30×30 | tiles5c#225 | object1c#136 / object2c#34 | — | 0 | derived |
| D003.map | 失乐园森林 | 400×400 | tiles5c#40000 | object1c#14291 | — | 0 | derived |
| D011.map | D011 | 400×400 | tiles5c#40000 | object1c#12149 | — | 0 | derived |
| D012.map | D012 | 400×400 | tiles5c#40000 | object1c#15381 | — | 0 | derived |

- 服务端 MiniMap.txt：D001 = 半兽洞穴1层、D002 = 半兽洞穴2层、D003 = 半兽洞穴3层、D011 = 天然洞穴1层、D012 = 天然洞穴2层（MMap.wil F1–F5）。
- 本机 catalog 中文名（幽灵森林/沙漠/失乐园森林）与服务端名不一致 → 中文名记录保留 catalog 值，服务端名见 crossref（candidate 层级差异）。
- Back 层 `tiles5c` **满格**（400×400 = 40,000 格）且帧集中在 20–13098（含 C17 黑帧 20–24 区间引用）；Middle 层 `object1c` 单库。无 Front 层。
- `tiles5c#40000` 满格 + 黑帧引用 → D201 类黑块资源侧事实（C18）在此类洞穴普遍存在。

## 4. 赤月山谷（D100–D103 系）

| map | 中文名 | W×H | Back 库#格 | Middle 库#格 | Front 库#格 | anomaly | evidence |
|---|---|---|---|---|---|---|---|
| D1001.map | D1001 | 400×400 | tiles5c#40000 | object2c#25179 | — | 0 | derived |
| D10011.map | D10011 | 400×400 | tiles5c#40000 | object2c#25179 | — | 0 | derived |
| D10012.map | D10012 | 300×300 | tiles5c#22500 | object2c#15373 | — | 0 | derived |
| D10013.map | D10013 | 300×300 | tiles5c#22500 | object2c#17236 | — | 0 | derived |
| D1002.map | D1002 | 300×300 | tiles5c#22500 | object2c#15851 | — | 0 | derived |
| D10031.map | D10031 | 300×300 | tiles5c#22500 | smtilesc#62 / object1c#164 / object2c#16865 | object1c#6 / object2c#56 | 62 | pending |
| D10032.map | D10032 | 300×300 | tiles5c#22500 | object1c#1 / object2c#15152 | — | 0 | derived |
| D1004.map | D1004 | 300×300 | tiles5c#22500 | object2c#14112 | — | 0 | derived |
| D10051.map | D10051 | 200×200 | tiles5c#10000 | object2c#7158 | — | 0 | derived |
| D10052.map | D10052 | 200×200 | tiles5c#10000 | object2c#8020 | — | 0 | derived |
| D10053.map | D10053 | 100×100 | tiles5c#2500 | object2c#2361 | — | 0 | derived |
| D10054.map | D10054 | 100×100 | tiles5c#2500 | object2c#1886 | — | 0 | derived |
| D10061.map | D10061 | 30×30 | tiles5c#225 | object2c#199 | — | 0 | derived |
| D10062.map | D10062 | 40×40 | tiles5c#400 | object2c#295 | — | 0 | derived |
| D10071.map | D10071 | 40×40 | tiles5c#400 | object2c#309 | — | 0 | derived |

| map | 中文名 | W×H | Back 库#格 | Middle 库#格 | Front 库#格 | anomaly | evidence |
|---|---|---|---|---|---|---|---|
| D1011.map | D1011 | 300×300 | tiles5c#22500 | object2c#15373 | — | 0 | derived |
| D1012.map | D1012 | 300×300 | tiles5c#22500 | object2c#16514 | — | 0 | derived |
| D10131.map | D10131 | 300×300 | tiles5c#22500 | object2c#17240 | — | 0 | derived |
| D10132.map | D10132 | 300×300 | tiles5c#22500 | object2c#15412 | — | 0 | derived |
| D1014.map | D1014 | 300×300 | tiles5c#22500 | object2c#16877 | — | 0 | derived |
| D10151.map | D10151 | 200×200 | tiles5c#10000 | object2c#6565 | — | 0 | derived |
| D10152.map | D10152 | 200×200 | tiles5c#10000 | object2c#8806 | — | 0 | derived |
| D10162.map | D10162 | 40×40 | tiles5c#400 | object2c#295 | — | 0 | derived |

| map | 中文名 | W×H | Back 库#格 | Middle 库#格 | Front 库#格 | anomaly | evidence |
|---|---|---|---|---|---|---|---|
| D1021.map | D1021 | 300×300 | tiles5c#22500 | object2c#17236 | — | 0 | derived |
| D1022.map | D1022 | 300×300 | tiles5c#22500 | object2c#15774 | — | 0 | derived |
| D10231.map | D10231 | 300×300 | tiles5c#22500 | object2c#19795 | — | 0 | derived |
| D10232.map | D10232 | 300×300 | tiles5c#22500 | object2c#23202 | — | 0 | derived |
| D1024.map | D1024 | 300×300 | tiles5c#22500 | object2c#17480 | — | 0 | derived |
| D10251.map | D10251 | 200×200 | tiles5c#10000 | object2c#10968 | — | 0 | derived |
| D10252.map | D10252 | 200×200 | tiles5c#10000 | object2c#10796 | — | 0 | derived |
| D10261.map | D10261 | 30×30 | tiles5c#225 | object2c#199 | — | 0 | derived |
| D10262.map | D10262 | 40×40 | tiles5c#400 | object2c#295 | — | 0 | derived |
| D10271.map | D10271 | 40×40 | tiles5c#400 | object2c#309 | — | 0 | derived |

- 服务端名：D1001/D1011/D1021 = 赤月山谷1层、D1002/D1012/D1022 = 2层、D1004/D1014/D1024 = 4层（MMap.wil F101–F125）。
- 全系 Back 层 `tiles5c` 满格（帧 10021–12985 为主区间），Middle `object2c` 单库，无 Front。
- D10031 是赤月系唯一 anomaly：ground lib2（smtilesc）62 格帧越界（frame 9998 超库帧），为全局唯一 ground OOB（P3）。
- D10011 与 D1001 完全相同（40,000/25,179 格同数）——候选为副本/对称入口图。

## 5. 沃玛系（D201–D203）

| map | 中文名 | W×H | Back 库#格 | Middle 库#格 | Front 库#格 | anomaly | evidence |
|---|---|---|---|---|---|---|---|
| D2011.map | D2011 | 100×100 | tiles5c#2500 | object1c#1343 | — | 0 | derived |
| D2012.map | D2012 | 200×200 | tiles5c#10000 | object1c#5388 | — | 0 | derived |
| D202.map | D202 | 300×300 | tilesc#1878 / tiles30c#20622 | smtilesc#181 / cliffsc#19678 / smobjectsc#4384 | cliffsc#666 / smobjectsc#607 | 0 | derived |
| D203.map | D203 | 300×300 | tiles5c#22500 | object1c#10925 | — | 0 | derived |

- D2011/D2012/D203：`tiles5c` + `object1c` 结构（与半兽洞穴同构）。D201 类黑块（C18）即此系地面显式引用黑帧。
- D202 结构不同：地面 `tilesc`/`tiles30c`（非 tiles5c），Middle `cliffsc` 19678 格 + `smobjectsc`，Front 有 `cliffsc`/`smobjectsc` —— 为唯一带 Front 层的 D2xx 图（candidate：雪地/山脊露天洞穴，服务端 F153 无中文名）。
- 服务端名缺失（D2011/12、D202、D203 行无 server_map_names）。

## 6. 沙漠 / 雪地

| map | 中文名 | W×H | Back 库#格 | Middle 库#格 | Front 库#格 | anomaly | evidence |
|---|---|---|---|---|---|---|---|
| D002.map | 沙漠 | 400×400 | tiles5c#40000 | object1c#13030 | — | 0 | derived |
| D021.map | D021 | 100×100 | tiles5c#2500 | object1c#936 | — | 0 | derived |
| D022.map | D022 | 500×500 | tiles5c#62500 | object1c#11802 | — | 0 | derived |
| D023.map | D023 | 400×400 | tiles5c#40000 | object1c#12002 | — | 0 | derived |
| D024.map | D024 | 100×100 | tiles5c#2500 | object1c#709 | object1c#48 | 0 | derived |
| 5.map | 沙漠土城 | 400×400 | tilesc#6396 / tiles30c#31041 / tiles5c#1 / sand_tilesc#2562 | housesc#2194 / cliffsc#26087 / wallsc#3099 / smobjectsc#2071 / animationsc#228 / object2c#1 / sand_smobjectsc#222 | housesc#1202 / cliffsc#4749 / wallsc#735 / smobjectsc#18467 / animationsc#1280 / sand_smobjectsc#4 | 0 | derived |
| 8.map | 冰雪村 | 800×800 | tilesc#42651 / tiles30c#30347 / tiles5c#85200 / wood_tilesc#1800 | smtilesc#96 / cliffsc#23426 / smobjectsc#14385 / animationsc#577 / wood_housesc#796 / wood_smobjectsc#1723 | cliffsc#39 / smobjectsc#1817 / animationsc#36 / wood_housesc#1 / wood_smobjectsc#91 | 2 | derived |

- 沙漠主题库族：`sand_tilesc`/`sand_housesc`/`sand_wallsc`/`sand_smobjectsc`（5.map、74.map、4.map 混用）；D002 沙漠洞穴为 tiles5c+object1c。
- 雪地主题库族：`wood_*`（冰雪村 8.map 用 wood_tilesc/wood_housesc/wood_smobjectsc —— EI 主题名 Wood，catalog theme_name 14 图）；`snow_*`/`forest_*` 出现在室内微型图探针中。
- 8.map Back 层 `tiles5c#85200` = 85,200 格引用 tiles5c（帧区间 30–34），为雪地地面主素材。

## 7. 错误类别分类（error taxonomy）

逐图异常按来源归类（异常类型 → 类别 → 案例）：

| 错误类别 | 判定标准 | 案例（map: 格数） |
|---|---|---|
| **map-file 错误**（结构/尺寸） | size_mismatch / 头部不一致 | 无（544 图全部 size_ok）；legacy 13B 为**版本差异**非错误（39 图，D3） |
| **library 错误**（库表槽号/库缺失） | 库槽 v 变换解析失败 / 库文件缺失 | 无（全部库槽可解析，C2） |
| **frame-decode 错误**（帧越界） | `frame_oob` = 地图引用帧号 ≥ 库帧数 | 3.map（3255 格，lib24/25 wood_*，C11）、41.map（1619）、50.map（39）、0_000/50_001（19，front lib22） |
| **offset 错误** | 帧 offset（+4/+6）非零值被忽略 | 地图层零 offset 读取已确认（C5）；actor 层应用 offset（C6）。EI 素材 offset 非零分布 = P9（candidate 影响） |
| **坐标转换错误** | 投影/锚点偏离 C3/C4 公式 | 无——C3/C4 全图对齐（C14）；模拟器 800×600 拉伸为可视化约定，非原版转换 |
| **图层顺序错误** | 绘制顺序偏离 C7 | 无——ground→mid→front→actor 已确认 |
| **版本差异** | legacy 13B vs 14B；ZL vs EI 库帧数 | 39 图 13B（D3）；EI_LARGER/DIFF 库对照见 resource-consistency.json |
| **特殊处理**（原版客户端行为） | 黑/空帧显式引用、ground_not_drawn、保留帧 | `ground_not_drawn` 670 格（D12121 171、0_003 137、74 90、5_0013 67、123 34、D1401/D1411/D1421 各 32）；黑帧引用 ≈1.2M 格（C18）；保留标记帧 0xFF00+（P10） |

## 8. 坐标转换 / 原点 / 图层顺序（全部 confirmed，引用 EVIDENCE-INVENTORY）

- 投影（C3）：`destX=(x−viewX)·48−scrollX−200`，`destY=(y−viewY)·32−scrollY−h−125`（h = 帧高）。瓦片 48×32，纵横 3:2 与 800×600 视口一致。
- 锚点（C4）：地图层全部格底/格左；ground 底 = mid/front 帧底 = −125 同线。
- 原点：视口左上 = viewX/viewY 处格；scrollX/scrollY 为滚动偏移。
- offset 读取（C5/C6）：地图层零 offset；actor 层读帧 offset（+4/+6）加进 dest。
- 图层顺序（C7）：ground → mid → front → actor。
- 帧尺寸/偏移：WIL 帧几何见 `resource-consistency.json`（每库尺寸分布）与 `catalog/map-catalog.json`（每库帧数）；帧 offset 非零分布 P9 pending。
- 黑/空帧（C17/C18）：tiles5c f20–24 资源近纯黑（mean≈2.7/std≈3.8）；黑块 = 地图显式引用黑帧（约 1.2M 格）。

## 9. 各分类 evidence_level 说明

- `confirmed`：反汇编 + 全图渲染 + catalog 三方对齐（0.map；3.map OOB 根因 C11）。
- `derived`：catalog 结构解析 + 交叉引用推断（绝大多数逐图记录）。
- `pending`：已知未解（0_003/5_0013 室内地面机制 P2；D10031 ground OOB P3）。
- 中文名：catalog `cn` 为准；服务端 MiniMap.txt 名（如 半兽洞穴1层）为 secondary 交叉引用，冲突时并列记录不覆盖。

## 10. 逐图勘察遗留（引用 EVIDENCE-INVENTORY pending）

- P1 越界帧替换逻辑（3.map 3255 格视觉缺失）→ frame-decode 类
- P2 室内地面绘制机制（0_003/5_0013）→ 特殊处理类
- P3 D10031 ground OOB（62 格）→ frame-decode 类
- P6 小地图帧内留白逐图校准（FMMap/MMap）→ 坐标转换类（模拟器）
- P9 EI 素材帧 offset 非零分布 → offset 类
- P10 保留标记帧（0xFF00+）/幻影帧引用 → library 类
