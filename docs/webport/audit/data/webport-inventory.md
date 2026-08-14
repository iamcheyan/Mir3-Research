# webport 实现清单（网页客户端 vs Godot 一致性审计底稿）

- 调查日期 2026-08-14；只读调查 `Tools/webport/`，行号以当日工作区为准。
- 路径约定：`js/*` = `Tools/webport/static/js/*`；`themes/zircon|ei` = `js/themes/*`。
- 运行形态：FastAPI `:8823`（serve.py:186-188 `uvicorn.run(..., port=8823)`），静态挂载 `/static`（serve.py:184）；游戏连接 `ws://<host>:7001`（wsgateway，js/ws.js:9-10）。
- 架构：`main.js` 场景流转（Login→Select→Game，main.js:26-64）→ 动态 import 主题（`themes/zircon` 主线 = DXControl DOM 移植 dx.js；`themes/ei` 参考 = 纯 CSS 面板）→ 共享逻辑层 `ws.js/net.js/data.js/res.js/camera.js/world.js`。世界逻辑全在 `world.js`（自 GameScene.cs 移植），主题只做 HUD 外观。

---

## 1. 实现范围清单（三场景 + HUD）

### 1.1 Login 场景（zircon: themes/zircon/login.js；ei: themes/ei/login.js）

| 控件/交互 | 状态 | 证据 |
|---|---|---|
| 背景 Interface1c[20] + 4 组循环动画(2200/2400/2300/2500) + logo 22/23 | ✅ | zircon/login.js:24-62 |
| 登录框 Interface[151]（尺寸异步定位底部居中） | ✅ | zircon/login.js:56-62 |
| 邮箱/密码输入框 | ✅ | zircon/login.js:65-68（DXTextInput） |
| 登录/退出/注册新账号/修改密码/排行榜/选项/激活账号 按钮 | ✅（后四者点击仅 setStatus 提示“网页版暂未实现”） | zircon/login.js:80-108、136-140、89-103、125 |
| 忘记密码（Label 可点，提示未实现） | ⚠️占位 | zircon/login.js:117-126 |
| 记住账号 checkbox + 回填 | ✅ | zircon/login.js:129-133、149-153 |
| 状态文本 Label | ✅ | zircon/login.js:143-147 |
| 密码框 Enter 登录 | ✅ | zircon/login.js:183-186；ei/login.js:66 |
| 登录协议 C_LOGIN(182)/S_LOGIN(183) | ✅ | net.js:26-27；ws.js:101-105 |
| 按钮启用门控：握手 versionOK 前登录/注册禁用 | ✅ | zircon/login.js:167-171；ei/login.js:73-77 |
| 断线处理（disconnected/serverDisconnect → 状态文本+禁用按钮） | ✅ | zircon/login.js:174-181 |

### 1.2 Select 场景（zircon: themes/zircon/select.js；ei: themes/ei/select.js）

| 控件/交互 | 状态 | 证据 |
|---|---|---|
| 背景 Interface1c[50] + 左右光晕动画(2800/2900) | ✅ | zircon/select.js:52-67 |
| 角色 intro/idle 动画 + overlay(index+100/+130) 跟随 | ✅ | zircon/select.js:10-18（INTRO_TABLE）、69-88、322-339、341-364 |
| 角色列表（≤4 行，职业图标 Interface[27+class]，名字/职业/等级/所在地） | ✅ | zircon/select.js:243-284、254-257 |
| 选中态（backColour/border 内联样式变化，默认自动选 0 号） | ✅ | zircon/select.js:309-319、281 |
| 所在地中文地名（maps_manifest.json id→name_cn 异步回填） | ✅ | zircon/select.js:286-306 |
| 进入游戏/创建角色/删除角色按钮 | ✅ | zircon/select.js:98-115 |
| 删除角色：原生 `confirm()` 弹窗（自动化需处理 dialog）；EI 模式无 confirm | ⚠️ | zircon/select.js:418-422；ei/select.js:177-180 |
| 创建面板：职业×4/性别×2（Interface1c 图标按钮）、名字输入（默认 'TestHero'）、预览动画、创建/取消 | ✅ | zircon/select.js:124-219、391-397 |
| 新建/删除角色协议 + 结果处理 | ✅ | net.js:278-279 C/S_NEWCHARACTER、67-68 DELETE；zircon/select.js:399-431 |
| STARTGAME_DELAYED(2) 3 秒自动重试 | ✅ | zircon/select.js:443-448；ei/select.js:193-199 |
| 进入游戏 C_STARTGAME(349)/S_STARTGAME(348) → startInformation | ✅ | net.js:28-29；zircon/select.js:432-452 |

