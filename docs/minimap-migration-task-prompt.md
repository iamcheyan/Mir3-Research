# 小地图迁移任务 — 智能体描述词

## 任务目标

把 EI 传奇3.0 客户端的小地图/大地图资源迁移到 Zircon Godot 客户端，使游戏内右上角小地图和 Tab 键大地图正确显示 EI 地图布局。

## 背景

Zircon 客户端已将 544 张 EI 地图替换到位（城镇/矿洞/洞穴画面正确），但小地图图库仍是旧版 Zircon 资源，显示的是旧地图布局，与 EI 地图不匹配。

## 资源位置

- EI 小地图源：
  - `/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/FMMap.wil` + `FMMap.wix`（城镇大地图，31 帧）
  - `/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/MMap.wil` + `MMap.wix`（洞穴小地图，255 帧）
- EI 帧绑定：`/home/tetsuya/development/Mir3-Research/Tools/mir3_client_simulator/data/map_bindings.json`（182 条，每条含 map/名称/library/frame）
- Zircon 当前小地图：`/home/tetsuya/development/Zircon/Debug/Client/Data/MiniMap.Zl`（v1 DXT1，537 帧，需替换）
- 备份目录：`/home/tetsuya/NAS/TMP/zircon-backup-20260811-095139/`

## Zircon 小地图加载机制

1. `GodotClient/Controls/MiniMapDialog.cs:77` — `LibraryFile = LibraryFile.MiniMap`（固定读 `Data/MiniMap.Zl`）
2. `MiniMapDialog.cs:137` — `Image.Index = map.MiniMap`（帧索引来自 DB `MapInfo.MiniMap` 字段）
3. `LibraryCore/Libraries.cs:26` — `[LibraryFile.MiniMap] = @"Data\MiniMap.Zl"`
4. `LibraryCore/SystemModels/MapInfo.cs:48` — `public int MiniMap { get; set; }`

## 执行步骤

### 步骤 1：备份

```bash
cp /home/tetsuya/development/Zircon/Debug/Client/Data/MiniMap.Zl \
   /home/tetsuya/NAS/TMP/zircon-backup-20260811-095139/MiniMap-original.Zl
```

### 步骤 2：转换 EI WIL → ZL2

用已有的转换工具链（位于 `/tmp/zircon-ei-convert/`）：

```bash
# FMMap → ZL2
python3 /tmp/zircon-ei-convert/convert_wil_to_zl2.py \
  "/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/FMMap.wil" \
  "/tmp/zircon-ei-convert/converted/FMMap.Zl"

# MMap → ZL2
python3 /tmp/zircon-ei-convert/convert_wil_to_zl2.py \
  "/home/tetsuya/NAS/TMP/EI传奇3.0客户端/Data/MMap.wil" \
  "/tmp/zircon-ei-convert/converted/MMap.Zl"
```

转换工具说明：
- `zl2writer.py` 用 PNG codec（无损，alpha 正确），raw deflate 压缩
- `convert_wil_to_zl2.py` 读 WIL/WIX，逐帧解码为 RGBA PIL Image，写入 ZL2
- 保留所有帧索引和偏移

### 步骤 3：合并 FMMap + MMap 为 MiniMap.Zl

Zircon 客户端只用一个 MiniMap.Zl 库。需要将 EI 的两个库合并：
- FMMap 帧 0-30 → MiniMap 帧 0-30
- MMap 帧 0-254 → MiniMap 帧 31-285

写一个合并脚本（复用 zl2writer.py 的 write_zl2 函数）：
1. 读 FMMap.Zl 所有帧
2. 读 MMap.Zl 所有帧
3. 拼接帧列表（FMMap 在前，MMap 在后）
4. 用 write_zl2 输出合并后的 MiniMap.Zl（286 帧）

输出到：`/home/tetsuya/development/Zircon/Debug/Client/Data/MiniMap.Zl`

### 步骤 4：更新 DB MapInfo.MiniMap 字段

`System.db` 是 MirDB 自定义二进制格式（非 SQLite），在 `/home/tetsuya/development/Zircon/Debug/Client/Data/System.db`。

