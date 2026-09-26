# Mir3 地图连接审计报告（2026-09-26）

## 结论范围

本轮建立了 1039 条 MovementInfo 逐行 canonical manifest，并用独立实现重读地图二进制核验边界和 `flag & 3 == 3`。审计覆盖 627 张 MapInfo；Zircon 地形目录有 808 个 `.map` 文件，其中 299 张被连接记录引用。工作区连接中的 2078 个源/目标端点均落在地图范围内且满足该 walkability 位规则；独立验证器无解析差异、无重复 MovementInfo Index、无重复同源/目标 Region 关系。

**1039 条连接状态均为 `pending_manual_review`，没有任何一条被标记 confirmed。** 当前证据只证明 System.db 的 MovementInfo→MapRegion 质心边在当前地图地形上可定位、可走。原版 EI `Envir/MapInfo.txt` 的 gate 行未在本机已查目录发现；workspace MovementInfo 没有源文件行号、gate 坐标或 `NeedItem` 字段。因此不能证明游戏实际走到出口会触发，也不能安全推断坐标修正。

## 数量与状态

| 项目 | 数量 |
|---|---:|
| MovementInfo 行 | 1039 |
| MapInfo 行 | 627 |
| 可用 Zircon 地形文件 | 808 |
| 连接引用的唯一地图 | 299 |
| confirmed / confirmed-after-map-alias | 0 / 0 |
| candidate / retain-current | 0 / 0 |
| pending_manual_review | 1039 |
| blocked-out-of-bounds / blocked-nonwalkable / blocked-missing-map | 0 / 0 / 0 |
| 冲突方向 / 重复 MovementInfo Index / 重复 Region 关系 | 0 / 0 / 0 |
| 源与目标端点 walkable 且 in-bounds | 2078 / 2078 |
| v2 唯一地图边数 → staging v3 | 553 → 553 |
| staging 相对 v2 新增 / 删除边 | 0 / 0 |

状态名中的 blocked 统计为 0 仅表示该 workspace 质心通过当前二进制几何检查；不表示实际 EI gate 坐标已确认。

## 来源和地图编号消歧

- 连接行和源/目标 Region 来自 `Tools/dbeditor/workspace/MovementInfo.json`、`MapRegion.json`；地图名称通过 Region 的 Map 引用与 `MapInfo.FileName` 连接，不按数字 Index 猜测。
- 复用 `map_manifest.json` 的已有 EI/英雄杀关系：全量清单有 `526 exact / 12 renamed / 12 variant / 6 replacement / 71 pending`；本次不跨地图族拷坐标。连接源/目标地图 relation 分布：`{'variant': 91, 'exact': 829, 'replacement': 37, 'pending': 78, 'renamed': 4}`。
- 源码 `LocalDB.pas` 的 `MAPDEFFILE='MapInfo.txt'`；`LoadMapFiles` 用 `EnvirDir + MapInfo.txt` 加载，并将 gate 行按源地图、源坐标、目标地图、目标坐标传给 `AddGate`。`svMain.pas` 默认 `EnvirDir=..\Envir\`，但实际值由服务端 ini 可覆写。仓库工作区没有该次实际运行的 gate 行，因此源码语义只能定义模型，不能逐条交叉确认。
- walkability 独立验证器按 28B 头、半分辨率 3B 地面段、列优先 14B 全分辨率格读取；验证脚本未 import 生成器或 `mapedit.mapio`。

## 地图族覆盖

| 地图族 | MapInfo 地图数 | 有连接记录的地图数 | 涉及连接行数* |
|---|---:|---:|---:|
| town/city | 200 | 68 | 571 |
| D-series caves | 417 | 226 | 601 |
| Sabuk | 2 | 1 | 2 |
| mine | 41 | 35 | 146 |
| Zuma | 17 | 10 | 37 |
| Woma | 13 | 13 | 52 |
| Crimson Moon | 15 | 15 | 41 |
| Panya | 15 | 15 | 41 |


\* 同一连接若源或目标任一侧属于该组则计入，故不同组行数不可相加。族群名/Description 仅用于汇总筛查，不用于确认地图别名。所有地图族连接仍处 pending。

## 指定地图抽查

| 地图文件 | MapInfo 描述 | 关联 MovementInfo 行 | 出边 | 入边 |
|---|---|---:|---:|---:|
| `0` | Bichon Town | 62 | 16 | 46 |
| `01` | 边境城市 | 28 | 14 | 14 |
| `02` | 银杏山谷 | 28 | 13 | 15 |
| `3` | Sabuk Keep | 2 | 1 | 1 |
| `4` | Numa Village | 63 | 31 | 32 |
| `5` | Desert Mud Fortress | 42 | 23 | 19 |
| `74` | 盟重县 | 34 | 18 | 16 |
| `D202` | Deserted Mine Lv 2 | 0 | 0 | 0 |
| `D203` | Deserted Mine Lv 3 | 0 | 0 | 0 |
| `D1105` | Zuma Temple Lv 5 | 0 | 0 | 0 |


D202、D203、D1105 在当前 MapInfo/MovementInfo 连接集合中均无精确文件名匹配记录；这不能由相似编号或名称替代。全体 D 系共有 417 张 MapInfo 地图、601 条至少一端为 D 系的 MovementInfo 行。城镇 0、01、02、3、4、5、74 有连接行，但未作浏览器截图验收。

## 代表性连接（修正前后）

本轮未改变任何 MovementInfo，因此每条“修正后”仍是原 workspace 值；下列列出原始连接样本及未改原因：

- `2482` 0 (186,198) → 0_000 (21,51); Palace Entrance → Entrance Landing，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `2483` 0_000 (19,52) → 0 (184,204); Entrance Door → Palace Landing，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3053` 01 (447,246) → 01_001 (20,21); Teleport Source → Teleport Destination，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3054` 01_001 (19,22) → 01 (446,247); Teleport Source → Teleport Destination，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3100` 0 (333,776) → 01 (564,69); Teleport Source → Teleport Destination，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3106` 0 (779,698) → 02 (30,452); Teleport Source → Teleport Destination，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3107` 0 (778,699) → 02 (29,453); Teleport Source → Teleport Destination，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3108` 0 (777,700) → 02 (28,454); Teleport Source → Teleport Destination，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3274` 4 (476,57) → 4_005 (11,26); Teleport Source → Teleport Destination，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3275` 4_005 (10,27) → 4 (475,58); Teleport Source → Teleport Destination，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3964` 0 (98,324) → 3 (44,29); Sabuk Wall Entrance → Bichon Town Landing，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。
- `3965` 3 (46,26) → 0 (102,320); Bichon Town Door → Sabuk Wall Landing，状态 `pending_manual_review`。这里只能确认 workspace 的区域边，不足以确认这组质心就是 EI gate 坐标。