### 1.3 Game 场景（world.js + themes/*/game.js）

| 能力 | 状态 | 证据 |
|---|---|---|
| MapIndex→地图 stem（maps_manifest id 反查）、walk 位图加载 | ✅ | world.js:37-43；data.js:124-133 |
| 对象表维护（ObjectPlayer/Monster/NPC/Remove/Move/Turn/userLocation） | ✅ | world.js:70-105、130-148 |
| 换图（S_MAPCHANGED → 重载 walk/清对象/提示） | ✅ | world.js:99-106；ws.js:126 |
| 相机 lerp(0.25) 跟随 + 512px 瓦片按需渲染 | ✅ | world.js:235-238；camera.js:89-146；TILE=512 data.js:11 |
| 渲染循环 rAF（_frame） | ✅ | world.js:214-246 |
| 移动输入（键盘+点击） | ✅（见 §3） | world.js:149-232 |
| 聊天收发 | ✅（见 §9） | world.js:96-102、212 |
| 光照 | ⚠️简化（见 §8） | world.js:114-128、240-245 |

### 1.4 HUD（MainPanel）

**Zircon 模式**（themes/zircon/game.js，GameInter 贴图）：
- 主面板 GameInter[50]，底部居中（36-43，对照 MainPanel.cs:31-34）。
- HP 条：GameInter[52] fill 图 `<img>` 宽度百分比（46、#bar 119-140、setBarPct 141-143）；MP 条 GameInter[54]（47）。**初始恒 100%**，无真实数值更新（114-116 注释 “Phase2 StatsUpdate 接入”）。
- 经验条：GameInter[51] 仅贴图、无数值（49-52）。
- **九宫按钮 ✅ 存在但为占位**：角色/背包/技能/任务/邮件/药品/组队/菜单/商城 = GameInter[82,87,92,112,97,107,102,117,122]，XS=[650,689,728,767,806,845,884,923,972]，点击仅 `addChat('xx窗口: Phase 3 点亮')`（55-66）。
- 聊天记录面板 400×150（主面板上方 -29）+ 输入框 400×25 + “喊话”频道按钮占位（68-105）。
- 坐标调试 Label（地图名+格坐标，107-112、142-144）。

**EI 模式**（themes/ei/game.js）：顶栏（品牌/地图名 #eig-map/坐标 #eig-pos，50-54）；HP/MP 圆球 `.ei-orb`（62-64，fill height 百分比，初始 100%）；**HP/MP 文本恒 “HP —/MP —”**——读的是 `this.info?.hp/mp`，而 startInformation 字段实为 `currentHP/currentMP`（ei/game.js:109-110 vs net.js:320-322，字段名错位 bug）；6 格腰带占位 “空”（61、74-80）；聊天区（57-59）。

### 1.5 逐项功能结论

| 功能 | 结论 | 证据 |
|---|---|---|
| 聊天（显示+发送） | ✅ | world.js:96-102、212；zircon/game.js:97-105；ei/game.js:85-99 |
| 聊天频道切换 | ❌ 占位（“喊话”按钮仅提示） | zircon/game.js:89-94 |
| 背包 | ❌（九宫按钮 Phase 3 提示） | zircon/game.js:55-66 |
| 技能 | ❌ 同上 | 同上 |
| 任务/邮件/药品/组队/菜单/商城 | ❌ 同上 | 同上 |
| NPC 对话 | ❌（ObjectNPC 仅入对象表渲染，无点击交互） | world.js:95-99；全文无 NPC 点击处理 |
| 小地图/大地图 | ❌（js 目录无任何 minimap 相关代码） | — |
| 攻击 | ❌（无攻击包、无攻击键，见 §3） | net.js:23-40 |
| 走路 | ✅（键盘节拍+点击一步） | world.js:218-232、158-171 |
| 跑步 | ❌（running 动画表已定义未用；move distance 恒 1） | data.js:17；world.js:205 |
| 自身血条 | ⚠️ UI 存在但恒 100% | zircon/game.js:114-116 |
| 怪物/他人血条 | ❌ | world.js:248-281（无 hp 渲染） |
| 掉落物 | ❌（S_OBJECTITEM id=293 已知未监听） | net.js:39；ws.js:66-135 无 case |

---

## 2. DOM 驱动选择器速查表（浏览器自动化）

### 2.0 全局骨架（两模式通用）

