# Goal E4 — 技能实验室 Magic Lab（webclient 改造 + 特效事实源闭环）

> 总纲见 `docs/editor/EDITOR_GOALS_MASTER.md`（§0 铁律、§4 环境同样适用本文）。
> 用户诉求原话背景：游戏里很多技能特效对不上，调一个坏一个；想要一个网页版技能查看器
> ——四种职业技能全列出，点一下人物就放那个技能，特效打向场景里的怪物；
> 至少可查看，最好能编辑（伤害等）。

---

## 1. 诊断（为什么对不上、为什么调一个坏一个）— 已实证

1. **特效不是数据驱动的**。`MagicInfo`（dbeditor workspace，174 行）**没有任何特效字段**；
   特效 100% 由代码查表决定。
2. 唯一权威 = 原版 `Client/Models/MapObject.cs:768` 的 `case MirAction.Spell` 巨型 switch
   （原版 Client 只读，Zircon 仓库铁律）。
3. Godot 端手工提取成 `GodotClient/Scripts/MagicEffectTable.cs`（697 行：
   `OriginalSpellCases` 95 技能 + `NoVisualSpellCases` 白名单 + 每技能
   施法站桩/弹道/命中/地面特效定义 `(LibraryFile, 帧, 帧数, blend, 颜色)`）。
   表头注释自述"未覆盖的技能不再伪造通用爆炸，由 GameScene 记录诊断"——即存在已知缺口。
4. 现存**三份各自维护的效果实现**：Godot `MagicEffectTable.cs`、webport `world.js` 内
   MAGIC 表、webclient `render.js` 技能特效。手抄 + 无系统验证 = 漂移必然。
5. 施法动作（跳/挥手/抬手）与特效是两件事：动作已由 webport `anims.js`（对照
   `PlayerObject.cs:578-803` 逐行移植）解决，par-anim goal 有 9 技能 GM 实测截图证据
   （`docs/webport/parity/par-anim/gm-*.png`）。
6. 伤害在服务端：`ServerLibrary/Models/MagicObject.cs` + `ServerLibrary/Models/Magics/
   {Warrior,Wizard,Taoist,Assassin}/*.cs`（每技能一个类）+ MagicInfo 的
   Min/MaxBasePower、BaseCost 等字段。

## 2. 方案总览（用户已拍板）

- **基底**：改造 `Tools/webclient/`（:8822）——已有四职业 255 级纸娃娃、怪物摆放、
  174 技能列表（MIcon.Zl 图标+中文名，见其 README M3 技能系统行）。
- **闭环**：提取原版 switch → 中立 JSON（唯一事实源）→ 网页实验室渲染 + Godot
  `MagicEffectTable.cs` 由生成器从 JSON 重生成（或 CI diff 校验）→ 改一处两端变。
- **回归**：全技能批量跑 → 截图画廊 + 基线 diff → 消灭"调完这个坏那个"。

## 3. 任务分解（P0→P4 顺序执行）

### P0 — 提取事实源 JSON（最高优先级，治本）

1. 工具 `Tools/magiclab/extract_effect_table.py`：解析原版 `Client/Models/MapObject.cs`
   `MirAction.Spell` switch（:768 起），产出 `Tools/magiclab/magic-effect-table.json`：
   ```json
   "<MagicType>": {
     "castAnim": "施法动作名(MirAnimation)",
     "castEffect": {"lib": "Magic", "frame": 500, "count": 10, "blend": 0.7},
     "projectile": {"type": "line|arc|multi|none", "lib": "...", "frame": "...",
                     "count": 0, "lines": 3, "has16dir": true},
     "hitEffect":  {"lib": "...", "frame": "...", "count": 0},
     "aoe":        {"lib": "...", "frame": "...", "count": 0, "durationMs": 150},
     "sound": "SoundIndex 名",
     "notes": "原版 case 行号"
   }
   ```
2. 对账：JSON vs Godot `MagicEffectTable.cs` 逐技能 diff，报告输出
   `docs/magiclab/GODOT_TABLE_DIFF.md`（哪些技能 Godot 缺/错——这份报告本身就是
   "特效对不上"的清单）。
