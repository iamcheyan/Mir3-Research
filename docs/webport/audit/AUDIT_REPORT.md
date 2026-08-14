# 网页客户端 vs Godot 客户端 像素级一致性深度审计报告

> 审计日期：2026-08-14 · 审计人：omp goal（WEBPORT_AUDIT_GOAL.md）
> 对象：webport `http://127.0.0.1:8823/`（Zircon 模式，默认）vs Godot 客户端 `~/development/zircon/GodotClient`（Xvfb :100 无头真跑）
> 纪律：只查不改——webport 代码零改动；ServerCore/wsgateway/serve.py 全程保持运行。
> 证据：截图对 `docs/webport/audit/screenshots/`（9 场景 × godot/web/diff）、DOM/包日志/资源数据 `docs/webport/audit/data/`。

---

## 一、执行摘要

| 类别 | 总数 | 达标 | 一致率 |
|---|---|---|---|
| 像素（全屏逐对） | 8 对可比 | 0 对 <15% | **31.4%**（1−平均差 68.6%） |
| 结构（控件坐标/帧号） | 43 项可比 | 39 项逐像素吻合 | **90.7%** |
| 行为（已实现功能逐项） | 14 项可比 | 5 项一致 | **35.7%** |
| 资源（抽帧 53） | 49 帧可比 | 49 帧 PSNR=∞ | **100%**（可比帧；含缺帧/缺 manifest 综合达标率 79.3%） |

**总体判断**：webport 已实现部分（登录页/选人页/HUD 静态布局）与 Godot **坐标/帧号级一致**（结构 90.7%），贴图质量无损级；但 (1) 全屏像素差被两端异步动画与色调差异放大到 C 级；(2) **发送聊天即被服务器断线**（C.Chat 缺字段，P0）；(3) 游戏内窗口系统（45/46 窗口）、战斗、对象动画完全未实现——按纪律计入「未实现清单」不扣差异分，但它们是「零差异」目标的主要剩余工作量。

**方法学纠偏**（对照任务书的两个预期偏差，源码为证）：
1. 本代码库**没有服务器列表步骤**：`C.Login`→`S.Login` 直接携带角色列表（`LibraryCore/Network/ServerPackets.cs:25-44`；`LoginScene.cs:181-186` 登录成功直接切 SelectScene）。任务书的「服务器列表」场景不存在，已从场景表移除。
2. 没有 `C.Walk/C.Run`：统一 `C.Move{Direction,Distance}`（`ClientPackets.cs:99-103`），Distance=1 走、≥2 跑；NPC 对话包是 `C.NPCCall`（`ClientPackets.cs:243-246`）。

---

## 二、逐场景差异表

评级公式（任务书 §三.2）：S=<1% 像素差+0 结构差 / A=<5% / B=<15% / C=≥15%。
「静态区差%」为剔除循环动画/世界动态后的可比区域（登录对话框/角色列表面板/HUD 主面板），用于归因。

| # | 场景 | 截图对 | 全屏像素差% | 静态区差% | 结构差 | 行为差 | 评级 |
|---|---|---|---|---|---|---|---|
| 01 | 登录页 | 01_login | 39.61 | 44.5（对话框区，纹理/字体 AA 级） | 2 | 1 | C |
| 02 | 选人页 | 02_select | 60.45 | 82.5（角色面板，预览动画相位+纹理） | 0 | 0 | C |
| 03 | 进比奇（基础） | 03_game_base | 71.88 | 67.2（HUD 区：HP 假满条+FocusBar 缺+色调） | 4 | 3 | C |
| 04 | 走路 | 04_walk | 70.64 | 67.2（同 HUD 基线） | — | 0（600ms/步一致） | C |
| 05 | 开背包(W) | 05_inventory | 79.19 | 69.0（web 无变化=差） | 1（窗口缺失） | 1 | C |
| 06 | 开技能(E) | 06_magic | 78.90 | 69.0 | 1 | 1 | C |
| 07 | 小地图(V) | 07_minimap | 77.22 | 69.0 | 1 | 1 | C |
| 08 | 攻击(Shift+点) | 08_attack | 70.96 | 68.8 | 0 | 1 | C |
| 09 | 聊天（web 侧取证） | 09_chat | n/a | n/a | 2 | 2（P0） | C |
| — | 服务器列表 | 不存在 | 任务书场景在本代码库无对应物（见 §一 纠偏 1） | | | | — |
| — | NPC 对话 | 未取得 | 双端视野内均无 NPC 对象同步（见 §四 B-11 取证限制）；web 端未实现 | | | | — |

