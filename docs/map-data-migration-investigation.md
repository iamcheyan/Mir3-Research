# EI 地图迁移：服务器数据迁移全面调查报告

> 日期：2026-08-11
> 状态：调查完成，待执行
> 背景：Zircon 客户端/服务器已将 544 张 EI 地图 + 27 个图库替换到位（画面正确）。但服务器 DB 里的 NPC/刷怪/传送门/安全区坐标还是 Zircon 旧版配置，与 EI 地图尺寸不匹配。用户要求以 EI 为准，Zircon 新增的地图如果 EI 没有就删掉。

---

## 1. 影响面总览

### 1.1 地图替换状态

| 类别 | 数量 | 说明 |
|------|------|------|
| Zircon 原版 | 258 | 已备份到 `/home/tetsuya/NAS/TMP/zircon-backup-20260811-095139/Map/` |
| EI 地图 | 544 | 已部署到客户端 + 服务器 Map 目录 |
| 当前总数 | 753 | 258 Zircon + 544 EI（同名覆盖后合并） |
| 同名尺寸不变 | 208 | 坐标安全，无需迁移 |
| 同名尺寸变化 | **50** | 坐标可能越界，必须处理 |
| EI 新增地图 | 485 | DB 无记录，需新建配置 |
| Zircon 独有（被删） | 0 | 无（所有 Zircon 地图都被 EI 覆盖） |

### 1.2 DB 数据量

从 Zircon System.db 提取的当前数据：

| 表 | 记录数 | 说明 |
|----|--------|------|
| MapInfo | 244 | 地图定义（FileName/Description/MiniMap 等） |
| MapRegion | 1666 | 区域定义（坐标 BitRegion/PointRegion） |
| MovementInfo | 554 | 传送门（Source→Destination Region） |
| RespawnInfo | 1471 | 刷怪点（Region + Monster + Count） |
| SafeZoneInfo | 13 | 安全区（Region + BindRegion） |
| NPCInfo | 125 | NPC（Region + MapIcon） |
| GuardInfo | 68 | 守卫（Map + X + Y 绝对坐标） |
| MineInfo | 20 | 矿区（Map + Region） |
| CastleInfo | 1 | 城堡（CastleRegion/ObjectiveRegion/AttackSpawnRegion） |
| MonsterInfo | 309 | 怪物定义（英文命名） |
| ItemInfo | 1078 | 物品定义 |

### 1.3 EI 服务端配置（迁移源数据）

EI 标准服务端（`/home/tetsuya/NAS/TMP/Mud3/Envir/`）用文本配置文件：

