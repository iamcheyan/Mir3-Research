# Goal E5 — 环境实验室 Light Lab（天气×昼夜×光照 模拟器）

> 总纲见 `docs/editor/EDITOR_GOALS_MASTER.md`（§0 铁律、§4 环境同样适用本文）。
> 用户诉求原话背景：游戏有天气和光照系统，晚上默认看不见东西，蜡烛/火把/火炬装备
> 后提升照亮范围，白天黑夜对应不同亮度，还有雾/风/雨/雷电天气；想单独测这块，
> 做一个天气模拟器，明确功能与边界。

---

## 1. 调研结论（2026-08-15 主会话实证，全部有代码出处）

### 1.1 定性：这是静态配置系统，不是运行时系统

| 子系统 | 事实源 | 机制 | 现状 |
|---|---|---|---|
| 天气 | `MapInfo.Weather` 位标志（每图静态） | **无服务器参与、无网络包**，客户端读库本地生成粒子 | 627 图全 `None`，游戏内看不到天气；`TownWeatherTestMode` 测试后门已移除 |
| 昼夜 | 服务器 `SEnvir.CalculateLights`（`Config.DayCycleCount`，当前 3：现实 8h=游戏 24h） | `S.DayChanged`/`S.TimeOfDayChanged` 广播 → `GameScene.OnDayTimeChanged` → `MapLightLayer.SetDayTime` | 双端已实现 |
| 环境光 | `MapInfo.Light`（实测分布 Default 580/Night 44/Light 3）× DayTime | `MapLightLayer.AmbientFor`：Light=1.0、Night=0.25、Twilight=100/255、Default=max(0.25, dayTime) | 已实现；**已知刻意偏差**：原版 Night=15/255≈6% 全黑，Godot 调成 25% 柔和月夜（`MapLightLayer.cs` 注释） |
| 火把蜡烛 | `ItemStats`：Candle=15、Bright Candle/Torch=25 等（共 24 个 Torch 类物品）→ `Stat.Light` | 光圈 `ObjectLightRadius=256×(0.1+light×0.04)`；其他玩家保底微光 3；特效光 `EffectLightRadius=÷5`；格子光 `256×(0.1+light×0.6)` | 已实现；**无燃烧消耗**（ServerLibrary 无 TorchDecay，蜡烛不烧完） |

原版对照（`Client/Scenes/Views/MapControl.cs` Light 类）：
`BaseLightSize=0.1, LightScale=0.02, TileLightScaleMultiplier=30, EffectLightScaleDivisor=5,
TileLightSearchPadding=15`，COLORFY 混合+共享光纹理；环境光 Default=`255×DayTime`、
Night=`(15,15,15)`、Twilight=`(100,100,100)`、Light=白。

天气粒子（Godot `MapWeatherLayer.cs` 249 行已按原版参数移植，素材 ProgUse.Zl）：
雨 509（落地水花 510-514）、雪 500、雾 550、闪电 540；详细参数见
`docs/GODOT_WEATHER_DAYLIGHT_GUIDE.md` §3（注意该文档地图统计是旧 244 图时代，
环境光描述也是旧的 100/255 时代，以本文件和当前代码为准）。

### 1.2 质量风险（实验室的存在理由）

1. **看不了**：全库 Weather=None，改库前零预览；改库要走 dbeditor 管线+重进游戏，试错贵
2. **已知偏差无回归**：Night 25% vs 原版 6%；Godot 光照是 shader 重写（smoothstep 衰减）
   vs 原版光纹理 COLORFY——无逐场景对照证据
3. **组合态从未验证**：Night 地图 × 雷雨 × 火把光圈 × 格子光叠加

## 2. 方案（用户已拍板：基底并入 E4 webclient 实验室；立即发 82 执行）

E4（Magic Lab，ed-magic）正在把 `Tools/webclient/` 改造成实验室基底（人物+木桩+场景）。
E5 复用同一基底，新增**环境面板**：Light/DayTime/Weather/光源四维实时预览。
两 goal 同仓并行，协作规则见 §5。