| 目标 | 选择器 | 证据 |
|---|---|---|
| 页面容器 | `#viewport` | static/index.html:12 |
| 场景挂载点 | `#stage` | index.html:13；main.js:7、26-28 |
| 当前 UI 模式 | `body[data-uimode="zircon"]` / `body[data-uimode="ei"]` | main.js:16；css/style.css:66-69 |
| 游戏中标记 | `body.ingame` | main.js:61；style.css:44-48 |
| 模式切换按钮（右上角） | `#mode-switcher`（button，文本=当前模式名） | shell.js:7-9；style.css:#mode-switcher |
| 模式菜单 | `#mode-menu`，项 `.mode-item`，当前项 `.mode-item.active`；点击后 `location.reload()` | shell.js:12-29 |
| 调试入口 | `window.__WEBPORT` → `{conn, current, log, mode}`；`window.__D()` 数据清单 | main.js:80-85；data.js:56 |
| 场景阶段 | `__WEBPORT.conn.stage` ∈ `none|login|select|game` | ws.js:31；main.js:39/49/60 附近赋值 |

### 2.1 Zircon 模式 DX 控件 DOM 规则（先读这个再用选择器）

- 一切 DX 控件都是 `div.dxctl`，`el.__ctl` 反查控件实例（dx.js:28-31）。
- 图片控件追加 `.dximg`（dx.js:94）；文本 `.dxlabel`（180）；按钮 `.dxbtn`，其内文字在 `span.dxbtn-label`（220、233-235）。按钮点击走原生 click 事件（dx.js:231）。
- DXTextInput = `.dxctl > input[type=text|password]`，**无 id**（dx.js:267-285）。
- DXCheckBox **不是原生 input**：span 勾选框 + 文本 span，click 切换（dx.js:288-310）。
- 按钮“禁用”= 灰度滤镜，判定用 `el.__ctl.enabled`（dx.js:159-162）；disabled 状态点击无效果。

通用文本按钮查找（zircon 全场景可用）：
```js
const dxbtn = (t) => [...document.querySelectorAll('#stage .dxbtn')]
  .find(b => b.querySelector('.dxbtn-label')?.textContent === t);   // 返回 div.dxbtn
```

### 2.2 Zircon 登录页

| 元素 | 选择器 | 证据 |
|---|---|---|
| 邮箱输入 | `#stage input[type="text"]`（本场景唯一 text 输入） | zircon/login.js:65 |
| 密码输入 | `#stage input[type="password"]` | zircon/login.js:66 |
| 登录按钮 | `dxbtn('登录')`；Playwright: `#stage .dxbtn:has(.dxbtn-label:text-is("登录"))` | zircon/login.js:80-83 |
| 退出按钮 | `dxbtn('退出')`（点击=断线+整页 reload） | zircon/login.js:84-88 |
| 注册按钮 | `dxbtn('注册新账号')`（用当前邮箱/密码直接发注册包） | zircon/login.js:96-99、206-210 |
| 排行榜/选项/修改密码/激活账号 | `dxbtn('排行榜')`/`dxbtn('选项')`/`dxbtn('修改密码')`/`dxbtn('激活账号')`（均仅提示） | zircon/login.js:89-95、100-103、136-140 |
| 忘记密码 | `[...document.querySelectorAll('#stage .dxlabel')].find(e => e.textContent === '忘记密码')`（可点） | zircon/login.js:117-126 |
| 记住账号 | `[...document.querySelectorAll('#stage .dxctl')].find(e => e.textContent === '记住账号')`；状态读 `el.__ctl.checked` | zircon/login.js:129-133；dx.js:288-310 |
| 状态文本 | `__WEBPORT.current.statusText`（或含“正在连接”的 `.dxlabel`） | zircon/login.js:143-147、19 |
| 登录按钮可用 | `dxbtn('登录').__ctl.enabled === true`（versionOK 后才 true） | zircon/login.js:167-171 |

### 2.3 Zircon 选人页

