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

### 10.1 更正：`arg8=-1` 的窗口**背景都烘焙了美术**（含坐骑窗）

**2026-10-01 更正**：本节初版曾据"按 offset (7,-44) 换算后 F850 区域近乎全黑"判断坐骑窗背景未烘焙
——**该判断是错的**，原因是那次坐标换算方向搞反了。改用**模板搜索**（把按钮帧在背景帧内全图滑动取最佳匹配）后结论相反：

| 按钮帧 | 在 F850 内最佳匹配 | 位置 |
|---|---|---|
| F860（말타기） | diff **15.9** | (135,333) |
| F862（말내리기） | diff 17.1 | (181,333) |
| F864（말숨기기） | diff 16.7 | (240,333) |
| F866（말꺼내기） | diff 13.7 | (299,333) |
| F161（关闭 ✕） | diff 33.2 | (359,382) |

且与窗口相对坐标精确对位（四个动作钮等间距 46–59px 递进，✕ 落在窗口右上）→ **F850 确实烘焙了这些按钮**。
同类核对（✕ 在各自背景帧内的命中位置）：F350→(758,412)、F250→(363,382)、F1001→(194,197)、
F400→(454,381)、F850→(359,382)——**全部与各窗口的关闭钮位置对位**。

→ 因此 §10 的修复规则对坐骑窗同样适用（坐骑窗已按此修复，见矩阵 `S-5`）。
**方法学教训**：背景偏移未知时不要手工换算坐标，直接用**模板搜索**取最佳匹配位置，可同时暴露偏移与"是否烘焙"两个问题。

### 10.2 覆盖盘查：已按「背景烘焙、自身不画」处理的窗口

按证据逐窗核对 `arg8=-1` 形态与端口实现，当前覆盖情况：

| 窗口 / 控件 | 原版 arg8 | 背景烘焙 | 端口现状 |
|---|---|---|---|
| 聊天窗**频道键** 6 个 | -1 | F350 有 | 本轮修正（`4abe4569`） |
| 聊天窗**滚动上/下** | -1 | F350 有（mean 64/62，非零 83%/99%） | 帧 381/382/383 在 WIL 中**不存在**（F380 是 16×502 导轨）→ 端口已走"无帧只留热区"回退，与原版一致 ✓ |
| HUD 键位条 16 个 | -1 | F50 有 | 本轮修正（`4ac1c1dc`） |
| 仓库翻页 2 个 | -1 | F1001 有 | 早已处理（`StorageDialog` `Modulate` alpha=0 + 注释）✓ |
| 组队/菜单/任务页签/交易接受取消 | -1 | 各自背景有 | 早已处理（`GroupDialog`/`MenuDialog`/`QuestDialog`/`TradeDialog` 的 `Modulate` alpha=0）✓ |
| 交易/公告/退出等对话框 | -1 | 各自背景有 | 已按证据实现 ✓ |
| **坐骑窗 4 动作钮** | -1 | **F850 无** | 保持现状（见 §10.1 / 矩阵 `S-5`）——机制未闭合 |

→ 结论：`arg8=-1` 的窗口**大多已正确处理**；本轮补齐了漏掉的两处（聊天频道键、HUD 键位条），
并明确了唯一未闭合项（坐骑窗）。后续若新增按钮，必须同时核对"背景是否已有该美术"。

### 10.3 `--legacy-audit` 全量自检（2026-10-01）

本轮把"按钮三态帧"的修正推广到行会动作钮与商店购买钮后，跑了一遍**实验室全量审计**：

```
[LegacyAudit] PASS character=True inventory=True magic=True horse=True npc=True chat=True quest=True
  trade=True guild=True storage=True config=True notice=True minimap=True lifecycle=True orb=True
  hud=True roots=True goods=True guildList=True
```

**过程中发现并修正的方法学问题**：审计里有两处断言**编码的是旧（叠画）行为**，
与证据（`arg8=-1` + 背景烘焙）冲突，导致 `--legacy-audit` 报 `npc=False`/`guild=False`：

