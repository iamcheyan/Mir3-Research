# Goal E5 — 客户端参数数据层化：抽干 → Godot 自证 → 双端共读

> 前作：E4 Magic Lab（特效事实源 JSON + 对账门禁，已完结）。
> 本文档是 E5 唯一任务书，自包含。总纲 `docs/editor/EDITOR_GOALS_MASTER.md` §0 铁律、§3 已实证的坑、§9 协作约定同样适用本文。
> 仓库：`~/development/Mir3-Research`（工具+文档）+ `~/development/zircon`（游戏本体，origin=iamcheyan fork，**只推 origin 不推 upstream**）。
> 所有「已实证」条目均为主会话 2026-08-16 逐项核实（行号/命令/截图可复核），执行时**不需要重新调查**，直接按任务分解开工。

---

## 0. 用户意图（原话语义，不得偏离）

1. 最终形态：**网页里改技能参数（特效样式、施法动作），客户端里立刻可见；反之亦然**——不是"改完再同步"，而是**两端读同一套数据文件，没有第二份**。
2. 实施顺序（用户明确拍板的三阶段）：
   - **阶段 A 抽干**：把客户端里所有可统一的参数全部抽出来，分层 JSON 存到一个文件夹；
   - **阶段 B Godot 自证**：先让 Godot 客户端接入这层数据，跑起来与现在**一模一样**（等价性证明 = 抽取被证明准确）；
   - **阶段 C 网页接入**：网页版读同一套文件，并修复实测体验（移动/大地图/施法动作/特效语义/加色混合/编辑回写）。
3. 工作方式（用户原话）：**边跑边试**（每个交付单元立即实测）、**经常提交并推送**（小步快跑，两仓库都推）。

## 1. 背景：为什么有这个 goal

E4 交付了特效事实源（`magic-effect-table.json` 138 技能 + `frame-formulas.json` 帧表/分派/纸娃娃公式）与两道门禁，并用 `gen_cs_table.py --fix` 完成过一次 JSON→C# 修复闭环（zircon `0dc1321`）。但用户实测实验室后反馈"跟想的完全不一样"，主会话全面调查确认：**共享的只是参数，渲染与编排仍是两套实现，且网页端带硬 bug**。用户最终拍板不做"codegen 按钮"路线，直接做**运行时共读**（文件即唯一事实源）。

### 1.1 已实证的问题清单（主会话 2026-08-16 调查结论）

| # | 症状 | 根因 | 证据 |
|---|---|---|---|
| 1 | B 大地图全黑（可传送但看不见，无法精准传送） | `Tools/webclient/static/js/main.js:334 drawJob` 引用 `TILE`，但 main.js:10 的 import 漏了它 → 首个瓦片绘制抛 `ReferenceError`（未捕获 rejection）→ 绘制队列静默死亡。实测画布暗像素 99.9%；瓦片本身 3750/3750 在盘（`Debug/Client/WebData/maps/0/`）、单张按需渲染 0.5s，与瓦片无关 | headless chrome 抓到 `REJ: ReferenceError: TILE is not defined at drawJob (main.js:334)` |
| 2 | 刷新后回出生点 | `wc_settings`（main.js:30-45）只存分辨率/缩放/UI 等，无坐标字段；每次刷新回 spawn (398,403) | main.js loadSettings |
| 3a | 漫游模式施法无动作分派 | `castMagic`（main.js:192-215）硬编码 `p.anim='combat2'`；无 GetMagicAnimation 分派；无释放延迟（特效 t=0 立即出）；world.js:102-107 动画计时是"总时长均分 6 帧"，不是 frame-formulas 逐帧延迟 | — |
| 3b | /lab 页施法者根本没画 | `drawPaperdoll`（lab.js:136-142）定义后**零调用**；画布上只有"施法者"文字标签；实测施法期施法者区域像素和恒定 2022219（完全静止） | 像素差分 |
| 4 | 特效无透明发光 | 原版 `MirEffect.Draw`（zircon Client/Models/MirEffect.cs:234-237）`Blend:true → DrawBlend`，Vulkan 管线加色混合 `SrcAlpha+One`（RenderingPipelineManager.cs:661 起，BlendRate 默认 0.7）；网页两个渲染器只有普通 alpha 叠加（lab.js:209 `globalAlpha 0.92`、render.js:180 `globalAlpha 0.9`）。帧图 alpha 通道本身完好（RGBA extrema 0-255 已验证） | MirEffect.cs + 管线源码 |
| 5 | 特效千篇一律原地播、不向目标 | 漫游 castMagic 把 effect 钉脚下（main.js:197-199）、弹道固定"面前 3 格"（:204-208），鼠标不参与；/lab 全部钉死 5 个固定木桩（lab.js:31-35）。而表里语义齐全：FireBall 条目含 `origin:caster / target:'point' / target:'target' / ctx:[target,arrival]`（对应原版 MapObject.cs:845/855/864） | magic-effect-table.json |
| 6 | 漫游弹道无方向帧 | render.js:174 `frame = start + idx`，缺 `+ dir16*Skip`（lab 版有 dir16，roam 版没有） | — |
| 7 | 零星缺帧 404 | `NPC/1000000.webp`、`Mon-13/7040`、`Mon-4/1040` 等精灵未抽取（webres 覆盖缺口） | performance entries |
| 8 | E4 回归画廊自参照 | 174/174 基线由同一套带 bug 渲染器自截，绝对性错误（施法者没画、无混合）测不出 | 问题 3b 反证 |

