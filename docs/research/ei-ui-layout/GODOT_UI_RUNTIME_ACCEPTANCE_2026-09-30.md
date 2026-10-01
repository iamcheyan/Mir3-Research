# GodotClient EI UI 真实联机运行验收（2026-09-30）

> 本文件记录一次**真实登录进游戏**的端到端运行验收，用于补上矩阵里
> 「联机链路」的 `UNVERIFIED` 缺口（见待决台账 B-9）。
> 所有结论来自真实进程：隔离服务端 + 800×600 客户端 + 真实按键/点击。

## 1. 环境

| 项 | 值 |
|---|---|
| 客户端 | `GodotClient`（commit `752a41cc`，legacy 模式默认） |
| 服务端 | **自建隔离实例**：`/tmp/godot-parity-srv`（由 `/tmp/ei-flow-srv` 复制，改 `Port=7002`/`UserCountPort=3002`），`dotnet ServerCore.dll` |
| 数据库 | 上述实例自带的 **副本**（未触碰生产/共享库，未改任何运行中服务端的数据） |
| 显示 | Xvfb `:101` 1280×960×24 + openbox；`scrot` 截图 |
| 客户端窗口 | 800×600（`--window`），客户区在屏幕 (128,100)-(928,700) |
| 账号/角色 | `test@test.com` / `EIFlow1`（该副本库里唯一的角色） |
| 输入注入 | `xdotool key f` / `xdotool mousemove X Y click 1` |

启动：
```bash
cd /tmp/godot-parity-srv && dotnet ServerCore.dll        # 监听 127.0.0.1:7002
godot-mono --path GodotClient -- --server 127.0.0.1 --port 7002 \
    --user test@test.com --pass test123 --char EIFlow1 --window
```

## 2. 流程与结果

| # | 步骤 | 结果 | 证据 |
|---|---|---|---|
| 1 | 启动 → WeMade 片头 → 登录 | 登录成功，`[Login] 登录成功, 角色数 1` | — |
| 2 | 选角屏 | EI 布局渲染（F50 背景、开始/创建/删除/结束按钮、1 个角色预览）；`--char TestHero` 不存在时正确拒绝 | 首轮截图 |
| 3 | 开始游戏 → StartGame 过场 | `[LegacySelect] 过场 StartGame.ogv 播放完毕` → 黑屏公告框（GameInter F0，19 字） | `parity-30-notice.png` |
| 4 | 点击公告框确认 ✔ | `[LegacySelect] 公告框底部对勾 -> 进入游戏` → `[Game] 进入游戏! 玩家: EIFlow1, 位置: (161,238), 地图: 1`（Bichon Town） | — |
| 5 | 进游戏后的 HUD | EI 主 HUD：双球体（HP/MP）、底部操作栏、AC/DC 数值、小地图、聊天栏 | `01-ingame-hud.png` |
| 6 | **按 Q** | 打开 **legacy 背包窗** | `03-bag-window-after-Q.png` |
| 7 | **按 F** | 打开 **legacy 行会窗** | `02-guild-window-after-F.png` |
| 8 | 背包与行会窗并存 | 两窗同帧可见、互不关闭 | `03-bag-window-after-Q.png` |

## 3. 验收点逐项核对

### 3.1 背包（任务书重点：格子数量/尺寸/起点）

`04-bag-grid-6x6-zoom.png` 是背包网格区的 2 倍放大。逐格点数：

- **列 = 6、行 = 6 → 36 格**（与 `inventory-window-render-evidence.json` 的
  `0x42F150`「0..0xD8 步进 0x24=36」、`0x42F2A0`「index%6 / ÷6」一致）
- 格子**无间隙**，36×36（`GridPadding=0`、`Step=36`）
- 网格起点窗口相对 **(25,41)**（= `win.x+0x19, win.y+0x29`）
- `负重 0/总量 1899` —— 原版格式 `负重:%d / 总量:%d`（`0x47BDFC`，mode-0 分支）
- `金钱 100000172` —— 原版金币框 `%d`（`0x47A214`）**且颜色 0x64C8F8 浅蓝**一致
- `[包袱]` —— 原版 mode-0 标签 `0x47BE10`
- `수리` 按钮 —— 原版 ctrl1 = F264/265 常驻美术（本模式不变帧）✓
- 右侧**锁链滚动轨** —— 原版 F280 位置 `(x+0xF8, y-0xA5) = (248,-165)` ✓

