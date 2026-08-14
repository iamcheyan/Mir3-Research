# Phase 1 移植对照文档 — 登录到进游戏（webport）

> 交付物：`Tools/webport/`（:8823）— 双 UI 参考模式网页客户端，
> 注册→登录→选人→进比奇→走路全链路真服联调通过（ServerCore :7000 + wsgateway :7001）。
> 依据总纲 `WEBPORT_MASTER_GOAL.md`（含 2026-08-14 追加拍板"双 UI 参考"）。

## 一、验收结果（2026-08-14 实测）

| 项 | 结果 |
|---|---|
| 握手链 | G.Connected→回显→G.GoodVersion→C.SelectLanguage ✓ |
| 登录 | S.Login 真实包 130B 解析：TestHero/道士/Lv255/GM/比奇城 ✓ |
| 选人 | 角色行（名字/职业/等级/所在地中文名）+ 进入游戏 ✓ |
| 进比奇 | S.StartGame result=5(Success)，StartInformation 出生点 (166,223) ✓ |
| 走路 | C.Move 一步一发 + moveLock 门控；方向键连续走 ✓（实测 223→228、166→170、228→224） |
| 对象同步 | S.ObjectPlayer/Monster/NPC 精确解析（视野内 21-26 对象渲染）✓ |
| Zircon 模式回归 | 重构后全链路复测 ✓ |
| EI 模式 | 同链路（共享 world.js）✓，模式切换器 localStorage 持久化 ✓ |
| 截图 | `screenshots/webport/phase1/` 6 张 1024×768（两模式 × login/select/game） |

测试账号 test@test.com / test123 / TestHero(GM)。
**联调纪律**：跑 webport 前确认无 BotRunner 在登录同一账号（占号会触发
S.Login AlreadyLoggedIn + G.Disconnect AnotherUser 踢线，实测踩过）。

## 二、双 UI 参考架构（总纲 §一）

```
浏览器 :8823
├─ 逻辑层（两模式共用, UI 无关）
│   ├─ net.js      包 id/序列化 (packet_id_dump 反射为准)
│   ├─ ws.js       WS→wsgateway:7001→ServerCore:7000, 握手状态机/事件总线
│   ├─ data.js     maps_manifest/npcs/monsters/... + 帧号公式
│   ├─ camera.js/res.js/sprites.js  瓦片渲染管线 (webclient 复用)
│   └─ world.js    共享世界控制器: 对象表/移动门控/事件订阅/渲染循环
├─ UI 层（只换皮肤与布局, 不碰协议）
│   ├─ themes/zircon/  主线: DXControl 体系 + Interface.Zl→WebP 贴图,
│   │   Login/Select 从 GodotClient 源码逐行转写 (见偏差 #1)
│   └─ themes/ei/      参考: webclient 的 EI 风格 CSS 面板 (顶栏/HP球/腰带/聊天)
├─ mode.js   模式管理 (localStorage `webport_uimode`, 默认 zircon)
├─ shell.js  右上角常驻切换器 (切换→整页重载重建 UI)
└─ main.js   按模式动态 import 主题, 场景流转 Login→Select→Game
```

## 三、Godot 源 ↔ Web 实现映射表

### 控件体系（Zircon 模式）

| Godot 源 | Web 实现 | 备注 |
|---|---|---|
| Controls/DXControl.cs | `dx.js DXControl` | absolute 定位 DOM 节点; location/size setter 触发 applyBase |
| Controls/DXImageControl.cs:155-160 | `dx.js getCurrentIndex` | 按下>悬停>普通 索引优先级 |
| Controls/DXAnimatedControl.cs:92-98 | `dx.js DXAnimatedControl` | AnimationDelay=总时长; restart/clearAnimationHandlers |
| Controls/DXButton.cs:187-203 | `dx.js DXButton` | Index=-1 → Interface 16/18/17 三片拼按钮 |
| Controls/DXLabel.cs + MirSkin.cs:169 | `dx.js DXLabel` | FONT_SCALE=4/3; 描边见偏差 #3 |
| Controls/MirSkin.cs | `skin.js` | manifest {idx:[w,h,ox,oy]} + /res/sprites/{lib}/{n}.webp |
| Shaders/LegacyScreenBlend.gdshader | `mix-blend-mode:screen` | Blend 贴图等价 |
| Controls/UiScaler.cs | `dx.js UiScaler` | clamp(min(h/768,w/1024),1,2), 居中偏移 |