### 1.2 事实源链现状（已验证全绿，这是本 goal 的地基）

```
原版 Client/Models/MapObject.cs（只读铁律）
  └─ Tools/magiclab/extract_effect_table.py → magic-effect-table.json（138 技能）
       ├─ 浏览器 /lab/table ← lab.js 消费
       └─ Tools/magiclab/gen_cs_table.py --check/--fix → GodotClient/Scripts/MagicEffectTable.cs（146 条）
zircon LibraryCore/FrameSet.cs + Functions.cs + GodotClient PlayerRenderer/ObjectRenderer.cs
  └─ Tools/resedit/frameformulas.py → frame-formulas.json
       ├─ 浏览器 /lab/frame-formulas ← 消费
       └─ --check 门禁
```

- 当前门禁状态（主会话刚跑过）：`frameformulas.py --check` 一致 ✓；`gen_cs_table.py --check` 146 条/白名单 136==138 原版 case/共有 136 技能三元组全一致（可接受差异 7）✓
- `frame-formulas.json` 覆盖已超预期：frameSets 含 players + defaultMonster/NPC/Item + 全部特殊怪物表 + 12 伙伴表；另有 attackDispatch / **magicDispatch（施法动作分派）** / armourShift / npcSpecial / paperdoll / objects / enums / magicTypes

### 1.3 关键结构事实（决定架构可行性，已核实）

- `LibraryCore/FrameSet.cs` 的所有字典是 `public static`（FrameSet.cs:8-40）→ **Godot 侧启动时从 JSON 填充即可，LibraryCore 源码零改动**（守住只读铁律）。FrameSet.cs 共 570 条 `new Frame(...)`。
- `Functions.GetMagicAnimation/GetAttackAnimation` 在 LibraryCore（代码 switch，非数据表）→ **保持原样不动**；JSON 里的 magicDispatch/attackDispatch 副本仅供网页端消费，一致性由 `frameformulas.py --check` 门禁锁。
- Godot 表里大量显式参数**不在现有 JSON 中**（`extra` 只有 `Blend:true`）：BlendRate（ScortchedEarth 1f / FrozenEarth 0.5f / 默认 0.7）、Opacity、EffectLayer（Floor/Object/Final）、StartDelayMs、DistanceDelayMs、DirectionFromCast、DirectionFromSource、CastAtSource、Colour、FrameLight、Skip、ProjectileLastLocationOnly、Projectile/TargetProjectile/AdditionalProjectiles、Source/Impact/MapImpact/TargetEffect/Additional、CompletionSound/ArrivalSound、NoColourKey。这些字段多数在原版代码里以属性赋值/时序表达式存在（extractor 目前只捕了子集），部分是 Godot 表的结构化再组织——见 §3 阶段 A 的双源合并方案。
- 硬编码参数表全景（本 goal 抽取范围）：
  - `GodotClient/Scripts/MagicEffectTable.cs`（726 行，特效表）
  - `LibraryCore/FrameSet.cs`（帧表；**只读，靠填充不靠改**）
  - `GodotClient/Scripts/PlayerRenderer.cs:803-` ArmourShift 表 + 纸娃娃公式（已在 frame-formulas.json）
  - `GodotClient/Scripts/MagicSoundCatalog.cs`（技能分阶段音效+门控）、`SoundCatalog.cs`（SoundIndex→wav，753 行）、`MonsterSoundCatalog.cs`（怪物音效）→ 全部是纯数据表，机械抽取
  - 光照/天气（MapLightLayer/MapWeatherLayer）不在本 goal 范围（低优先级，二期）

