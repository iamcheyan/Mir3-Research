# Godot 客户端行为基线（web 一致性审计对照用）

> 生成：GodotBehaviorScout 只读研究（2026-08-14）。
> 行号基准：当日 `~/development/zircon` 工作区实读，均来自真实读取，未编造。
> 引用路径约定：`GodotClient/…`、`LibraryCore/…`、`ServerLibrary/…` 均相对 `~/development/zircon/`。
> 协议文档实际只有 3 篇（`docs/codebase/protocol/{connection-lifecycle,packets-c2s,packets-s2c}.md`，任务书说的 23 篇与实际不符），本文以源码实读为准、文档作旁证。

**两个与任务书预期不同的关键事实（web 端对照时务必注意）：**
1. 本代码库**没有** `C.AccountLogin`、`S.AcceptLogin`、`C.SelectServer`、服务器列表这一步。登录包是 `C.Login`，`S.Login` 直接携带角色列表 `Characters`（`LibraryCore/Network/ServerPackets.cs:25-44`）。Godot 登录页与选人页之间**只有 2 个 UI 状态**（LoginScene → SelectScene），无服务器列表页/下拉/自动选服。
2. 走路/跑步**没有** `C.Walk`/`C.Run` 两个包，统一是 `C.Move{Direction, Distance}`，Distance=1 走、≥2 跑（`LibraryCore/Network/ClientPackets.cs:99-103`）；回显同理是 `S.ObjectMove`，不是 `S.ObjectWalk`。NPC 对话包叫 `C.NPCCall`，不是 `C.NPCConverse`（`LibraryCore/Network/ClientPackets.cs:243-246`）。

---

## 1. 登录链完整包序列（TCP → 选人页）

网络栈：`NetworkManager`（autoload 节点）每帧同步轮询 TCP + `Connection.Process()` 分发（`GodotClient/Network/NetworkManager.cs:31-68`）；`ServerConnection` 继承 `BaseConnection`，超时 30s（`GodotClient/Network/ServerConnection.cs:20`），CheckSum = `user://checksum.bin` 持久化 GUID 前 20 位（`ServerConnection.cs:23-31`）。

精确序列（C=客户端发、S=服务端发、G=双向通用包）：

1. **TCP connect**：LoginScene `_Ready` 即连（不等用户点登录）：host/port 来自 `--server/--port` > ClientSettings > 默认 `127.0.0.1:7000`（`GodotClient/Scripts/LoginScene.cs:82-85`），`_net.Connect(host, port)`（`LoginScene.cs:97`）；连接重建时清空半包缓冲防登录卡死（`NetworkManager.cs:71-78`）。单机模式下端口无监听自动拉起本地 ServerCore（`LoginScene.cs:88-96`）。
2. **S→C `G.Connected`**：服务端 accept 即发。客户端处理：`Process(G.Connected)` → 触发 `ConnectedEvent` + **回发 `G.Connected`**（`ServerConnection.cs:364-368`）。
3. **C→S `G.Connected`**（回显，见上）。
4. **S→C `G.GoodVersion`**：服务端 `Process(G.Connected)` 在 `CheckVersion=false` 时置 `Stage=Login` 并下发（`ServerLibrary/Envir/SConnection.cs:277-281`）。⚠️ Godot 客户端**没有** `G.CheckVersion`/`G.Version` 处理器，只能连关闭版本校验的服务端（`docs/codebase/protocol/connection-lifecycle.md` TL;DR 末条）。
5. **C→S `C.SelectLanguage{Language="Chinese"}`**：客户端收到 `G.GoodVersion` 立即上报语言并触发 `VersionOK` 事件（`ServerConnection.cs:369-372`）。
6. **C→S `C.Login{EMailAddress, Password, CheckSum}`**：触发条件二选一——用户点皮肤版登录按钮 `OnLoginPressed`（`LoginScene.cs:244-263`），或 `--auto-login` 时在 `OnVersionOK` 里自动发（`LoginScene.cs:200-208`）；`SendLogin` 组包（`ServerConnection.cs:893-896`）；字段定义 `LibraryCore/Network/ClientPackets.cs:55-59`。
7. **S→C `S.Login{Result, Message, Characters, Items(仓库), BlockList, Address, IsGM}`**：字段 `LibraryCore/Network/ServerPackets.cs:25-44`；Godot 处理 `Process(S.Login)`（`ServerConnection.cs:385-391`），仓库物品存 `PendingStorageItems`。
8. `Result==Success` → `LoginScene.ShowLoginResult`（`LoginScene.cs:175-198`）：实例化 SelectScene、**AddChild 前** `SetCharacters(_pendingCharacters)` 注入角色列表、QueueFree 登录场景。失败则状态栏显示错误并重新启用按钮。
9. **心跳**（此后全程）：服务端每 2s `S→C G.Ping` → 客户端回 `C→S G.Ping`（`ServerConnection.cs:379`）→ `S→C G.PingResponse` 更新 RTT（`ServerConnection.cs:380`）。

