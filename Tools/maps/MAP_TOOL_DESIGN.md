# Mir3 地图工具说明

## 1. 工具目的

`Tools/maps/` 是 Mir3/EI 与 Zircon 客户端地图研究工具目录，目标是把客户端实际使用的地图数据、图库资源和传送关系，以一个可以核对游戏坐标的方式展示出来。

主要用途：

- 读取和检查 `.map` 文件；
- 按客户端的地图图层规则组合地面、中层和前景；
- 从 `.Zl`/`.wil` 图库中读取地图贴图；
- 生成静态 JPG，供浏览器地图查看器显示；
- 鼠标移动时显示与游戏一致的地图坐标；
- 显示地图之间、区域之间和小地图之间的连接关系；
- 审计地图引用的图库、帧编号和缺失资源；
- 对比 Zircon、EI 和其他客户端的地图资源。

## 2. 目录中的主要程序

### `mapviewer.py`

浏览器地图查看器的服务端程序。默认读取：

```text
/home/tetsuya/development/Zircon/Debug/Client/Map
/home/tetsuya/development/Zircon/Debug/Client/Data/Map Data
```

它负责：

1. 解析地图列表和地图尺寸；
2. 解析地图单元格中的 Back、Middle、Front 三个图层；
3. 根据文件编号将图层映射到 `KR_ORDER` 对应的图库；
4. 解码 ZL/WIL 帧并组合成 JPG；
5. 提供地图坐标、缩放、图层开关和连接关系接口；
6. 在当前地图上绘制传送点、出口和目标地图信息。

启动：

```bash
cd /home/tetsuya/development/Mir3-Research
python3 Tools/maps/mapviewer.py --port 8766
```

浏览器地址：

```text
http://127.0.0.1:8766/
```

如果查看其他客户端资源，可以显式指定客户端根目录：

```bash
python3 Tools/maps/mapviewer.py \
  --client-root /path/to/client \
  --port 8899
```

### `render_client_map.py`

命令行静态渲染入口，使用和 `mapviewer.py` 相同的地图解析、图库查找和渲染逻辑。

```bash
python3 Tools/maps/render_client_map.py 0.map
python3 Tools/maps/render_client_map.py 3.map --output /tmp/map-3.jpg
```

默认输出到 `/tmp/zircon-map-<地图名>.jpg`，也可以使用 `--output` 指定文件。

### `export_map_connections.py`

从数据库导出的 `MapRegion.*.md` 和 `MovementInfo.*.md` 中整理地图连接，生成：

```text
docs/database/data/map-connections.json
```

连接记录包含源地图、源坐标/区域、目标地图、目标坐标/区域以及连接类型。查看器读取这个 JSON，并把当前地图相关的连接画在地图上。

### 其他辅助程序

- `audit_mir3_maps.py`：地图文件和资源引用审计；
- `check_map_resource_consistency.py`：检查地图引用与图库资源是否一致；
- `diagnose_map_glitch.py`：定位地图显示异常；
- `render_map_comparison.py`：不同客户端或不同资源目录的地图对比；
- `build_map_catalog.py`：建立地图目录和尺寸索引；
- `lib_frame_stats.py`：统计图库帧和空帧情况；
- `gen_minimap_ei.py`：生成 EI 小地图索引；
- `map_routes.py`：分析地图连接路径。

## 3. 地图数据逻辑

### 地图坐标

游戏地图使用逻辑格子坐标。当前工具采用客户端使用的格子尺寸：

```text
一个格子 = 48 × 32 像素
像素 X = 地图格子 X × 48
像素 Y = 地图格子 Y × 32
格子 X = floor(像素 X / 48)
格子 Y = floor(像素 Y / 32)
```

因此浏览器中的鼠标坐标可以直接对应游戏内坐标，而不是浏览器窗口坐标或 CSS 缩放后的坐标。

### `.map` 文件

当前解析逻辑按以下顺序读取：

1. 文件头中的宽度和高度；
2. Back 地面层：偶数格上的半分辨率记录，每条记录 3 字节；
3. 全分辨率单元格记录，每格 14 字节；
4. 每个单元格的中层和前景图层引用。

地图中的文件编号不是文件名，而是客户端地图图库表中的编号。`KR_ORDER` 负责把编号映射为例如 `Tilesc`、`Tiles30c`、`SmObjectsc`、`Housesc`、`Sabak` 等图库名称。

### 图层绘制顺序

每个地图格子的绘制顺序为：

```text
Back 地面
  ↓
Middle 中层/小物件/建筑底部
  ↓
Front 前景/墙体/屋顶/遮挡物
```

地图贴图和角色贴图的锚点规则不同。地图工具当前按客户端地图绘制逻辑处理：地面从格子左上角开始，中层和前景按贴图底边与格子底部对齐。不能把角色的偏移规则直接套到地图层，否则会造成建筑错位。

## 4. 图库查找规则

图库查找顺序是：

