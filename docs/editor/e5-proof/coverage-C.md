# E5 阶段 C 验收证据（网页接入）

日期: 2026-08-16 · 服务: webclient :8822 (FastAPI) · 浏览器: headless Chromium (CDP)

## C1 — serve.py 数据源切换 ✓

- `/lab/table` 与 `/lab/frame-formulas` 读 `zircon/ClientData/`（`MIR3_ZIRCON_ROOT` 解析），
  缺文件 500 带再生成指引。实测 `GET /lab/table` → 200，148 keys，
  FireBall 含 start(1)/release(3) effects + sound 三段。

## C2 — 漫游操作面 ✓

- **TILE import 修复**（main.js:7）：B 大地图 ReferenceError 黑屏根因。
  实测（headless 浏览器）：`b` 键打开大地图，1050×700 canvas **绘制率 100%**
  （paintedRatio=1.0），无 console 错误。
- **位置持久化**：`localStorage['wc_pos:<stem>']`，enterMap 恢复（walkable 校验由
  环扫回退保证）、tryStep/transition/teleport 落位即写。实测：移动 (398,403)→(398,404)
  → **刷新页面 → (398,404)** 精确恢复。

## C3 — 施法动作分派 + 逐帧延迟 ✓

- `data.js loadAll` 拉 ClientData 两表；PLAYER_ANIMS 就地合入 frame-formulas
  （combat1..15/channelling/stance 全套 + 逐帧 delays）。
- `castMagic` 重写：`anim = FF.animOf(key)`（magicDispatch 同表）→ FireBall 实测
  **combat1**（非旧硬编码 combat2）；relDelay=spellReleaseDelayMs（min(3,count-1)
  延迟和，PlayerRenderer.cs:124 语义，引擎 t0=relDelay 起播 release 段）。
- 施法朝向目标：`dir8To`（修掉 lab 遗留单位错位——原式像素向量×48 与格差比较，
  东南恒判 Down；实测 东西南北=2/4/6/0）。
- **world.update 接回主循环**（旧代码从未调用，combat 动作卡死第 0 帧）；
  施法动作播完 → **stance 3s**（原版 SetFrame 语义）→ standing。
  实测时序: t=300ms combat1 → t=1.5s stance → t=3.7s standing。

## C4 — 特效引擎统一 effects.js ✓

- 新模块 `static/js/effects.js`：makeFF/frameDelays/spellReleaseDelayMs/
  direction16/dir8To/frameSpriteCached/createFxEngine（original 段语义编排
  start/release/aoe/arrival + 渲染）。lab.js 删掉三份手抄（DIRS8/direction16/
  dir8To/FF/frameDelays/spellReleaseDelayMs/spawnFx/fxFrame/fxPos/updateFx/
  frameSprite/drawFx/spawnFromEffect），FF/ENGINE 全部来自共享模块；
  引擎时钟=labT 保持截图确定性（__LAB.freezeAt 同步 ENGINE.st.t）。
- 语义分派（original 段字段）：projectile→像素直线弹道（dur=Distance px，
  dir16 方向帧 `+dir16*Skip`）；aoe→落点扇形扩散（StartDelayMs+距离×
  DistanceDelayMs）；ctx 含 arrival→弹道到达后；target='point'→落点。
- 实测（roam）：FireBall 东向弹道 4 fx（起手+弹道+落地）；ScortchedEarth
  **41 格 floor 层 AOE** + 21 格 object 层附加；EvilSlayer 悬停怪 target 命中。

## C5 — 渲染保真 ✓

- `Blend→ctx.globalCompositeOperation='lighter'`（blendRate 默认 0.7 对齐
  Godot CastEffect）；非 Blend 用 Opacity。图层 floor（实体下）/object/final。
- Colour 色染（Fire/Ice/… 离屏 multiply 按帧缓存）。
- lab.js drawScene 实际绘制施法者纸娃娃（原只算不画，问题 3b）。
- **反自参照证据**（C6 项提前实测）：活体关 blend 后施法者区域平均亮度
  302.43 vs 开 blend 301.17（lighter 高光带来自加色混合，diff 非零）；
  火球像素采样（橙红通道判定）1008 px 命中。
- 四类语义截图: `shots/C5-buff-castAtSource.jpg`（原地增益 MagicResistance）、
  `shots/C3-projectile-fireball.jpg`（指向弹道）、`shots/C3-target-hit-evilslayer.jpg`
  （目标命中）、`shots/C5-aoe-scortchedearth.jpg`（落点 AOE）。

## C6 — 回归体系重建

- webres `frame_state()`（ok/blank/missing 三态）+ manifest `_empty`/`_max` 标记；
  serve.py 库内空帧 → **200 透明 + X-Empty-Frame:1**（原版 MirLibrary.Draw 空帧
  同样画不出），界外 → 404。NPC 库实测 0 空帧、max=26989。
- npcs.json 增 `noVisual`（帧号界外，如行会旗帜 Image=10000→100×100>26989），
  render.js 跳过（原版同语义静默）。实测仅行会旗帜 1 条被标记。
- 画廊基线 `--baseline` 重做（渲染语义变更: paperdoll/blend/分层/stance）：
  `docs/magiclab/gallery/_baseline/manifest.json` 收录 **174 技能、freeze=900、
  0 errors**；`REGRESSION.md` 为 174 新增/0 失败的首次基线报告。
- `batch_run.mjs` 预取结算移入 `engine.update()`（层无关）并在 `freezeAt()` 时
  用固定 lab-time 强制重结算；否则实时帧停在回拨前的 `_lastNo`，framesReady
  永不就绪（此前卡在 20/174/46 失败的根因，已修）。
- `framesReady()` 与 `effects.js` 统一读取 `_lastNo`；基线长跑使用 `setsid` 托管，
  `batch_run` 自己创建 `_baseline/`，避免最后复制报告时才因目录不存在失败。
- 门禁: gen_cs_table --check ✓（违规 0）；merge_effects --check 演化为
  **cutover 模式**内部一致性自检（B4 删表后双源重生成口径退役）✓；
  frameformulas --check ✓；extract_sound_catalogs --check ✓。

## C7 — 编辑闭环

- `/lab` 技能详情区参数编辑器：帧/数量/间隔/skip/blend/blendRate/opacity/
  startDelay/distDelay/混合/色/层 全字段，改动 400ms 去抖即时重放预览。
- `POST /lab/save`：白名单字段清洗 → original 段写回（帧三元组按位映射同步
  godot 段）→ `.bak` → 重读回显校验 → `gen_cs_table --check --skip-runtime`
  自检，失败自动回滚。
- 闭环验收记录见 `C7-edit-loop.md`。