**登录页→选人页之间 UI 状态数：2 个场景、0 个中间页**。LoginScene 内部有「隐藏的原生 VBox 表单 + DX 皮肤 UI」（`LoginScene.cs:540-545` 把 VBox 设为不可见）和若干弹出对话框（注册/改密/排行榜/选项，`LoginScene.cs:314-364`），但无服务器选择环节。

## 2. 选人 → 进游戏链（C.StartGame → 可操作）

1. **C→S `C.StartGame{CharacterIndex}`**：点开始按钮 `OnStartPressed`（`GodotClient/Scripts/SelectScene.cs:622-632`）或 `--auto-login` 自动 `AutoStartGame`（`SelectScene.cs:171-179`）；`SendStartGame`（`ServerConnection.cs:938-942`）。⚠️ **没有 `S.SelectStarted` 这个包**——服务端直接回 `S.StartGame`。
2. **S→C `S.StartGame{Result, Message, StartInformation}`**（`LibraryCore/Network/ServerPackets.cs:82-90`）。`StartGameResult` 枚举（`LibraryCore/Enum.cs:2340-2347`）：`Disabled`（服务器禁进）、`Deleted`（角色已删）、`Delayed`（重登冷却 `RelogDelay=10s` 内）、`UnableToSpawn`（出生点全失效）、`NotFound`、`Success`。
   - `Delayed` → Godot 3 秒定时器后原 CharacterIndex 重发 `C.StartGame`（`SelectScene.cs:687-706`）。
   - `Success` → `SelectScene.ShowStartGameResult`（`SelectScene.cs:679-689`）实例化 GameScene 并注入 `StartInfo`。
3. **进图突发包序列**（服务端 `PlayerObject.OnSpawned`，按 Enqueue 顺序，`ServerLibrary/Models/PlayerObject.cs:1053-1130`）：
   1. `S.StartGame{Success, StartInformation}`（:1059）
   2. `S.Chat`（欢迎语，Announcement）（:1062）
   3. `S.GuildInfo`（有行会时，SendGuildInfo :1064）
   4. `RefreshStats()` → `S.StatsUpdate` 等属性包；`S.InformMaxExperience`（:1073-1074）
   5. `AddAllObjects()`（:1094）→ 对视野内全部对象逐个 `S.ObjectPlayer`（含自己）/`S.ObjectMonster`/`S.ObjectNPC`/`S.ObjectItem`
   6. `S.RefineList`（有精炼时 :1101-1103）
   7. `S.MarketPlaceConsign`（:1104）、`S.MailList`（:1105）、`S.GameStoreData`（:1106-1113）
   同时 `S.MapChanged{MapIndex, InstanceIndex}` 在 Spawn 流程中随地图切换下发（Godot 处理见下）。
