# Godot 天气、昼夜与环境光说明

本文记录 Godot 客户端当前天气、地图环境光、昼夜循环和局部光源的完整关系，并注明与旧版客户端的对应位置。

## 1. 结论摘要

- 天气由 `MapInfo.Weather` 决定，纯客户端本地读取位标志（无服务器参与、无网络包），不会因为进入夜晚而自动出现。
- 当前数据库 627 张地图 `Weather` 全部为 `None`——游戏内看不到天气；历史上的 `TownWeatherTestMode` 城镇随机覆盖测试模式**已移除**（污染客户端，加过又删）。想看天气须改库（走 dbeditor 管线）或用 web 预览实验室。
- **web 环境实验室（Goal E5）**：`http://127.0.0.1:8822/static/env.html`（Light Lab）可零成本实时预览四维（环境光/天气/光源/特殊态），改库前先用它看效果；三方对照与已知偏差见 `docs/lightlab/PARITY_REPORT.md`。
- 环境光由 `MapInfo.Light` 和服务器下发的 `DayTime` 共同决定（`AmbientFor`，见 §6）。
- `TimeOfDay` 主要表示 Dawn/Day/Dusk/Night 阶段和小地图图标；客户端环境亮度实际使用 `LightSetting` 或 `DayTime`。
- 夜间局部光源来自玩家、其他玩家、带光照属性的对象、地图格子光和技能/特效光。
- **特殊光照态**（死亡红染/深渊黑视）已实现，见 §8。
## 2. 天气类型

天气定义在 `LibraryCore/Enum.cs` 的 `[Flags] Weather`：

| 名称 | 数值 | 含义 |
|---|---:|---|
| `None` | 0 | 无天气 |
| `Rain` | 1 | 雨 |
| `Snow` | 2 | 雪 |
| `Fog` | 4 | 雾 |
| `Lightning` | 8 | 闪电 |

天气是位标志，可以组合。例如：

| 组合 | 数值 |
|---|---:|
| `SnowFog` | 6 |
| `RainLightning` | 9 |
| `FogLightning` | 12 |
| `RainFogLightning` | 13 |

客户端使用位判断，因此组合天气可以同时生成多种粒子：

```csharp
Has(Weather.Rain)
Has(Weather.Snow)
Has(Weather.Fog)
Has(Weather.Lightning)
```

地图天气配置位于服务端数据库的 `MapInfo.Weather` 字段，管理界面对应 `Server/Views/MapInfoView.cs` 的 Weather 下拉框。

## 3. 四种天气的旧端参数

天气素材来自 `ProgUse.Zl`，当前 Godot 实现位于 `GodotClient/Scripts/MapWeatherLayer.cs`。

### 雨

- 生成间隔：10ms
- 生成位置：80% 从顶部，20% 从右侧
- 初始速度：`(-1, 5)`
- 缩放：旧端 `1..2`
- 初始角度：`0.4`
- 初始生命周期：500～2000ms
- 素材：509
- 到期后停止移动，播放水花 510、511、512、513、514
- 水花每帧 100ms
- 水花播放完毕后移除

### 雪

- 最大数量：500
- 生成间隔：20ms
- 生成位置：屏幕顶部
- 初始速度：X 为 `-1` 或 `0`，Y 为 `1`
- 缩放：`0..1.5`
- 旋转速度：`0.1` 个旧端逻辑 tick
- 生命周期：4000～10000ms
- 素材：500
- 到期后停止移动、停止旋转
- 之后以 `ScaleRate=-0.01`、`FadeRate=0.01` 消散

### 雾

- 最大数量：4
- 初始生成，不按时间间隔补充
- 素材：550
- 缩放：4
- 速度：`(1, 0)`
- 生命周期：1小时
- 颜色：`DarkGray`
- 多张雾图按素材宽度连续排列，形成循环雾带

### 闪电

- 最大数量：3
- 生成间隔：随机1000～5000ms
- 生成位置：屏幕顶部随机 X
- 速度：0
- 缩放：1～3
- 生命周期：100～200ms
- 素材：540
- 到期后淡出，淡出速度对应旧端 `FadeRate=0.1`

## 4. 天气的绘制顺序

当前世界绘制顺序为：

```text
地图/对象/技能
    ↓
天气层 Z=850
    ↓
环境光层 Z=900
    ↓
UI、小地图等界面层
```

这样夜间环境光会同时压暗地图、人物、技能和天气。天气不会覆盖夜间黑暗层。

地图切换时 `MapWeatherLayer.SetWeather()` 会：

1. 更新天气位标志
2. 清空旧地图残留粒子
3. 重置生成计时器
4. 重新生成雾
5. 按新地图天气位生成雨、雪、闪电
## 5. 当前地图天气配置