→ **背包可视几何与标签在真实运行中与原版一致**（矩阵 §6.4 由静态+lab 升级为真机）。

**补充（2026-10-01）：总槽数 46(EI) vs 48(Zircon)，但可视行为一致**
- 原版背包窗（窗口 id 9，对象 `+0x6554`）构造 `0x42E810`：
  `push 0x2E; lea ecx,[esi+0x774]; push 0xC2C; …call 0x4686C4`
  → **槽记录数组 = 0x2E(46) 条 × 0xC2C(3116) 字节**，与 `bag-tooltip-verification-evidence.json`
  的「46 槽 · bag+0x774+i*0xC2C」完全一致（本次由二进制直接确认）。
- Zircon 侧 `Globals.InventorySize = 48`（`LibraryCore/Globals.cs:304`）→ 数据模型多 2 槽。
- 两侧的**可视网格都是 6 列**、可见 6 行、用 F280 gauge 滚动；`ceil(46/6)=ceil(48/6)=8` 行，
  **滚动行数相同** → 只要玩家物品不超过 46 件，渲染与滚动范围逐像素一致；差异仅在数据模型
  （由服务端协议决定，非客户端 UI 缺陷）。

### 3.2 行会（本轮修复的回归）

`02-guild-window-after-F.png`：F600 背景 + `문파` 烘焙标题 + 底部 8 个韩文动作控件
（골드 지불 / 골드 수락 / 문파 석제 / 문파 제해 + 문파 표기 / 문파 제공 / 전위 수락 / 문파 해제）
+ 滚动条 + 关闭键；成员列表区为空（该角色无行会）。

- 修复前（`b8c26340` 状态）同一步骤显示的是**现代「创建行会」页**
  （步骤 1..4 / 加入新手行会 / 创建行会）+ EI 8 按钮的混合 UI。
- 修复后（`752a41cc`）混合 UI 消失 ✓。原版该窗**没有**创建行会入口，
  无行会即空列表 —— 属 1:1 行为。

### 3.3 窗口互斥/叠放

背包与行会窗**同帧并存**，证实 Godot 与 EI 一致：
`0x42B820`（窗口切换前的「demote-all」）只重置 `+0x34` 活动槽，
**不动 `+0x30` 可见门、不摘链表节点** → 原版窗口**不互斥**
（`window-visibility-dispatch-evidence.json::close_all_first`）。矩阵 §5 的 MATCH 得到真机印证。

## 4. 本轮真机验收暴露并已修复的缺陷

| 缺陷 | 症状 | 修复 |
|---|---|---|
| legacy 行会窗残留现代建会页 | 无行会角色按 F 看到「步骤 1..4 / 创建行会」混合 UI | `ApplyLegacyEiLayout` 末尾补 `RefreshRows()`（commit `752a41cc`） |

> 说明：该缺陷**只在真实联机路径出现**（构造期先跑现代 RefreshRows、之后无行会数据
> 就不再刷新），`LegacyHudLayoutLab --legacy-audit` 与 `--ui-audit` 都测不到 ——
> 印证了「不能只靠 lab/静态检查宣称完成」。

## 4.1 证据文件

本目录 `docs/evidence/godot-runtime-acceptance-2026-09-30/`（客户区 800×600 裁剪）：

| 文件 | 内容 |
|---|---|
| `01-ingame-hud.png` | 进入 Bichon Town 后的 EI 主 HUD |
| `02-guild-window-after-F.png` | 按 F → legacy 行会窗（修复后，无建会页） |
| `03-bag-window-after-Q.png` | 按 Q → legacy 背包窗 + 行会窗并存 |
| `04-bag-grid-6x6-zoom.png` | 背包网格 2×放大（可逐格点数 6×6） |

## 4.2 逐窗口热键真机扫描（2026-09-30）

进游戏后逐个按 EI caption 热键，验证打开的是**对应的 EI 窗口**（同一会话截图）：