场景量化明细（MAD=256×192 降采样平均绝对差 / r=相关系数）见 `data/pixel-diff.json`；diff 标注图 `screenshots/{场景}_diff.png`。
噪声说明：两端各自跑 4 组登录循环动画、角色预览动画、世界昼夜光照与对象漂移（两次截图非同一次会话，玩家出生/离线点不同），全屏差% 下限即被抬高——**全屏 C 级 ≠ 布局错误**；布局正确性以结构对比（§三）为准。

---

## 三、结构差异全清单（B 节：UI 树/DOM 逐项）

方法：Godot 侧 = 源码布局常量（LoginScene.cs/SelectScene.cs/MainPanel.cs/GameScene.cs LayoutHud）+ `ui_tree.json`（2026-08-14 18:42 重导出，46 窗口/441 控件）；Web 侧 = 同状态 DOM `getBoundingClientRect` 全量 dump（`data/web-dom-{login,select,game}.json`）。逐项对表：

### 3.1 登录页（16 项可比，14 项逐像素吻合）

| 控件 | Godot（源码引用） | Web（实测 DOM） | 结论 |
|---|---|---|---|
| 背景 Interface1c[20] 1024×768 | (0,0) LoginScene.cs:379-385 | (0,0,1024,768) bg=Interface1c/20 | ✅ |
| 4 组登录动画 2200/2400/2300/2500 | LoginScene.cs:386-389 | 帧 2281/2418/2324/2508（动画中段帧） | ✅ |
| logo 底 Interface1c[23] | (230,25) :390-395 | (230,25,496,244) | ✅ |
| logo Interface1c[22] 564×300 | (−35,−35)+父=(195,−10) :396-404 | (195,−10,564,300) | ✅ |
| 主框 Interface[151] | (120,644) 784×104（(1024−784)/2, 768−104−20）:408-421 | (120,644,784,104) | ✅ |
| 邮箱输入 | (70,65)+框=(190,**709**) 170×14 :433-437 | (190,**716**) 170×14 | ❌ **+7px 垂直偏移** |
| 密码输入 | (357,65)+框=(477,**709**) :438-442 | (477,**716**) | ❌ **+7px 垂直偏移**（含 input 元素内 +2px 基线偏移，dx.js 输入控件基线差异） |
| 登录/退出按钮 | (550,60)/(660,60)+框=(670/780,704) 100×24 :468-469 | (670,704,100,24)/(780,704,100,24) | ✅ |
| 排行榜/选项 | (20/93,0)+框=(140/213,644) 68×32 :471-472 | (140,644,68,32)/(213,644,68,32) | ✅ |
| 注册新账号/修改密码 | (485/625,0)+框=(605/745,644) 136×32 :473-474 | (605,644,136,32)/(745,644,136,32) | ✅ |
| 忘记密码 label | (640,38)+框=(760,682) :510 | (760,682,100,16) | ✅ |
| 记住账号 checkbox | (490,38)+框=(610,682) :514-516 | 文本 span (626,687,48,17) | ⚠️ +16/+5px（LabelBoxPadding 近似差异） |
| 激活账号按钮 | (20,36)+框=(140,680) 72×20 :520 | (140,680,72,20) | ✅ |
| 状态 label | (20,84)+框=(140,728) 500×36 :524 | (140,728,500,36) | ✅ |
| 标题提示 | (280,38)+框=(400,682) 220×18 :424-430 | (400,682,220,18) | ✅ |

### 3.2 选人页（13 项可比，全部吻合）

| 控件 | Godot | Web | 结论 |
|---|---|---|---|
| 背景 Interface1c[50] / 光晕 2800/2900 | SelectScene.cs 背景组 | bg=Interface1c/50、2804/2904 | ✅ |
| 列表面板 Interface[8] | (96,171) 320×425 | (96,171,320,425) | ✅ |
| 角色行 i=0 | 面板+(20,45+i·78) 280×75 :203-208 | (116,216,280,75) | ✅ |
| 职业图标 Interface[27+Class] | 行+(6,4) 64×64 :209-216 | (122,220,64,64) img=Interface/29（27+2 道士） | ✅ |
| 名字/职业/等级/所在地 label 组 | 行+(77,7)/(135,8)/(77,29)/(135,28)/(235,28)/(77,51)/(135,48) :217-223 | (193,223)/(251,224)/(193,245)/(251,244)/(351,244)/(193,267)/(251,264) | ✅ 全对 |
| 进入/创建/删除按钮 | 面板底部 :445-453 | (121/216/311,553,80,24) | ✅ |
| 创建面板（职业 4 钮 Interface1c/120-136、性别 115/111、预览 304、名字输入、创建钮、关闭 Interface/15） | :124-219 | (382,59,260,650) 及子件齐备 | ✅ |

