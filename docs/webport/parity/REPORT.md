# webport 五路并行军团 总验收报告 (REPORT.md)

> 军团长 E 路 (par-keys) 出具 — 计划 §五: "五路全绿 + 军团长 E 合并出最终验证"。
> 基准 commit: `3c085e3` (2026-08-15 05:1x)。逐轮过程见 `LEAD_LOG.md` (R0-R13)。

## 一、五路终态

| 路 | tmux | 终态 | 证据 |
|---|---|---|---|
| A 移动手感 | par-move | **核心全绿**: 按住左键走/右键跑(2格/600ms Godot 节拍)/方向键/主面板开窗/Esc/聊天 (CDP 真服独立账号); P1+P2 NPC 14 种对话框全类型真实现+回包反馈+提交锁; PARITY_CHECKLIST **全表 ✅** (2026-08-15 定稿)。会话停在 recap 提示符 (待用户定夺真机对照或继续长尾) | `PARITY_CHECKLIST.md` + LEAD_LOG R0-R13 |
| B 动作系统 | par-anim | 已终态回收 (watchdog dd4a4b2): 17 MirAction→46 MirAnimation 全分派 + GetMagicAnimation 全表 + GM 号 10 技能实测证据 | LEAD_LOG R2/R4 |
| C HUD+聊天 | par-hud | 已终态回收: MainPanel/MiniMap/ChatTextBox/ChatLogPanel 逐方法 + 经验/等级/聊天解析 + 登录竞态修复 | LEAD_LOG R1/R4 |
| D 窗口系统 | par-win | 已终态回收: win-registry + 11 win-*.js 模块 (46 窗口体系骨干); 仲裁制品已按 R13 清理闭环 | LEAD_LOG R2/R7 |
| E 键位+军团长 | par-keys | **本报告** (见下) | `keys/` 全目录 |

## 二、E 路交付 (keybinds.js = KeyBindManager.cs 全量移植)

### 代码 (`Tools/webport/static/js/keybinds.js`)

- KeyBindAction 枚举 79 项 + 默认表 70 条 — 与 C# (GodotClient/Controls/KeyBindManager.cs:13-179) 逐条 1:1
- GetAction (:250-268, Key1/Key2 双键+修饰键) / NormalizeKey 小键盘归一 (:270-273)
- GetKeyBindLabel (:276-297) / GetKeyText C# ToString 域 (:299-316, Comma/Period/Scrolllock/Esc)
- Load/Save/ResetDefaults (:181-238) — localStorage `ZirconKeyBinds.ini`, 缺 section 跳过/缺字段保默认的 ConfigFile 语义
- Defaults 快照 + getBind() 重绑数据层 (KeyBindDialog.cs 数据侧等价); 模块加载即 Load() (GameScene.cs:919)
- 初版 (par-move) 70 条表经核对全对, 按"功能全为准"保留; 修复其 ACTION_NAMES 类型过滤反转 bug

### 验证 (三层, 全部可复跑)

1. **Manager 级** `scripts/check-keybinds.mjs`: 解析 KeyBindManager.cs 源码与 JS 逐条
   diff (C# 漂移即 fail) + 70 正例 + 280 修饰键负例 + 冲突键位语义 + 小键盘 + Key2 +
   持久化往返 = **557 断言全过** (每合并轮回归, R0-R13 零退化)。
   证据 `keys/verify-keybinds.txt`。
2. **浏览器模块级** (R1): 真 bundle 内 import → getAction/标签/localStorage 改绑往返全绿。
3. **CDP dispatch 级** `scripts/check-keybinds-cdp.mjs`: 独立账号注册→登录→建角→
   进比奇城真服, 对 70 条默认绑定逐键 CDP 派发 (含 Ctrl/Shift 掩码):
   - **70/70 按键, 0 页面异常** (最终轮)
   - **28/28 窗口类绑定 toggle ✓** (27 窗口键 + Escape→ExitDialog 单窗)
   - 42 非窗口键 (belt/spell/spellset/pickup/modes/itemlock) 空槽位静默 = Godot 语义
   - V/L HUD 可见性取反探针 ✓ (GameScene.cs:1891-1900)
   - 证据 `keys/cdp-dispatch-r3/r5/r7/final.txt` + 同名 matrix JSON

### 仲裁记录 (以 Godot 源码为准)

- **Escape 双段语义** (R0#1): Godot 仅 CloseTop() 成功才 return, 无窗时 Escape →
  ExitGameWindow → ExitDialog。web 初版无条件 return — 仲裁后 par-move 采纳 (4128435),
  CDP 终验: 无窗 Escape 恰好开 1 窗 ✓
- F12 环境性同构 (Godot 截做热重载/浏览器是开发者键) — 不改, 备案
- 聊天 HandleGlobalKey 优先于键位分发 — web 已同构
- QuestTrackerWindow/MapMiniWindow = HUD 可见性取反非开窗 (GameScene.cs:1891-1900)
  — par-move R6 依此实现, E 路 CDP 探针确认

## 三、军团长合并履历 (R0-R13, 22:19-05:16)

- 13 轮 20-30min 节奏: fetch/pull --rebase/push; **零 git 冲突** (文件边界纪律有效);
  共合并四路 33 commit (A:20+/B:3/C:4/D:2)
- index.html `?v=3→v4` (E 路入口); serve.py /static no-cache 佐证
- 交接闭环: dialogs.js/gamedata.js/uitree diff (R3 交接 → par-win 仲裁 → R13 清理)
- 交叉发现转办: data.js 启动竞态 (R5 转出 → par-move R9 修复 → E 路 0 异常终验)
- 环境事故协调: ServerCore 死亡螺旋由 A 路拉起 hub daemon `servercore-7k` 共用

## 四、结论与残留

**键位域 = 完成**: KeyBindManager.cs 全表移植 + 三层验证全绿 + 仲裁全闭环。
五路核心 CHECKLIST 全表 ✅ (P0 移动/HUD/聊天/键位 + P1 46 窗 + P2 NPC 全类型)。

残留 (非键位域, 供后续):
1. 重绑 UI (KeyBindDialog 网页版) 待 ConfigWindow 内接入 — keybinds.js 数据层已就绪
2. EI 参考模式 (双 UI) 未动 — scope 外
3. A 路长尾交互 (真机对照验收) 由用户定夺后续