## 3. 任务分解（P0→P4）

### P0 — 素材与数据准备

1. 提取天气素材：`ProgUse.Zl` 帧 500（雪）、509-514（雨+水花）、540（闪电）、550（雾）
   → WebP（zlsdk；放 `Tools/webclient/static/assets/weather/` 或 E4 已建的资源目录）
2. 导出环境数据快照 `docs/lightlab/env-snapshot.json`：627 图的
   `{FileName, Light, Weather}`（读 dbeditor workspace MapInfo.json）+ 24 个 Torch 物品
   `{Name, Light}`——实验室下拉框数据源，也是分布统计证据

### P1 — 环境面板（webclient 内）

1. 新模块 `Tools/webclient/static/js/env-lab.js`（E5 领地，见 §5）：
   - **环境光控件**：LightSetting 四选一 + DayTime 0-1 滑条 → 场景环境光实时变化
     （复现 `AmbientFor` 语义：Light=1.0/Night=0.25/Twilight≈0.39/Default=max(0.25,dayTime)，
     同时提供"原版严格模式"开关：Night=15/255——对照用）
   - **天气控件**：Rain/Snow/Fog/Lightning 四开关（位组合）+ 强度滑条 → 粒子按原版参数
     渲染（MapWeatherLayer 的 web 版：生成率/生命期/缩放/水花序列照抄 §1.1 参数）
   - **光源控件**：装备槽选火把（Candle15/Bright Candle25/Torch15/Bright Torch25/无）
     → 人物光圈；"其他玩家微光×N"、"特效光(FrameLight)"、"格子光演示瓦片"开关
   - **特殊态按钮**：死亡红染、深渊黑视——按 §7 已实现的 Godot 规格做 web 预览，
     供用户对照检测（Godot 端已上线，见 §7）
2. 叠加顺序对齐 Godot：地图/对象 → 天气(Z850) → 环境光(Z900) → UI
3. 特殊态 web 预览规格（与 Godot `MapLightLayer.cs` 对齐）：死亡=整层 IndianRed
   (205,92,92) 相乘红染、白天也渲染、优先于深渊；深渊=全黑+玩家位置微光半径
   `256×(0.1+4×0.02)=46.08` 逻辑像素+980ms 循环 Abyss 环绕特效（MagicEx4 帧 2000 起
   14 帧可用 E4 已接的素材管线）

### P2 — 对照与回归证据链

1. 组合采样网格截图（web 端）：`{4 LightSetting} × {DayTime 0/0.25/0.5/1} × {无/雨/雪/雾/雷/雨+雷} × {无火把/蜡烛/亮蜡烛}` 抽样正交网格 → `docs/lightlab/gallery/` 画廊
2. Godot 无头对照（总纲 §4.4 配方 + `MapTestScene -- --light-render-audit`，现 5 stage
   含 dead/abyss；注意用户参数需 `--` 分隔符）+ GM 号进 Night 地图实测截图，与 web 端并排
3. 偏差报告 `docs/lightlab/PARITY_REPORT.md`：逐项列出 Godot vs 原版 vs web 三方差异
   （含已知的 Night 25% 偏差），**只记录不改 Godot**——改不改由用户拍板

### P3 — 数据出口（写库唯一管线）

1. 面板"应用到地图"：选定地图 + 目标 Weather/Light → 生成 dbeditor workspace
   MapInfo.json 的变更预览（diff 展示）→ 走 `/api/sync` → sync.sh 管线写回
   （铁律：实验室本身绝不直写 .db；服务器运行中不写；写前备份；round-trip 验证）
2. 写回后游戏内验证：重进地图查 `[Light]` 日志行（setting/weather/dayTime）+ 截图

### P4 — 修补文档（收尾）