### 3.3 游戏内 HUD（17 项可比，13 项吻合，2 缺失，2 多余）

| 控件 | Godot（MainPanel.cs / GameScene.cs LayoutHud:4713-4730） | Web 实测 | 结论 |
|---|---|---|---|
| 主面板 GameInter[50] | (0,700) 1024×68 | (0,700,1024,68) | ✅ |
| 经验条 GameInter[51] | (17,703) 992×10（(1024−992)/2+1, 3） | (17,703,992,10) | ✅ |
| HP fill GameInter[52] | (35,722) 220×8（CreateBar(35,22,52,52)） | (35,722,220,8) | ✅（但见行为 B-2：填充值假 100%） |
| MP fill GameInter[54] | (35,736) 220×8 | (35,736,220,8) | ✅（同上） |
| **Focus(FP)条 GameInter[58/59]** | (35,750) 220×8（CreateBar(35,50,58,58) MainPanel.cs:41） | **缺失** | ❌ S-1 |
| 九宫按钮 82/87/92/112/97/107/102/117 | x=650/689/728/767/806/845/884/923, y=723, 36×34（CreateButton MainPanel.cs:45-53） | 逐项一致 | ✅ |
| 商城按钮 122 | (972,716) 48×48 | (972,716,48,48) | ✅ |
| 新邮件/可接任务角标 240 等 | MailButton.AddControl(NewMailIcon) MainPanel.cs:70-77 | 缺失（与功能未实现一致） | ❌（并入未实现清单） |
| 聊天记录区 | (0,521) 400×150（ChatLogPanel 400×150 + LayoutHud:4721-4723：mainPanel.y−150−29） | (0,521,400,150) | ✅ 逐像素 |
| 聊天输入行 | (0,673) 400×25（ChatTextBox + LayoutHud:4726-4728） | (0,673,400,25) | ✅ |
| 聊天输入框 | (65,674) 275×23（ChatTextBox/2 (65,1)） | (65,674,275,23) | ✅ |
| 聊天第二按钮 | (345,673) 50×24（ChatTextBox/1） | **缺失**（web 只有 x=0 的「喊话」占位钮） | ❌ S-2 |
| 坐标调试 label | **无** | (8,8,400,16)「比奇城 178,245」 | ❌ S-3 web 多余控件 |
| 小地图 | (1024−w,0) 右上角（LayoutHud:4730-4732） | **缺失** | ❌（并入未实现清单） |
### 3.4 游戏内窗口系统

ui_tree.json 46 窗口 vs web：**仅 ChatTextBox 部分实现（缺 1 按钮）**，其余 45 个窗口无一实现（详单见 §六 未实现清单）。W/E/V/B 键截图取证：web 端按键前后 0.0% 像素变化（05-08_web 四图两两 diff=0.0%），无任何窗口打开。

**结构差异合计：6 项**（登录输入框 +7px×2 计 1 项、记住账号 +16px、FocusBar 缺失、聊天第二按钮缺失、坐标调试 label 多余；另 45 窗口缺失归未实现清单）。

---

## 四、行为差异全清单（C 节）

格式：预期[Godot 源码引用] vs 实际[web 表现/证据]。B-* 为「已实现但有差异」，未实现的进 §六。

### B-1（P0）发送聊天即断线 — C.Chat 序列化缺字段
- 预期：`C.Chat{Text, LinkedItemIndexes:List<int>}`（`ClientPackets.cs:237-241`；服务端 `SConnection.cs:604` 读取 `p.LinkedItemIndexes`）。
- 实际：web `net.js:380` `Chat:(text)=>new Writer().string(text).build(ID.C_CHAT)` **漏写 LinkedItemIndexes**，包体不完整 → 服务端反序列化失败断开连接。
- 证据：两次独立会话，发送聊天后 ≤2s 收到连接关闭——session1 进游戏 10:04:43 → 10:05:59 断（发聊天于 10:05:5x）；session2 发聊天 ~10:07:05 → 10:07:07 断（`data/web-packet-log-session2.json` 尾部 + 聊天记录「连接已断开」）。
- 波及：聊天发送全功能不可用。