| 元素 | 选择器 | 证据 |
|---|---|---|
| 角色行（第 i 个） | `__WEBPORT.current.charButtons[i].el`；DOM 等价 `#stage .dxbtn` 中含 64×64 职业图标(`.dximg`)者，按列表顺序 | zircon/select.js:248-274 |
| 选中角色索引 | `__WEBPORT.current.selectedIndex`（权威；DOM 无 class 标记，仅内联背景色 rgb(71,36,36) 选中 / rgb(24,12,12) 未选） | zircon/select.js:309-318 |
| 进入游戏按钮 | `dxbtn('进入游戏')` | zircon/select.js:98-102 |
| 创建角色按钮 | `dxbtn('创建角色')`（点击切换到创建面板） | zircon/select.js:103-107、372-377 |
| 删除角色按钮 | `dxbtn('删除角色')`（触发原生 `confirm()`，自动化需 dialog 处理） | zircon/select.js:108-112、418-422 |
| 创建面板名字输入 | `#stage input[type="text"]`（创建面板打开时场景唯一，默认值 TestHero） | zircon/select.js:204 |
| 职业选择 | `dxbtn('战士'|'法师'|'道士'|'刺客')`（选中态换贴图 index） | zircon/select.js:146-156、369-371 |
| 性别选择 | `dxbtn('男')` / `dxbtn('女')` | zircon/select.js:165-174、369-371 |
| 确认创建 | `dxbtn('创建')` | zircon/select.js:209-212 |
| 取消创建 | `dxbtn('')`（空文本按钮，Interface[15] 叉号） | zircon/select.js:213-216 |
| 面板可见性 | `__WEBPORT.current.panel.el.style.visibility` / `createPanel.el.style.visibility` | zircon/select.js:372-377；dx.js visible setter |

### 2.4 Zircon 游戏页

| 元素 | 选择器 | 证据 |
|---|---|---|
| 世界画布 | `#stage canvas`（无 id；点击走路监听挂在其 mousedown） | zircon/game.js:14-16；world.js:158 |
| HUD 容器 | `#stage` 的最后一个子 div（`mountScene(root)` 后 `appendChild(hud)`） | main.js:62-63 |
| 聊天输入 | `#stage input[type="text"]` 或 `__WEBPORT.current.chatInput.input` | zircon/game.js:95 |
| 聊天发送 | 无按钮，Enter 发送 / Esc 失焦 | zircon/game.js:97-105 |
| 频道按钮 | `dxbtn('喊话')`（占位） | zircon/game.js:89-94 |
| 九宫按钮（顺序：角色,背包,技能,任务,邮件,药品,组队,菜单,商城） | `[...__WEBPORT.current.mainPanel.el.children].filter(el => el.classList.contains('dximg') && el.style.pointerEvents === 'auto')` | zircon/game.js:55-66 |
| HP/MP 条 fill | `__WEBPORT.current.healthFill.el` / `.manaFill.el`（img 元素，宽度=百分比） | zircon/game.js:46-47、119-140 |
| 经验条 | mainPanel 内 GameInter[51] 的 `.dximg`（无 pointer-events） | zircon/game.js:49-52 |
| 坐标/地图名 | `__WEBPORT.current.posLabel.text` | zircon/game.js:107-112、142-144 |
| 玩家格坐标 | `__WEBPORT.current.player.x / .y`（world 代理字段） | zircon/game.js:25-30 |
| 移动门控 | `__WEBPORT.current.moveLock`（true=等服务器确认） | zircon/game.js:25-30；world.js:201 |

### 2.5 EI 模式（原生 id，直接 querySelector）

| 场景 | 元素 | 选择器 | 证据 |
|---|---|---|---|
| 登录 | 邮箱 | `#ei-email` | ei/login.js:40 |
| 登录 | 密码 | `#ei-pw`（type=password） | ei/login.js:41 |
| 登录 | 登录按钮 | `#ei-login`（原生 button，握手前 `disabled`） | ei/login.js:46、73-77 |
| 登录 | 注册按钮 | `#ei-register` | ei/login.js:45 |
| 登录 | 记住账号 | `#ei-remember`（原生 checkbox） | ei/login.js:43、57 |
| 登录 | 状态文本 | `#ei-status` | ei/login.js:48 |
| 选人 | 角色列表 | `#ei-char-list`；行 `.ei-char`，选中行 `.ei-char.selected`；行内 `.cls`（职业）/`.lvl`（等级）/`.loc`（所在地） | ei/select.js:46、14-19、139-140 |
| 选人 | 进入游戏 | `#ei-start` | ei/select.js:48 |
| 选人 | 打开创建 | `#ei-create-open` | ei/select.js:49 |
| 选人 | 删除角色 | `#ei-delete`（无 confirm） | ei/select.js:50、177-180 |
| 选人 | 创建面板 | `.ei-create`（打开加 `.open`）；名字 `#ei-new-name`；职业 `input[name="ei-cls"]`（radio value 0-3）；性别 `input[name="ei-gender"]`（0/1）；确认 `#ei-create-ok`；取消 `#ei-create-cancel`；状态 `#ei-create-status` | ei/select.js:54-83 |
| 游戏 | 画布 | `#eig-canvas` | ei/game.js:56、68 |
| 游戏 | 地图名/坐标 | `#eig-map` / `#eig-pos` | ei/game.js:52-53 |
| 游戏 | 聊天记录 | `#eig-chatlog`（行 class `.sys`/`.hint`） | ei/game.js:58、124-131 |
| 游戏 | 聊天输入 | `#eig-chatin` | ei/game.js:59 |
| 游戏 | HP/MP 球 | `.ei-orb.hp .fill` / `.ei-orb.mp .fill`（height 百分比）；文本 `#eig-hp` / `#eig-mp`（恒 “—”，见 §1.4） | ei/game.js:62-64、109-110 |
| 游戏 | 腰带格 | `.ei-belt-slot`（6 个，文本“空”） | ei/game.js:61、74-80 |