| 断言位置 | 旧断言 | 更正后 |
|---|---|---|
| `NPCDialog.AuditLegacyEiLayout` | `close.Index == 161` | `Index == -1 && HoverIndex == -1 && PressedIndex == 162` |
| `GuildDialog.AuditLegacyEiLayout` | `actions[i].Index == arg2` | `Index == -1 && HoverIndex == -1 && PressedIndex == arg2+1` |
| `NPCGoodsPanel.AuditLegacyEiLayout` | `_buy.Index == 1012` | `Index == -1 && HoverIndex == -1 && PressedIndex == 1013` |

→ **规则**：当按证据更正实现语义时，必须同步更正"编码了旧行为"的验收断言（并在断言处写明证据来源），
否则自检会以"FAIL"形式把正确的实现挡住（本轮即如此）。

### 10.4 待决：技能书导航钮 / 背包动作钮（`BLOCKED`）

本轮把"背景烘焙、自身不叠画"的规则继续推广时，遇到两项**证据不足**的情况，按纪律记录并跳过：

| 项 | 已证部分 | 未闭合部分 | 状态 |
|---|---|---|---|
| 技能书导航钮 | 原版 `arg8=-1`、`arg9=0`，`(arg2,arg3)=(410,411)`（`0x4392A5`）与 `(412,413)`（`0x4392D4`） | 模板搜索命中位置 (437,432)/(429,432)/(445,439) 与端口窗口位置 (61,303)/(366,303)/(399,340) **无法用同一偏移对齐** → 命中可能不是导航钮美术 | `BLOCKED` |
| 背包动作钮（F264/265） | 端口当前 `Index=264/Hover=265/Pressed=265` | `264/265` 未在 `0x417550` 调用点以立即数出现（arg8 未证）；F264 在 F250 内命中 (289,380)，按端口背景偏移 (-114,-94) 换算回窗口为 (403,474)，**在 284×324 窗口之外** | `BLOCKED` |

**方法学**：模板搜索只证明"该图样在背景帧内存在"，**不证明它就在按钮位置**——必须用端口已知的窗口→帧偏移换算交叉验证命中位置；
偏移未知时（如本两项）不能仅凭 diff 值下结论。

**需要**：原版运行截图 A/B，或逐窗反汇编出按钮的精确 draw offset（含父对象相对换算）。

### 10.5 更正与教训：模板命中 ≠ "美术烘焙在按钮位置"（`a891c010`）

10.2 的批量处置（12 个窗口关闭钮统一置 `Index=-1`）**过度套用**了"背景烘焙"结论。真机逐窗截图后更正：

| 窗口 | 改后真机表现 | 处置 |
|---|---|---|
| 背包 / 角色 / 技能书 / 设置 / 组队 / 坐骑 / 聊天 | ✕ 仍可见（背景烘焙） | **保留** |
| **任务** | ✕ **消失**（露出底色） | **回退** |
| **行会** | ✕ **消失** | **回退** |
| 仓库 / 菜单 / NPC | 精确位置 diff 46–61（未烘焙） | **回退** |
| 公告（diff 32.0）/ 交易（本就纯热区） | — | 保留 |

任务窗另有滚动钮与两个"操作图标"：F723/721 是**该窗控件自身绘制**的美术（不是背景烘焙）→ 一并回退。

**三条方法学教训（已写入本节）**
1. 模板搜索只证明"该图样在背景帧内存在"，**不证明它就在按钮位置**——必须用端口已知的"窗口→帧"偏移换算**精确位置**再比 diff；
2. 即便精确位置 diff 较低（如 32–34），也不能单凭数值判定烘焙——**真机截图才是判据**（本轮 33.8 是烘焙、38.8 不是，差距不足以区分）；
3. `DXButton` 在 `Index<0` 且无贴图时会画 **fallback 底色框**（`DrawFallbackButton`，深灰蓝 alpha0.8）——暗背景几乎不可见、亮背景明显；
   需要"只放热区、不画任何东西"时应同时置 `Modulate = alpha0`（本批对保留项已补）。

