# LEAD_LOG — webport 五路并行军团长(E路 par-keys 兼)合并与进度日志

> 职责: 每 20-30 分钟 git pull --rebase 合并四路 commit; 冲突按 Godot 源码行为仲裁;
> index.html 版本号 bump; 记录各路进度。格式: 每轮一节, 倒序追加在本文件顶部读最方便,
> 但为 git diff 友好按时间正序追加在文件尾部。

---

## 2026-08-14 22:2x — R0 起步轮 (par-keys)

### E路职责1: keybinds.js 全表移植 — **完成**

- 基础: par-move 已提交未 commit 的 keybinds.js 初版(70 条默认表+getAction+label),
  与 KeyBindManager.cs 逐条核对**完全一致**, 按目标要求"以功能全为准"保留其表,
  补齐缺失的 Manager 层:
  - `load()/save()/resetDefaults()` — localStorage `ZirconKeyBinds.ini`
    (对照 C# ConfigFile user:// 语义: 缺 section 跳过、缺字段用当前值/默认值, C#:184-238)
  - Defaults 快照 + cloneBind (C#:181, 240-247); 模块加载即 load() (对照 GameScene.cs:919)

  - `getBind(action)` 重绑数据层 (KeyBindDialog.cs 直接改公有字段的 JS 等价)
  - getKeyText 修正为 C# ToString 域: `,`→Comma, `.`→Period, scrolllock→Scrolllock,
    null→None, Up/Down/Left/Right 显式映射
- 修复初版 bug: ACTION_NAMES 类型过滤反了(typeof 'string' → 'number'), 会导致
  load() 把所有 section 读成 undefined 键、互相覆盖。
- **验证**: `Tools/webport/scripts/check-keybinds.mjs` — 直接解析 KeyBindManager.cs
  的 enum+默认表与 JS 逐条 diff(C# 漂移即 fail), 逐绑定 GetAction 正例×70+负例×280、
  冲突键位语义(p/Ctrl+P 等 8 组)、小键盘归一(Kp4≡Digit4)、Key2 双键、
  持久化往返(改绑→save→新实例 load→resetDefaults)。**557 项断言全过**,
  证据 `docs/webport/parity/keys/verify-keybinds.txt`。
- game.js(par-move) 对 keybinds.js 的既有 import 不受影响(导出全集保留)。

### R0 补充 (~22:50) — 仲裁备忘 (源码依据 GameScene.cs _Input :9842-9916)

1. **Escape 语义**: Godot 是 `if (WindowManager.CloseTop()) { ...; return; }` — 只有
   真关掉窗口才 return; 无窗可关时 Escape 落到 GetAction → ExitGameWindow →
   OpenExitDialog。当前 web game.js #bindGlobalKeys 无条件 return, 无窗时 Esc
   无法打开退出对话框 → **par-move 仲裁点**: 去掉无条件 return, 让 Escape 继续
   走 getAction 分发。
2. **F12**: Godot 在 keybind 分发前截 F12 做 UI 热重载/截图, 默认键位 SpellUse12=F12
   不可达 (源码注释明说); 浏览器 F12 也是开发者工具键 → 环境性同构, 网页端不改。
3. **聊天优先**: HandleGlobalKey 先于 keybind 分发 — web 已实现 ✓ (game.js:234)。
4. **M/D/T 功能键**: 不走 KeyBindManager (GameScene.cs:9883-9898, 源码注释"避免改
   KeyBindManager 与他人冲突"), 属 A 路范围。
5. par-move 正在分解 game.js (650→248 行), handleKeyBind 暂时不存在于任何文件 —
   在制状态, 待其落地 input.js 后做 dispatch 级验证。

### 合并状态

- 工作区快照: master@0791190 与 origin 同步; 未提交 = par-move(game.js/world.js/
  mouse.js/gamedata.js) + par-win(windows.js/uitree.js?) 的在制品, **不代提交**。
- 四路 commit: 尚无(起步阶段)。index.html `main.js?v=3 → v=4`(E路 keybinds 入口)。

## 2026-08-14 23:0x — R1 合并轮 (par-keys)

### 新增 commit (3)

- `0ecc65e` par-hud [shared]: windows.js #refreshZ 语法修复 (R0 期间浏览器报的
  "Private field '#refreshZ' must be declared in an enclosing class" 根因, 已消)
- `6d434ae` par-anim [shared]: world.js 接线 anims.js 全动作分派
- `86a5788` par-hud: game.js UiScaleNow 导入 + chat.js 类字段私有语法修复

### 合并动作

- `git fetch` + `git pull --rebase`: origin 无新提交 (四路同树本地提交), 本地领先1
  (R0 备忘 commit) 已 push。无冲突。

### E路状态

- `check-keybinds.mjs` 回归: **557 项全过** (合并后无退化)。
- **浏览器内 E2E (真 bundle, :8823)**: keybinds.js 模块加载 ✓; enum 79 项 ✓;
  getAction: Q=CharacterWindow(4), Ctrl+P=AutoPotionWindow(11), Shift+F1=SpellUse13(67),
  Shift+小键盘4=UseBelt04(42) ✓; 标签 Ctrl+H / Comma ✓;
  **localStorage 改绑往返**: HelpWindow→Alt+F24 save→新实例命中→resetDefaults 恢复 H ✓。
- 客户端整体状态: 游戏场景已能完整加载 (道士255/比奇城/聊天公告全渲染)。
- **dispatch 级仍缺**: par-move 分解 game.js 后 handleKeyBind/getAction 尚未在新
  结构落地 — CDP 实测按 q 无反应。属 A 路在制, 继续等待, R0 仲裁备忘仍然有效。

## 2026-08-14 23:3x — R2 合并轮 (par-keys)

### 新增 commit (3)

- `338aaa1` par-anim: GM 号实测全技能施法动画证据 (10 技能×分派+特效截图)
- `0d78c66` mapviewer: 瓦片全量后台预生成 + 拖拽请求根治 + /api/maps 缓存
- `000ce70` par-win: 13 窗口模块全量落地 (win-registry + 11 个 win-*.js)

### 合并动作

- origin 无分叉; 本地领先已 push。无冲突。index.html 未 bump (v4 仍最新 —
  本轮合并不改 ESM 入口 URL; serve.py /static 本就 no-cache)。

### E路状态

- `check-keybinds.mjs` 回归: **557 项全过**。
- getAction 消费方仍缺: 全仓库无 import — par-move todo 明确列有
  "Keybind dispatch (HandleKeyBind port) into world" (其 phase I 0/4, 会话活跃,
  23:31 仍在跑 readiness probe), 不越权代写, 等 A 路落地后做 CDP 逐键验证。
- 窗口侧就绪: par-win 11 个 win-*.js 已入库, dispatch 一落地即可端到端逐键对照。


## 2026-08-14 23:5x — R3 轮 (par-move)

### A路 commit `4128435` — 移动/键位全链路 + 真机验收

- **mouse.js 入库** (关键: 之前 world.js `import './mouse.js'` 但文件未跟踪,
  clone 即断)。
- **net.js 枚举修正 (协议级 bug)**: NewCharacterResult `Success=10` (旧值 3 =
  BadGender!), NewAccountResult `Success=8/AlreadyExists=4`。现象: 服务端建角
  成功、客户端报"创建失败"。LoginResult 文案序同步 Enum.cs:2302。
- **world.js**: `lastKeyStep=0` 初始化 (未定义 → `NaN>600` 恒假 → 方向键死)。
- **game.js**: `#bindGlobalKeys` 完整 HandleKeyBind 分发 (70 键位: 窗口表 ×27/
  SpellUse01-24/SpellSet01-04/UseBelt01-10/ItemPickUp/Mount/ChangeAttackMode×5/
  ChangePetMode×5/AutoRun/ChangeChatMode/ToggleItemLock/TradeRequest/
  PartnerTeleport/GroupAllowSwitch/GroupTarget/TradeAllowSwitch; Escape=CloseTop
  语义按 R0 备忘 #1)。**E路 getAction 现已有消费方** — 请 E 路跑 dispatch 级
  CDP 逐键回归。
- **game.js 交互根因修复**: hudLayer `isControl:true` → 全屏 pointer-events 拦截
  + elementFromPoint 恒命中 → 鼠标移动/点击全灭。改 false (Godot 根层
  MouseFilter.IGNORE 语义)。MiniMap 入 WindowManager (Esc/M 可关)。
- **game.js 并发编辑抢救**: 本轮 par-move 会话期间 game.js 被 3 次并发重写丢
  import (World/net.js/keybinds) 与文件尾 (addChat/dispose/`}`), 均已恢复。
  **请各路重写 game.js 前先 `git pull` + 整文件读写后跑 `node --check`。**
- ws.js: sendItemLock/sendMailOpened 补齐, sendLogout 恢复 (被 auto-repair 误删)。

### 验收证据 (CDP chromium + ServerCore:7000/wsgateway:7001 真服)

独立账号 (避开共享 test@test.com 的 `[Account in Use]` 争用): 注册→登录→建角
(枚举修正后)→进比奇城, 全链路 0 页面异常:

| 用例 | 结果 |
|---|---|
| 按住左键 2.5s | 走 6 格 PASS |
| 按住右键 1.8s ×3 方向 | 跑 6 格/次 = 2格/600ms Godot 节拍 PASS |
| 方向键右 1.2s | 4 格 PASS |
| 主面板角色键开窗 → Esc | visible 1→0 PASS |
| Enter 聚焦/发送聊天 | 回显 PASS |

已知残留 (非 A 路): 聊天本地显示两行、其中一行名字重复 (chat.js/game.js 双渲染,
 待 par-hud 查); ServerCore 启动期 ~11s 才回 GoodVersion, 登录需等 DB 就绪。

### 环境事故记录

- 23:0x ServerCore (pid 1029909) 80% CPU 死亡螺旋, 23:2x 由 par-move 经 hub
  拉起 **servercore-7k** (hub daemon, cwd=zircon/Debug/ServerCore) — 目前稳定
  在跑, 各路共用, 勿重复起服。
- 346MB 内存 chromium ×多路并发 CDP 时注意: spawn 的 chrome 要显式 kill,
  否则进程组回收时挂起 bash 调用 300s。

### A路未提交在制品 (par-win 吸收或删, 不代提交)

- `dialogs.js` (34KB, 未跟踪): 15 个 par-win 未覆盖窗口的接线草稿
  (belt/currency/autopotion/filterdrop/fortune/questtracker/dungeonfinder/
  companion/gamestore/bigmap/mail/ranking/help/chatoptions/menu/exit),
  基于旧 uitree DXItemCell + gamedata.js API — 与 dxgrid/itemstore 不兼容,
  建议按 win-*.js 模式重写吸收, 或确认无用后删除。
- `gamedata.js` (未跟踪): GameData 状态镜像, 已被 itemstore.js 取代 → 可删。
- `uitree.js` 未提交 diff (+136 行): A路的 DXItemCell graft, 仅 dialogs.js 用。
  par-win 已有 dxgrid.js 版本 — 若吸收 dialogs.js 则一并重写, 否则还原该 diff。

### R3 续 (~00:1x) — installWindows 断线修复 (commit 5501777)

- **根因**: par-win 的 `installWindows` 全仓库无调用方 — 11 个 win-*.js 从未加载,
  一切开窗走 fallback。game.js 构造即 `installWindows(this)`, #openWindow 改
  async 等安装完再决定接管/兜底。
- CDP 复验: 主面板 9/9 按钮开真窗+Esc 关; 键位 W/N/Z 与默认表一致; 方向键 4 向
  4 格/1.4s。**E 路: dispatch 已可端到端逐键回归。**
- 详表: `docs/webport/parity/PARITY_CHECKLIST.md` (P0 达成; P1 余 ~15 窗待
  par-win 吸收 dialogs.js 草稿; BuffDialog/QuestTracker/聊天双行=已知缺口)。
## 2026-08-15 00:1x — R3 合并轮 (par-keys)

### 新增 commit (5)

- `ebc8066` [shared] world.js 聊天聚焦时不驱动移动 / `24c74c9` par-hud 登录竞态+小地图轮询
- `10378b2` mapviewer 快池钳制 / **`4128435` par-move 移动/键位全链路+真机验收**
  (mouse.js 入库; net.js NewCharacterResult/NewAccountResult 枚举协议级修正;
  world.js lastKeyStep 初始化; **game.js #bindGlobalKeys 完整 HandleKeyBind 分发,
  Escape=CloseTop 语义采纳 R0 仲裁#1**)
- `945f4c7` par-move 在 LEAD_LOG 交接: dialogs.js(34KB 未跟踪,15窗口草稿)/
  gamedata.js(已被 itemstore.js 取代,可删)/uitree.js diff(+136 行) → **par-win 仲裁**

### 合并动作

- origin 无分叉; 本地领先 3 已 push。无冲突, index.html 不需 bump
  (路由改动均在 ESM 内部, serve.py /static no-cache)。

### E路 dispatch 级逐键回归 — **全绿** (新脚本 check-keybinds-cdp.mjs)

独立账号注册→登录→建角→进比奇城真服全链路后, 对 keybinds.js 全部 70 条默认绑定
逐个 CDP Input.dispatchKeyEvent (含 Ctrl/Shift 修饰键掩码):

- **70/70 按键分发, 0 页面异常**
- **28/28 窗口类绑定全部开窗且二次按键关闭 (toggle✓)** — 27 个窗口键 + Escape
  (ExitGameWindow); 含 Ctrl+P/C/F/R/B/O 修饰键组合、`,`/`.` 标点键
- Escape 无窗可关时打开 ExitDialog — **R0 仲裁#1 行为确认落地**
- 非窗口类 42 键 (UseBelt×10/SpellUse×24/SpellSet×4/ItemPickUp/
  ChangeAttackMode/ChangePetMode/ToggleItemLock): 无窗口变化、无异常 —
  新号空 belt/无技能, 与 Godot 空槽位静默语义一致; 键→action 匹配已由
  check-keybinds.mjs 557 断言覆盖。
- 证据: `docs/webport/parity/keys/cdp-dispatch-r3.txt` + `cdp-matrix-r3.json`

### E路职责1 状态: **dispatch 级验证完成** (manager 级 R1 完成, browser 级 R1 完成)

残留: 重绑 UI (KeyBindDialog 网页版) 属 par-win ConfigWindow 范围, keybinds.js
数据层 (getBind/mutate/save/resetDefaults) 已就绪待接。

## 2026-08-15 00:3x — R4 合并轮 (par-keys)

### 新增 commit (1)

- `dd4a4b2` watchdog: parity 会话修正为 par-move, 注册 par-keys, 移除
  par-anim/par-hud → **B/C/D 三路已终态回收**, 存活: par-move(A) + par-keys(E)。

### 合并动作

- 无冲突; 领先1已 push。check-keybinds.mjs 回归 557 全过。

### 局势

- par-move 剩余: MiniMap/BuffDialog/QuestTracker + ChatLogPanel/ChatTextBox 全量
  + P1 Windows×5 (其在制, 会话活跃)。等 A 路终态后做五路总验收 (REPORT.md,
  计划§五: 军团长 E 合并出最终验证)。

## R5 — par-move (A路): 聊天双渲染修复 + BuffDialog + QuestTracker

- `聊天双渲染根因` world.js:718 与 game.js #wireNet 双监听 'chat'。手术: world 只留
  头顶气泡副作用 (o.chatText/chatUntil), 日志归 game.js 唯一路径 + overheadOnly
  guard (GameScene.cs:2538)。CDP: 一次 sendChat delta=1。
- `发现` "Name: Name: text" 双名是 Godot 原版行为: 服务端 PlayerObject.cs:1808
  已把 Name 拼进 Text, Godot OnChat (GameScene.cs:2536) 再拼 sender — 网页与原版
  结构一致, 非 bug。中文 label 空是 MsgTypeName[0]='' 本地化选择。
- `BuffDialog` (BuffDialog.cs:15-120) hud.js: buffAdd/Remove/Time/Paused 全接线,
  过滤 Ranking/Developer, 剩余时间降序, 27px 栅格≤6列, Pause=IndianRed,
  <10s 白→CadetBlue 渐变, 锚小地图左侧+LayoutNeeded 重锚。CBIcon webres 未导出
  →着色瓦片暂代 (首字+title 提示), 后续 webres 补 CBIcon 库可直换 DXImageControl。
- `QuestTracker` hud.js: itemStore.quests (QuestChanged/Cancelled 维护) +
  gamedb QuestInfo 名称, 完成✓前缀, 点击切换追踪 localStorage 持久, 锚小地图下方;
  itemStore.on() 订阅变更重绘 (observers 是 Set, 勿 push)。
- `CDP 验收` pmv-buff-qt.mjs (独立新号注册→建角→进图): 9 键 PASS×, KeyW/N/Z
  开窗 PASS, BuffDialog visible@[759,0], QuestTracker 注入任务 rows=[任务#9001,
  ✓任务#9002], 0 页面异常。
- `坑` game.js 尾部曾被并发重写打断成 class 提前闭合 (#receiveChat 变悬空 private
  field → 全站白屏)。修复后 node --check 放过 (script vs module 差异), ESM 语法
  验收必须 cp 到 /tmp/*.mjs 再 --check。已修: 149/150 行双闭合。
- `提交` 聊天/Buff/QuestTracker 三件套 + checklist 3 行 ✅。uitree.js(M) 是
  par-win 的 DXItemCell graft, dialogs.js/gamedata.js 未跟踪, 归 par-win 仲裁不变。
