# mapviewer 地图工坊六大增强（刷怪热力/任务叠加/等级总览/连通图谱/NPC审计/坐标拾取）— 完整任务目标

## 一、背景

mapviewer（~/development/Mir3-Research/Tools/maps/mapviewer.py，mir3-venv，8899 端口）
刚完成 NPC 位置+地图连接的基础修复（另一 agent 的改动，先 `git pull`/读最新代码再动手，
前端已有 drawRoutes/renderConnPanel/NPC 标记逻辑可复用）。

本 goal 在其上叠加**六个面向游戏开发工作流的能力**。数据全部来自
Tools/dbeditor/workspace/*.json（System.db 全表导出，79 张表）——**只读数据，不写 DB**。

## 二、数据资产速查（都已验证可用）

| 表 | 规模 | 关键字段 |
|---|---|---|
| MapRegion | 5009 | Index/Name（"0 / Spawn Ring 1"=地图号+区域名）/坐标在 Region 内 |
| RespawnInfo | 2475 | Monster{Name}/Region{Name}/Count/Delay/DropSet |
| MovementInfo | 1039 | SourceRegion/DestinationRegion（Region 名对） |
| MonsterInfo | 434 | MonsterName/Level/IsBoss |
| NPCInfo | 294 | 坐标已修正（NpcMover 85 个对齐 EI 坐标系） |
| SafeZoneInfo | 17 / GuardInfo 94 | 安全区/守卫点 |
| QuestInfo | 34（现有） | 任务步骤 VisitRegion/KillMonster/GainItem |
| mapnames.py | — | 地图 ID→中文名（Tools/maps/mapnames.py） |

Region 名称格式 `"<地图号> / <区域名>"`——解析出地图号即可挂到对应地图视图。
MapRegion 的坐标：读 MapRegion 表结构确认（X/Y/Width/Height 矩形）。

## 三、六大功能（全做）

### 1. 刷怪分布热力图 ⭐核心
- 图层开关「怪物刷新」：RespawnInfo 2475 条按 Region 画半透明色块
  （数量分级染色：绿<10 黄<50 橙<150 红≥150）
- 悬停 tooltip：`鸡 ×250 · 刷新延迟 1s · DropSet 0`（怪物名用 db_names.json 中文）
- 图例常显
### 2. 任务设计叠加模式 ⭐核心
- 顶部加「任务」下拉（QuestInfo 34 个，中文名）+ 选中后：
  - VisitRegion 步骤 → 对应 MapRegion 矩形金色描边+半透明填充
  - KillMonster 步骤 → 该怪物的 RespawnInfo 点位红色脉冲标记（跨地图列出：任务步骤在哪张图）
  - GainItem → 掉该物品的怪物点位（DropInfo 反查，可只列怪物名）
- 无任务选中时不渲染；QuestInfo 结构参考 LibraryCore/SystemModels/QuestInfo.cs（只读源码）
### 3. 等级分层地图总览
- 新视图「总览」：627 张图网格缩略图（用现有渲染管线出缩略，可低分辨率+懒加载）
- 每图染色 = 该图 RespawnInfo 怪物等级均值（ JOIN MonsterInfo.Level）：
  1-15 灰绿/16-30 黄/31-50 橙/51+ 红/无怪 灰
- BOSS 图（IsBoss 刷新点）角标 👑
### 4. 连通性图谱 + map_links_v2.json 产出
- 新视图「连通」：MovementInfo 1039 条为边，地图为节点，力导向或分层布局（纯前端 SVG 即可，节点=中文地图名）
- 孤岛地图标红（入度=0 且非出生点）、必经之路（割点）标黄
- 后端新增 `/api/map_links_v2.json`：遍历 MovementInfo 产出机器可读连接表
  （含 D 系地下城！格式对齐 mir2ei 的 map_links.json：names + links），
  **同时落盘到 Tools/maps/map_links_v2.json 并 commit**——这是任务地理审计的缺口补全
### 5. NPC 密度/覆盖审计视图
- 「总览」或单独区块：NPC 按地图聚合表——每张城图列出 功能 NPC 覆盖检查
  （药店/仓库/修理/传送，按 NPCInfo 名称关键词分类），缺项标红
- NPC 数量 choropleth（地图染色=NPC 数）
### 6. 坐标拾取器
- 地图视图点击任意格：浮窗显示 `(x, y)`（游戏格子坐标，不是像素）+「复制」按钮
- Shift+点击连续取两点显示曼哈顿距离（跑图估时用）

## 四、技术约束

- 单文件 mapviewer.py 继续内嵌前端（现有模式），纯标准库+mir3-venv
- 数据加载：启动时或首请求时从 workspace/*.json 读一次并缓存（内存索引：
  地图号→[regions/respawns/npcs/links]，避免每请求全表扫描）
- 性能：2475 刷新点/5009 区域的图层用 canvas 批量绘制（别一个一个 DOM 节点）；
  627 缩略图懒加载（IntersectionObserver 或分页）
- 移动端 390px 可用（图层开关折叠成 chips 行）
- 所有新端点失败要优雅降级（表缺失→该图层禁用+提示，不崩）

## 五、验收标准（全部满足）

1. 比奇县（0/1）页面：开「怪物刷新」图层能看到色块热力+悬停中文怪物信息（截图 /tmp/mv_heatmap.png）
2. 选一个含 KillMonster 的现有任务（如新手任务），其怪物点位在对应地图上红色标记出现（截图 /tmp/mv_quest.png）
3. 「总览」视图渲染 ≥600 张缩略图且按等级染色（截图 /tmp/mv_overview.png）
4. 「连通」视图显示连接图，孤岛地图红色可见；Tools/maps/map_links_v2.json 生成且含 D 系地图连接（jq 统计 links 数 > map_links.json 原版）
5. NPC 审计视图：至少一张城图的药店/仓库覆盖检查结果可见（缺项红标）（截图 /tmp/mv_npc.png）
6. 坐标拾取：点击地图浮窗显示格子坐标（截图 /tmp/mv_pick.png）
7. 服务重启后 8899 全部端点 200；桌面+手机视口无布局破碎
8. git commit+push 到 Mir3-Research（中文信息，含 map_links_v2.json）
9. 最终汇报：六功能各一句话验证结果 + map_links_v2 统计（总边数/D 系边数/孤岛数）

## 六、边界

- 只读 System.db 导出（workspace/*.json）与源码参考；**不写任何 DB**
- 不动 zircon 仓库（QuestInfo.cs 只读）
- 与基础修复 agent 的改动合并时以 git pull 最新为准，冲突保留双方功能
- 8899 重启前 pgrep 确认杀对进程（可能还有旧 survey 进程占着）