### B-2（P0）HP/MP 条恒满 100%（假数据）
- 预期：`CreateBar(..., ()=>PercentOf(_currentHP,_stats[Stat.Health]))`（MainPanel.cs:38-40），S.StatsUpdate(351) 驱动。
- 实际：web HP fill 恒 100%（zircon/game.js:114-116 注释自认 Phase2）。像素取证：Godot 截图 HP 条红色填充 70/220≈**32%**（真实值），web 220/220=**100%**（`03_game_base_{godot,web}.png` (35,722,220,8) 区域红通道扫描）。
- 波及：HP/MP 显示 + 战斗反馈全链条（依赖 StatsUpdate 接入）。

### B-3（P1）S.Chat 解析字段序错误
- 预期：`S.Chat{ObjectID:uint32, Text:string, Type:byte, LinkedItems:List, OverheadOnly:bool}`（`ServerPackets.cs:641-648`）。
- 实际：web `net.js:464` 读 `type:byte, message:string, objectID:uint32` —— 顺序错 + 漏 2 字段。
- 证据：进游戏瞬间聊天列表出现**空文本 say 行**（两次会话复现，t=entry+0~0.2s）——错位解析的产物。
- 波及：即使修好 B-1，他人聊天显示也会乱码/丢字。

### B-4（P1）聊天第二按钮缺失 + 「喊话」为占位
- 预期：ChatTextBox 双按钮 (0,0,60,24)/(345,0,50,24)（ui_tree ChatTextBox/0、/1），支持频道/表情等。
- 实际：web 仅左侧一个「喊话」钮，点击仅提示「Phase 3」（zircon/game.js:89-94）；右侧 50×24 钮缺失（§三 S-2）。

### B-5（P1）游戏内快捷键体系未接线（W/E/V/B 等全无响应）
- 预期：KeyBindManager 默认绑定（KeyBindManager.cs:107-150）：W=背包 Q=角色 E=技能 V=小地图 B=大地图 Tab=拾取……
- 实际：web 无任何窗口快捷键处理（world.js 仅消费方向键/WASD 移动）；实测 W/E/V/B 按键前后截图 0.0% 变化。
- 注：这是「键位→开窗」行为；窗口本身未实现（§六），但**键位监听层**属已进入 Game 场景的行为面，列差异。

### B-6（P2）zircon 聊天输入框打字会走路（输入法/按键泄漏）
- 预期：Godot 聊天框聚焦时按键只进输入框（LineEdit 焦点消费）。
- 实际：world.js window keydown 无「输入框聚焦」判断（world.js:152-156），chatInput keydown 只处理 Enter/Esc 不 stopPropagation（zircon/game.js:97）→ 聊天框里按 WASD/方向键角色同时移动（代码级证据，未逐帧复现 UI）。

### B-7（P2）HUD 面板底图色调偏亮
- 实测：HUD 条带逐行均值剖面错位（row10：Godot 97 vs web 20；row34：48 vs 74），整体亮度接近（51.7 vs 50.6）但分布不同；HP 条区 web 红通道 +28%（167.9 vs 131.4）。
- 归因候选：Godot LegacyScreenBlend/逐贴图 blend（LoginScene logo `Blend=true`、`Shaders/LegacyScreenBlend.gdshader`）vs web `mix-blend-mode:screen` 只在部分控件启用；GameInter 底图在 Godot 侧可能带 blend/滤镜。未逐贴图定源，列为待修项（工作量含在贴图渲染一致性里）。

### B-8（✓一致）登录链包序列与握手
- web 实测 `WS open → G.Connected 回显 → G.GoodVersion db=2026.08.14.4 → C.Login → S.Login result=10(Success) chars=1`，与 Godot `ServerConnection.cs` 握手链逐包一致（Godot 日志 `[Login] 服务端确认连接/版本校验通过 version=2026.08.14.4`）。

### B-9（✓一致）G.Ping 心跳
- web ws.js:86-88 收 G.Ping 即回 C.Ping（对照 ServerConnection.cs:379）；两次会话存活期间未见心跳超时断线（断线均由 B-1 触发）。注：日志里每 2s 的「未处理包 id=61」是 **S.DataObjectLocation**（packet_id_dump 反射核实，376 包表），非心跳，不影响。