### 场景（Zircon 模式）

| Godot 源 | Web 实现 |
|---|---|
| Scripts/LoginScene.cs:368-530 (BuildLegacyLoginUi) | `themes/zircon/login.js` — bg Interface1c[20]、4 组登录动画(2200/2400/2300/2500)、Logo[22]/[23]、主框 Interface[151] 居中偏下(L419-421)、输入框(70,65)/(357,65)、按钮组、记住账号回填 |
| Scripts/SelectScene.cs:359-531 | `themes/zircon/select.js` — bg Interface1c[50]、角色行(L213-221: Interface[27+class] 图标+名字/职业/等级/所在地)、GetLocationName(L265-271)、底部按钮(L445-453)、创建面板(职业/性别按钮组) |
| Scripts/SelectScene.cs:679-714 | `#onStartGame` — Success/Delayed(3s 重试)/失败分支 |
| Scripts/GameScene.cs:836-840 | `world.js #tryMove` 移动门控 |
| Scripts/GameScene.cs:2033-2095 | `world.js #onObjectMove` 他人/自己确认 |
| Scripts/GameScene.cs:7715/7854-7905 | `world.js #sendMove` 预测位移 + 5s 兜底解锁 |
| Scripts/GameScene.cs:1119-1230 | `world.js #wire` 事件订阅全集 |
| Scripts/MouseWalker.cs:56,262 | `world.js` 600ms/段键盘节拍 + 绕行 |
| Controls/MainPanel.cs:31-55 | `themes/zircon/game.js #buildHud` — GameInter[50] 主面板、HP/MP/经验条、9 宫功能按钮 |
| Scripts/GameScene.cs:4698-4790 (LayoutHud) | 主面板底部居中锚定 |
| ChatTextBox.cs:43-70 | 聊天面板/输入框 (400x150/-29, 400x25) |

### 协议层

| 服务端/C# 源 | Web 实现 | 备注 |
|---|---|---|
| LibraryCore/Network/Packet.cs:195-300 | `net.js Reader/Writer` | 序列化规则逐条对照：string=7bit变长+UTF8 无 bool 前缀; class 属性=bool 非空前缀; List<T>=bool+count+(元素bool+体); Dictionary=dict bool+count+(k,v); enum=底层类型; Color=ARGB i32; Point=(i32,i32); Decimal=16B |
| ServerPackets.cs:25-43 (S.Login) | `S.Login` | 实包 130B 验证 |
| ServerPackets.cs:82-90 (S.StartGame) | `S.StartGame` | result=5 实测 |
| ServerPackets.cs:290-339 (S.ObjectPlayer) | `S.ObjectPlayer` | 末尾 Filters*/HideHead 是字段非属性→不序列化 |
| ServerPackets.cs:340-367 (S.ObjectMonster) | `S.ObjectMonster` | CompanionObject=bool+{Name,HeadShape,BackShape} |
| ServerPackets.cs:369-378 (S.ObjectNPC) | `S.ObjectNPC` | 5 字段精简包 |
| ServerPackets.cs:96-156 | `UserLocation/ObjectTurn/ObjectMove` | |
| Globals.cs:333-343 (SelectInfo) | `readSelectInfo` | 实包验证 |
| Globals.cs:345-452 (StartInformation) | `readStartInformation` | |
| ServerConnection.cs:364-373 | `ws.js` 握手 | G.Connected 回显→SelectLanguage |
| ServerConnection.cs:379 | `ws.js` G.Ping→回显 | 20s 超时踢 |
| SConnection.cs:43-64 | wsgateway 透传 (已有工具) | |