| 键 | EI 语义 | 真机结果 | 判定 |
|---|---|---|---|
| Q | 包袱栏 | legacy 背包 F250（6×6=36 格、负重/总量、金钱、[包袱]、수리、锁链轨） | MATCH |
| W | 状态栏 | 人物状态 F200（纸娃娃 + 装备槽 + 属性文本） | MATCH |
| E | 技能书 | 技能书 F400（书页 + 左页列表 + 右页详情文本） | MATCH |
| R | 聊天记录 | F350 聊天弹窗（需先取消聊天输入焦点，见下） | MATCH |
| N | 设置栏 | 设置 F750（배경음악/효과음/환경음/그림자 四组 ON/OFF + 滑条） | MATCH |
| G | 组队 | 组队 F900（인원 관리/모집） | MATCH |
| D | 信息窗口(任务) | 任务 F700（羊皮卷） | MATCH |
| S | 坐骑 | 坐骑 F850（말타기/말내리기/말숨기기/말꺼내기 + 무게/스태미너 双 gauge + 关闭键） | MATCH |
| F | 行会 | 行会 F600（8 个韩文动作控件） | MATCH（本轮补） |
| Z / V / Alt+Q / Alt+X | 腰带 / 小地图 / 退出 / 注销 | 走 `KeyBindManager` 默认表，与本轮一致 | MATCH |

证据：`docs/evidence/godot-runtime-acceptance-2026-09-30/05-window-sweep-hotkeys.png`
（W/E/N/G/D/S 六窗带标注，2×3）。

**发现的一处交互细节**：聊天输入框获得焦点时按 R 会被当作**输入文本**而不是热键
（`GameScene.cs:10877-10882` 的 `InputHasFocus` 分支）—— 这与原版一致（聊天框有焦点时
字母键应当输入文本），不是缺陷；真机扫描时需先点击世界取消焦点。

## 5. 仍未覆盖（本轮真机范围之外）

- **原版客户端 A/B**：无 Windows 环境（`../../ORIGINAL_GODOT_PARITY_AUDIT.md` P-002）。
- **目标框/悬停名牌**：Godot 侧原本整体缺失；本轮已实现其中**名字牌**（见 §6），
  HP 条（`0x5600FC` 元素）与悬停 3000ms 保持仍未实现（B-8）。
- **背包 F280 gauge 拖柄几何**：真机只看清轨道位置，拖柄比例仍需原版运行时对照（B-4）。
- **多角色/多职业/装备外观**：本副本库只有 1 个角色，未跑逐职业矩阵。
- **封包级验收**：本轮只验证客户端表现，未抓包比对「相同操作 → 相同封包」。

## 6. 续轮补充：B-8 目标名字牌已实现并验证

### 6.1 原版行为（反汇编定案，2026-09-30）

`0x0040B850` 对**当前目标**（调用点 `0x41C063` 传入 `[ROOT+0x364444]`）画名字（文本位于对象 +8）：

- **不是矩形边框**。此前文档把「`0xA0A0A` 边框 + 文本」当成框，实际是**同一段文本画多次**：
  `0x40B8E7`、`0x40B93C`、`0x40B991`、`0x40B9E6` … 每处都是 `push 0xa0a0a` 后 `call 0x45DE50`，
  rect 每笔 ±1 偏移（`SetRect` 调用点 `0x40B8AB`/`0x40B8DC`/`0x40B931`/`0x40B986`/`0x40B9DB`…），
  即「近黑名字 + 1px 描边」。
- 几何：`left = anchor_x+(48-w)/2`、`right = anchor_x+(w+48)/2`、`top = anchor_y-0x1E`、`bottom = anchor_y-0xF`
  → 宽 w+48、高 15px、中心 = `anchor_x+24`（48 宽瓦片中心）、位于 `anchor_y` 上方 15~30px。
- 颜色 `0xA0A0A`（`0x00BBGGRR`）→ **RGB(10,10,10) 近黑**（同一约定见 `0x96C8FF` = RGB(255,200,150) 的职业文本）。

### 6.2 Godot 实现

- `RenderPrimitives.DrawTargetNamePlate(canvas, text)`：名字画 3 次（`(-1,-1)`/`(+1,+1)`/`(0,0)`），
  颜色 RGB(10,10,10)，水平居中 `x=24`、垂直居中于 y 带 **-30..-15**（Godot 节点原点 == 原版 anchor）。