### B-10（✓一致）走路步频与移动门控
- 预期：600ms/步（MouseWalker.cs:50-56 RunIntervalMs=600）+ moveLock 服务器确认门控（GameScene.cs:7854-7905）。
- 实测：web 按住→3.0s 走 5 格 = **600ms/步** ✓（session4：178,244→183,244）；moveLock/S.UserLocation 纠正/5s 兜底实现齐（inventory §3）。

### B-11（取证限制）NPC 对话与攻击未取得 Godot 端对照
- Godot 端：比奇出生点视野内全程**无 S.ObjectNPC 对象同步**（整场日志仅 Monster/Player，`/tmp/webport_audit/godot_game.log`「添加物体」全量 35 条无 NPC）；webport `npcs.json` 的 NPC 坐标是 **EI 坐标系**（NpcMover 迁移产物，`Tools/dbeditor/workspace/NPCInfo.json` 无坐标字段佐证），与服务端对象同步不一致——**web 端任何基于 npcs.json 坐标画 NPC 标记的功能都会错位**（当前 web 未画标记，记录为隐患）。
- GM `@move` 在本服测试号上未生效（两次尝试无位置变化），无法瞬移到 NPC 旁取证。
- 攻击：比奇出生点为安全区，Godot 端 Shift+左键 6 次尝试 0 个 `S.ObjectAttack` 回显——安全区不触发攻击，未取得对照。web 端攻击未实现（§六）。
- 结论：NPC 对话/攻击两场景 web 均未实现（不算差异），Godot 参照缺失原因如上，后续补证需非安全区或 NPC 邻位坐标。

### B-12（P2）进游戏瞬间出现空 say 聊天行
- 两次会话均在 entry+0.2s 内出现 1-2 条空文本 say 行。[INFERENCE] 归因候选为 B-3 字段错位（某条 S.Chat 被错序解析成空文本）或本地 addChat 空调用；待 B-3 修复后回归验证归因。

### 行为差异计数：已实现可比 14 项（登录链/心跳/走路/步频/门控/选人链/StartGame 重试/对象入表/聊天收发/光照/HP 条显示/MP 条显示/聊天输入/坐标显示），一致 5 项（B-8/9/10 + 选人链 + StartGame Delayed 重试——zircon/select.js:443-448 对照 SelectScene.cs:688-714），差异 9 项（B-1..7、B-12，其中 2 项 P0）。

---

## 五、资源差异全清单（D 节，`data/resource-diff.{json,md}`）

抽样 53 帧（登录界面全量 Interface1c 21 帧 + Interface 9 + GameInter 13 + 怪物 5 + 图标 5）：

| 检查项 | 结果 |
|---|---|
| 像素质量 | 49 可比帧 **100% PSNR=∞**（黑底合成 MSE=0）；25 帧 RGBA 逐位一致，24 帧差异全部限于 alpha=0 不可见像素的 RGB（DXT 透明 texel 垃圾值被 lossless WebP 归一，程序逐帧验证） |
| 帧号映射 | 5 个有 manifest 的库（Interface1c 1488/Interface 282/GameInter 2485/Mon-3 2208/M-Weapon1 6840 条）帧数与 .Zl 完全相等，抽样 w/h/ox/oy **0 不一致**、0 孤儿 webp |
| 缺帧 | **4 帧缺失**：Interface1c[740]（法师男 intro）、Interface1c[1740]（刺客男 intro）、Interface[28]（法师职业图标）、Interface[30]（刺客职业图标）——manifest 有条目但 webp 不存在（选法师/刺客角色行/intro 动画时该图不显示） |
| manifest 覆盖 | **69/92 库缺 manifest.json**（Flag、M-Weapon×15、MagicEx×7、Mon-×35、ProgUse、Storeitem、WM-Hum 等）——纯静态部署下 skin.js 对这些库整库返回 null；serve.py:163-180 运行时可按需自愈（首次访问抽取+生成） |
| 调色 | 0 帧 R/B 交换；0 帧半透明边缘差异 |
| 体积 | webp 合计 2.21MB vs Zl payload 2.43MB（比值 1.10） |

综合达标率 79.3%（42/53：4 缺帧 + 7 帧 manifest 缺失库）。