## 2. 架构决策（已定，执行时不再议）

1. **数据层 canonical 位置 = `zircon/ClientData/`**（客户端仓库内自有数据目录）：
   ```
   zircon/ClientData/
     magic-effects.json    ← 特效表全字段（阶段 A 产物）
     frame-formulas.json   ← 帧表/分派/纸娃娃（frameformulas.py 产出写入）
     sounds.json           ← 三张音效 catalog（新 extractor 产物）
     _meta/                ← 各文件 provenance 与生成信息
   ```
   生成器仍住 Mir3-Research（`Tools/magiclab/`、`Tools/resedit/`），以 ClientData 为输出目标；Mir3-Research 内旧副本（Tools/magiclab/magic-effect-table.json、Tools/resedit/frame-formulas.json）降级为兼容软链或删除，**杜绝双份**。webclient serve.py 改为直接读 `zircon/ClientData/` 绝对路径（经 `MIR3_ZIRCON_ROOT` 环境变量，与 services.sh 一致）。
2. **Godot 接入 = 启动时 loader 填充**：新增 `GodotClient/Scripts/DataLayer.cs`，在引擎初始化早期（先于任何 FrameSet/MagicEffectTable 消费者）加载 JSON：填充 FrameSet 静态字典、构建 MagicEffectTable、构建三张音效 catalog。**等价性证明完成后删除旧硬编码表本体**（干净 cutover，无兼容垫片）。loader 容错：文件缺失/坏条目打 `GD.PrintErr` 并跳过该条目（不崩客户端），但完整快照对账（§3 阶段 B）必须零差异。
3. **网页编辑 = 直接写 ClientData JSON**（写前自动备份 `.bak`，git 可回滚），无 codegen、无 overrides 旁车、无同步步骤。文件是唯一事实源。
4. **原版 `Client/`、`LibraryCore/` 继续只读**；只动 `GodotClient/`、`Mir3-Research/Tools/*`、新建 `zircon/ClientData/`。

## 3. 任务分解（严格按 A→B→C，阶段间有验收门）

### 阶段 A — 抽干：数据层完备化（门：三 JSON 落位 + 覆盖率 100% + 门禁绿）

**A1. 特效表全字段化（双源合并）**
- 原版源：升级 `Tools/magiclab/extract_effect_table.py`，解析扩到 case 内全部属性赋值与时序表达式（Blend/BlendRate/Opacity/DrawType/StartLight/EndLight/Colour/Skip/StartTime AddMilliseconds/距离延迟/方向语义 ctx），schema 加版本号。
- Godot 源：新增 `Tools/magiclab/extract_godot_table.py`，**机械全保真**解析 `GodotClient/Scripts/MagicEffectTable.cs`（CastEffect/ImpactDef/ProjectileDef 全字段 → JSON，含 Godot 结构字段 DirectionFromCast/EffectLayer/MapImpact/AdditionalProjectiles/CompletionSound 等）。
- 合并器 `Tools/magiclab/merge_effects.py`：原版字段为帧数据事实源、Godot 字段为结构事实源；**共有字段冲突必须为零**（当前门禁已保证三元组一致；有冲突即停，人工比对 `docs/magiclab/GODOT_TABLE_DIFF.md` 可接受清单裁决）；产出 `zircon/ClientData/magic-effects.json`，`_meta` 记录两源 commit hash 与生成时间。
- 回写 `gen_cs_table.py`：改为对 ClientData JSON 对账（三元组口径不变，可扩全字段）。旧 `magic-effect-table.json` 处理见架构决策 1。