4. **Godot 侧时序关键点——突发包缓冲**：GameScene._Ready 订阅事件之前到达的包会先被 `Process` 双发进 `Pending*` 队列（`ServerConnection.cs:311-329, 227-260`；`BufferPendingPackets` 默认 true :311），`GameScene._Ready` 末尾 `DrainPendingObjects()` 按序排空（Move→Turn→Player→Monster→NPC→Item→…，`GodotClient/Scripts/GameScene.cs:1451-1453, 7503-7524`）再 `StopPendingPacketBuffering()` 关闭缓冲。切图时 `S.MapChanged` 若在缓冲期不清队列、运行态才 `ClearPendingWorldPackets()`（`ServerConnection.cs:415-421 引用的 319-330`；实际 `Process(S.MapChanged)` 在 `ServerConnection.cs:408-413` 附近，缓冲清理逻辑 `ServerConnection.cs:319-330`）。
5. `GameScene.ShowStartGameResult`（`GameScene.cs:1750-1796`）：从 StartInformation 取 ObjectID/MapIndex/Location/Direction/Horse，`_canRun=true`，`InitHudData`（`GameScene.cs:4927`）灌 HUD；等 `S.MapChanged`（`GameScene.cs:1799-1807`）到达后 `LoadPlayerMap`，之后即可操作。

## 3. 走路/跑步（C.Move 节奏与回显）

**输入模型**（`GodotClient/Scripts/MouseWalker.cs`，GameScene 挂载于 `GameScene.cs:979-989`）：
- 左键按住 = 朝鼠标方向走（Distance=1）；右键按住 = 跑（Distance=GetRunSteps()）；Shift 按住不移动（原地攻击交给战斗组件）；Alt+左键是采集/钓鱼/驯服，不移动（`MouseWalker.cs:120-128`）。
- 方向算法：鼠标相对玩家（恒居中）角度按 22.5° 八分（近距离 ≤2 格先按格差取方向，`MouseWalker.cs:216-246`）；撞墙绕路 `MouseDirectionBest` 复刻（`MouseWalker.cs:250-274`）。
- **步频公式**：本地节拍 `WalkIntervalMs = RunIntervalMs = 600ms`（`MouseWalker.cs:44-50`）+ **ServerTime 停等门控**：发一个 `C.Move` 后锁 `_moveServerLockUntilMs = now+5000ms`（容错上限，正常几十 ms 回包即解锁），锁定期不再发（`MouseWalker.cs:146-151`、`GameScene.cs:7893-7896`、门控谓词 `GameScene.cs:984-985`、注释 `GameScene.cs:836-839`）。解锁点：`S.ObjectMove`（经 `ShowUserLocation`，`GameScene.cs:7715-7723`）或 `S.UserLocation` 纠正（`GameScene.cs:1858-1880`）。即**严格一包一回显，实测节奏 ≈ 每 600ms（或 RTT 更大时按 RTT）一个 C.Move**。
- **跑 vs 走**：不是动画加速，而是同样 600ms/6 帧内移动 2 格（`MouseWalker.cs:44-48`）。`GetRunSteps()`（`GameScene.cs:7906-7918`）：`steps = 2` 需 `冷却OK(_runCooldownUntilMs, 受击后 600ms) && _canRun && 背包未超重 && 穿戴未超重`，否则 1；骑马再 +1（=3）。`_canRun` 进图即 true（`GameScene.cs:1764-1766`），攻击后置 false（`GameScene.cs:1014`）、受击置 false+600ms 冷却（`GameScene.cs:4198-4199`）。
- **右键近身只转身**：鼠标在玩家 2 格内或不可移动时只发 `C.Turn`（`MouseWalker.cs:154-158`）。`C.Turn{Direction}`（`LibraryCore/Network/ClientPackets.cs:92-95`）对本地玩家**无回包**（服务端只广播 `S.ObjectTurn` 给别人），所以 Godot 发包同时本地应用朝向（`GameScene.cs:1483-1489` SendTurn，注释 1477-1482）。
- **本地预测**：`SendMouseMove` 发包即把权威格跳到预测终点并启动插值（`GameScene.cs:7860-7915`）；`S.ObjectMove` 回显处理 `OnObjectMove`（`GameScene.cs:2033-2090`）：自己→`CallDeferred(ShowUserLocation)`，预测命中只补方向不重启插值、不命中走纠正路径重跳+回拉式插值（`GameScene.cs:7725-7790`）；Slow 减速经 `MouseWalker.AddMoveDelay` 叠加到下一发包时刻（`MouseWalker.cs:65-68`、`GameScene.cs:2068`）。其他玩家/怪物→平滑补间 `StartMove/QueueMove` 并提升点击优先级 HitOrder（`GameScene.cs:2072-2089`）。
- `C.Move` 字段：`{MirDirection Direction, int Distance}`（`LibraryCore/Network/ClientPackets.cs:99-103`）；组包处 `GameScene.cs:7893`（鼠标）与 `GameScene.cs:1015`（追击回调）。