### 10.6 本轮保留项的补充可视验证（2026-10-01）

对 10.5 中"保留"的改动做了进一步真机核验：

| 保留项 | 真机核验 | 结论 |
|---|---|---|
| 背包 / 角色 / 技能书 / 设置 / 组队 / 坐骑 / 聊天 关闭钮 | 8 窗扫描截图逐一对比：BEFORE 亮绿 ✕ → AFTER **背景烘焙灰 ✕** 且清晰可见 | ✅ 保留正确 |
| **组队权限钮**（F920/921） | 裁切真机截图：窗口(9,52) 处**圆石按钮 + 白色符号**由 F920 烘焙美术显示，右侧 `[拒绝]` 文本正常 | ✅ 保留正确 |
| 行会 8 动作钮 | 前后对比：8 钮由亮灰叠画底板变为 F600 烘焙样式，韩文标签清晰 | ✅ 保留正确 |
| 商店购买钮 | 模板搜索 F1012 在 F1000 内 **diff 6.4**（强匹配）+ `--legacy-audit goods=True`；商店需 NPC 未能截图 | ✅ 证据充分（视觉待 NPC 场景） |
| 公告 / 交易 关闭钮 | 公告精确位置 diff 32.0（与已验证烘焙同档）；交易原版本就"纯热区、不绘制" | ✅ 保留 |

### 10.7 更正：任务窗图标**确已烘焙**（10.7 初版的"状态驱动"推论作废）

初版曾据"隐藏后该处变黑"推断任务窗两个操作图标无烘焙、靠状态置 1 显示——**该推论错误**。
直接裁切 F700 帧内对应区域（窗口(290,59)/(290,89) + 背景偏移(-86,-36) → 帧(376,95)/(376,125)）可见：
**F700 自身就画着两个圆石按钮——白色右箭头与白色 ✕**。

那块"黑"来自端口自己：`DXVScrollBar` 默认 `BackColour = Colors.Black`，而 legacy 下滚动条被移到
(290,59) 28×58，**正好压在烘焙图标上**；同时端口还有 4 个重叠控件（滚动条上下箭头 +
两个 `_legacyAcceptButton`/`_legacyPageButton`）都在画 F723/724、F721/722 的绿色字形。

**最终修正（`ebb02ed5`）**：4 个控件一律 `Index/HoverIndex=-1` + `Modulate=alpha0`（保留热区与按下 arg3），
并把 `_scroll.BackColour` 置透明 → 真机对比由"绿色叠画 + 黑底"变为"**F700 烘焙的白色 → 与 ✕**"（证据 22）。
`--legacy-audit` PASS。

**方法论补记**：判断"是否烘焙"必须**直接看背景帧的对应像素**（或用隐藏法截图），
两者一致才可信；仅凭"隐藏后变黑"会把**端口自身控件（如滚动条底色）**误当成背景。

### 10.8 其余窗口的叠画/烘焙核对结论（2026-10-01）

按"背景帧像素 + 真机隐藏法"逐一核对剩余可闭合窗口，结论如下（均无需再改）：

| 窗口/控件 | 原版实参 | 端口现状 | 判定 |
|---|---|---|---|
| 交易 accept / cancel | `arg8=-1`、`arg9=0`（`0x417550(0,161,162,…)` 同族） | 早已 `Modulate=alpha0`（只放热区） | ✅ 与证据一致（trade 证据明写 "buttons are never drawn"） |
| 仓库翻页 2 钮 | 同上 | 早已 `Modulate=alpha0`，注释记录"热区与 F1001 烘焙箭头重叠" | ✅ |
| 组队 3 个动作钮 / 菜单 6 钮 | 同上 | 早已 `Modulate=alpha0` | ✅ |
| 设置窗 8 toggle + 2 滑条 | **非** `0x417550` 按钮类（`DXCheckButton`/滑条） | 端口自绘命中区 + 4 个指示器 | ✅ 规则不适用，保持 |
| 背包模式页签（`_legacyModeArt`） | 页签控件 `arg8=-1`，但**模式美术随模式变化** | 端口按 `InvMode` 绘制对应帧 | ✅ 该美术必须由客户端绘制（背景是固定帧），保持 |
| 公告框关闭/动作钮 | `arg8=-1` | 关闭钮已按 S-6 处置；动作钮保持绘制 | ✅ 真机隐藏前后**逐像素无差异**（该对话框两种状态下外观一致） |