### 2.6 场景判定（自动化流程状态机）

- 权威：`__WEBPORT.conn.stage`（ws.js:31）。
- DOM 兜底：zircon 三场景分别以 `#stage input[type="password"]`（登录）、`.dxbtn` 含“进入游戏”（选人）、`#stage canvas`（游戏）为特征；EI 用 `#ei-email` / `#ei-char-list` / `#eig-canvas`。
- 点移动自动化：对 `#stage canvas`（zircon）或 `#eig-canvas`（EI）dispatch `mousedown`，world.js:158-163 用 `ev.clientX/clientY` 经 `camera.screenToWorld` 换算格坐标（zoom 恒 1，world.js:23、29；CELL_W=48 CELL_H=32 data.js:12）。

---

## 3. 走路输入

- **键盘**：方向键 + WASD 均可。`world.js:225-228`：`arrowup/w → dy=-1`、`arrowdown/s → dy=1`、`arrowleft/a → dx=-1`、`arrowright/d → dx=1`（键名统一小写存入 `this.keys`，world.js:151-156）。
- **步频/节拍**：600ms/步（对照 MouseWalker.cs:56）。`_frame` 每帧检查 `now - lastKeyStep > 600 && !moveLock` 才 `#tryMove`（world.js:218-232，节拍常量在 221/229）。**无跑步**：distance 恒 1（world.js:205），running 动画表未用（data.js:17）。
- **点击移动**：canvas `mousedown` → `screenToWorld` → 目标格 → `#stepTowards`（world.js:158-164）。**注意：每次点击只走一格**——`#stepTowards` 用 `Math.sign(tx-p.x)` 取方向走一步（166-171），无寻路/无连续走。遇阻挡时 `#tryMove` 尝试 [原方向, 纯横, 纯纵] 绕行（BestWalkDirection 近似，world.js:185-197），可走性查 walk 位图（data.js:135-139，位图来自 `/res/walk/{stem}.bin` zlib inflate，data.js:124-133）。
- **移动门控（ServerTime 门控移植）**：`#sendMove` 置 `moveLock=true` + 本地预测位移（world.js:200-205，对照 GameScene.cs:7854-7905）；S_OBJECTMOVE 自身包确认解锁（world.js:159-166 中 self 分支）；S_USERLOCATION 权威纠正亦解锁（world.js:86-93）；5 秒兜底解锁（world.js:206-208）。
- **攻击键**：**未实现**。无攻击包（net.js ID 表 23-40 无攻击类），world.js 无攻击输入；combat2/struck/die 动画帧表已定义但零调用（data.js:18-20）。`conn.sendTurn`（C_TURN 372）已封装但无任何 UI 调用（ws.js:167，全目录无 caller）。

---

## 4. 键盘事件监听全集

| # | 监听位置 | 键 | 行为 | 证据 |
|---|---|---|---|---|
| 1 | window keydown/keyup（World） | 全部键（小写存 set；仅消费 arrow×4 + wasd） | 走路输入集合 | world.js:152-156、223-228 |
| 2 | window keydown（main.js） | F5（仅 `body.ingame`） | `preventDefault()` 防误刷新断线 | main.js:74-78 |
| 3 | window keydown **捕获阶段**（EI 游戏） | Enter（聊天框未聚焦时） | `preventDefault()` + 聚焦聊天输入 | ei/game.js:94-99（第三参 `true`） |
| 4 | 密码框 keydown | Enter | 登录（按钮可用时） | zircon/login.js:183-186；ei/login.js:66 |
| 5 | 聊天输入 keydown | Enter 发送 / Escape 失焦 | zircon/game.js:97-105；ei/game.js:85-92 |