### 数据/渲染

| 来源 | Web 实现 |
|---|---|
| webclient data.js/res.js/camera.js/sprites.js | 近乎原样复用（地图瓦片/精灵帧/manifest） |
| FrameSet.cs 帧号公式 | `data.js` PLAYER_ANIMS/monsterFrame/npcFrame 注释逐条标注 |
| webres 管线 | serve.py 按需从 .Zl 抽帧 → WebP（Interface/Interface1c/GameInter/...） |

## 四、偏差清单（无法 1:1 之处及原因）

1. **LoginScene/SelectScene 布局来自源码转写而非 ui_tree.json**：UiTreeExporter
   只反射无参构造的 DXWindow 子类，这两个 Scene 是命令式构建不在树内（46 个
   游戏内窗口才在）。坐标/贴图索引全部标注 LoginScene.cs/SelectScene.cs 行号，
   与 ui_tree.json 同源（同一份 C# 源），精神符合"禁止手写布局数字"。
2. **点击音效（ButtonA）未实现**：Phase 4 音效总线统一接入。
3. **DXLabel 描边**：Godot 用 outline 渲染；Web 用 `-webkit-text-stroke` +
   `paint-order:stroke` 近似（Noto Sans CJK 下视觉等价）。
4. **ui_overlay.json 不存在**（GodotClient/UI/ 下无此文件）——未使用，overlay
   机制待文件就绪后接入。
5. **EI 模式为 CSS 风格参考**：沿用 webclient 的深棕金面板美学，非 EI 原版贴图
   复刻；`MIR3_EI_ROOT` 图库接入留给后续阶段（EI 模式世界画面与 Zircon 共用
   WebData，符合"共用世界数据"拍板）。
6. **HP/MP 条暂满条**：MaxHP/MaxMP 需 S.StatsUpdate(id=351) 接入，Phase 2。
7. **未知包跳过**：帧已定界，解析失败只丢当前包（ws.js try/catch + trace）。
   已知未处理：GuildInfo(123)/GuildConquestDate(108)/StatsUpdate(351)/
   WeightUpdate(375)/InformMaxExperience(154)/DataObjectPlayer(64)/
   DataObjectMonster(63)。
8. **模式切换 = 整页重载**：切换 UI 参考需重建全部 DOM，重载最简可靠；
   断线重连属 Phase 4。
9. **双实例模块陷阱**（实现细节）：浏览器对 `/skin.js` 与 `/skin.js?v=1`
   视为两个模块实例——调试时统一 URL 后再 hook。

## 五、运行手册

```bash
# 1) 服务端 (Debug/ServerCore 已编译)
cd ~/development/zircon/Debug/ServerCore && dotnet ServerCore.dll   # :7000
# 2) WS 网关
/home/tetsuya/mir3-venv/bin/python Tools/wsgateway/wsgateway.py      # :7001
# 3) webport
cd Tools/webport && /home/tetsuya/mir3-venv/bin/python serve.py      # :8823
# 浏览器 http://127.0.0.1:8823/ — 右上角切换 Zircon(默认)/EI
```

- 账号 test@test.com / test123 / TestHero；数据库写入禁止（服务器运行中）。
- 联调前 `pgrep -af BotRunner` 确认无占号进程。

## 六、Phase 2 接口预留

- `world.js` hooks：`onChat/onPosChange/onMapChange`（UI 无关回调）。
- `net.js` 已具备 Stats 字典/ClientUserItem/Buff 等 DTO，S.StatsUpdate 接入即可点亮 HP/MP。
- 战斗/物品/窗口系统按总纲 Phase 2/3 展开；60+ 窗口点亮前先 `--ui-export` 补导出。