- `ObjectRenderer.IsTarget` / `PlayerRenderer.IsTarget` + `GameScene._Process` 每帧
  `IsTarget = ReferenceEquals(ob, _combatController.TargetObject)`（怪物/NPC/物品对象与其它玩家都设）。
- 与 hover 名字是两个独立组件：hover 名字基线更低（`NameAboveHealthBarBaseline`/`OriginalNameBaseline`），
  与原版一致（原版目标名字牌同样独立于悬浮名字）。

### 6.3 真机验证（2026-09-30）

因原版颜色近黑、在暗色林地上肉眼不可见，验证分两步：

1. **仪表化验证（几何/门控）**：临时把名字牌颜色改成品红后进游戏，基线无名字牌；
   左键点选「牛」（`[Combat] 选中目标: 牛 ObjectID=522`）后，牛瓦片上方 y -30~-15 带
   出现品红「牛」，中心与瓦片对齐，且连续两帧（间隔 1s）持续存在。
   证据：`docs/evidence/godot-runtime-acceptance-2026-09-30/08-target-nameplate-instrumented-magenta.png`
2. **出厂颜色复核**：恢复 `0xA0A0A` 后与基线一致（近黑在暗底不可见，与原版行为一致）。
   证据：`.../09-target-nameplate-as-shipped-dark.png`

**判定**：B-8 的「名字牌」子项 = **已修复并有真机证据**；「悬停名字 3000ms 保留」= **已实现并有仪表化真机证据**（§6.4）；
「目标 HP 条」= `BLOCKED`（库为运行时绑定，见待决台账 B-8）；「悬浮名字 ProgUse 帧 2/3（32×4）」= `LIKELY`（语义未定，暂不实现）。

### 6.4 B-8 残余之一：悬停名字 **3000ms 保留**（已实现）

**原版机制（反汇编定案）**