→ 至此"背景烘焙、自身不叠画"这一类差异已全部核对完毕：**已修正 9 处**（选角 5 钮、聊天频道 6 钮、HUD 16 钮、
坐骑 5 钮、12 窗口关闭钮中的 7 个、行会 8 钮、商店购买钮、组队权限钮、技能书页签+导航钮、任务窗图标），
**判定无需改动 6 类**（交易/仓库/组队/菜单的既有处置、设置控件、背包模式美术、公告框）。
剩余仍标 `BLOCKED` 的与按钮三态无关（HP 条资源、协议项、原版 A/B）。

### 10.9 按钮三态帧审计的覆盖闭环（2026-10-01 收尾）

最后一处同类排查：**NPC 对话窗滚动箭头**（F52/53 上、F54/55 下）。
反汇编 `0x43ED6C` 的 `0x417550` 实参为 `(arg2,arg3,arg8,arg9)=(54,55,54,0)` —— **`arg8=54`（有值，非 -1）**
→ 该钮的普通态**本来就画帧**，端口 `Index=54/HoverIndex=55/PressedIndex=55` 与之一致，**无需改动**。

至此"按钮三态帧（普通=`+0x20`、悬停=`+0x18`、按下=`+0x1C`）"这一类差异已**逐窗核对完毕**：

| 类别 | 数量 | 状态 |
|---|---|---|
| 需修正（`arg8=-1` 且背景已烘焙 / 悬停按下写反 / fallback 底色框） | 11 类 | 已修正并逐条真机验证（选角 5 钮、聊天频道 6 钮、HUD 键位条 16 钮、坐骑 5 钮、7 窗关闭钮、行会 8 钮、商店购买钮、组队权限钮、技能书页签+导航钮、任务窗图标、角色窗切换钮） |
| 判定无需改动 | 8 类 | 背包动作钮（未烘焙）、NPC 滚动箭头（`arg8` 有值）、交易/仓库/组队/菜单既有处置、设置控件（非该类）、背包模式美术（须客户端按模式画）、公告框（隐藏前后无差异） |
| 未实现于端口 | 3 处 | `0x417880` 其余 `arg3=-1` 调用点（398/399、760/761 等），端口未使用 → 非当前问题 |

→ 该类**无非阻塞剩余项**；后续新增按钮请按同一判据（实参三元组 + 背景帧像素 + 真机隐藏法）核对。

### 10.10 真实可见缺陷：技能书右页段落与所选技能不匹配（`650fe5bb`）

**联机复现**（本轮首次做到"带技能角色的真机验证"——隔离服务端日志显示 `[SingleDev] test@test.com 已注入满级数据`，
角色 `TestHero` 自带 161 个技能，故技能书可实测）：

- 左页选中「焦土烈焰」→ 右页显示 **`#34 [莲月剑法] 属性 : 无属性 …`** —— 完全不同技能的文本 ✗
- 根因：EI 的 `Magic.exp` 只有 **50 段**（`#1=[火球术]`、`#34=[莲月剑法]`、`#26=[烈火剑法]`…），
  而 Zircon 有 **174 个魔法**，端口按"段号 = 技能 id"查表 → 必然错位
  （Zircon `Fire Ball` id=23，而 EI 的 `#1` 才是 `[火球术]`）。