1. `Data/`；
2. `Data/Map Data/`；
3. `Data/Map Data/<地形目录>/`，例如 `Forest`、`Sand`、`Snow`、`Wood`。

同名图库可能存在多个地形目录。当前实现会优先命中根目录版本，因此如果某张地图需要特定地形图库，必须进一步根据地图或客户端实际加载规则选择对应目录，不能只按照文件名覆盖。

## 5. 地图连接关系

连接关系不是从地图图片推断出来的，而是来自数据库中的区域和移动信息：

```text
MapRegion.*.md
MovementInfo.*.md
        ↓
export_map_connections.py
        ↓
map-connections.json
        ↓
mapviewer.py 的连接层
```

查看器中的连接线只是关系可视化层，不参与地图贴图渲染。即使地图 JPG 生成失败，连接线仍然可能显示；因此“能看到连接线”不能证明地图图片已经正确生成。

## 6. 缓存

查看器的渲染缓存位于：

```text
/home/tetsuya/development/Zircon/Debug/Client/Map/.tilecache-v3
```

缓存版本会在地图解析规则或图库映射变化时递增。修改解析器后如果仍看到旧图，应：

1. 重启 `mapviewer.py`；
2. 浏览器执行强制刷新（Ctrl+Shift+R）；
3. 确认服务端日志中的缓存目录已经变为新版本。

不要把缓存目录当作源数据，也不要把缓存 JPG 复制回客户端资源目录。

## 7. 已修复问题

### 7.1 ZL2 图库解析导致黑图（已修复）

**症状**：`0.map` 渲染出 9600×6400 纯黑 JPG。

**根因**：Python `zlsdk.py` 的 ZL2 容器解析与 C# `ZlReader.cs` 不一致：

1. **ZL2 索引条目格式错误**：Python 按 22 字节解析（eid i32 + off i64 + length i32 + packed_len i32 + comp byte + fmt byte），但 C# `Zl2Entry.Read` 是 23 字节：`Type(1) Id(i32) UncompressedSize(i32) CompressedSize(i32) Offset(i64) Compression(byte) Codec(byte)`。字段顺序和语义全错，导致 offset/size 全是垃圾值。
2. **ZL2 帧元数据解析不完整**：Python 只读了 width/height/offset + 跳过少量字节，但 C# `ZlImage.Read(version=2)` 在 baseline 25 字节后还有 `AtlasPage(i32) + SourceRect(h×4) + VisibleBounds(h×4) + 3 codec bytes + 3 runtime bytes + 9 个 i32 (StoredDataSize/Bc7/Fallback × Image/Shadow/Overlay)` = 额外 64 字节。Python 没读这些，导致从第二帧起全部错位。
3. **Deflate 解压用错 API**：C# `DeflateStream` 是 raw deflate（无 zlib 头），Python 用 `zlib.decompress`（期望 zlib wrapper）对压缩条目（compression=1/2）报 `incorrect header check`。

**修复**（对照 `GodotClient/Formats/ZlReader.cs`）：

- `Zl2Entry` 字段改为 Type/Id/UncompressedSize/CompressedSize/Offset/Compression/Codec（23 字节）。
- `ZlImageHeader` 增加 codec/stored_size/bc7_size 字段；`_parse` ZL2 分支按 C# `ZlImage.Read(v2)` 读完整 25+64 字节元数据。
- `decode` ZL2 分支按 codec 分派：Png(4) 用 PIL、Bgra32(2) 转 RGBA、Dxt1(0)/Dxt5(1) 用现有 BCn 解码器、Bc7(3) 暂不支持。
- 压缩条目改用 `zlib.decompressobj(-zlib.MAX_WBITS)`（raw deflate）。

**验证**（`render_client_map.py 0.map`）：修复前纯黑 960KB；修复后 2400×1600，168052 色，mean RGB [101,110,66]（比奇县绿色地面），90% 像素非黑。Tilesc/Tiles30c/Tiles5c/SmObjectsc/Housesc/Wallsc/Cliffsc 全部 ZL2 库解码正常，Sabak 旧版库不受影响。

> 修改 `zlsdk.py` 后若仍看到黑图，先清 `__pycache__`（`find Tools -name __pycache__ -exec rm -rf {} +`），Python 会缓存旧字节码。

## 9. 运行验证清单

```bash
cd /home/tetsuya/development/Mir3-Research

python3 -m py_compile Tools/maps/mapviewer.py Tools/maps/zlsdk.py
python3 Tools/maps/export_map_connections.py
python3 Tools/maps/render_client_map.py 0.map --output /tmp/map-0-check.jpg
python3 Tools/maps/render_client_map.py 3.map --output /tmp/map-3-check.jpg
python3 Tools/maps/check_map_resource_consistency.py --help
```

查看器启动后应看到类似日志：

```text
[*] Maps directory: /home/tetsuya/development/Zircon/Debug/Client/Map
[*] Connections: 554 movements loaded
[*] Tile cache: .../Map/.tilecache-v3
[*] Map Viewer running on http://127.0.0.1:8766/
```