每条 MapInfo 记录有一个 MiniMap 整数字段。需要按 `map_bindings.json` 更新：

```python
# 伪代码
bindings = json.load(open("map_bindings.json"))
for b in bindings:
    map_id = b["map"]  # 如 "D401"
    lib = b["library"]  # "FMMap.wil" 或 "MMap.wil"
    frame = b["frame"]  # 如 11
    
    if lib == "FMMap.wil":
        new_minimap = frame  # 0-30
    elif lib == "MMap.wil":
        new_minimap = frame + 31  # 31-285
    
    # 找到 DB 里 FileName == map_id 的 MapInfo 记录
    # 设置其 MiniMap = new_minimap
```

**DB 修改方法**（三选一）：
- **A**（推荐）：用 Zircon 的 ServerCore 管理工具（Server/Views/MapInfoView）GUI 修改
- **B**：写一个 C# 控制台程序，用 MirDB Session API 加载 DB → 修改 → 保存
- **C**：直接二进制补丁（风险高，不推荐）

注意：DB 修改后需要重启服务器和客户端才能生效。服务器和客户端用同一份 System.db（在 `Debug/Client/Data/System.db`），服务器也有一份副本在 `Debug/ServerCore/Database/System.db`（需同步）。

### 步骤 5：验证

1. 重建客户端：`cd /home/tetsuya/development/Zircon && dotnet build GodotClient/ZirconClient.csproj`
2. 启动客户端：`godot-mono --path /home/tetsuya/development/Zircon/GodotClient -- --user test@test.com --pass test123 --char TestHero --window`
3. 进比奇县（0.map）→ 右上角小地图应显示比奇城布局（800×800 城镇）
4. 进矿洞（D201=D2011）→ 小地图应显示矿洞布局
5. Tab 键大地图确认

## 帧绑定参考（map_bindings.json 节选）

### FMMap（城镇大地图）

| 地图编号 | 中文名 | 帧 |
|---------|--------|----|
| 0 | 比奇县 | 0 |
| 01 | 边境城市 | 1 |
| 02 | 银杏山谷 | 2 |
| 1 | 道馆 | 3 |
| 12 | 灌木林 | 4 |
| 2 | 毒蛇山谷 | 5 |
| 4 | 绿洲 | 6 |
| 5 | 沙漠土城 | 7 |
| 6 | 沙漠 | 8 |
| 71 | 沙漠 | 9 |
| ... | ... | ... |

### MMap（洞穴小地图）

| 地图编号 | 中文名 | 帧 |
|---------|--------|----|
| D001 | 半兽洞穴1层 | 1 |
| D002 | 半兽洞穴2层 | 2 |
| D003 | 半兽洞穴3层 | 3 |
| D011 | 天然洞穴1层 | 4 |
| D401 | 废矿矿山入口 | 11 |
| D402 | 废矿东部洞穴 | 12 |
| D403 | 地下1层采矿所 | 13 |
| D404 | 地下2层采矿所 | 14 |
| D405 | 矿石储藏所 | 15 |
| D406 | 废矿南部洞穴 | 16 |
| ... | ... | ... |

## 注意事项

1. **不要修改客户端源码**（MiniMapDialog.cs / BigMapDialog.cs / Libraries.cs），只替换数据文件
2. **DB 修改前必须备份** System.db
3. **服务器和客户端的 System.db 需要同步**
4. **MiniMapIcon.Zl 不需要替换**（图标库，与地图布局无关）
5. 转换后用 `dotnet build GodotClient/ZirconClient.csproj` 验证编译通过
6. 大地图（BigMapDialog）可能用不同的库（Fmmap.Zl），检查 BigMapDialog.cs 确认它用哪个库——如果也用 MiniMap.Zl 则一起修好，如果用 Fmmap.Zl 则也需要替换

## 交付物

1. 替换后的 `MiniMap.Zl`（EI FMMap + MMap 合并版）
2. 更新后的 `System.db`（MapInfo.MiniMap 字段修正）
3. 转换报告（帧数、文件大小、验证截图）