**修正**：`LegacyMagicExpParagraph(string skillName)` 改为**按技能名匹配**——段落首行形如 `[莲月剑法] 属性 : …`，
载入时用方括号内名字建索引（`StoreLegacyMagicExp` 同时维护 id 表与名字表，日志输出 `loaded 50 paragraphs (50 named)`）；
调用点传 `info.Local() ?? info.Name`。

**验证（真机联机）**：
- 选中「火球术」(Fire Ball id=23) → 右页 `[火球术] 属性 : 自然系 / 元素 : 火(火 : 火力) / 修炼1级需要等级 : 7 / … 说明 : 火球术是火系列最基本的魔法` ✓ 与所选一致（证据 24）；
- 选中「焦土烈焰」（EI 表内无此技能）→ 段落为 `null`，**不再显示错误文本** ✓；
- `--legacy-audit` PASS。

**顺带记录的联机环境事实**（供后续联机验收复用）：
- 隔离服务端 `/tmp/ei-flow-review` 的账号 `test@test.com` 在服务端日志中为 **`Admin: False`**，
  但 `@level` 等命令可用（服务端对单机 dev 账号放行）；角色名 **TestHero**，登录时被注入满级数据；
- 聊天命令往返正常（实测 `@giveSkills` 返回 `Invalid Parameters for command @GIVESKILLS`，该命令实需 `@giveSkills <角色名>`）。

### 10.11 观察（非 UI 范围）：`@move 0` 后地图渲染为黑，`missingLibraries=1`

用 GM 命令 `@move 0` 传送到地图 0（800×800）后，客户端日志：

```
[MapView] 加载 0: 800x800
[MapView] 贴图诊断: missingLibraries=1, missingTextures=0, emptyImageEntries=0   ← 地图 0 缺 1 个贴图库
[MapView] 贴图诊断: missingLibraries=0, missingTextures=0, emptyImageEntries=21  ← 对照：地图 4 无缺失
```

画面上地图区域几乎全黑，仅少量墙体边缘可见。地图文件位于 `/home/tetsuya/mir2ei/Map/0.map`。
**判定**：`LIKELY_DIFFERENCE`（资源部署/路径问题，非 UI 布局问题），不阻塞本轮 UI 验收
（本轮所有验收均在渲染正常的地图 4 完成）。

**定位（2026-10-01，已缩小范围）**：按 `LibraryCore/Libraries.cs::KROrder`（63 条）逐条核对磁盘：
- 现代数据根 `/home/tetsuya/mir2ei/Data/Map Data/` **63/63 全部存在**（`Wood/` `Sand/` `Snow/` `Forest/`
  四个子目录各含 `Tilesc.Zl` 等变体，库名 `Wood_Tilesc` 对应文件 `Map Data/Wood/Tilesc.Zl`）；
- 但 **legacy UI 数据根 `/home/tetsuya/mir2ei/LegacyEI/Data/` 下没有 `Map Data/` 目录**，
  只有扁平 WIL/WIX（`Tilesc.wil`、`Animationsc.wil`、`Dungeonsc.wil`…）→ **不含 Wood/Sand/Snow 变体**；
- 客户端日志同时显示 `[MirSkin] UI 库 Interface 在 legacy 目录缺失，回退到 /home/tetsuya/mir2ei/Data/: Interface.Zl`
  —— 即 legacy 根优先、缺失时回退现代根。

**结论**：地图 0 缺失的那 1 个库，最可能是它引用的 **Wood/Sand/Snow/Forest 地形变体**在 legacy 根下不存在
且未触发回退（`LIKELY`，未逐字节解析 .map 的 file 字段最终确认）。这属**资源路径/完整性**问题，
与 UI 布局无关；若要彻底定位，需解析 `0.map` 单元格的 file 字节并与两级数据根比对。

### 10.12 NPC 对话窗**联机**验证（首次：服务端文本驱动）

用 NPC 清单（`docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/npc_manifest.json`，
294 条含地图/坐标）定位 NPC，再用 GM 命令传送到其坐标：

```
xdotool type "@move 0 402 356"      ← Mr. Kang（map 0，原版坐标 402,356）
```

