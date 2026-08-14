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

## R6 — par-move (A路): P1 剩余 11 窗 fallbackWindow 真实现 + questtracker 键语义修正

- `缺口` WIN 表 27 键映射的窗口类型中 11 个走 fallbackWindow 空壳 (help/dungeonfinder/
  autopotion/currency/filterdrop/fortune/ranking/companion/chatoptions/exit + bigmap
  旧实现仅图)。dialogs.js 草稿是旧 gamedata.js 世代, 直接接线会与 par-win 11 模块
  冲突 → 决策: 在 fallbackWindow 内补真实现 (数据源全部用现行 itemstore/gamedb/
  conn 事件), dialogs.js 保持未跟踪待 par-win 仲裁。
- `实现` hud.js fallbackWindow +9 case + ranking 空态修正; gamedb.js +3 helper
  (currencyList/companionList/instanceList); game.js: QuestTrackerWindow 从 WIN 表
  移出 → #toggleQuestTracker() 可见性取反 (GameScene.cs:1898 语义, 非 WindowManager)。
- `协议对照` C.RankRequest(cls,onlineOnly,startIndex) Godot 默认 RequiredClass.None=0
  (ServerConnection.cs:1077); S.Rankings.ranks (非 rankings); Companion 领养=
  sendCompanionAdopt(index,name)。
- `CDP 验收` pmv-buff-qt.mjs (独立新号): 12/12 窗 vis=true 且内容非空 — help=键位表
  (1144字), currency=Gold/GameGold..., companion=Pig 500000 等 10 行, chatoptions=
  9 频道开关, exit=确认框, ranking=(服务器 total:0 → 空态文案), dungeonfinder=
  (InstanceInfo db 0 行 → 空态), KeyL toggle true/restored true。前置每窗 Esc 清场
  (否则 closeTop 抢走 exit 的 Escape — 测试序列问题非产品 bug)。
- `数据现状` InstanceInfo workspace 表 0 行 (dbeditor 快照如此), 副本窗显示空态为真。

## R7 — par-move (A路): P0 残留 🟡 三项 CDP 清零

- `小地图 3 悬停按钮` (MiniMapDialog.cs:89-117): mouseenter 显示 Size(132)/
  Transparency(130)/BigMap(137), mouseleave 隐藏 — CDP shown[3×true]/hidden[3×false];
  Size 点击 200→300→200 (getAcceptableResize 150-300 clamp); Transparency 窗级
  Opacity ''→0.5 (Godot ToggleTransparency 447-452 同款窗级, 非 image 级); BigMap
  开窗 vis=true。
- `聊天频道循环` (ChatTextBox.cs:73-77): cycleMode ×6 = 普通|私聊|编组|行会|喊话|
  全局 循环回到起点; ChangeChatMode 键 (game.js:351) 接线在位。
- `聊天历史 ↑↓ + 草稿` (ChatTextBox.cs:25/62-70): ↑ 取最新→次新, ↓ 回退, 半句
  输入后 ↑↓↓ 精确恢复草稿 — CDP 全 PASS。
- `回归` check-keybinds.mjs 557 断言全过 (WIN 表改动后); pmv-buff-qt 全链路
  (9键+11窗+KeyL+聊天) 单脚本全绿。

## 2026-08-15 01:1x — R5 合并轮 (par-keys)

### 新增 commit (3, 全部 par-move)