---

## 六、未实现清单（Phase 范围外，不算差异但必须列全）

**窗口系统（ui_tree.json 46 窗口，web 实现 0.5 个）**：
AutoPotionDialog, BeltDialog, BigMapDialog, BuffDialog, BundleDialog, CaptionDialog, CharacterDialog, ChatOptionsDialog, ~~ChatTextBox(部分：缺第二按钮)~~, CompanionDialog, ConfigDialog, ConsignmentDialog, CurrencyDialog, DungeonFinderDialog, EditCharacterDialog, ExitDialog, FilterDropDialog, FishingCatchDialog, FishingDialog, FortuneCheckerDialog, GameStoreDialog, GroupDialog, GuildDialog, GuildMemberDialog, HelpDialog, InventoryDialog, KeyBindDialog, LootBoxDialog, MagicDialog, MarketHistoryDialog, MenuDialog, MilestoneDialog, MiniMapDialog, MonsterDialog, NPCCompanionStorageDialog, NPCDialog, NPCQuestDialog, NPCQuestListDialog, NPCSocketCombineDialog, NPCSocketDialog, QuestDialog, QuestRewardChoiceDialog, QuestTrackerDialog, StatusWindow, StorageDialog, TradeDialog

**战斗/对象**：攻击（C.Attack/CombatController 全链）、跑步（C.Move Distance≥2 + running 动画表已定义未用，data.js:17/world.js:205）、对象动画（走路/攻击/受击/死亡——恒 standing frame 0）、怪物/他人血条、掉落物（S.ObjectItem id=293 无监听）、伤害数字、纸娃娃外观层（armour/weapon/hair/helmet 帧偏移未叠加，world.js:288-301；sprites.js 完整管线未接线）、名字颜色/公会名/聊天气泡、坐骑/宠物、per-object 光、体型。
**网络/系统**：键位系统（KeyBindManager 全表）、音效/BGM（ButtonA 点击音等，Phase 4）、断线重连（Phase 4）、注册独立页（当前复用登录框直发注册包）、忘记密码/排行榜/选项/激活账号（点击仅提示「暂未实现」）。
**未处理包 24 种**（进游戏即收，packet_id_dump 反射定名）：BuffAdd(22)×3、BuffRemove(25)×2、CompanionWeightUpdate(56)、DataObjectLocation(61)×6、DataObjectMaxHealthMana(62)×4、DataObjectMonster(63)×24、DataObjectPlayer(64)、DataObjectRemove(65)、FortuneUpdate(75)、GameStoreData(84)、GroupLFG(93)、GuildCastleInfo(105)、GuildConquestDate(108)、GuildInfo(123)、HelmetToggle(150)、InformMaxExperience(154)、MailList(202)、MarketPlaceConsign(214)、MarriageInfo(225)、ObjectBuffAdd(283)、ReviveTimers(341)、StatsUpdate(351)×5、WeightUpdate(375)×5。

---

## 七、修复优先级与工作量估计

| 级 | 项 | 工作量 | 依据 |
|---|---|---|---|
| **P0** | B-1 C.Chat 补 `LinkedItemIndexes`（空 List 前缀 bool+count） | 0.5h（net.js Writer 一行 + 联调） | 聊天即断线，功能全灭 |
| **P0** | B-3 S.Chat 按 C# 字段序重写解析（ObjectID→Text→Type→LinkedItems→OverheadOnly） | 1h | B-1 修后立即暴露 |
| **P0** | B-2 接 S.StatsUpdate(351) 点亮 HP/MP/FP 真实值 | 4h（DTO 已备，net.js:395-424 已解析相邻字段） | 一眼假级别 |
| **P0** | 资源缺帧 4 帧（Interface1c 740/1740、Interface 28/30）补抽取 | 0.5h（webres 单帧抽取） | 职业图标/intro 黑块 |
| **P1** | B-5 键位系统 + ChatTextBox 第二按钮（含 B-4） | 8h（KeyBindManager 移植 + 窗口开关框架） | Phase 3 门户 |
| **P1** | FocusBar(58/59) 补齐（§三 S-1） | 1h | 结构缺失 |
| **P1** | 登录输入框 +7px / 记住账号 +16px 基线对齐（§三） | 1h | 像素级目标必做 |
| **P1** | B-7 HUD 底图色调/blend 一致性（逐贴图 screen-blend 核对） | 4h | 全屏像素差主要成分之一 |
| **P2** | B-6 聊天框按键泄漏 stopPropagation | 0.5h | 边缘场景 |
| **P2** | B-12 空 say 行回归（随 B-3 修复验证消失） | 0.2h | |
| **P2** | 坐标调试 label 加开关（§三 S-3） | 0.2h | |
| **P2** | 69 库 manifest 预生成（serve.py 自愈已兜底，预生成去首次延迟） | 1h 脚本 | |
| **P2** | npcs.json 坐标系勘误（EI 系→服务端真值）或改用对象同步渲染 | 4h（联动 webres 数据管线） | NPC 功能前置隐患 |
| Phase3 | §六 全部（45 窗口/战斗/动画/纸娃娃/音效/重连） | 按总纲 Phase 2-4 展开 | 未实现不计差异 |

