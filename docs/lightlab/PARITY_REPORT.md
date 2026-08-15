# PARITY_REPORT — 天气/昼夜/光照 三方对照（原版 / Godot / web Light Lab）

> Goal E5 产出 · 2026-08-15 · 只记录不改 Godot（改不改由用户拍板）。
> 三方事实源：
> - **原版** = `Client/Scenes/Views/MapControl.cs` Light 类（Zircon 仓库只读）
> - **Godot** = `GodotClient/Scripts/MapLightLayer.cs` + `MapWeatherLayer.cs` + `GameScene.cs`（Zircon 8d1a6a3b）
> - **web** = `Tools/webclient/static/js/env-lab.js`（本仓库 E5）
>
> 证据目录：`gallery/`（web 27 张采样）、`godot/`（无头审计 6 张）、`env-snapshot.json`（分布统计）。

## 0. 现状一句话

627 图 Weather 全 `None`、Light 分布 Default 580 / Night 44 / Light 3 —— 天气系统**全库未启用**，
原版与 Godot 均无天气可看；改库前 web 实验室是唯一预览面。

## 1. 对照总表

| # | 项 | 原版 (MapControl.cs) | Godot (MapLightLayer.cs) | web (env-lab.js) | 差异定性 |
|---|---|---|---|---|---|
| 1 | Night 环境光 | `(15,15,15)` = 5.9% (:1766) | `0.25` 柔和月夜（注释明示刻意偏差） | 默认 0.25 对齐 Godot；严格开关 15/255 | **Godot/web 默认 vs 原版 = 已知刻意偏差**；web 提供严格模式回归原版 |
| 2 | Default 环境光 | `255×DayTime` 无下限 (:1761, byte 截断可到 0) | `max(0.25, dayTime)` 有下限 | 默认 Godot 语义；严格模式 `max(15/255, dayTime)` | 原版昼夜循环下限=纯黑；Godot/web 永远 ≥ 最低可见。严格模式仍非原版（原版无下限），已在面板 hint 标注 |
| 3 | Twilight / Light | 100/255 / 255（不渲染层） | 100/255 / 1.0（≥0.999 跳过） | 同 Godot | 三方一致 |
| 4 | 物体光半径 | `scale=0.1+L×2×0.02`，直径=1024×scale 物理 px(2x 输出) | `256×(0.1+L×0.04)` 逻辑 px | 同 Godot 公式 | 数值等价（1024/2/2=256 换算，见 MapLightLayer 注释）；web 实测火把 25 → r=358.4 |
| 5 | 特效光半径 | `scale=0.1+fl×2×0.02/5` (:1689) | `256×(0.1+max(1,⌊fl/5⌋)×0.04)` | 同 Godot | Godot 对 fl<5 有 max(1,·) 垫底（fl=4 时 0.14 vs 原版 0.132），细微偏大 |
| 6 | 格子光半径 | `scale=0.1+L×30×0.02` (:1720) | `256×(0.1+L×0.6)` | 同 Godot | 数值等价；搜索范围 padding 15 格一致 |
| 7 | 光衰减曲线 | 1024px 径向**光纹理** COLORFY 混合（纹理自带衰减） | `1-smoothstep(r×0.35, r, dist)` shader 近似 | 同 Godot（16-stop 径向渐变） | Godot/web 用 smoothstep 近似原版纹理衰减；曲线形状 vs 二进制纹理未逐像素比对 [未比对] |
| 8 | 多光源合成 | 光纹理 COLORFY 叠加 | `brightness=max(ambient, ambient+inf×(1-ambient))` 逐源取 max | destination-out 乘性擦除 ≈ `1-(1-a)Π(1-inf)` | **web 多光源交叠处略暗于 Godot**（乘积 ≤ max），采样：交叠点 136 vs 单圈中心 147；视觉细微，保守方向 |
| 9 | 光源色 tint | `ob.LightColour` COLORFY | `mix(white, colour, inf×0.22)` 乘性 | multiply 渐变（中心混 22% 同式） | web 近似 Godot；暖色 (1,0.86,0.55) / 微光白 (1,1,1) 色值同源 GameScene.GetObjectLightSources |
| 10 | 天气粒子参数 | Client/Models/Particles/Weather/（雨 509/水花 510-514、雪 500、雾 550、闪电 540） | MapWeatherLayer.cs 全参数移植 | 逐项照抄 Godot（=原版参数；legacy tick 100/s） | 三方参数一致；web 额外有**强度滑条**（生成率倍率，实验室扩展非游戏语义，1.0×=原版） |
| 11 | 雾片数 | 固定 4 片 DarkGray | 固定 4 片 | 1.0× 时 4 片；强度>1 增片 | 实验室扩展 |
| 12 | 天气绘制层 | DrawObjects 内、光照层之前（**天气被暗化**） | Particles=3300 < LightOverlay=3401（同） | 天气先画、光照层后合（同） | 三方一致；gallery `E_abyss_rain` 可见雨滴被深渊黑视吞掉 |
| 13 | 死亡红染 | `Clear(IndianRed)` 整层相乘，白天也渲染，优先于深渊 (:1622) | 同（global_tint, ambient=1, 无光源） | 同（multiply IndianRed 全屏） | 三方一致；Godot 审计 dead 探针 0x502424 = 白板×IndianRed ✓ |
| 14 | 深渊黑视 | 全黑 + 玩家微光 scale=0.1+4×0.02 (:1650) | ambient=0 + 玩家微光 r=46.08 | 同 | 半径公式三方一致（46.08 逻辑 px） |
| 15 | **深渊环绕特效层** | `effect.Draw()` 画**入光照层纹理** (:1662) → 黑暗中全屏可见 | MirEffectNode ZIndex=LocalPlayerEffect=3301 **< LightOverlay** → 被全黑层压暗，仅微光圈内可见 | 画在光照层之后（对齐原版） | **Godot vs 原版真实偏差**：Godot 特效被暗化吞掉。建议用户拍板是否将 Abyss 特效提层 |
| 16 | 深渊特效素材 | MagicEffect.Abyss | MagicEx4 帧 2000-2013，14 帧×70ms=980ms 循环 | 同（`/res/sprites/MagicEx4/`） | 三方一致 |
| 17 | 火把燃烧消耗 | 原版 Mir3 蜡烛会烧完（耐久） | **无**（ServerLibrary 无 TorchDecay，蜡烛不耗） | N/A（只预览） | **玩法缺口**：只记录不实现（任务书 §4.6 边界） |
| 18 | 天气网络包 | 无（客户端本地读 MapInfo.Weather） | 无 | N/A | 静态配置系统，三方定性一致 |

