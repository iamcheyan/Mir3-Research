# Web 移植资源体积估算 (阶段0 Spike)

测量日期: 2026-08-14。工具: `Tools/webres/decode_zl_webp.py` (Pillow lossless WebP, method=4)。
源数据: `/home/tetsuya/development/zircon/Debug/Client/Data`。

## 1. Interface.Zl 全量实测

| 指标 | 值 |
|---|---|
| 源文件 | 4.71 MB (ZL2 v2 容器) |
| 帧槽位 / 实际帧 | 311 / **282** (29 空槽) |
| 源编码 | 全部 Png (codec 4) |
| 解码总像素 | 9.81 Mpx |
| **lossless WebP 总大小** | **2.05 MB** (0.22 B/px) |
| lossy q90 WebP 总大小 | 0.87 MB (仅统计未落盘) |
| 压缩比 (源/lossless) | **2.29×** |
| 压缩比 (源/lossy q90) | 5.41× (q90 再比 lossless 小 2.36×) |
| 编解码耗时 | decode 0.5s + encode 16.6s (wall 17.1s) |

输出: `Debug/Client/WebData/interface/{0..310}.webp` + `manifest.json`。

## 2. Interface1c.Zl 抽样外推

| 指标 | 值 |
|---|---|
| 源文件 | 118.7 MB (legacy v0 容器, DXT1) |
| 帧槽位 / 实际帧 | 3020 / 1488 (1532 空槽) |
| 全库总像素 (headers 统计) | 248.8 Mpx |
| 抽样 | 40 帧均匀抽样, 4.18 Mpx, 0 错误 |
| 抽样 lossless / q90 | 0.398 MB (0.10 B/px) / 0.199 MB |
| **外推全库 lossless** | **≈ 15–24 MB** (按帧均摊 14.8 MB；按像素均摊 23.7 MB) |
| 外推全库 q90 | ≈ 7–12 MB |
| 抽样耗时 | decode 0.7s + encode 5.2s (40 帧) |

注: legacy DXT1 帧多为大面积纯色 UI 位图, lossless WebP 压缩比极高
(源/lossless ≈ 298×, 因源按 DXT1 块状 4bpp 定长存储)。

## 3. 客户端目录组成 (Debug/Client)

| 目录 | 大小 | 组成 |
|---|---|---|
| **Data** | 7.4 GB | `.Zl` ×279 = **6.38 GB**；wil/wtl 2.78 MB；`Map Data/` 868 MB；Backup 28 MB；其它 52.5 MB |
| **Map** | 775 MB | `.map` ×808 (非图像数据, 本 Spike 不转换) |
| **Sound** | 835 MB | `wav` ×1594 = 783.2 MB；`ogg` ×1578 = 45.1 MB |
| Database | 5.5 MB | — |
| _extra | 13 MB | — |

### Sound wav→OGG 实测

同名 wav/ogg 对 1578 组: wav 445.0 MB ↔ ogg 45.1 MB = **9.86:1** (与业界典型 ~10:1 一致)。
另有 16 个仅 wav 的文件共 338.2 MB。全目录 OGG 化预估:
45.1 (已有) + 338.2/9.86 ≈ **79.4 MB** (原 835 MB → 约 10.5×缩)。

## 4. 全量 Web 化预估

假设: `.Zl`→WebP lossless 压缩比取实测两库区间——
Interface1c (UI/纯色, DXT1) 5.0× 为乐观界, Interface.Zl (PNG 重编码) 2.29× 为保守界;
写实精灵库 (马匹/装备特效, 大量渐变 Alpha) 预计更接近保守界。

| 资产 | 当前 | Web 化后 (lossless) | Web 化后 (q90 有损) |
|---|---|---|---|
| Data `.Zl` ×279 | 6.38 GB | **2.8–6.4 GB** (按 1–2.29×) | 1.1–1.6 GB |
| Sound → OGG | 835 MB | **79 MB** | — |
| Map (.map 原样) | 775 MB | 775 MB | — |
| 其它 (Database/_extra/杂项) | ~70 MB | ~70 MB | — |
| **合计** | **8.0 GB** | **≈ 3.7–7.3 GB** | **≈ 2.0–2.5 GB** |

结论: lossless 方案即可把客户端资源压到一半以下; 音频 OGG 化收益最大 (10.5×)。
若接受 q90 有损 WebP, 图像资产可再省 ~60%, 总量进入 ~2 GB 区间。
按需加载 (本 Spike 的 manifest + 单帧路由) 使首屏只需 Interface 级别的小库 (≈2 MB)。