- `8553410` R5: 聊天双渲染修复 + BuffDialog + QuestTracker
- `bc14aab` R6: P1 剩余 11 窗真实现 + QuestTrackerWindow 键语义
  (GameScene.cs:1898 可见性取反, 非开窗 — 与本日志 R0 备忘#5 同源)
- `c663e83` R7: P0 残留三项 CDP 清零 (小地图3钮/频道循环/历史草稿)

### E路 dispatch 级逐键回归 v2 — **全绿** (快照口径修正后重跑)

修正了 R3 版测量口径的两处缺陷 (自误非客户端误): DXControl.visible 用
`style.visibility` 而非 display; BuffDialog/QuestTracker/MiniMap 在 Godot 是
_uiLayer 普通子节点 (GameScene.cs:4284-4296), 不入 WindowManager, Escape 不关它们。
修正后 (账号 pkmst5f4mg, 真服):

- **70/70 按键, 28 窗口类绑定全部 toggle✓** (27 窗口键 + Escape→ExitDialog),
  42 非窗口键 (belt/spell/spellset/pickup/modes/itemlock) 无异常静默 (空槽位语义)
- **Escape 无窗时恰好开 1 个窗 (ExitDialog)** — R0 仲裁#1 终确认
- **HUD 开关探针**: V→miniMap.visible 取反 ✓, L→questTracker.visible 取反 ✓
  (初始 true, 对照 ClientSettings.QuestTrackerVisible 默认)
- 证据: `keys/cdp-dispatch-r5.txt` + `keys/cdp-matrix-r5.json`

### 交叉发现 (转 A 路/shared)

- 启动竞态 1 例: `TypeError: null.tables @ data.js:92 pickLibs ←
  PlayerObject.refreshLibs (world.js)` — 建号进图瞬间 data.js 表未就绪即被
  PlayerObject 消费。不影响按键链路 (70 键照常), 但建议 data.js 加就绪门闩。

### 未提交在制品 (持续跟踪, R3 起归 par-win 仲裁)

- uitree.js 未提交 diff (+136); dialogs.js(34KB)/gamedata.js 未跟踪。

## R8 — par-move (A路): 移动残留 🟡 三项 CDP 清零 → CHECKLIST 全 ✅

- `Shift 原地攻击门控` (mouse.js tick: d.shift() 检查): shiftHeld=true + 左键按住
  2.2s 驱动 tick → 坐标 moved:false。
- `预测跳格` (world.stepMove): stepMove(0,1,false) 调用瞬间本地 y-2 (153,234)→
  (153,232), 不等服务器; server-lock 5s 超时+ObjectMove 解锁在位。
- `撞墙绕路` (#bestWalkDirection, MouseWalker.cs:250-266): 出生点开阔 → 半径 60
  螺旋扫描找墙 (blocked=[-1,0]), 鼠标指向墙 tick 1.5s, 走访格逐格校验 walkable
  全过, crossedWall=false。
- `键位 70 键 CDP 回归` check-keybinds-cdp.mjs 复跑: 70/70 dispatch 0 页面异常,
  toggle 69/70 — 唯一 ExitGameWindow escape "fail" 是套件顺序伪影 (前窗未关,
  Escape 被 closeTop 语义消费 = Godot 9864 同款行为; 单测 R6 已证无窗时正常开
  退出框)。
- `CHECKLIST 状态` 全表 ✅ (P0 移动×8/HUD×6/聊天×4/协议×5/键位×10 + P1 46 窗)。
  dialogs.js/gamedata.js 未跟踪草稿归 par-win 仲裁 (仅 belt 细化吸收价值)。

## R9 — par-move (A路): data.js 启动竞态修复 (par-keys R5 转办)

- `竞态` 建号进图瞬间 ObjectPlayer 包先于 appearance.json 就绪 → pickLibs 读
  Data.appearance.tables 抛 TypeError (data.js:92)。修两层:
  1) data.pickLibs 就绪门闩 — appearance 未载入返回 null-libs 骨架 (渲染层
     `if (!lib) continue` 已 null-safe, 玩家先无名壳后补图层);
  2) world.#enterWorld loadAll 后对 objects 全量 refreshLibs 重解析。
- `验收` check-keybinds-cdp v2: 70/70 toggleOk (含 ExitGameWindow — 上一轮
  "fail" 是套件顺序伪影), exceptions=[]; 全链路新号注册→进图 0 异常
  (pmv-move-edge 复跑)。

## R10 — par-move (A路): Login 场景 5 按钮 "暂未实现" 清零 (铁律违规)

- `发现` login.js 4 处 onClick + 忘记密码 = setStatus('xx: 网页版暂未实现') — 违反
  冲刺铁律 1 (禁止"暂未实现"按钮)。Godot LoginScene.cs 全有真实现:
  排行榜→RankingDialog+SendRankings(:281-286), 选项→ConfigDialog(:522),
  修改密码/忘记密码/激活→C.ChangePassword/RequestPasswordReset/Activation 系
  (ServerConnection.cs:897-905, LoginScene.cs:51-55)。