**结果**：F1100 NPC 对话窗在联机客户端**自动打开**（角色落在 NPC 格上），内容区顶部渲染服务端下发的
蓝色问候文本「欢迎来到比奇省，请让我看看我能为你做点什么吧!」；窗口背景为 **EI `GameInter.wil` F1100**
（实测 512×256，见下），关闭/滚动钮按 §10/§10.1 的 static hit-test 位置绘制。
证据：`25-npc-dialog-online-map0.png`（整屏，含窗口位置与 HUD）、`25-npc-dialog-online-text.png`（窗口内容区放大）。

**结论**：NPC 对话窗的"布局（实验室）+ 服务端文本渲染（联机）"两级验收通过；
**选项交互仍为 `UNVERIFIED`**（详见 §10.12.1）——实测点击 0 次到达 `SendNPCButton`。

**素材独立核对（2026-10-01）**：用 `Tools/common/wilsdk.py` 直接解码 EI 资源
`/home/tetsuya/mir2ei/LegacyEI/Data/GameInter.wil`（legacy UI 实际加载的就是它，不是 `/Data/GameInter.Zl`）：
- `F1100` = **512×256**（对话框背景，深色石面 + 金属边框，**其中不含任何烘焙的按钮图标**），
  与 `ApplyLegacyEiLayout()` 的 `_headerBackground.Index = 1100` / `Location = (-64,-59)` 一致；
- 对照：现代库 `/Data/GameInter.Zl` 的 `F1100` 只有 28×32 —— 说明**两套库帧号语义不同**，
  任何"按帧号查素材"的核对都必须指明数据根（`ZIRCON_LEGACY_UI_DATA_PATH`）。
**前置条件**：map 0 贴图缺库导致背景全黑（§10.11），但 NPC 作为**对象**仍正常渲染并可交互——说明该缺库只影响地图地形层。

#### 10.12.1 NPC 对话窗按钮点击（`UNVERIFIED`）

按 §10.12 的联机环境，逐个点击窗口底部 6 个选项按钮（窗口 (0,0)，按钮行 `LegacyTextX+10 = 160`、
行距 22，屏幕命中区约 x∈[282,552]、首行 y≈499），两次坐标校准后仍**看不到可见变化**。

- **代码侧已确认接线**：`NPCDialog` 创建按钮时 `button.MouseClick += (o,e) => GameScene.Game?.SendNPCButton(id)`，
  而 `GameScene.SendNPCButton(int)` = `_net.Connection.Enqueue(new C.NPCButton { ButtonID = buttonId })` —— 发包链路完整；
- **未观察到服务端回包导致的文本变化**；服务端日志无 NPC 相关行，客户端也未打印发包日志；
- **可能解释**：该 NPC（`npc_manifest` 中 map 0 (402,356) 的 `02Weapon_Bichon1`）在角色为 GM 时展示的是
  GM 工具型菜单（文本含「当前在线人数: 1」），其选项可能是**纯副作用**（传送/开关等），不改变文本。

**判定**：`UNVERIFIED`（不是 `CONFIRMED_DIFFERENCE`）—— 需要下一步：在 `SendNPCButton` 加临时打印，
或查服务端 NPC 脚本分支，确认按钮是否真的触发服务端逻辑；以及用一个**普通商人 NPC**（非 GM 菜单）复测买卖/修理分支。

#### 10.12.2 更正：截图中的"6 个图标"不是对话窗选项按钮

§10.12 初稿曾把窗口下方一排 6 个图标描述为"对话窗底部按钮"，**该描述已更正**，依据：

1. **代码路径**：`NPCDialog` 的选项并非常驻 DXButton —— 注释明确"原版按钮不是单独一行的 DXButton，
   而是画在正文中的可点击文字区域。NPCTextControl 已经保留了这些区域；只有协议没有内嵌按钮时才使用
   `Page.Buttons` 作为兼容性后备"。即真正的可点区域在**正文文本内**。