偏差提醒（审计/自动化都要注意）：
- **zircon 聊天打字会走路**：chatInput 的 keydown 未对方向键 stopPropagation（zircon/game.js:97 只处理 Enter/Esc），而 World 的 window keydown 无“输入框聚焦”判断（world.js:152）→ 中文输入/打 WASD 时角色同时移动。EI 无此问题（ei/game.js:86 对一切键 `ev.stopPropagation()`）。
- EI 模式游戏内任意 Enter 都会抢占聚焦聊天（捕获监听）。
- 无 Tab 切换/背包技能快捷键（Godot hotkey 体系未移植）。

---

## 5. 贴图服务（/res/sprites）

### 5.1 HTTP 路由（serve.py）
- `GET /res/sprites/{lib}/{frame}.webp`（serve.py:152-169）：磁盘有则直出；缺失时 `webres.extract_frame(lib, int(frame))` 按需抽取（锁 `_frame_lock`）；WebData > 3G 时 507（serve.py:161-162）。frame 必须纯数字（serve.py:156）。
- `GET /res/sprites/{lib}/manifest.json`（serve.py:171-183）：缺失时 `webres.cmd_manifest` 生成。
- 其他：`/res/data/*`（94-101）、`/res/walk/{stem}.bin`（104-109）、`/res/maps/{stem}/{tx}_{ty}.webp` 512px 瓦片按需渲染（115-149）、`/ui/{name}.json` 转发 GodotClient/UI（84-92）、`/api/disk`（77-81）。

### 5.2 manifest 结构与取帧 API（skin.js / res.js）
- manifest = 对象 `{帧号: [w, h, ox, oy]}`（skin.js:10-14；res.js:59-70）。ox/oy 为帧左上相对锚点偏移（与 Zl OffSetX/Y 同源，sprites.js:6-8）。
- `skin.frame(lib, idx)`（UI 控件用）：返回 `{url:'/res/sprites/{lib}/{idx}.webp', w, h, ox, oy}`，Map 缓存，缺图返回 null 控件静默跳过（skin.js:17-29）；`skin.cached(lib, idx)` 同步取缓存（skin.js:31）。DXImageControl 将其转成 CSS `background-image`（含 useOffSet→backgroundPosition、blend→mixBlendMode:screen，dx.js:104-130）。
- `res.loadSprite(lib, frame)`（canvas 世界渲染用）：`new Image()` + LRU 4000（res.js:9-37）；URL 由 `spriteURL()` 拼 `/res/sprites/{lib}/{frame}.webp`（res.js:42）。缺帧 resolve(null) 不阻塞（res.js:33）。

### 5.3 三大 UI 库的用法
| 库 | 用途 | 关键帧号 | 证据 |
|---|---|---|---|
| Interface | 通用 UI 件 | 登录框 151；按钮三拼片 16(左)/18(中)/17(右)；窗口九宫 0-9,126；关闭钮 15；职业图标 27-30；注册/修改密码钮 152；排行/选项钮 153 | zircon/login.js:57、96-103；dx.js:246-248、321-341；zircon/select.js:255、213-216 |
| Interface1c | 登录/选人大图 | 登录 bg 20、logo 22/23、登录动画 2200/2300/2400/2500；选人 bg 50、光晕 2800/2900、职业/性别钮 110-136（选中 -1）、角色动画 240-2000（INTRO_TABLE）、overlay=基础+100/+130、建角预览 300-2000 | zircon/login.js:24-50；zircon/select.js:10-24、52-88、146-173、349-350 |
| GameInter | 游戏 HUD | 主面板 50、经验条 51、HP fill 52、MP fill 54、九宫钮 82/87/92/112/97/107/102/117/122 | zircon/game.js:36-66 |

世界对象库：NPC 固定 `'NPC'` 库（world.js:261）；怪物库 = monsters.json 的 `mon.lib`（world.js:265-267）；玩家 body/weapon 库 = `data.pickLibs()` 查 appearance.json（data.js:91-121）。

### 5.4 帧号 → 文件名公式（文件名就是帧号整数本身）
- 基式：`drawFrame = frameIdx + anim.start + dir*10`（data.js:59-61；动画表 PLAYER_ANIMS/MONSTER_ANIMS data.js:14-27；站立 standing(0,4)/走路(80,6)/跑步(160,6)/combat2(640,5)/struck(1840,3)/die(1920,10)）。
- 玩家纸娃娃（data.js:63-79 注释 + playerFrames；sprites.js:51-73 完整实现）：
  - body = base + (armourShape%11)×off + shift，off=5000（刺客 3000），shift=armourShift（刺客 walking/running +1600、struck -640、die -400，data.js:63-66）
  - weapon = base + (weaponShape%10)×5000，weaponShape≥1000 时先 -1000
  - hair = base + (hairType-1)×5000；helmet = base + ((helmetShape-1)%10)×off + shift