- `协议` net.js +5 builder (ClientPackets.cs:17-49 字段序), ws.js +5 sender +5
  result 监听 (ServerPackets.cs:18-60: ChangePassword/RequestPasswordReset 带
  message+duration, RequestActivationKey 带 duration, 其余仅 result byte)。
- `实现` login.js: #toggleLoginRanking (窗口+rankings 事件渲染+SendRankings
  RequiredClass.None), #toggleLoginOptions (UI 缩放持久), #promptChangePassword/
  PasswordReset/Activation (prompt 链→真包→结果事件改状态行)。
- `CDP 验收` pmv-login-btns.mjs: 排行榜开窗渲染"(暂无上榜角色)"(服务器 total:0
  真响应); 选项缩放 1.25 持久; 修改密码 prompt×3→包发出→服务器回 result:4
  (WrongPassword — 假旧密码, 枚举语义正确); 忘记密码/激活 prompt→包发出;
  0 页面异常。

## 2026-08-15 01:4x — R6 合并轮 (par-keys)

### 新增 commit (4, 全部 par-move)

- `fa5cb30` R8: 移动残留清零, CHECKLIST 全 ✅
- `a5e9f58` R9: **data.js 启动竞态修复** (pickLibs 门闩 + loadAll 后重解析,
  即 R5 转交的交叉发现), 70 键 CDP 复测全绿
- `285413b` R10: Login 5 按钮真实现, "暂未实现"清零
- `d522807`: PARITY_CHECKLIST 结论定稿 — **全表 ✅ (P0+P1 46 窗)**

### E路终态回归 (合并后 master)

- manager 级: 557/557 ✓
- CDP dispatch 级 (独立新账号, 真服): 70 键 / 28 窗口 toggle 全✓ /
  **0 页面异常 (竞态修复生效)** / Escape 无窗→恰好 1 个 ExitDialog /
  V·L HUD 取反 ✓。证据 `keys/cdp-dispatch-final.txt` + `cdp-matrix-final.json`。

### 局势

- A 路 (par-move) CHECKLIST 定稿全✅, 会话仍在做最终复核 (mailbox render/compose)。
  待其终态后: E 路写总验收 `docs/webport/parity/REPORT.md` (计划§五) 并收官。

## R11 — par-move (A路): Mail 窗升级真邮箱 + MailSend BigInt 修复

- `mail` fallback 从"好友列表只读"升级为真邮箱 (CommunicationDialog 语义):
  S.MailList/MailNew/mailDelete 事件驱动列表 (未读●/金币/附件标记), 点击阅读
  → C.MailOpened, 右键删除 → C.MailDelete, 写邮件 prompt 链 → C.MailSend。
- `协议 bug` net.js MailSend gold 参数 int64(BigInt64Array) 传 Number 抛
  "Cannot convert 0 to a BigInt" — 包从未发出。修: BigInt(gold) 归一。
  字段序对照 ClientPackets.cs:505-512 (Links/Recipient/Subject/Message/Gold) ✓。
- `CDP 验收` pmv-buff-qt: 注入 mailList 渲染 ●/金币 100/附物品 全显; 写邮件
  handler 触发 composeSent:true (真包出站), 0 异常。

## R12 — par-move (A路): BuffDialog 真图标 (CBIcons.Zl) 替换着色瓦片

- `发现` CBIcons.Zl webres 其实已导出 (WebData/sprites/CBIcons/ 200 帧, 所需
  24 帧全在) — R5 当时误判"未导出"(curl 的是 CBIcon 无 s 库名)。serve.py
  /res/sprites/CBIcons/{frame}.webp 200 OK。
- `实现` buff-icons.js: GetBuffIcon switch 表照抄 (BuffDialog.cs:144-220:
  Castle=242/Observable=172/Heal=78/MagicShield=100/Partner=137/...兜底 73);
  BuffDialog 渲染 img.pixelated + CSS filter 模拟 SelfModulate (Pause=
  sepia红, <10s=hue-rotate/saturate 蓝渐变, 永久=原色)。
- `CDP 验收` 注入 4 buff: srcs=[100,137,78,229] 与 switch 表逐项吻合, 剩余
  时间降序排列, pause 红/<10s 蓝滤镜生效, visible ✓。

## R13 — par-move (A路): par-win 仲裁遗留制品清理 (终态收尾)