当前导出的 `MapInfo` 数据共 **627** 张地图（2026-08-15 快照，权威源 `docs/lightlab/env-snapshot.json`）：

| Weather | 地图数量 |
|---|---:|
| `None` | 627 |
| 其他天气或组合 | 0 |

> 历史注：本文旧版记录的「Godot 测试模式对 5 个城镇随机覆盖天气」(`TownWeatherTestMode`) 已删除——
> 该后门污染客户端真实行为，教训记录在案；**不要再加客户端测试后门**。要看天气：
>
> 1. 零成本预览：Light Lab（§1）四开关任意组合实时渲染；
> 2. 真改库：dbeditor 管线改 `MapInfo.Weather`（如 `RainFogLightning`），停服→备份→写库→round-trip→
>    重启进图。E5 已全流程实测：`02_0062` 改 `RainFogLightning` 后游戏内日志
>    `[Light] map=02_0062 setting=Default weather=RainFogLightning dayTime=0`（证据
>    `docs/lightlab/ingame_020062_rainfoglightning.png`），验证后已回滚。

把某张地图 Weather 改为非 None 保存数据库后重新进入地图，客户端日志会输出：

```text
[Light] map=... setting=... weather=... dayTime=...
```

其中 `weather=None` 就表示该地图没有配置天气，不是客户端没有加载成功。

**注意（E5 实测定性）**：夜晚环境下闪电几乎不可见——闪电纹理（ProgUse 帧 540）不透明区平均
亮度约 77/255，经夜晚环境光 0.25 相乘后 ≈19，与夜间背景同量级；闪电只在 Default 白天或
Light 地图上才明显。雨/雾在夜间可见度也大幅下降。
## 6. 环境光四种模式（AmbientFor，MapLightLayer.cs）

| 模式 | 环境亮度 | 原版实现 (MapControl.cs) | Godot 实现 |
|---|---:|---|---|
| `Light` | 100% | `(255,255,255)`（层不渲染） | `1.0`（≥0.999 跳过） |
| `Night` | 25% | `(15,15,15)` ≈ 5.9% | `0.25`（柔和月夜，**刻意偏差**） |
| `Twilight` | 约 39.2% | `(100,100,100)` | `100/255 ≈ 0.39` |
| `Default` | 随昼夜 | `255 × DayTime`（无下限） | `max(0.25, DayTime)` |

当前客户端为了保证夜间仍能看清地图，最低环境光取 `0.25`（注释明示"柔和月夜"）。
原版 `Night` 是 `(15,15,15)` 接近全黑、`Default` 无下限——两端在这两档存在**已知的刻意偏差**
（完整对照与「原版严格模式」预览见 `docs/lightlab/PARITY_REPORT.md` #1/#2）。

固定模式优先级：

```text
MapInfo.Light == Light    -> 100%（光照层不渲染）
MapInfo.Light == Night    -> 25%（原版 15/255，刻意调亮）
MapInfo.Light == Twilight -> 100/255
MapInfo.Light == Default  -> max(0.25, 服务器 DayTime)
```

当前 627 张地图的环境光配置统计（2026-08-15 快照）：

| LightSetting | 地图数量 |
|---|---:|
| `Default` | 580 |
| `Night` | 44 |
| `Light` | 3 |

## 7. 服务器昼夜循环

昼夜逻辑位于 `ServerLibrary/Envir/SEnvir.cs:CalculateLights()`。

服务器配置：

```csharp
DayCycleCount = 3
```

服务器将现实时间乘以 `DayCycleCount`，再折算为游戏时间。因此当前配置下：

- 现实 8 小时 = 游戏 24 小时
- 游戏 1 小时 = 现实 20 分钟

游戏时间阶段：

| 游戏时间 | `TimeOfDay` | `DayTime` |
|---|---|---:|
| 00:00～04:59 | `Night` | 0 |
| 05:00～07:59 | `Dawn` | 0→1 线性增加 |
| 08:00～16:59 | `Day` | 1 |
| 17:00～19:59 | `Dusk` | 1→0 线性降低 |
| 20:00～23:59 | `Night` | 0 |

注意：`TimeOfDay` 和 `DayTime` 是服务器分别计算、分别广播的两个值。客户端不会自行根据本地电脑时间计算昼夜。

## 8. 网络切换流程

### 进入游戏

`StartInformation` 同时带有：

- `DayTime`
- `TimeOfDay`
- `TimeOfDayLabel`
- 当前地图索引

Godot 在进入游戏时保存这些值，然后加载地图。

### 游戏运行中

服务器变化时发送：

```text
S.DayChanged
S.TimeOfDayChanged
```

Godot 网络层处理位置：

- `GodotClient/Network/ServerConnection.cs`