**A2. 音效表抽取**
- 新增 `Tools/magiclab/extract_sound_catalogs.py`：解析 Godot 三张 catalog → `zircon/ClientData/sounds.json`（SoundIndex→文件/类别/循环 + 技能分阶段 Start/End/Duration + 门控 Locations/Targets + 怪物音效表）。

**A3. 帧表落位 + 覆盖率对账**
- `frameformulas.py` 输出改写 `zircon/ClientData/frame-formulas.json`（`--check` 门禁同步改路径）。
- 新增覆盖率对账工具（独立性铁律：不复用生成器解析）：`LibraryCore/FrameSet.cs` 字典名清单（含全部特殊怪/伙伴表）vs JSON frameSets keys **必须 100%**；magic-effects.json 技能集 vs Godot 表条目集 100%；sounds.json vs 三 catalog 100%。产出报告 `docs/editor/e5-proof/coverage-A.md`。

**A4. 阶段 A 验收门**：三 JSON 落位；三道 `--check` 绿；覆盖率 100%；commit+push（两仓库）。

### 阶段 B — Godot 自证：loader 接入 + 等价性证明 + cutover（门：快照全等 + 审计全绿）

**B1. 改造前快照（先于任何改动）**
- 写 `GodotClient/Scripts/TableSnapshotTool.cs`（或 MapTestScene 旗标模式）：反射导出当前**硬编码**的 MagicEffectTable 全条目、三张音效 catalog、FrameSet 全字典 → `docs/editor/e5-proof/snapshot-before.json`（稳定序列化：键排序、枚举转字符串、TimeSpan→ms double）。commit。
- 跑一次 Godot（MapTestScene 审计模式）留改造前基线日志。

**B2. DataLayer loader**
- `GodotClient/Scripts/DataLayer.cs`：初始化早期（Program/场景引导，找到先于 FrameSet 首次消费的点）加载三 JSON：
  - FrameSet：字典名↔JSON key 映射（camelCase 约定同 frameformulas.py），`Frame` 构造（start,count,offset,逐帧 delays 数组；TimeSpan.FromMilliseconds）。
  - MagicEffectTable：JSON→CastEffect/ImpactDef/ProjectileDef（枚举 LibraryFile/Color/MirAnimation 解析、字段默认值与 C# 初始化器逐一对齐）。
  - 音效 catalog 同理。API（`MagicEffectTable.Get/GetAttack`、SoundCatalog）签名不变，消费者零改动。
- 导出打包：确保 ClientData 进 Godot export（export_presets.cs / csproj 包含非导入资源）；缺目录时启动报清晰错误。

**B3. 等价性证明（本阶段灵魂）**
- 改造后用同一快照工具导出 `snapshot-after.json`，与 before **逐键逐字段 diff 必须全等**。任何 diff = loader 或抽取 bug，修复后重跑（不许放宽口径，不许白名单）。
- `dotnet build` 0 错；MapTestScene 全套审计绿：MagicCoverageAudit（castConfigured=146, missingOriginalSpell=0）、MagicFrameAudit、MagicSpotAudit 5/5、SpellTimingAudit、FrameAudit；魔法舞台抽测 ≥5 技能与改造前逐帧一致（Godot 端截图对比，落 `e5-proof/`）。

**B4. cutover**
- 等价证明后：删除 MagicEffectTable/三音效 catalog 的硬编码字典本体（保留枚举/结构体/API 壳，数据全部来自 loader）；commit+push。
- 用户实机提示：在最终报告写明"如何验证（启动客户端放几个技能）+ 如何回滚（git revert <hash>）"。用户在边跑边试过程中发现问题会直接反馈到 goal 会话。

**B5. 阶段 B 验收门**：快照全等；build+审计全绿；cutover 完成且二次审计仍全绿。

### 阶段 C — 网页接入：读同一层 + 实测体验修复 + 编辑回写

**C1. 服务端数据源切换**
- `Tools/webclient/serve.py`：`/lab/table`、`/lab/frame-formulas` 改读 `zircon/ClientData/`（经 MIR3_ZIRCON_ROOT；缺文件报 500 带指引）。/lab/magicinfo 不动。