## 2. 环境差异备注（非产品差异）

- **82 机 llvmpipe 软渲染**：`MapTestScene -- --light-render-audit` abyss 探针读数 0.369 < 断言阈值 0.5
  （`godot/zircon-light-abyss.png` 全图 mean=1.5、微光区可见）。主会话 GPU 机器全 PASS（任务书 §7）。
  视觉语义（全黑+微光）在软渲染下同样成立，探针绝对值受渲染器影响——**断言阈值对软渲染偏紧**，
  不改 Godot（边界 §4.5），如实记录。
- web 画布 1280×720 逻辑像素 vs Godot 视口 1024×768/WorldScale2=512×384：粒子绝对数量按各自视口
  生成率独立运行（原版语义即按视口生成），同参数不同视口 → web 视口大 3.5 倍，粒子总数相应更多、
  面密度一致。

## 3. 数值锚点（复现用）

| 量 | 值 | 出处 |
|---|---|---|
| Night (Godot) | 0.25 = 63.75/255 | MapLightLayer.cs:15 |
| Night (原版严格) | 15/255 = 0.0588 | MapControl.cs:1766 |
| Twilight | 100/255 = 0.392 | 两端一致 |
| 火把 L15 光圈 | 256×(0.1+0.6) = 179.2 逻辑 px | ObjectLightRadius |
| 亮火把 L25 光圈 | 256×(0.1+1.0) = 358.4 | 同上 |
| 微光保底 L3 | 256×(0.1+0.12) = 56.32 | GameScene:5085 |
| 深渊微光 | 256×(0.1+0.08) = 46.08 | AbyssGlowRadius |
| 特效光 fl=10 | 256×(0.1+2×0.04) = 46.08 | EffectLightRadius |
| 格子光 L=1 | 256×(0.1+0.6) = 179.2 | TileLightRadius |

## 4. 证据清单

- `gallery/web_A_*.png`（9）：环境光四档×DayTime 梯度 + 严格模式（mean 亮度 65→17→4.7 单调）
- `gallery/web_B_*.png`（6）：雨/雪/雾/雷/雨雷/全组合（闪电竖条位于列 280-297，7s 采样窗）
- `gallery/web_C_*.png`（5）：光源档位（无/蜡烛15/亮25/亮+路人/格子+特效光）
- `gallery/web_D_*.png`（2）：死亡红染白天渲染、深渊黑视白天渲染
- `gallery/web_E_*.png`（5）：组合态（夜+雷雨+火把、夜雪蜡烛、黄昏雾、深渊+雨、死亡+风暴）
- `godot/zircon-light-{night,twilight,default,dead,abyss}.png` + `zircon-weather-rain-fog-lightning.png`：
  82 机 Xvfb+llvmpipe 无头审计产物（5 stage PASS + 天气 PASS；abyss 探针见 §2）
- web 实测像素锚点：火把中心 (147,160,99) 暖亮 / 圈外 (16,13,11) 暗 / 深渊玩家 (255,255,255) 全亮
  / 深渊远处 (0,0,0) 纯黑 / 死亡采样 R/G=2.47（IndianRed 0.804/0.361=2.23 同量级，含地形色偏差）