场景层处理位置：

- `GameScene.OnDayTimeChanged()`：更新环境光层
- `GameScene.OnTimeOfDayChanged()`：更新时间阶段和小地图图标

`DayTime` 的变化会立即调用：

```csharp
_lightLayer.SetDayTime(DayTime);
```

## 9. 夜间局部光源

环境光变暗后，局部光源会把附近区域提亮。

当前光源来源：

| 来源 | 无装备/无属性时 | 有光照属性时 |
|---|---:|---:|
| 本地玩家 | 半径3微光 | 使用玩家 `Stat.Light` |
| 其他玩家 | 半径3微光 | 使用玩家 `Light` |
| NPC/怪物/物体 | 无 | 使用对象 `Light` |
| 地图格子 | 无 | 使用 `.map` 格子 Light |
| 普通技能特效 | 无 | 使用 `FrameLight` |
| 投射物 | 无 | 使用 `ProjectileDef.FrameLight` |

人物和对象光源使用旧端的物体光公式；技能特效额外除以5，避免技能光圈放大过度。

局部光源只在环境光小于100%时可见。白天 `LightSetting.Light` 或 `Default + DayTime=1` 时，整张地图已经全亮，局部光源不会产生明显视觉差异。

## 10. 常见问题排查

### 看不到天气

按顺序检查：

1. 日志中的 `weather` 是否为 `None`
2. 当前地图的 `MapInfo.Weather` 是否配置了对应位
3. `ProgUse.Zl` 是否存在且成功加载
4. 是否在地图切换后等待粒子生成时间
5. 配置中的天气绘制开关是否关闭

### 整张地图很黑

检查日志：

```text
[Light] map=... setting=... weather=... dayTime=...
```

- `setting=Night`：当前客户端使用 Twilight 亮度，不再是旧端约5.9%
- `setting=Default dayTime=0`：服务器正处于夜晚，但客户端会使用 Twilight 下限
- `setting=Default dayTime` 接近0但 `TimeOfDay` 不合理：检查服务器昼夜广播
- `setting=Light`：不应出现环境黑暗层

### 只有本地玩家发光

当前版本已经为其他未死亡玩家增加半径3的基础微光；如果仍看不到，应检查：

- 该地图是否为 `Light` 或白天满亮
- 远端玩家是否已进入 `_otherPlayers`
- 远端玩家是否被标记为 `Dead`
- `[Light]` 日志和运行时光源位置是否正常

## 11. 主要代码和数据索引

- 天气枚举：`LibraryCore/Enum.cs`
- 环境光枚举：`LibraryCore/Enum.cs`
- 地图天气/光照字段：`LibraryCore/SystemModels/MapInfo.cs`
- 服务器昼夜计算：`ServerLibrary/Envir/SEnvir.cs`
- 网络数据包：`LibraryCore/Network/ServerPackets.cs`
- Godot 天气：`GodotClient/Scripts/MapWeatherLayer.cs`
- Godot 环境光：`GodotClient/Scripts/MapLightLayer.cs`
- Godot 场景接线：`GodotClient/Scripts/GameScene.cs`
- 旧端天气：`Client/Models/Particles/Weather/`
- 旧端环境光：`Client/Scenes/Views/MapControl.cs`
- 当前地图数据：`docs/research/ei2-research/data/MapInfo.md`

## 12. 特殊光照态（死亡红染 / 深渊黑视，2026-08-15 Zircon 8d1a6a3b）

对照原版 `Client/Scenes/Views/MapControl.cs` Light.OnClearTexture 补齐，`MapLightLayer.PlayerLightState`
（`GameScene.SetPlayerState` 驱动）+ shader `global_tint`：

| 态 | 视觉 | 规格 |
|---|---|---|
| 死亡 | 整层 `IndianRed (205,92,92)` 相乘红染 | **白天也强制渲染**；**优先于深渊**；无光源恢复 |
| 深渊中毒 | 全黑 (ambient=0) + 玩家微光 | 微光半径 `256×(0.1+4×0.02)=46.08` 逻辑 px；`GameScene` 每 980ms 循环施放 Abyss 环绕特效（MagicEx4 帧 2000 起 14 帧 × 70ms） |

渲染审计：`MapTestScene -- --light-render-audit` 5 stage（night/twilight/default/dead/abyss）；
dead 探针 `0xcd5c5c` 精确等于 IndianRed。web 对照预览：Light Lab 特殊态按钮（§1）。

已知偏差（只记录，改不改由用户拍板，见 PARITY_REPORT #15）：原版把 Abyss 环绕特效画进
光照层纹理（黑暗中全屏可见）；Godot 端特效节点 ZIndex=3301 < LightOverlay=3401，被全黑
层压暗、仅微光圈内可见。