3. 校验器独立性（总纲 §0 铁律）：对账工具不得 import 生成器同一套解析；以
   frame 能否在 ZL 库解码为独立交叉验证（复用 zlsdk）。

### P1 — 实验室 UI（webclient 改造）

1. 新页/新模式 `Tools/webclient/static/`（如 `lab.html` 或 `?lab=1`）：
   - 左栏：174 技能，按职业分组（Warrior/Wizard/Taoist/Assassin/Archer），
     MIcon.Zl 图标 + 中文名（db_names）；显示 MagicInfo 字段（NeedLevel/Cost/Delay/描述）
   - 场景：现有四职业人物 + 摆 3~5 个木桩怪（webclient 已有怪物摆放）
   - 点技能 → 人物播施法动作（webclient 现有纸娃娃动画管线；动作分派可参考
     webport `anims.js`）→ 特效按 JSON 完整渲染：弹道（直线/抛物线/多线）飞向
     木桩、命中爆炸、地面/范围特效
   - 慢放（0.25×/0.5×）、逐帧步进、弹道轨迹叠层可视化
2. 特效渲染器目标结构对齐原版语义（cast/projectile/hit/aoe 四段），不要 webclient
   旧 render.js 的简化版——旧的可以留着给漫游模式，实验室用新引擎。

### P2 — 回归证据链

1. `Tools/magiclab/batch_run.mjs`（CDP 驱动，参考 webport 的 check-*-cdp.mjs 模式）：
   逐技能施放 → 截图 `docs/magiclab/gallery/<MagicType>.webp`
2. 基线 diff：像素/感知哈希对比上次画廊，报告 `docs/magiclab/REGRESSION.md`
3. 接入总纲方法论：改 JSON → 重生成 Godot 表 → 重跑画廊 → diff 全绿才算改完

### P3 — Godot 端闭环（跨仓改动，谨慎）

1. 生成器 `Tools/magiclab/gen_cs_table.py`：JSON → 重生成
   `GodotClient/Scripts/MagicEffectTable.cs`（保持现有代码结构与注释风格，
   只重生成数据部分）；或保守方案：JSON→C# 常量 diff 校验脚本（不重写文件，
   报不一致），先跑通校验再谈生成
2. 验证：`dotnet build GodotClient/ZirconClient.csproj`（Zircon 仓库根目录）通过
   + 无头 Godot（总纲 §4.4 配方）进游戏 GM 抽测 5 个技能截图对照实验室
3. Zircon 仓库改动遵循其 AGENTS.md（中文 commit、推 fork iamcheyan/Zircon）

### P4 — 伤害预览与编辑（二期，可独立 goal）

1. 实验室显示伤害公式预览：从 `ServerLibrary/Models/Magics/**` 提取每技能公式要点
   （基础/等级加成/元素），展示计算示例（只读）
2. 编辑走 dbeditor 管线（MagicInfo 字段，同总纲 §6 写库纪律），实验室提供
   "在 dbeditor 中打开此技能"跳转
3. 伤害数值最终以服务器为准——实验室是预览不是模拟器，界面上写明

## 4. 验收标准

- [ ] P0：`magic-effect-table.json` 覆盖原版 switch 全部 case；
      `GODOT_TABLE_DIFF.md` 产出（Godot 缺口清单）
- [ ] P1：实验室可点放 174 技能，人物动作+弹道+命中+范围四段齐全；
      慢放/逐帧/轨迹可视化可用
- [ ] P2：批量画廊 174 张 + diff 报告；故意改坏一个 JSON 条目能被 diff 抓到（自证有效）
- [ ] P3：生成/校验闭环跑通；Godot build 通过；游戏内 5 技能抽测对照一致
- [ ] 证据全部落 `docs/magiclab/`；新坑回写总纲 §3

## 5. 领地与协作

- 领地：`Tools/magiclab/`、`Tools/webclient/`（改造部分）、`docs/magiclab/`
- 跨领地：`GodotClient/Scripts/MagicEffectTable.cs`（P3，Zircon 仓库）——动手前
  在 tmux 声明；`Tools/webport` 只读（参考 anims.js）
- 与 E0-E3 无文件冲突；可并行