1. 更新 `docs/GODOT_WEATHER_DAYLIGHT_GUIDE.md` 过时章节（244→627 图统计、
   Night 环境光 100/255→25%、TownWeatherTestMode 已移除、补特殊态一节指向 §7）
2. 新坑回写总纲 §3；E5 结论摘要回写 `docs/PROJECT_MENTAL_MODEL.md`

## 4. 边界（不该碰的——用户明确要求写清）

1. ❌ 不改服务器昼夜算法（`CalculateLights`/`DayCycleCount`）——玩法参数，实验室只复现
2. ❌ 不做动态天气系统（服务器随机天气事件、天气网络包）——原版没有，加=动协议，超范围
3. ❌ 不在 Godot 加测试后门（TownWeatherTestMode 教训：加过又删，污染客户端）
4. ❌ `.map` 格子光**编辑**归 E1 地图编辑器（mapviewer 领地）——E5 只读格子光做预览演示
5. ❌ 不碰原版 `Client/`；不碰 Godot `MapLightLayer.cs`/`MapWeatherLayer.cs`（特殊态已由
   主会话实现并推送，Zircon 8d1a6a3b；后续 Godot 调整需用户点头）；dbeditor 之外禁写库
6. ⚠️ 火把燃烧消耗（蜡烛烧完）是原版 Mir3 有、当前 Zircon 无的玩法缺口——**只写进
   PARITY_REPORT 差异清单，不实现**（注意与特殊态不同：特殊态已实现）

## 5. 领地与协作（与 E4 并行的关键）

- E5 领地：`Tools/webclient/static/js/env-lab.js` 及配套 css/素材、`docs/lightlab/`
- E4 领地（**只读**）：webclient 其它文件（lab 主结构、world/render/ui/sprites）
- 协作规则：E5 的面板以**独立模块+最小挂载点**方式接入——若 E4 的实验室骨架已有
  面板注册机制就用它；没有就 `<script>` 独立加载、DOM 挂到独立容器，**不改 E4 文件**；
  实在必须改（如 index.html 加一行 script 标签），先在 tmux 用 `[shared]` 前缀声明再小步提交
- 开工先 `git pull --rebase`，commit 前再 pull 一次（E0-E4 都在本仓提交）

## 6. 验收标准

- [ ] P0：天气素材 WebP 可显示；env-snapshot.json 627 图 + 24 火把数据齐全
- [ ] P1：四维面板实时联动（环境光/天气粒子/光源/特殊态），叠加顺序与 Godot 一致；
      死亡红染=IndianRed(205,92,92) 相乘、深渊=全黑+46.08 半径微光（对照 Godot 8d1a6a3b）
- [ ] P2：web 采样画廊 + Godot 无头对照截图（含 dead/abyss stage）+ PARITY_REPORT.md
- [ ] P3：选一张测试地图改 Weather=RainFogLightning 经 dbeditor 管线写回，游戏内
      `[Light]` 日志 + 截图证实天气生效（测试图选无关紧要的图，改完可回滚）
- [ ] P4：两份文档更新；证据全部落 `docs/lightlab/`

## 7. 特殊态（Godot 端已实现，实验室提供检测面）

原版规格（`Client/Scenes/Views/MapControl.cs` Light.OnClearTexture）：死亡→整层
IndianRed 红染；深渊中毒→全黑+玩家微光+`MagicEffect.Abyss` 环绕特效；二者白天也强制
渲染（ShouldRenderLightLayer），死亡优先于深渊。

**Godot 端已于 2026-08-15 由主会话实现并推送（Zircon commit `8d1a6a3b`）**：
`MapLightLayer.PlayerLightState`（SetPlayerState）+ shader global_tint + `GameScene`
Abyss 特效循环；渲染审计扩为 5 stage（night/twilight/default/dead/abyss）全 PASS，
dead 探针 `0xcd5c5c` 精确等于 IndianRed。本 goal 只需在 web 端做同规格预览供
用户检测对照，**不再改 Godot**。