- 怪物：`monsterFrame = shape*1000 + drawFrame`（data.js:81-84，对照 ObjectRenderer.cs）。
- NPC：`npcFrame = image*100 + frameIdx`（data.js:86-88，无方向偏移）。
- 最终 URL：`/res/sprites/{lib}/{帧号}.webp`（skin.js:23；res.js:42）。
- **实现偏差**：world.js `#drawPlayer`（288-301）只用 `base = dir*10`（standing frame 0），**未叠加** armour/weapon/hair 偏移（armourShape 仅影响 pickLibs 选库）；装备/发型不会反映在帧号上。sprites.js 的完整纸娃娃管线（playerSprites/drawPlayer 含前后武器分层）**全目录无 import，是未接线代码**（grep 验证：仅 world.js:283 注释提及）。

---

## 6. 日志 / 调试

- **协议包日志常开、无开关**：`ws.js #trace`（36-40）→ `console.log('[net] <msg>')`，同时写入环形缓冲 `conn.log`（上限 200 条，37-38）。时间戳格式 `HH:MM:SS.mmm`（toISOString 截取，ws.js:37）。
- 会上控制台的包事件：`WS open <url>`（49）、`G.Connected → 回显`（75）、`G.GoodVersion db=<版本>`（82）、`G.Disconnect reason=<n>`（96）、`S.Login result=<n> chars=<n>`（103）、`S.StartGame result=<n>`（122）、`未处理包 id=<n> (<名>) <n>B`（137）、`包解析失败 id=… <错误>`（142，单包失败不断流）。
- 脚本侧读取：`__WEBPORT.log`（=conn.log，main.js:83）；`__WEBPORT.conn`（发包/状态）、`__WEBPORT.current`（当前场景实例）、`__WEBPORT.mode`；数据清单 `__D()`（data.js:56）。
- 其他控制台输出：`console.error('网关连接失败')`+alert（main.js:33-35）；`console.error('未知 MapIndex')`（world.js:40）；`console.warn('创建失败')`/`console.warn('进入游戏失败')`（zircon/select.js:411、449）。EI 模式无额外日志。

---

## 7. world.js 对象渲染 vs Godot ObjectRenderer

已实现（world.js:248-301）：
- 玩家（self/其他玩家）：body + weapon 两层（weapon 仅当 `o.weapon≠0`），standing frame 0（297-300）。
- 怪物：`mon.lib` + `monsterFrame(shape,'standing',0,dir)`（264-269）。
- NPC：`'NPC'` 库 + `npcFrame(image,0)`（258-263）。
- 名字：canvas 文本，黑色 1px 偏移描边，self=#8cf 其他=#fff，y-26（271-279）。
- y 排序（252）、视野剔除 ±14 格 x / ±12 格 y（250-251）、底中锚定绘制（#blit：`sx-w/2, sy-h+16`，283-286）。

未实现（对照 ObjectRenderer / 已解析但未用的字段 net.js:395-424）：
- 走路/跑步/攻击/受击/死亡动画（恒 standing frame 0；动画表 data.js:14-27 仅 standing 被用）。
- **血条**（任何对象都没有；ObjectPlayer/Monster 的 hp 相关与 dead/poison/buffs 字段已解析未渲染，grep 无 hp/health/dead/poison 渲染代码）。
- hair/helmet/shield/costume 层；前后武器方向分层（sprites.js:60-66 有 backDirs=[0,5,6,7]/frontDirs=[1,2,3,4] 实现但未接线）。
- caption/公会名/名字颜色（nameColour 已解析未用）、聊天气泡（S.Chat 只进聊天框，world.js:96-102）、宠物/坐骑（horse/horseShape）、per-object 光（light 字段）、掉落物（S_OBJECTITEM 无监听）、体型（sizePercent）。
- 逐帧 ox/oy 锚点：world.js 不读 manifest 偏移，用图像原始尺寸底中近似（283-285）；Godot DrawLayer 用 OffSetX/Y（sprites.js:29-36 有实现未用）。
- 帧号偏差：见 §5.4（玩家帧未叠外观偏移）。

---

## 8. 光照 #applyLight