| 文件 | 有效行 | 说明 |
|------|--------|------|
| Mapinfo.txt | 2359 | 地图信息（名字+属性，含传送点 `坐标 -> 目标`） |
| Merchant.txt | 318 | NPC（名字 地图名 X Y NPC脚本路径） |
| GuardList.txt | 117 | 守卫（名字 地图名 X,Y : 方向） |
| StartPoint.txt | 18 | 安全区（地图名 X Y） |
| MiniMap.txt | 313 | 小地图绑定（地图名 帧号） |
| MonGen.txt | 63 | 刷怪入口（loadgen "文件名.gen"） |
| Mon_Def/*.gen | 72 文件 | 刷怪配置（地图名 X Y 怪物名 数量 ...） |
| MapQuest.txt | 549 | 地图任务 |

**EI 刷怪统计**：3221 个刷怪点，涉及 293 张地图，312 种怪物名（中文）。

---

## 2. 核心问题：坐标错乱机制

### 2.1 坐标存储两种形式

Zircon DB 的 `MapRegion` 有两种坐标存储：

1. **PointRegion**（`Point[]`，绝对坐标）：直接存 X/Y 点集，地图缩小后坐标可能越界。
2. **BitRegion**（`BitArray`，索引编码）：`bit 索引 = x + y * width`，**用运行时地图宽度解码**（`x = i % width, y = i / width`）。地图尺寸变了，同一个 BitArray 解出的坐标完全不同。

### 2.2 尺寸变化的影响链

| 影响 | 机制 | 后果 |
|------|------|------|
| BitRegion 错位 | `i % width` 用新宽度 | 坐标完全错乱（如 0.map 350→800） |
| PointRegion 越界 | 绝对坐标超出新尺寸 | `GetCell()` 返回 null → 区域静默丢弃 |
| 可走性变化 | EI 地图阻挡格不同 | 坐标在界内但落在不可走格 → Spawn 失败 |

### 2.3 50 张尺寸变化地图的关键样本

| 地图 | Zircon 尺寸 | EI 尺寸 | 变化方向 |
|------|------------|---------|---------|
| 0.map（比奇城） | 350×350 | 800×800 | 放大 |
| 1.map（道馆） | 350×350 | 600×600 | 放大 |
| D201（废矿Lv1） | 350×350 | 100×100 | 缩小 |
| D202（废矿Lv2） | 300×300 | 200×200 | 缩小 |
| D603（石灯屋） | 300×300 | 50×50 | 大幅缩小 |
| D1104（潘夜4层） | 500×500 | 200×200 | 大幅缩小 |

**这 50 张地图上承载**：523 个 Region、457 个刷怪点、87 个 NPC、197 个传送门、8 个安全区、52 个守卫。

### 2.4 服务器启动时的错误

当前服务器日志已出现：
```
[Movement] Bad Origin, Source: Deserted Mine Lv 2 (D202) - Floor 1 Door, X:28, Y:300
[Safe Zone] Bad Location, Region: ...
[Cell] Bad Point, Source: ...
```
这些坐标按旧地图（350×350）配置，超出新地图（200×200）范围。

---

## 3. 服务器代码坐标使用路径

### 3.1 坐标来源分类

**A. DB 来源（需迁移）：**
- `MapRegion.PointRegion` / `BitRegion` → 所有区域（传送门/刷怪/安全区/NPC/任务/矿区/城堡）
- `GuardInfo.X / Y` → 守卫绝对坐标
- `CastleFlagInfo / CastleGateInfo / CastleGuardInfo` 的 X/Y → 城堡物件坐标
- `EventInfo.RegionParameter` → 事件动作区域
- `QuestTask.RegionParameter` → 任务区域
- `InstanceInfo.ConnectRegion / ReconnectRegion` → 副本进出场

**B. 运行时计算（不迁移）：**
- `Functions.Move` / `ShiftDirection` → 方向位移
- `Map.GetRandomLocation()` → 随机落点
- `Map.GetCells()` → 半径取格
- `Cell.GetMovement()` → 传送判定

### 3.2 关键代码路径

| 文件 | 行号 | 功能 | 坐标来源 |
|------|------|------|---------|
| Map.cs | 70-71 | 读 .map Width/Height | 文件 |
| Map.cs | 191-202 | CreateCellRegions → 遍历 PointList | MapRegion |
| Map.cs | 274-277 | GetCell(x,y) 边界检查 | 运行时 |
| SEnvir.cs | 757-759 | 全量 CreatePoints(width) | MapRegion + map.Width |
| SEnvir.cs | 872-890 | Movement 源区域绑定 | PointRegion |
| SEnvir.cs | 940-941 | NPC Spawn | Region.PointList |
| SEnvir.cs | 980-1025 | Quest 区域 | PointList |
| SEnvir.cs | 1101-1123 | SafeZone 区域 | PointList |
| MapObject.cs | 789-803 | Spawn(region) | Region.PointList 随机 |
| PlayerObject.cs | 900-945 | 角色出生 | BindPoint |
| PlayerObject.cs | 14926-14936 | 采矿 | Region.PointList |
| Functions.cs | 709-727 | 钓鱼 | Region.PointList + Width/Height |
| AutoPathRoutePlanner.cs | 353-355 | 寻路 | Region.GetPoints(width) |

---

## 4. 怪物名中英对照问题

Zircon DB 怪物名是**英文**（309 个），EI 服务端配置是**中文**（312 个）。迁移刷怪时需要建立对照表。

部分已知对照：

| Zircon 英文 | EI 中文 |
|------------|--------|
| Chicken | 鸡 |
| Deer | 鹿 |
| Wolf | 狼 |
| Zombie | 僵尸 |
| Skeleton | 骷髅 |
| Bat | 山洞蝙蝠 |
| GhostSorcerer | 恶形鬼 |
| Scarecrow | 稻草人 |
| Oma | 半兽人 |
| Wraith | 沃玛... |
| Zuma | 祖玛... |

完整对照需从 Zircon DB 的 MonsterInfo.Description 字段（可能含中文名）或从 EI 客户端的 Mon-*.wil 帧名提取。

---

## 5. DB 修改方法

### 5.1 MirDB 格式

- `System.db` 是 MirDB 自定义二进制格式（非 SQLite，非加密）
- `LibraryCore/MirDB/Session.cs:232` — `public void Save(bool commit)`
- 格式：表头（表名+属性+类型）→ 数据区（每表 nextIndex + 记录数 + 逐记录长度前缀 + 记录体）
- 字段类型：7-bit 变长字符串、Point=[X,Y] int32 对、Point[]=[bool+int32 n+points]、BitArray=[bool+int32 字节数+字节]

### 5.2 修改方案

**方案 A（推荐）：写 C# 控制台程序**
1. 引用 `LibraryCore` 项目
2. `Session session = new Session(SessionMode.Users, root); session.Initialize(assembly);`
3. `var mapInfos = session.GetCollection<MapInfo>();`
4. 遍历修改 MapInfo/MapRegion/MovementInfo/RespawnInfo 等记录
5. `session.Save(true);`

**方案 B：Python 直接二进制补丁**
- 已有 ZirconDB subagent 的 MirDB 解析器（`/tmp/investigate/zircon_db_records.json`）
- 可写 Python 脚本直接修改二进制
- 风险较高，需严格按 MirDB 格式操作

**方案 C：Server GUI Views**
- Zircon Server 项目有 `MapInfoView.cs` / `MapRegionView.cs` 等 WinForms 编辑器
- 可启动 Server GUI 手动编辑（不适合批量操作）

### 5.3 DB 同步

- 客户端 DB：`Debug/Client/Data/System.db`
- 服务器 DB：`Debug/ServerCore/Database/System.db`
- 修改后需同步两份（或用同一份）

---

## 6. 迁移策略

### 6.1 总原则

用户要求：**以 EI 为准，Zircon 新增的地图如果 EI 没有就删掉。**

### 6.2 分步执行

**第一步：清理 Zircon 独有数据**
- 删除 DB 中 EI 没有对应地图的 MapInfo 及其关联 Region/Movement/Respawn/NPC/Guard/Mine 记录
- 0 张 Zircon 独有（已确认），此步可能无需操作

**第二步：修正 50 张尺寸变化地图的现有 Region 坐标**
- 对每张尺寸变化地图：
  - BitRegion：用旧 width 解码 → 得绝对点集 → 校验是否在新尺寸内 → 转为 PointRegion 存储
  - PointRegion：逐点校验是否在新尺寸内 → 越界的按比例缩放或删除
- 涉及 523 个 Region、457 个刷怪、87 个 NPC、197 个传送门

**第三步：为 485 张 EI 新增地图导入配置**
- 从 EI 服务端文本配置解析坐标：
  - `Merchant.txt` → NPCInfo + MapRegion
  - `GuardList.txt` → GuardInfo
  - `StartPoint.txt` → SafeZoneInfo
  - `Mon_Def/*.gen` → RespawnInfo + MapRegion
  - `Mapinfo.txt` 传送点 → MovementInfo + MapRegion
- 需建立怪物名中英对照表

**第四步：更新 MiniMap 绑定**
- 从 `MiniMap.txt` 更新 MapInfo.MiniMap 字段

**第五步：同步 + 重启验证**
- 同步客户端/服务器 DB
- 重启服务器，检查日志无 Bad Origin/Point/Location
- 登录测试传送门/刷怪/NPC/安全区

### 6.3 怪物名对照表

需从以下来源建立：
1. Zircon DB MonsterInfo.Description 字段
2. EI 客户端 Mon-*.wil 帧名
3. 手动映射已知对照

---

## 7. 关键文件清单

### 7.1 源数据

| 文件 | 用途 |
|------|------|
| `/home/tetsuya/NAS/TMP/Mud3/Envir/Mapinfo.txt` | EI 地图信息 + 传送点 |
| `/home/tetsuya/NAS/TMP/Mud3/Envir/Merchant.txt` | EI NPC 坐标 |
| `/home/tetsuya/NAS/TMP/Mud3/Envir/GuardList.txt` | EI 守卫坐标 |
| `/home/tetsuya/NAS/TMP/Mud3/Envir/StartPoint.txt` | EI 安全区 |
| `/home/tetsuya/NAS/TMP/Mud3/Envir/MiniMap.txt` | EI 小地图绑定 |
| `/home/tetsuya/NAS/TMP/Mud3/Envir/Mon_Def/*.gen` | EI 刷怪配置（72 文件，3221 点） |
| `/home/tetsuya/NAS/TMP/Mud3/Envir/MapQuest.txt` | EI 地图任务 |

### 7.2 目标 DB

| 文件 | 用途 |
|------|------|
| `/home/tetsuya/development/Zircon/Debug/Client/Data/System.db` | 客户端 DB（MirDB） |
| `/home/tetsuya/development/Zircon/Debug/ServerCore/Database/System.db` | 服务器 DB（MirDB） |

### 7.3 调查输出

| 文件 | 内容 |
|------|------|
| `/tmp/investigate/size_diff.json` | 50 张尺寸变化地图明细 |
| `/tmp/investigate/zircon_db_records.json` | Zircon DB 全部记录（2.3MB） |
| `/tmp/investigate/server_code_paths.md` | 服务器代码坐标使用路径 |

### 7.4 代码参考

| 文件 | 用途 |
|------|------|
| `LibraryCore/MirDB/Session.cs:232` | Save(bool commit) API |
| `LibraryCore/SystemModels/MapRegion.cs` | MapRegion 模型（BitRegion/PointRegion） |
| `LibraryCore/SystemModels/MapInfo.cs` | MapInfo 模型 |
| `ServerLibrary/Models/Map.cs:70` | 地图加载（Width/Height） |
| `ServerLibrary/Envir/SEnvir.cs:757` | 区域装配 |

---

## 8. Subagent 任务划分建议

| Subagent | 任务 | 输入 | 输出 |
|----------|------|------|------|
| DBParser | 写 C# 控制台程序读写 System.db | MirDB 格式 + zircon_db_records.json | 修改后的 System.db |
| EIImporter | 解析 EI 配置文本生成导入数据 | Mud3/Envir/*.txt + *.gen | ei_import_data.json |
| MonsterMapper | 建立怪物名中英对照表 | Zircon MonsterInfo + EI 怪物名 | monster_name_map.json |
| RegionFixer | 修正 50 张尺寸变化地图的 Region | size_diff.json + zircon_db_records.json | 修正后的 Region 数据 |
| MiniMapFixer | 更新 MiniMap 绑定 | MiniMap.txt + map_bindings.json | 更新后的 MapInfo.MiniMap |

---

## 9. 风险与注意事项

1. **BitRegion 是最大隐患**：300 个 Region 用 BitRegion，其中 77 个在 38 张尺寸变化地图上。必须用旧 width 解码后转 PointRegion。
2. **怪物名中英对照不完整**：312 个 EI 怪物名（中文）需映射到 309 个 Zircon 怪物名（英文），部分可能无法一一对应。
3. **DB 格式敏感**：MirDB 是自定义二进制，修改时必须严格按格式操作，否则 DB 损坏。
4. **备份必须**：修改 DB 前必须备份 System.db。
5. **客户端/服务器同步**：两份 System.db 需同步，否则不一致。
6. **可走性变化**：即使坐标在新尺寸内，也可能落在 EI 地图的不可走格上 → Spawn 失败。
7. **Zircon 新增地图**：用户要求删掉 EI 没有的。已确认 0 张 Zircon 独有，但 DB 里可能有指向已不存在地图的 Region（需清理孤儿引用）。
---

## 10. EI 配置解析结果（已提取）

已从 `/home/tetsuya/NAS/TMP/Mud3/Envir/` 解析全部配置到 `/tmp/investigate/ei_config_data.json`：

| 数据类型 | 条目数 | 格式 |
|---------|--------|------|
| NPC | 318 | {name, map, x, y} |
| 守卫 | 117 | {name, map, x, y, dir} |
| 安全区 | 18 | {map, x, y} |
| 小地图绑定 | 313 | {map → 帧号} |
| 刷怪点 | 3221 | {map, x, y, monster, count} |
| 地图任务 | 549 | 文本行 |
| 传送点 | 1940 | {src_map, src_x, src_y, dst_map, dst_x, dst_y} |

### EI 怪物名（中文，312 种）

狼、鸡、鹿、猪、牛、羊、半兽人、半兽勇士、半兽战士、骷髅、骷髅士兵、骷髅弓箭手、骷髅战士、骷髅战将、骷髅教主、骷髅精灵、僵尸、雷电僵尸、僧侣僵尸、山洞蝙蝠、洞蛆、多角虫、天狼蜘蛛、独眼蜘蛛、黑角蜘蛛、花色蜘蛛、幻影蜘蛛、月魔蜘蛛、蜈蚣、钳虫、邪恶钳虫、黑色恶蛆、跳跳蜂、楔蛾、角蝇、粪虫、沃玛战士、沃玛勇士、沃玛卫士、沃玛护卫、沃玛战将、火焰沃玛、沃玛教主、祖玛卫士、祖玛弓箭手、祖玛雕像、祖玛教主、赤月恶魔、赤血恶魔、灰血恶魔、血巨人、血金刚、尸王、触龙神、震天魔神、霸王教主、潘夜战士、潘夜鬼将、诺玛法老、诺玛教主、神舰守卫...

Zircon 怪物名（英文，309 种）对照需单独建立。
