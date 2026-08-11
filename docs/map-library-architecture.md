# Zircon 地图与图库架构知识

> 日期：2026-08-11
> 记录本次 EI/Zircon 地图迁移中关于「地图」「图库」「数据库」三者关系的完整知识

## 1. 核心架构：地图与贴图分离加载

### 1.1 三类文件，各司其职

| 文件 | 内容 | 说明 |
|------|------|------|
| `.map`（地图） | **引用数据**（不含像素） | 每个格子存「文件编号 + 图片索引」 |
| `.Zl` / `.wil`（图库） | **实际贴图像素** | 地图运行时按引用取帧绘制 |
| `System.db`（数据库） | **逻辑配置**（NPC/刷怪/传送门/安全区） | 与地图画面无关 |

### 1.2 .map 文件内部结构

```
偏移 22: Width (Int16 LE)
偏移 24: Height (Int16 LE)
偏移 28: 背景层（Width/2 × Height/2，每项 3 字节）
         [backFile(1)][backImage(2 LE)]
之后:    主层（Width × Height，每项 14 字节）
         [flag(1)][midAnim(1)][value/frontAnim(1)][frontFile(1)][middleFile(1)]
         [middleImage+1(2)][frontImage+1(2)][skip3(3)][light(1)][skip1(1)]
```

每个格子的「文件编号 + 图片索引」就是图库引用。

### 1.3 文件编号 → 图库映射（KROrder）

`LibraryCore/Libraries.cs` 的 `KROrder` 表：

```csharp
[0]  = Tilesc          [1]  = Tiles30c      [2]  = Tiles5c
[3]  = SmTilesc        [4]  = Housesc       [5]  = Cliffsc
[6]  = Dungeonsc       [7]  = Innersc       [8]  = Furnituresc
[9]  = Wallsc          [10] = SmObjectsc    [11] = Animationsc
[12] = Object1c        [13] = Object2c
[15] = Wood_Tilesc     [17] = Wood_Tiles5c  [21] = Wood_Dungeonsc  ...
[30] = Sand_Tilesc     [34] = Sand_Housesc  ...
[45] = Snow_Tilesc     [60] = Forest_Tilesc ...
```

EI 客户端（Mir3.exe 反汇编）用**相同的 v 变换体系**：
`v = file − floor(file/14)`，组 0-4（14 库/组含 object1c/2c），与 Zircon KROrder 一致。

### 1.4 运行时加载流程

```
.map 文件 → 读格子引用(文件编号, 图片索引)
         → KROrder[文件编号] → LibraryFile
         → LibraryList[LibraryFile] → .Zl 文件路径
         → 读 .Zl 第「图片索引」帧 → 绘制
```

## 2. 图库文件格式

### 2.1 Zircon 原版 `.Zl`（v1 格式）

- version=0 → DXT1（BC1）压缩，version=1 → DXT5（BC3）
- 元数据块 + 每帧 DXT 压缩数据
- `Tiles5c.Zl` MD5 = `286b1220005970c6d511e0a9599f0d11`

### 2.2 EI 转换版 `.Zl`（ZL2 格式）

- 头部 `ZL2` 签名
- version=2，PNG 无损 codec + Deflate 压缩
- `Tiles5c.Zl` MD5 = `482f56b627752f39e136dfd6fc069bf7`

### 2.3 差异影响

| 维度 | Zircon 原版 (DXT1) | EI 转换版 (ZL2/PNG) |
|------|-------------------|--------------------|
| 帧索引 | 相同 | 相同（关键！） |
| 帧内容 | 原版像素 | EI 像素 |
| 黑帧 20-24 | DXT1 c0≤c1 → 透明 | PNG alpha=255 → 不透明黑 |
| 帧数 | 20000 | 20000 |

**帧索引一致**是两种图库可互换的基础——地图引用不变，只是画面像素不同。

## 3. 本次迁移操作记录

### 3.1 EI 迁移（已完成）

1. EI 544 张 `.map` 覆盖 Zircon 258 张
2. 27 个 WIL/WIX → ZL2/PNG 转换，覆盖 Zircon 原版图库
3. DB 迁移（删除 185 孤儿地图 + 修正 48 张尺寸变化 + 导入 485 张 EI 配置）

### 3.2 临时切回 Zircon（当前）

1. 地图：258 张 Zircon 原版（备份恢复）
2. DB：Zircon 原版 pre-delete
3. 图库：**27 个 Zircon 原版**（MD5 全匹配）

### 3.3 备份位置

| 内容 | 路径 |
|------|------|
| EI 完整状态 | `/home/tetsuya/NAS/TMP/ei-state-20260811-1438/`（1.3G） |
| Zircon 原版备份 | `/home/tetsuya/NAS/TMP/zircon-backup-20260811-095139/` |

## 4. 关键经验

1. **地图和贴图是两类独立文件**——恢复地图 ≠ 恢复贴图，要分别处理
2. **图库是全局共享的**——不是"每张地图自带贴图"，而是 KROrder 统一映射
3. **换图库影响所有引用它的地图**——换 EI 图库后，所有地图（包括 Zircon 原版地图）的像素都变 EI
4. **帧索引一致**是混用图库的基础——只要帧号对得上，Zircon 地图 + EI 图库也能显示（只是画面是 EI 风格）
5. **MD5 校验是验证恢复完整性的可靠手段**——对比当前文件与备份的 MD5
