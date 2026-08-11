# 小地图迁移：调查报告与智能体任务描述

> 日期：2026-08-11
> 背景：已将 EI 传奇3.0 的 544 张地图 + 27 个图库迁移到 Zircon 客户端/服务器。地图画面已正确（矿洞、城镇等），但**小地图与大地图仍显示旧版 Zircon 布局**，与 EI 地图不匹配。

## 1. 问题概述

Zircon 客户端右上角小地图（`MiniMapDialog.cs`）和 Tab 键大地图（`BigMapDialog.cs`）从图库 `MiniMap.Zl` / `Fmmap.Zl` 按帧索引读取地图图片。帧索引由数据库 `MapInfo.MiniMap` 字段决定。

当前 Zircon 的 `MiniMap.Zl` / `Fmmap.Zl` 是旧版 Zircon 资源（537 帧 / 120 帧，v1 DXT1 格式），对应的是 Zircon 原版地图布局。替换为 EI 地图后，地图文件尺寸/布局全变了，小地图帧对不上。

## 2. 资源现状

### Zircon 当前（旧版，需替换）

| 文件 | 格式 | 帧数 | 用途 |
|------|------|------|------|
| `Debug/Client/Data/MiniMap.Zl` | v1 DXT1 | 537 | 小地图（`LibraryFile.MiniMap`） |
| `Debug/Client/Data/Fmmap.Zl` | v1 DXT1 | 120 | 大地图（`LibraryFile.Fmmap`，实际未在 LibraryList 出现，可能已废弃） |
| `Debug/Client/Data/MiniMapIcon.Zl` | v1 DXT1 | — | 小地图图标（NPC/出口标记），**不需要替换** |

### EI 原版（目标资源）

| 文件 | 帧数 | 用途 | 绑定地图数 |
|------|------|------|-----------|
| `EI传奇3.0客户端/Data/FMMap.wil` | 31 | 城镇大地图 | 29 张（frame 0-30） |
| `EI传奇3.0客户端/Data/MMap.wil` | 255 | 洞穴/地牢小地图 | 153 张（frame 0-254） |

### EI 帧绑定（map_bindings.json）

完整绑定在 `/home/tetsuya/development/Mir3-Research/Tools/mir3_client_simulator/data/map_bindings.json`：

```json
{"map": "0", "name": "比奇县", "library": "FMMap.wil", "frame": 0}
{"map": "01", "name": "边境城市", "library": "FMMap.wil", "frame": 1}
{"map": "D001", "name": "半兽洞穴1层", "library": "MMap.wil", "frame": 1}
{"map": "D401", "name": "废矿矿山入口", "library": "MMap.wil", "frame": 11}
```

- **FMMap.wil**：城镇/区域大地图（0/01/02/1/12/2/4/5/6/71/...）
- **MMap.wil**：洞穴/地牢小地图（D001-D903 等 153 张）

## 3. Zircon 客户端小地图加载机制

### 代码路径

1. `MiniMapDialog.cs:77` — `LibraryFile = LibraryFile.MiniMap`（固定用 MiniMap.Zl）
2. `MiniMapDialog.cs:137` — `Image.Index = map.MiniMap`（帧索引 = DB MapInfo.MiniMap 字段）
3. `BigMapDialog.cs` — 同理用 Fmmap 或 MiniMap

### DB 字段

`LibraryCore/SystemModels/MapInfo.cs:48` — `public int MiniMap { get; set; }`

每条 MapInfo 记录有一个 MiniMap 整数字段，指向 MiniMap.Zl 的帧索引。

### 库注册

`LibraryCore/Libraries.cs`:
```csharp
[LibraryFile.MiniMap] = @"Data\MiniMap.Zl",
[LibraryFile.MiniMap2] = @"Data\MiniMap2.Zl",
[LibraryFile.MiniMapIcon] = @"Data\MiniMapIcon.Zl",
```

注意：**Fmmap.Zl 不在 LibraryList 里**，可能已废弃或通过其他方式加载。

## 4. 迁移方案

### 方案 A（推荐）：合并 EI FMMap + MMap 到 MiniMap.Zl

EI 用两个独立库（FMMap + MMap），Zircon 用一个 MiniMap.Zl。需要：

1. **合并帧**：将 EI FMMap.wil（31 帧）+ MMap.wil（255 帧）合并为一个 ZL2 库，帧索引连续编号
   - FMMap 帧 0-30 → MiniMap 帧 0-30
   - MMap 帧 0-254 → MiniMap 帧 31-285
2. **更新 DB**：每条 MapInfo 的 MiniMap 字段改为合并后的帧索引
   - 城镇地图（FMMap 绑定）：MiniMap = FMMap frame（不变）
   - 洞穴地图（MMap 绑定）：MiniMap = MMap frame + 31
   - 无绑定的地图：MiniMap = -1 或 0

### 方案 B：保持两个库

保持 FMMap.Zl 和 MMap.Zl 分开，修改客户端代码加载逻辑按地图类型选择库。改动较大。

### 推荐执行步骤（方案 A）

1. **转换 EI WIL → ZL2**
   - 用已有的 `/tmp/zircon-ei-convert/zl2writer.py` + `convert_wil_to_zl2.py` 工具链
   - FMMap.wil + FMMap.wix → FMMap.Zl（31 帧）
   - MMap.wil + MMap.wix → MMap.Zl（255 帧）
   - 合并为 MiniMap.Zl（286 帧）
2. **部署**
   - 备份旧 `Debug/Client/Data/MiniMap.Zl`
   - 用新 MiniMap.Zl 替换
3. **更新 DB MapInfo.MiniMap**
   - 读 `map_bindings.json` 获取每张地图的帧绑定
   - 按方案 A 映射计算新帧索引
   - 修改 `System.db` 的 MapInfo 记录
4. **验证**
   - 进游戏开小地图确认城镇/洞穴地图正确

## 5. 关键文件清单

| 文件 | 用途 |
|------|------|
| `/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/FMMap.wil` + `.wix` | EI 城镇大地图源 |
| `/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/MMap.wil` + `.wix` | EI 洞穴小地图源 |
| `/home/tetsuya/development/Mir3-Research/Tools/mir3_client_simulator/data/map_bindings.json` | EI 地图→帧绑定（182 条） |
| `/home/tetsuya/development/Zircon/Debug/Client/Data/MiniMap.Zl` | 当前 Zircon 小地图（需替换） |
| `/home/tetsuya/development/Zircon/LibraryCore/SystemModels/MapInfo.cs` | MapInfo.MiniMap 字段定义 |
| `/home/tetsuya/development/Zircon/LibraryCore/Libraries.cs` | 库注册（MiniMap/MiniMapIcon） |
| `/home/tetsuya/development/Zircon/GodotClient/Controls/MiniMapDialog.cs` | 小地图 UI 代码 |
| `/home/tetsuya/development/Zircon/GodotClient/Controls/BigMapDialog.cs` | 大地图 UI 代码 |
| `/tmp/zircon-ei-convert/zl2writer.py` | ZL2 写入器（PNG codec） |
| `/tmp/zircon-ei-convert/convert_wil_to_zl2.py` | WIL→ZL2 转换脚本 |

## 6. 备份目录

- 旧 Zircon 资源备份：`/home/tetsuya/NAS/TMP/zircon-backup-20260811-095139/`
- EI 转换输出：`/home/tetsuya/NAS/TMP/ei-map-converted/`