- `仲裁执行` LEAD_LOG R3 登记的 dialogs.js(34KB)/gamedata.js 未跟踪草稿
  归 par-win 仲裁 ("吸收进 win-*.js 模式或删"); par-win goal 已终态且无人
  认领 → 吸收已完备 (win-*.js 11 模块 + fallbackWindow 12 窗 + itemstore/
  gamedb/dxgrid 全覆盖, DXItemCell 正典在 dxgrid.js:250, win-*.js 只用
  uitree 的 getWindow) → 删两草稿 + revert uitree.js 未提交的 +136 行
  DXItemCell graft (孤儿重复实现, 唯一消费者是 dialogs.js)。
- `验收` 清理后全链路 CDP 复跑: 9 键 PASS / Buff 图标 srcs 吻合 / 邮箱
  compose 真包 / 11 窗全开 — 无任何模块引用被删文件, 0 异常。
- `仓库状态` Tools/webport/static/js/ 下无未跟踪/未提交 JS; 冲刺工作区干净。

## 2026-08-15 02:1x — R7 合并轮 (par-keys)

### 新增 commit (4, par-move R11-R13)

- `5fa4e0f` R11: Mail 真邮箱 (列表/阅读/删除/撰写) + MailSend BigInt 修复
- `cc0cb9d`+`b3d4148` R12: BuffDialog 真图标 (CBIcons.Zl + GetBuffIcon switch 表)
- `007815a` R13: **par-win 仲裁制品清理落地** — dialogs.js/gamedata.js 删除,
  uitree graft 还原 (R3 起跟踪的三件交接全部闭环, webport 工作区归零)

### E路回归

- 557 manager 断言 ✓; CDP 70 键: 28/28 toggle, 0 异常, Escape→1 窗 ✓
  (`keys/cdp-dispatch-r7.txt`)。工作区首次完全干净。

### 局势

- A 路收尾动作明显 (仲裁清理+图标+邮箱), 等终态 → REPORT.md 总验收。

## R14 — par-move (A路): P2 寄售行 ConsignmentDialog (最后长尾窗)

- `缺口` Consignment (摆摊/寄售) 无任何 UI: Godot 经 NPC 页 DialogType=
  Consignment → OpenConsignmentDialog (NPCDialog.cs:116, GameScene.cs:628),
  web 侧 win-npc showPage 未路由 dtype 19。
- `实现` win-consign.js (新模块, 单例语义=GameScene._consignmentDialog):
  两页 — 搜索购买 (C.MarketPlaceSearch → S.results 渲染, 点击 prompt 数量
  → C.MarketPlaceBuy) / 我的寄售 (S.MarketPlaceConsign 列表, 右键下架 →
  C.MarketPlaceCancelConsign, 寄售背包首格 prompt 价格 → C.MarketPlaceConsign
  cellLink{GridType,Slot,Count})。win-npc showPage +dtype===19 路由。
- `CDP 验收` winConsign 开窗: 搜索页注入 2 结果 → 行渲染 "x3 5,000 金"/
  "x1 120,000 金"; 切我的寄售页 → 注入 consignments 渲染 "我的寄售 1 件";
  0 异常。(探针断言曾用 '5000' 对 '5,000' toLocaleString — 测量口径问题)

## R15 — par-move (A路): NPC 精炼取回面板 (RefineRetrieve, dtype 4)

- `对照` NPCAdvancedPanels.cs:190-192 Configure→BuildRetrieve (:518-527):
  列表 491x302 + 刷新按钮(RequestNPCRefineList) + 取回选中; SetRefineList
  (GameScene.cs:2776 OnRefineList → NPCDialog)。
- `协议` net.js +NPCRefineRetrieve builder (ClientPackets.cs:328 {Index}),
  ws.js +sendNPCRefineRetrieve; S.RefineList 监听已有 (readClientRefineInfo:
  index/weapon/type/quality/chance/maxChance/ReadyDuration)。
- `实现` win-npc.js retrievePanel (列表+刷新+取回选中, 选中高亮), showPage
  dtype===4 显隐 + renderRetrieve; w.addControl 挂载。
- `CDP 验收` 注入 refineList 2 条 → 行渲染 "80/100"/"50/100"+品质; 点击行选中;
  取回选中按钮 → 真包出站 (packetSent:true); 0 异常。