## 4. 攻击（触发键与间隔公式）

触发路径（`GodotClient/Scripts/CombatController.cs`，挂载与回调接线 `GameScene.cs:991-1046`）：
1. **左键点怪物** → `_Input` 命中测试选中 TargetObject（纯客户端状态，无包；`CombatController.cs:316-389`，选中分支 329-361）。
2. **顶部自动攻击**（任何鼠标状态之前，每帧检查）：目标为相邻怪物（Chebyshev 距离=1，同格不砍）且冷却到且未骑马且无元素飓风 → `C.Attack`（`CombatController.cs:214-231`）。按住左键持续攻击即走此分支。
3. **Shift+左键且未选中目标** → 朝鼠标方向原地攻击 `TryAttack`（`CombatController.cs:241-244, 402-413`）。
4. **飞镖（Shuriken 武器形状）**：超 `MagicRange=10` 格提示并清目标；冷却中清目标；可投 → `C.RangeAttack{Direction, Target}`（`CombatController.cs:150-157 判定, 336-356 分发`；`LibraryCore/Network/ClientPackets.cs:149-153`）。
5. **底部追击**：选中目标 >1 格时按 `MoveTime=600ms` 节拍发 `C.Move(dir,1)` 接近（`CombatController.cs:296-303`）。
6. 右键 = 取消选中（RightClickDeTarget 开启时，仅怪物目标，`CombatController.cs:364-372`）。

**攻击间隔公式**（`GameScene.ComputeAttackIntervalMs`，`GameScene.cs:1492-1504`）：
`interval = max(800ms, AttackDelay − AttackSpeed × ASpeedRate)`；超重或 Neutralize 中毒 ×2。常量 `AttackDelay=1500, ASpeedRate=47`（`LibraryCore/Globals.cs:304-306`）。⇒ 默认 0 攻速 = **1500ms/刀（约 0.67 次/秒）**，攻速拉满也有 800ms 地板。CombatController 侧兜底同公式（`CombatController.cs:415-418`）。

`C.Attack` 字段：`{Direction, Action(MirAction.Attack), AttackMagic}`（`LibraryCore/Network/ClientPackets.cs:142-147`；Godot 组包 `GameScene.cs:1007`，攻击前本地先播动作、`_canRun=false`，`GameScene.cs:997-1008`）。

**回显**：`S.ObjectAttack` → `OnObjectAttack`（`GameScene.cs:3013-3062`）：攻击者播攻击动画并按 Slow 校正位置；`TargetID≠0` 时被击者播 Struck 动画/音效、按 MagicEffectTable 出特效。受击方自身收 `S.ObjectStruck` → 位置被服务端改写（击退）+ Struck + 600ms 跑步冷却（`GameScene.cs:4187-4213`）。伤害数字走 `S.HealthChanged`（`ServerConnection.cs:650-655` 事件族）。