不存在已批准坐标变换或实际 gate 文本证据，所以所有记录的 `correction` 保持 null。常见多格传送关系（例如 3106–3108 各自从比奇进入 02 的相邻质心格）作为不同 MovementInfo 保留，未合并或删改。

## 问题分类及后续证据

| 检查项 | 本轮结果 | 说明 |
|---|---:|---|
| 越界 / 不可走 / 缺失 MapInfo | 0 / 0 / 0 | 独立验证的是 workspace region 质心 |
| 地图对应关系冲突 | 0 个已确认冲突 | pending/replacement/variant 仍需地标闭合，未盲目确认 |
| Region 冲突或同 Index 重复 | 0 | MovementInfo 索引及 (source region,destination region) 无重复 |
| 反向 MovementInfo 缺失 | 未统计为错误 | 单向连接允许；无 gate 文本不能判断应否存在反向连接 |
| 实际 gate 触发性 | 1039 未决 | 需要服务端实际 `EnvirDir/MapInfo.txt` 或逐条游戏内实测 |
| `NeedItem` | 数据源无字段 | manifest 记录 null；未推测或伪造 |
| Icon / NeedHole / RequiredClass | 保留 workspace 原值 | 不将展示字段转成连接语义结论 |

## 交付文件和验证

- `connection-manifest.json/.tsv`：逐行 canonical audit records，含两端坐标、地图对应关系、字段、来源优先级、状态和原因。
- `connection-diff.json`：staging 与 v2 地图边差异；不包含 MovementInfo 写回建议。
- `connection-verification.json`：独立二进制解析与全量端点核验结果。
- `Tools/maps/map_links_v3.json`：只读 staging 数据，全部 MovementInfo 行保留。

命令：

```bash
python3 Tools/maps/map_connections_audit.py
python3 Tools/maps/verify_map_connections_audit.py
python3 -m unittest discover -s Tools/maps/tests -p 'test_map_connections_audit.py' -v
```

8899 浏览器验收未完成：技能所需 browser 导航/DOM/截图/console 工具未提供，当前 live mapedit process 仍运行旧代码，页面没有 v3 source 切换、状态样式及审计 tooltip。桌面/手机截图与浏览器 console/pageerror 证据为空。不能宣称 8899 展示验收通过，也没有更新 `map_links_v2.json` 或真实数据库。