- 实现位置：world.js:118-128（`#applyLight`），应用在 `_frame`：对象画完后以全屏 `rgba(0,0,0,lightAlpha)` 覆盖（world.js:240-245，世界之上 UI 之下）。
- 公式：`NIGHT=0.25, TWILIGHT=100/255`（对照 MapLightLayer.cs:15-16）；`setting = mapMeta.light ?? 'Default'`；Light→ambient=1，Night→0.25，Twilight→100/255，**Default→ambient = clamp(dayTime, 0.25, 1)**；`lightAlpha = 1 - ambient`（118-127）。
- dayTime 来源：初始 = startInformation.dayTime（float，net.js:330 readStartInformation；world.js:120 兜底 `?? 1`）；运行时 = S_DAYCHANGED(66) → ws.js:127 emit `'dayTime'` → world.js:107-110 clamp 0..1 后重算。
- 已知偏差（代码自述）：无 .map 逐格光/物体径向光（webres 未导出 light 数据），仅全局环境光乘法近似（world.js:114-117 注释）。

---

## 9. 聊天实现

- **已实现（收+发）**。收：S_CHAT(39) → ws.js:134 → world.js:96-102（对象名前缀拼接）→ `hooks.onChat` → 两主题聊天框。发：C_CHAT(76) `conn.sendChat`（ws.js:169；world.js:212）。
- 输入框位置：**zircon** — 主面板正上方 400×25 chatBox，内含 “喊话” 按钮(60×24) + DXTextInput 275×23（zircon/game.js:81-105）；Enter 发送并 blur、Escape blur（97-105）。**EI** — 左下 `.ei-chat` 区，`#eig-chatin`（placeholder “回车发言 / Esc 收起”，maxlength 200，ei/game.js:58-59），Enter/Esc（85-92），任意 Enter 捕获聚焦（94-99）。
- 显示：zircon 保留 250 行内存 / DOM 12 行，hint/system 金色 #ffd573（zircon/game.js:147-156）；EI 250/80 行 + 自动滚动，class `.sys` 绿 `.hint` 金（ei/game.js:124-131）。
- 未实现：频道切换（“喊话”按钮占位，zircon/game.js:89-94）；S.Chat 的 `type` 字段已解析（net.js:464）但 UI 不区分频道着色（只区分本地 hint/system）。

---

## 10. 账号记忆 / 注册 / 模式切换（localStorage 全表）

| key | 写入点 | 含义 | 证据 |
|---|---|---|---|
| `webport_uimode` | shell.js 切换菜单（`zircon`\|`ei`，非法值回落 zircon） | UI 参考模式，切换后整页 reload | mode.js:5-13；shell.js:18-25 |
| `webport_checksum` | 首次连接生成 20 位 hex 随机指纹（对照 user://checksum.bin） | C_Login/NewAccount/Delete 等包的 checkSum 字段 | ws.js:12-21、160-165 |
| `webport_remember` | 登录时勾选 `记住账号` → `'1'`；取消则三个 key 全删 | 记住账号开关 | zircon/login.js:194-201；ei/login.js:90-98 |
| `webport_email` / `webport_password` | 同上（**密码明文存储**），回填于两模式登录框 | 账号回填 | zircon/login.js:149-153、196-197；ei/login.js:59-63、91-93 |

- 注册：**无独立注册页**。两模式都是登录页 “注册新账号/注册” 按钮直接拿当前输入的邮箱+密码发 C_NEWACCOUNT(278)（zircon/login.js:206-210；ei/login.js:102-106）；`C.NewAccount` 固定 `realName='Player'、birthDate=0、referral=''`（net.js:383-386）。结果经 S_NEWACCOUNT(277) 显示在状态栏（zircon/login.js:157-163）。
- 模式切换 UI：`#mode-switcher`（两模式常驻右上角）→ `#mode-menu` → `.mode-item` 点击 → 写 `webport_uimode` → `location.reload()`（shell.js:5-30）；`body[data-uimode]` 属性在 loadTheme 时设置（main.js:14-16）。

---

## 附：审计可直接引用的已知偏差汇总
1. sprites.js 完整纸娃娃/锚点管线未被任何模块引用（死代码），world.js 用简化版 #drawPlayer（§5.4/§7）。
2. 玩家帧未叠 armour/weapon/hair 帧偏移，仅换库（world.js:288-301）。
3. 无对象血条、无走路动画、无攻击体系（§1.5/§3/§7）。
4. 光照只有全局环境光，无逐格/径向光（§8）。
5. 点击移动每次只走一格，无寻路（§3）。
6. zircon 聊天输入打字会触发走路（§4）。
7. EI 模式 HP/MP 文本字段名错位恒显 “—”（§1.4）。
8. 自身 HP/MP 条恒 100%，经验条无数值（§1.4）。
9. 删除角色 zircon 用原生 confirm、EI 无确认（§1.2）。
10. `conn.sendTurn`（C_TURN）已封装无调用方（§3）。