---

## 八、附录

### 8.1 截图与数据索引

| 文件 | 内容 |
|---|---|
| `screenshots/01..09_{godot,web}.png` | 9 场景双端截图（1024×768，ZIRCON_UI_SCALE=1，deviceScaleFactor=1） |
| `screenshots/{场景}_diff.png` | 红色差异标注图（>30 阈值） |
| `data/pixel-diff.json` / `pixel-diff-regions.json` | 全屏与静态区量化 |
| `data/web-dom-{login,select,game}.json` | web 三场景 DOM 结构 dump（坐标/贴图帧/文字） |
| `data/web-packet-log-session2.json` | web 完整包日志（70 条，含断线时序） |
| `data/godot-behavior-baseline.md` | Godot 行为基线（13 项，全部 file:line） |
| `data/webport-inventory.md` | webport 实现清单（10 节 + 选择器速查表） |
| `data/resource-diff.{json,md}` | 53 帧资源对比明细 |
| `data/pixdiff.py` | 像素对比脚本 |
| `/tmp/webport_audit/packet_ids.txt` | 376 包 id 反射表（PacketIdDump 运行产物） |

### 8.2 复现命令

```bash
# Godot 端（无头真跑，Xvfb :100 + openbox 无边框隔离配置）
pkill -f 'Xvfb :100'; Xvfb :100 -screen 0 1024x768x24 -nolisten tcp &
XDG_CONFIG_HOME=/tmp/webport_audit/xdgcfg DISPLAY=:100 openbox &   # rc.xml: decor=no
cd ~/development/zircon && DISPLAY=:100 ZIRCON_UI_SCALE=1 \
  ~/.local/bin/godot-mono --path GodotClient -- \
  --server 127.0.0.1 --port 7000 --user test@test.com --pass test123 \
  --char ZZZZAUDIT --window        # 卡选人页；--char TestHero 进游戏
# 窗口对齐: xdotool windowmove <WID> -1 -1 && xdotool windowsize <WID> 1024 768
# 截图: DISPLAY=:100 scrot -o <场景>_godot.png ；键鼠: xdotool key/mousemove/type

# Web 端（CDP 无头，1024×768 dsf=1）
~/.cache/ms-playwright/chromium-1208/chrome-linux64/chrome --headless=new \
  --remote-debugging-port=9223 --user-data-dir=/tmp/webport_audit/chromeprofile --no-sandbox
# attach 后: page.setViewport({width:1024,height:768,deviceScaleFactor:1})
# DOM/日志: window.__WEBPORT.{conn,log,current}；输入需用原生 value setter（无头键盘怪癖，见 8.3）

# 像素对比
python3 docs/webport/audit/data/pixdiff.py
# 包 id 反射表
cd Tools/wsgateway/packet_id_dump && dotnet run --project PacketIdDump.csproj
```

### 8.3 审计过程副产品记录（非 webport 缺陷）

- 无头 Chromium 中 `page.keyboard.type` 字符不落入 input（keydown 到达且未 preventDefault）——环境怪癖，真浏览器不受影响；自动化用 `HTMLInputElement.prototype.value` 原生 setter + input 事件。
- Xvfb+openbox 下 Godot 窗口默认带 1px 主题边框，须 `windowmove -1 -1` + `windowsize 1024 768` 使内容精确落于 (0,0) 1024×768（UiScaler 输出 `viewport=(1024,768)` 为准）。
- openbox 隔离配置：`XDG_CONFIG_HOME` 指向临时目录，`rc.xml` 全应用 `decor=no`，不污染用户全局配置。