| 组件 | VA | 行为 |
|---|---|---|
| 设置悬停名字 | `0x0040BA60` | `0x45E200(lib 0x8AB7A8, 0x90, &HUD+0x61C8C, &HUD+0x620A0, buf)`；随后 `sprintf(HUD+0x621A4, "%[^`]%*c %[^`]%*c …", HUD+0x621A4, 0x622A8, 0x623AC, 0x624B0, 0x625B4, 0x626B8, 0x627BC, 0x628C0)`（8 个反引号分隔字段，9 个 `0x104` 步长缓冲）；**结尾 `mov dword ptr [esi+0x6209C], 0` 重置计时器** |
| 保留门 + 绘制 | `0x0040BB00` | 每帧 `[HUD+0x6209C] += 帧间隔`；`> 0xBB8 (3000)` 时 `memset(HUD+0x620A0, 0, 0x104)` + `memset(HUD+0x621A4, 0, 0x820)` 清空名字；绘制起点 `(anchor_x-0x2C, anchor_y-0x37)`、文本水平居中 |

→ 语义：**悬停期间持续刷新（设置方每帧重置计时器）；停止刷新（鼠标移开）后名字最多再保留 3000ms**。
调用方 `0x422F5F`/`0x422FDC`（同族消息处理器）在收到「设置目标/悬停信息」时调用设置方，与 Godot 侧「鼠标悬停 → 每帧 RefreshNameHold」等价。

**Godot 实现**

- `RenderPrimitives.HoverNameHoldMs = 3000d`（常量，对应 `0xBB8`）；
- `MapObjectNode.NameHoldUntilMs` / `RefreshNameHold()` / `NameHoldActive`；
  `PlayerRenderer` 因不继承 `MapObjectNode` 单独保存同一状态；
- `GameScene._Process`：悬停对象（怪物/NPC/物品与其它玩家）与本地角色所在格命中时
  每帧调用 `RefreshNameHold()`；
- 节点 `_Process` 到期清标记并 `QueueRedraw()`（名字随之消失）；
- `ObjectRenderer.DrawName` 与 `PlayerRenderer` 的名字/公会/聊天行改为
  `NameHovered || NameHoldActive` 门控。

**真机验证（2026-09-30，仪表化）**：环境无法自然触发悬停（见 §6.5），故用**合成悬停**做端到端验证：
临时让客户端在进游戏后 12s 置 `_player.NameHovered = true` 并调 `RefreshNameHold()`，
1s 后置回 `false`（此后不再刷新），并在三个时点截图：

| 时点 | 结果 |
|---|---|
| A：悬停中点（+0.4s） | 名字绘制（品红仪表，124 px，bbox x[504..845] y[308..626]，含右上血球 6 px） |
| B：**悬停关闭后 +0.4s**（保留窗口内） | **仍为 124 px（逐像素同数）→ 名字保留** ✅ |
| C：悬停关闭后 +3.4s（超出 3000ms） | 仅剩 6 px（血球）→ **名字消失** ✅ |

（仪表：把名字颜色临时改成品红，以便在亮雪地上定量计数；已验证的绘制/保留逻辑与出厂态相同，
仅颜色与合成触发点不同。）
证据：`docs/evidence/godot-runtime-acceptance-2026-09-30/10-hover-name-3000ms-hold-instrumented.png`

**判定**：悬停名字 3000ms 保留 = **已实现并有仪表化真机证据**。

### 6.5 悬停保留的**自然**验证与受限项

**自然验证（出厂构建，无仪表）**：把鼠标停在**本机角色所在格**（屏幕 `(522,360)`；实测该点可
触发 `localPlayerNameHovered`，见 `11-*.png` 基线/悬停两格）后移开，四时点像素统计
（相对基线的差异，取名字所在的 `x[440..610], y[280..360]` 窗口）：

| 时点 | 名字区差异像素 | 判定 |
|---|---|---|
| 悬停中 | 449（bbox `x[493..561] y[297..359]`，含角色本体变化） | 名字显示 ✅ |
| 移开后 +0.5s | 420（bbox `x[493..561] y[297..317]`＝**名字行**） | **仍在** ✅ |
| 移开后 +2.5s | 420（同上 bbox） | **仍在**（3000ms 窗口内）✅ |
| 移开后 +4.0s | 37（bbox 落在 `y[320..359]`，即角色动画；名字行**已空**） | **已消失** ✅ |

证据：`docs/evidence/godot-runtime-acceptance-2026-09-30/11-hover-name-3000ms-hold-natural.png`
（与 §6.4 的合成触发仪表化验证互相印证；两者结论一致）

**受限/存疑项**：

- 起始地图可见范围内没有怪物，扫点探针（`NameHovered` 日志）只在**对象**悬停路径上生效，
  不含本机角色的 `localPlayerNameHovered` 分支，故早期扫点结论为假阴性，已由上面的自然验证纠正；
- GM 传送（`@move D201`）在本隔离副本上未生效（客户端日志无命令回显），未能到怪物密集地图复测；
- 「其它玩家 / 怪物」的悬停保留未单独复测（代码路径与本地角色共用 `RefreshNameHold`/`NameHoldActive`）。

## 7. 并发提交后的回归复验（2026-10-01）

**背景**：本 goal 期间有并发提交进入 zircon（`9a58a80b`…`cf61c82a`：EI 登录/公告框与
确认对话框控件等）。为确认这些改动**没有破坏**已验收的窗口与交互，在隔离服务端（端口 7003）
上用当前构建（`9c1f47b7`）重跑一遍逐窗口热键扫描。

**环境**：Xvfb 1280×960 + openbox；客户端 `--server 127.0.0.1 --port 7003 --stay-select --window`
（隔离副本 `/tmp/ei-flow-review`，不触碰 7000 共享库）；测试账号 `test@test.com`。

| 键 | 期望窗口 | 复验结果 |
|---|---|---|
| Q | 背包 F250（6×6=36 格 + 负重/金钱 + 锁链轨） | ✅ 正常 |
| W | 人物状态 F200（纸娃娃 + 装备槽 + 属性文本） | ✅ 正常 |
| E | 技能书 F400（书页 + 左列表 + 右详情） | ✅ 正常 |
| R | 聊天记录 F350（羊皮卷 + 频道图标条） | ✅ 正常 |
| N | 设置 F750（배경음악/효과음/환경음/그림자 四组 ON/OFF + 滑条） | ✅ 正常 |
| G | 组队 F900（인원 관리 / 모집） | ✅ 正常 |
| D | 任务 F700（羊皮卷；该角色无任务数据 → 列表为空） | ✅ 正常 |
| S | 坐骑 F850（말타기/말내리기/말숨기기/말꺼내기 + 双 gauge） | ✅ 正常 |
| F | 行会 F600（8 个韩文动作控件） | ✅ 正常 |
| Z | 腰带（开/关切换生效） | ✅ 正常 |
| V | 小地图（开/关切换生效） | ✅ 正常 |

证据：`docs/evidence/godot-runtime-acceptance-2026-09-30/12-regression-hotkeys-qwer-post-merge.png`
（Q/W/E/R 四窗）、`13-regression-hotkeys-ngdsfzv-post-merge.png`（N/G/D/S/F/Z/V 七窗）。

**复验方法学注意**：聊天记录窗（R）打开后会持有输入焦点，后续字母键会被当作输入文本吞掉
（与原版一致）。因此每个窗口截图后必须 `Esc`×2 并点击本机所在格复位焦点，否则会出现
「多个键返回同一张截图」的假结果（本轮第一次扫描即如此，已在第二次扫描修正）。

**判定**：11/11 窗口在并发提交后的当前构建上**无回归**；§3/§4 的既有结论继续成立。

## 8. 验收口径澄清：封包级「与原版一致」在本移植中不可达（`BLOCKED-by-design`）

goal 的验收条款含「相同用户操作产生相同的**数据请求/封包**、服务端结果」。就本移植而言，
该条**在设计上不可满足**，需显式记录：

- 移植端（GodotClient）连接的是 **Zircon 服务端**（`ServerCore`，`LibraryCore/Network` 的
  反射式封包），运行日志实测为 `[Net] 入队: Ping / PingResponse / BuffChanged …`
  （`Library.Network.*Packets` 的类名）；原版 EI 客户端连接的是 Mud3/EI 服务端与其自有协议。
- 两者的封包 ID、字段顺序、握手与登录流程**结构性不同**（Zircon 的封包 ID 与属性顺序由反射推导，
  见仓库 `AGENTS.md`「Packet dispatch is … discovered by reflection」）。
- 因此「封包/SERVER 结果与原版逐字节一致」只能通过**改用原版协议栈**实现，属重构级改动，
  超出 UI 一致性审计范围；本 goal 的口径应限于：**UI 结构/几何/资源/文本/交互 + 由同一操作触发的
  客户端可见状态变化**（后者已用服务端结果间接核对，如装备/技能/交易）。
- 反过来说：凡是「原版行为」依赖**原版协议/服务端数据**的项（B-6 行会解散、B-7 任务列表文本、
  HP 条资源集合），都以 `BLOCKED-协议` 记录，而非客户端缺陷。

## 9. 项目自带 legacy 自检套件（2026-10-01 全量复跑）

这些自检是仓库自身携带的验收断言（断言控件属性/几何/状态，而非像素），复跑一遍即是一次强回归：

| 自检 | 命令 | 结果 |
|---|---|---|
| 创建界面按钮帧 | `res://Scenes/SelectScene.tscn -- --legacy-select-selftest` | **PASS（本轮由 FAIL 修复后转 PASS，见矩阵 §9 S-2）**：9 钮 Index/HoverIndex/Location/Size 全匹配；职业三钮 91/94/97→Warrior/Wizard/Taoist ✓ |
| 人物属性格式 | `res://Scenes/LegacyHudLayoutLab.tscn -- --legacy-character-selftest` | **PASS** 14 项全匹配（准确=+9% 敏捷=+10% 等） |
| 关闭框键盘链 | `... --legacy-keychain-selftest` | **PASS** Tab 循环/回绕/跳过 disabled；帧表 150/153/156 与 44×20/44×20/64×20 ✓ |
| NPC 对话窗 | `... --legacy-npc-selftest` | **全部 ok**（几何 552×176/F1100、maxScroll=18、选项命中/悬停、行级上下滚动、`offsetY=-21*18`） |
| 悬停提示矩形 | `... --legacy-tooltip-selftest` | **PASS** 背包=(105,205)/(70,47) 商店=(105,205)/(112,47) 裁切=(775,95)/(25,17) |
| WIL 直读 vs 回退 | `res://Scenes/UITestScene.tscn -- --legacy-wil-audit` | **PASS** Interface1c 直读 F50 640×480 + MirSkin WIL 回退 F51 96×26；导出 PNG sha256 已记录 |
| 技能书右页段落 | `... --legacy-magic-selftest` | **不可判定（lab 内无角色技能）**：`selectedSkillId=-1 paragraph=null` → 需联机角色，记 `UNVERIFIED` |

**本轮由自检直接抓到并修复的真实缺陷**：选角屏 5 个按钮的**悬停帧与按下帧互换**
（`41cd2543`）。这说明该自检套件有效，也说明"期望表"必须由原版**绘制状态机**定性，
而不是按 ctor 实参顺序想当然（本轮已把判据注释写进代码）。

## 10. 按钮三态帧的同类缺陷系统排查（2026-10-01）

原版按钮类（ctor `0x417550`）的字段语义由绘制状态机 `0x417640` 与鼠标处理
（`0x417780` 悬停置 `+0x25=1`、`0x4177C0` 按下置 2、`0x4177F0` 释放置 0）确定：

| 状态 | 画哪一帧 |
|---|---|
| 普通（`+0x25==0`） | **`+0x20` = arg8** |
| 悬停（`+0x25==1`） | **`+0x18` = arg2**（仅当 `+0x30`=arg9≠0）+ 文字（`0x417370`） |
| 按下（`+0x25==2`） | **`+0x1C` = arg3** |

按此排查已发现并修复两处真实可见缺陷：

1. **`41cd2543` 选角屏 5 个按钮**：Godot 传成 `(arg8, arg3, arg2)` → 悬停显示按下帧；
   自检 `--legacy-select-selftest` 由 FAIL 转 PASS。
2. **`4abe4569` 聊天窗频道键**：Godot `Index=arg2`（亮绿"屏蔽/激活"态）常显；
   原版常态不画（灰白图标由 F350 烘焙）。真机前后对比：亮绿 → 白/灰 ✓。
3. **`4ac1c1dc` HUD 16 个键位条按钮**：`arg8=-1/arg9=0`（常态不画、悬停只画文字），
   Godot 却叠画 arg2 并让 `PressedIndex=HoverIndex`。真机同点位对比：保留图标本体与
   F50 烘焙细框、去掉多画的一层亮灰底板 ✓。

**判据已写入代码注释**（`SelectScene.MakeSelectIconButton` 调用点、`MainPanel.CreateButton`、
`LegacyChatDialog` 频道键），后续新增窗口按钮应按 (normal=arg8, hover=arg2, pressed=arg3) 映射。
仍未逐窗核对（帧号由寄存器计算、证据只给帧对）的窗口：坐骑/仓库/行会/组队/商店等，
列为后续项（需要逐窗反汇编取 ctor 实参三元组）。

### 10.1 重要反面案例：`arg8=-1` 不等于「背景必有烘焙美术」

对坐骑窗 4 个动作钮反汇编（`0x426938` 起四组调用）得到同一形态：
`arg8 = -1`、`arg9 = 0`（普通态不画、悬停不画帧）、`(arg2,arg3) = (860,861)/(862,863)/(864,865)/(866,867)`。
**但**按窗口相对坐标换算到 F850（512×512、offset (7,-44)）后，
动作钮区域几乎全黑（mean 0.0/7.8/18.5/26.4），与 F860/F864 的像素差 55–70
→ **F850 并没有把这 4 个按钮烘焙进去**。

→ 结论：`arg8=-1` 只说明"普通态这个控件自己不画帧"，**可见性来自别处**（背景烘焙、或客户端把状态置为 1 让它画 arg2）。
因此 §10 的修复规则**必须先验证"背景是否已有该美术"**再套用：

| 窗口 | arg8 | 背景是否已烘焙 | 端口处置 |
|---|---|---|---|
| 选角屏 5 钮 | arg8=正常帧（有值） | — | 修正 hover/pressed 映射即可（`41cd2543`） |
| 聊天频道键 | -1 | **是**（F350 内含灰白图标） | 去掉叠画，显示烘焙美术（`4abe4569`） |
| HUD 键位条 16 钮 | -1 | **是**（F50 内含细框图标） | 去掉叠画（`4ac1c1dc`） |
| **坐骑窗 4 动作钮** | -1 | **否**（F850 内近乎全黑） | **保持现状不改**，否则按钮会消失；机制未闭合，记 `S-5` 候选 |

坐骑窗的可见性来源（客户端是否把 `+0x25` 置 1、或由窗口 paint 另画）仍需运行时 A/B 才能闭合。