**C2. 操作面修复（漫游模式 `/`）**
- 修 main.js:10 import 补 `TILE`（B 大地图黑屏根因，问题 1）。实测：大地图可见（暗像素比 <30%）、点击传送精准。
- 位置持久化：`localStorage['wc_pos'] = {stem:{x,y}}`；enterMap 恢复（校验 walkable，不可走回退出生点）；到达格子时节流写入；实测刷新/换图回原坐标。

**C3. 施法动作（漫游模式）**
- world.js 动画计时换 frame-formulas 逐帧延迟（lab.js:95-99 frameDelays 公式搬来）；PLAYER_ANIMS 扩到全 Combat 系（数据从 frame-formulas.json 取，消灭 data.js 手抄常量）。
- castMagic 重写：`anim = FF.animOf(key)`（magicDispatch 同表）、`relDelay = spellReleaseDelayMs(anim)`（min(3,count-1) 延迟和，与 Godot PlayerRenderer.cs:124 SpellReleaseDelayMs 逐字一致）、施法后 3s Stance（原版 SetFrame 语义）、施法朝向目标。

**C4. 特效引擎统一（effects.js 公共模块）**
- 从 lab.js 抽出编排引擎（playSkill/spawnFx/fxFrame/fxPos/updateFx/direction16）为 `Tools/webclient/static/js/effects.js`，roam 与 lab 共用，消灭第三份手抄。
- 鼠标选目标：点击地面 = point 落点；点击怪物/召唤物 = target（`@spawn` 的怪即靶子）。
- 语义分派（按 JSON 字段）：`origin:caster`→施法者身上；`target:'point'`→鼠标落点；`target:'target'`→目标实体；`ctx:[...,arrival]`→弹道落地后触发；`segment:'aoe'`/MapImpact→落点地面层；StartDelayMs/DistanceDelayMs 照表。
- 弹道：施法者→目标像素直线，`duration = Distance(px) ms`，Direction16 量化 22.5°（Functions.cs 语义），方向帧 `+dir16*Skip`（修漫游缺失，问题 6）。

**C5. 渲染保真（roam+lab 同步）**
- `Blend:true → ctx.globalCompositeOperation='lighter'`，BlendRate→alpha（默认 0.7）；非 Blend 用 Opacity 普通叠加（问题 4）。
- 图层 Floor（地面层，实体之下）/Object/Final 按表 DrawType/segment 排序绘制。
- lab.js 接上 `drawPaperdoll`（问题 3b）。
- 全字段消费：Opacity/Layer/StartDelay/DistanceDelay/Colour 着色（Godot CastEffect.Colour 语义：Fire/Ice 等色调染）。

**C6. 回归体系重建（反自参照）**
- webres 补抽缺失帧（NPC/1000000 等），确属 ZL 空帧的在 manifest 标记（问题 7）。
- `batch_run.mjs --baseline` 重做画廊基线（渲染语义变更，旧基线作废，报告注明）。
- 新增反自参照验收：施法期施法者区域像素差分必须非零（问题 8）；blend 开/关对比帧亮度必须有显著差。
- 两道 `--check` 门禁持续绿。

**C7. 编辑闭环（终态交付）**
- /lab 技能详情区做参数编辑器（全字段：lib/frame/count/delayMs/blend/blendRate/opacity/colour/skip/layer/startDelay/distanceDelay），改动即时重渲预览。
- 保存 → 写 `zircon/ClientData/magic-effects.json`（写前 `.bak` + 写后重读回显 + `gen_cs_table.py --check` 自检通过才算保存成功）→ Godot 重启即生效（可选：DataLayer 加文件 watch 热重载，Godot 侧可选项不做硬性要求）。
- 音效可选播放（serve.py 伺服 wav，SoundCatalog 文件名→`Debug/Client/Data/Sound/` 路径），不作为验收项。

## 4. 验收标准（全勾才算完成）