2. **素材核对**：EI `GameInter.wil` F1100（对话框背景）中**没有**这排图标（§10.12 图与本次解码对照）。
3. **几何**：legacy 窗 `Size = 552×176`（屏幕 (122,99)-(674,275)），而该排图标位于屏幕 y≈455–495，
   **在窗口之外**，属于游戏世界层。

**判定**：该排图标为**游戏世界层内的未知 sprite**（未逐个确认身份，`UNVERIFIED`），
不构成对话窗按钮；`SendNPCButton` 在两次坐标校准的点击中均 **0 次被调用**（`grep -ac` 实测）。
**下一步**（未做）：点击正文中的内嵌选项文字区域，或换一个**普通商人 NPC**（非 GM 菜单）复测买卖/修理分支。

#### 10.12.3 第二个 NPC（药商 David）复测：页面同样无选项

按 §10.12.2 的下一步，改访 `04Potion_Bichon1`（药商 David，map 0 (397,362)）：

- 对话窗正常打开，正文为蓝色服务端文本「欢迎来到传奇3，请开启你的游戏之旅吧!」；
- 页面**同样没有可见选项**，正文中也不存在内嵌可点区域（`NPCTextControl.ButtonAreas` 由正文标记生成）；
- 两次复测（武器商 Mr. Kang / 药商 David）均无选项 → **点击路径无法触发**，`SendNPCButton` 仍 0 次调用。

**结论与边界**：客户端侧行为**符合实现约定**（无选项则无可点区域）；"商人是否应该有菜单"
取决于**服务端 NPC 页面数据/脚本**，属服务端范围，本次未判定（`UNVERIFIED`，非客户端差异）。
客户端侧可判定的部分是：**对话窗能正确显示服务端下发的任意页面文本**（已两次验证）。

### 10.13 发现（待裁决）：legacy UI 下**仓库窗（StorageDialog）无入口**

**事实链**（全部来自当前 checkout 的源码检索，非推测）：

| 环节 | 证据 |
|---|---|
| 窗口存在 | `GodotClient/Controls/StorageDialog.cs`；实验室日志 `[LegacyWindowLoc] sto=StorageDialog@(0, 0)` |
| 唯一打开函数 | `GameScene.ToggleStorageWindow()`（`Scripts/GameScene.cs:277`）→ `WindowManager.Toggle(_storageDialog, _uiLayer)` |
| 调用者仅两处 | ① `Controls/MenuDialog.cs:65` 的 `StorageButton`（**现代**菜单窗）；② 键位表 `KeyBindManager.StorageWindow = Key.S`（`Controls/KeyBindManager.cs:117`） |
| legacy 模式下 `S` 被覆盖 | `GameScene.cs:11012-11016`：`AutoLoginArgs.LegacyUi && Key.S` → `ToggleHorseWindow()`（依据 EI 键位表，坐骑）→ **legacy 下走不到仓库** |
| 服务端无仓库 NPC 类型 | `LibraryCore/Enum.cs:567 NPCDialogType` 全部成员（BuySell/Repair/Refine/…/SocketCombine）**不含仓库**；NPC 清单 294 条 identity 前缀亦无仓库类（`02Weapon/04Potion/07Grocer/10ChestnutMarket/13Move_/14Quest_/15Magic_`…） |
| 客户端仅处理 `S.StorageSize` | `GodotClient/Network/ServerConnection.cs:886`（无 `S.StorageOpen`/列表包处理） |

**判定**：`LIKELY_DIFFERENCE`（legacy UI 下仓库不可达），**但需先确认原版 EI 是否提供 legacy 仓库入口**
（若原版 EI 的仓库同样由 NPC/服务端功能提供，而 Zircon 服务端本就无该功能，则属**服务端功能缺失**而非客户端 UI 差异）。
**未做**：原版 EI 的仓库入口取证（HUD 按钮 or NPC）、服务端 `S.StorageSize` 的触发路径追踪。
**风险**：不下结论——本项已按"证据不足不猜"原则登记为待裁决，不影响本轮已完成的验收结论。