- [ ] A：三 JSON 落位 `zircon/ClientData/`；覆盖率对账 100%（报告落 `docs/editor/e5-proof/`）；三道 `--check` 绿
- [ ] B：快照 before/after 全等；`dotnet build` 0 错；MapTestScene 全套审计绿；硬编码表已删且审计仍绿；报告含验证/回滚指引
- [ ] C1-C2：serve.py 读 ClientData；B 大地图可见+精准传送；位置刷新/换图保持
- [ ] C3-C5：漫游施放 FireBall = Combat1 动作（非通用 combat2）+ 抬手延迟 + 弹道飞向鼠标点（带方向帧）+ 加色发光 + 落地命中；四类语义抽查各 ≥1：原地增益（MagicResistance 类）/ 指向弹道（FireBall）/ 目标命中（EvilSlayer 类）/ 落点 AOE（ScortchedEarth），位置与动作各归其位（截图落 e5-proof/）
- [ ] C6：画廊基线重做全绿；施法者像素差分非零；blend 对比有亮度差；门禁绿
- [ ] C7：闭环演示——网页改 FireBall 帧号 → 保存（自检过）→ `git -C zircon diff` 可见 ClientData 变更 → Godot 启动即用新参数；网页刷新亦见
- [ ] 全程：无新增 console 错误（页面 4xx 仅限已标记空帧）；`scripts/services.sh status` 家族正常；不破坏 E1（:8899 `?edit=1`）/ E2（mapviewer /npc/*）表面
- [ ] 收尾：踩坑回写总纲 §3 新小节；`PROJECT_MENTAL_MODEL.md`（若存在于 docs/）补 E5 完成态；watchdog 数组行归档三件套（.off + 注释行 + goal-completed.log）

## 5. 工作流纪律（用户明确要求）

1. **边跑边试**：每个交付单元完成立即实测（门禁命令 / `services.sh restart webclient` + headless 浏览器截图 / `dotnet build` + 审计场景），证据（截图/报告/日志）落 `docs/editor/e5-proof/`；**禁止**只靠编译通过就进入下一单元。
2. **经常提交并推送**：每个功能单元一次 commit（中文信息，跨仓库改动各自提交），commit 后立即 `git push origin`（**两仓库都推；zircon 绝不推 upstream**）。禁止长跑不提交。
3. 服务经 `scripts/services.sh` 管理（start/restart/status），不自起裸进程；调试用 headless chrome（`/home/tetsuya/.cache/ms-playwright/`）完场收干净。
4. 共享 checkout 纪律（总纲 §9.2）：只写自己领地（`Tools/webclient|webres|magiclab|resedit`、`docs/editor/e5-*`、`zircon/GodotClient/Scripts/DataLayer*` 与 cutover 涉及文件、`zircon/ClientData/`）；他人脏文件不碰不提交。当前工作树已有的 `Tools/maps/mapedit/map_links_v2.json`、`docs/magiclab/REGRESSION.md` 脏文件属于历史会话产物，绕开。
5. NAS 负载：headless 浏览器用完即杀；不做全量瓦片重渲；dotnet 增量构建。
6. 长跑：watchdog 每 5 分钟巡检，卡住会自动发「继续」——除非验收标准全勾，否则不要停。遇到真阻塞（如等用户裁决）在转录里写明阻塞点再 idle。

## 6. 风险与预案

| 风险 | 预案 |
|---|---|
| 原版 extractor 扩字段时源码格式难解析 | 只需覆盖已有三元组口径不回退；新增字段尽力提取，提取不到的从 Godot 源补（provenance 标注），`GODOT_TABLE_DIFF.md` 记录 |
| 等价性 diff 非零 | 逐条修复（loader 默认值/枚举解析/TimeSpan 精度）；禁止白名单放行；修不动即停下写明阻塞 |
| Godot export 漏 ClientData | export_presets/csproj 显式 include + 启动缺文件报错自检 |
| webport（:8823）也读 frame-formulas 旧路径 | serve.py 切换时同步检查 webport 侧引用点，改读 ClientData 或软链，保持其不破坏 |
| 快照工具反射拿不到私有静态 | MagicEffectTable 字段可见性最小调整（readonly 不变），快照工具只读 |

## 7. 开工第一步

1. `git -C ~/development/Mir3-Research pull && git -C ~/development/zircon pull`（确认包含 Mir3-Research 最近 master）
2. 通读本文档 + 总纲 §0/§3/§9
3. 建 `docs/editor/e5-proof/`，从 A1 开工
