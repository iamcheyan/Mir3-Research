# GodotClient EI UI 对齐：已决 / 待决事项台账（2026-09-29）

> 本文件记录「GodotClient 原版 1:1 一致性审计」过程中**需要做取舍**的事项。
> 目标：agent 能自己判定的直接判定并执行；判定不了或需要产品决策的登记在此，
> 由用户回头统一处理。
>
> 配套：对照矩阵见 [`GODOT_WINDOW_PARITY_MATRIX_2026-09-29.md`](GODOT_WINDOW_PARITY_MATRIX_2026-09-29.md)。

## A. 已由本轮自行判定并执行（附理由，均可回滚）

| # | 事项 | 判定 | 理由 | 提交 |
|---|---|---|---|---|
| A-1 | 技能书 id14 窗口尺寸 | 采用 **452×380 @(348,0)**，改研究文档旧值 296×332 | main-init `0x004278E1-0x00427904` 9 参 push 序列 + F400 alpha bbox 451×378 + 11 控件越界三重佐证；旧值是 horse 行复制 | `b29f8645` |
| A-2 | 行会 id4 legacy 布局 | 按原版 9 控件 paint 坐标 + 成员列表 (35,60)/字高+5/18 行 | `0x425152-0x425258` paint 真值 + `0x4253E6`/`0x4252BD`/`0x4252C5` 反汇编复核 | `b8c26340` |
| A-3 | legacy 行会背景帧 | legacy 恒用 GameInter F600、锚点恒 -(214,33) | 原版 id4 只有一张 F600；现代 `ApplyGuild/SelectTab` 覆写成 261/262… 会让背景整块消失（截图实证） | `b8c26340` |
| A-4 | 任务详情正文色 | 改 **RGB(0,0,125)**（0x7D0000，0x00BBGGRR 约定） | `0x00447EF7/0x00447F51/0x00447F70` 三处 push 0x7D0000 | `2855e0ac` |
| A-5 | `--ui-audit` HUD 断言 | 改用 EI caption 坐标（648,70)/(648,32)/(703,16)/(703,85)/(665,16) | 原断言是已废弃的新版九键排布，必然 FAIL；EI 坐标有 `hud-label-evidence.json::caption_ctor_table` 依据 | `10cb0511` |
| A-6 | 行会成员行原点 1px 分歧 | 取 **(x+0x23,y+0x3C)**（`guild-window-paint-evidence.json` 的 (x+0x22,y+0x3B) 判为笔误） | `0x00425409 add ecx,0x23` / `0x004253FB +0x3C`；与 social-window 证据一致 | 证据文件已注 |
| A-7 | 任务列表行公式 | 更正为 **y=win.y+90+15·line**（旧文字漏了 ×5） | `0x00447618 lea eax,[ecx+ecx*2+0x12]` + `0x00447622 lea eax,[eax+eax*4]` | `40474946` |
| A-8 | 背包「46 格」口径 | 判定 **46 = 记录容量，36 = 可视格**；Godot 可视 6×6/36px/(25,41) 与原版一致 | `0x0042F150`/`0x0042F2A0`/`0x0042F79C` + 运行实测 | 矩阵 §6.4 |
| A-9 | 背包三个子控件帧号 | 判定 Godot 现有实现**正确**（idle 取 `[+0x20]`，即 handler 最后 push 的 263/270/273） | `0x417880` 字段映射 + `0x417640` 状态机 + 三个 mode handler 的 push 序 | 矩阵 §9 I-3 已收窄 |
| A-10 | 背包 F161/162「关闭」是否偏差 | 判定 **不是确认差异**（保留现状） | `0x42BF85`：背包窗口输入 handler 返回 0 时 `0x42ADB0(hud,0)` = 切换关闭背包；点 X 命中其装饰 vtable（只播音）后仍落到背景路径 → 原版也会关 | 本轮新证据 |

## B. 待决（需要用户决策或需要目标资源/协议，本轮不擅自改）

### B-1 窗口「点击背景即关闭」这一交互模型要不要照搬

**原版事实（primary-static）**：子窗口点击分派 `0x42C4D4` 每个 case 的形态一致 ——
先调该窗口自己的输入 handler，**返回 0 就 `0x42ADB0(hud, id)` 切换关闭该窗口**：

| id | 窗口 | 输入 handler | 关闭调用 |
|---|---|---|---|
| 0 | 背包 | `0x4300F0`（`0x42BF85`） | `0x42ADB0(hud,0)` |
| 1 | 状态 | `0x44CCD0`（`0x42BFB3`） | `0x42ADB0(hud,1)` |
| 3 | 交易 | `0x416EF0`（`0x42C00B`） | `0x42ADB0(hud,3)` |
| 4 | 行会 | `0x4258F0`（`0x42C039`） | 同形 |

即：**点窗口内没被 handler 消费的区域 = 关闭该窗口**（背包/交易/状态/行会…通用）。

**Godot 现状**：点窗口空白区不关闭（只有拖拽）。

**为什么没直接改（已核实前提）**：本轮查了 `DXControl._GuiInput`
（`Controls/DXControl.cs:262-290`）：`MouseClick` 在 **press 后 release 即触发**，
**没有任何拖拽距离阈值**（`_dragging` 只用于 `MouseMove` 分支，release 时照样
`MouseClick?.Invoke`）。所以在 Godot 里「窗内按下 → 拖动 → 在窗内松手」会误判为点击；
直接照搬 B-1 会让**每次拖拽窗口/物品都以关窗收尾**。
原版靠 `0x423FA0`（拖动路径）与 click 分派（`0x42C4D4`）两条独立路径区分，
Godot 侧没有等价区分。

**因此 B-1 的前置条件**（本轮新增结论）：先给 `DXControl` 加 click/drag 判别
（例如记录 press 位置、release 时位移超阈值则不发 `MouseClick`，或新增
`DragHappened` 标志），**再**逐窗口接「背景点击 → `0x42ADB0(hud,id)` 等价关闭」。
前者改动共享基类 `DXControl`，影响全部窗口 → 必须单独回归。

**补充**：原版 `0x42BF85`/`0x42C00B` 等 case 证实背包/交易/状态/行会都吃这条
「handler 返回 0 → toggle 关窗」；且 `0x42BF85` 显示**点背包的装饰 X（F161/162）
最终也走这条背景路径关窗**，所以 Godot 现在把 F161/162 绑 `WindowManager.Close`
在**可观测结果**上与原版一致（见 A-10）。

**选项**：
1. 照搬（最 1:1，但需先设计 click/drag 判别，逐窗口回归）；
2. 只对背包/交易实现；
3. 保持现状，仅登记。

**推荐**：选项 1，但单独开一个 goal 做（需要 13 个窗口的点击/拖拽回归矩阵）。

### B-2 交易 close 热区 (532,350) 的关窗行为

原版该热区**在 484×330 窗口矩形之外**，窗口命中测试 `0x42AAB0` 按窗口 rect 分派，
因此该热区实际**不可达**；其自身行为是「播音 + 消费点击」。Godot 把同一坐标的
按钮绑成 `CloseTrade()`。

**待决**：是否移除 Godot 这处「窗口外可点关闭」？（影响极小，但严格说不是原版行为。）
**推荐**：随 B-1 一起处理（B-1 落地后该热区自然应改为无行为）。

### B-3 背包逐物品图标映射（`I-1`）—— 已判定，**无需修复**

2026-09-29 经 NAS 拿到目标 EI 服务端物品表
（`/data/NAS/TMP/Mud3/Envir/stditem.dat`，已有解码
`docs/research/mud3-dat-decoded/stditem.json`，`Looks` = 外观图 ID），
并与 Zircon `ItemInfo.Image` 对照：

- **帧号空间同一**：Gold 0 = 金币 0、Iron Sword 1043 = 铁剑 1043、Candle 290 = 蜡烛 290；
  按 (Price,Weight) 配对的 533 件中 364 件数值相等，其余多为「同价同重的不同物品」误配。
- **图标库内容同一**：`Data/Inventory.Zl` 的 0..1439 帧与目标 `inventory.wil` 同号帧
  尺寸一致（496/499 可解码项）、肉眼一致、平均 RGB 差 ≈5（BC7 重编码）。
- 残余：本机服务端物品库是 Zircon 上游英文集（1078 件），目标 EI 是中文 1143 件
  → 逐物品 1:1 是**部署数据**问题，不是客户端缺陷。
- 待查（不影响实现）：`Commoner Outfit` Image=941 vs `布衣（男）` Looks=940 的 1 之差。

**判定**：客户端机制（帧号 → `Inventory` 库）正确，不修。

### B-4 背包 F280 gauge 的最终屏幕换算（`I-2`）

已闭合部分：F280 源帧 16×424、填充区 12×218、构造参数 (6,12,218,12,vertical)、
`(x+0xF8, y-0xA5)`、value=`[bag+0x58]`、max=94（= 100 行占位表 − 6 可视行）。
未闭合：原版 `0x4179B0` 把 (x,y) 当**相对父对象**的起点，其最终屏幕矩形与
「94 是行数还是定点尺度」仍标 candidate（见 `trade-window-closure-evidence.json`
的 split 量纲 tension）。

**需要**：运行时捕获一次原版 gauge 的屏幕矩形（本机无原版运行环境 → 需 Windows 主机）。
**在那之前**：Godot 自绘轨道 + 拖柄保留。

### B-4b legacy 键盘绑定：14/16 已覆盖，F→行会 缺失（`CONFIRMED_DIFFERENCE`）

**纠正**（2026-09-30 复核）：上一轮称「全表反向」是**错误**的。GameScene 的
`_UnhandledKeyInput` 在 `AutoLoginArgs.LegacyUi` 下有 10 个键的 EI 语义覆盖
（`GameScene.cs:10877-10978`）：

| EI 键 | EI 语义 | Godot legacy 覆盖 | 状态 |
|---|---|---|---|
| Q | 包袱栏 | `Key.Q`→Toggle InventoryDialog ✓ | MATCH |
| W | 状态栏 | `Key.W`→ToggleCharacterWindow ✓ | MATCH |
| E | 技能书 | `Key.E`→Toggle MagicDialog ✓ | MATCH |
| R | 聊天记录 | `Key.R`→LegacyChatDialog ✓ | MATCH |
| N | 设置 | `Key.N`→OpenConfigDialog ✓ | MATCH |
| G | 组队 | `Key.G`→GroupWindow ✓ | MATCH |
| D | 信息窗口(任务) | `Key.D`→Toggle QuestDialog ✓ | MATCH |
| C | 交易栏 | `Key.C`→TradeRequest ✓ | MATCH |
| S | 坐骑 | `Key.S`→ToggleHorseWindow ✓ | MATCH |
| T | 小地图切换 | `Key.T`→MiniMap toggle ✓ | MATCH |
| Z | 腰带 | KeyBindManager `Key.Z`=BeltWindow ✓ | MATCH |
| V | 小地图 | KeyBindManager `Key.V`=MapMiniWindow ✓ | MATCH |
| Alt+Q | 退出游戏 | KeyBindManager `Alt+Q`=ExitGameWindow ✓ | MATCH |
| Alt+X | 注销人物 | KeyBindManager `Alt+X`=LogoutCharacter ✓ | MATCH |
| **F** | **行会** | KeyBindManager `Key.F`=BlockListWindow ✗ | **CONFIRMED_DIFFERENCE** |
| **B** | **技能图鉴** | KeyBindManager `Key.B`=MapBigWindow ✗ | **= B-5** |

→ legacy 模式下 14/16 键已与 EI caption 一致；只剩 **F→行会** 和 **B→技能图鉴**（B-5）。

**修复方案（F→行会）**：在 `GameScene._UnhandledKeyInput` 的 legacy 覆盖层加
`if (LegacyUi && key.Keycode == Key.F && !Alt && !Shift) → OpenGuildDialog(); return;`。
最小、可逆、与现代 `Key.F`（FilterDrop/BlockList）不冲突（legacy 下被覆盖）。
**推荐**：执行。

### B-5 HUD cap2「技能图鉴」动作（`H-1`）

原版 cap2 点击只翻转 `[hud+0x6208]` 布尔 flag（`0x42C241`），该 flag 的**消费者未闭合**；
Godot 把它映射成打开技能书（与 cap8 重复）。

**需要**：定位 `[hud+0x6208]` 的读取点（全二进制扫描 `mov al,[reg+0x6208]` 类模式）。
本轮未做完 → 登记。
**推荐**：找到消费者后按原版改；找不到就保留 Godot 映射并标注。

### B-6 行会解散（`G-1`）

原版走掌门守卫 + 对话框 601 双确认；Zircon **没有 disband 客户端包**（`ClientPackets`
里只有 GuildLeave/GuildTransferLeader 等）。
**需要**：是否新增 `C.GuildDisband` + 服务端处理？这是**协议/持久化改动**，超出审计范围。

### B-7 任务列表 legacy 渲染（`Q-2`）

原版列表行：x=65、y=90+15·line、行距 15、可见 19 行、色 `0x1919C8`/`0x19197D`
（0x00BBGGRR → RGB(200,25,25)/RGB(125,25,25)），条目文本 >160px（`0x004475B8 cmp eax,0xa0`）
时换行（`0x44755C` 起的 wrap 路径）。
Godot legacy 仍渲染现代分组列表（x=8/18/28、金色/白色、分组标题/描述）。

**待确认**：原版列表**每条 entry 显示什么文本**（entry+4 指向的字符串是任务名？
含状态？）——需要继续追 quest-list 的服务器填充链（`[bag/quest+0x54]` 的写入点）。
**在那之前**：不擅自改，避免「按猜测换文本」。
**推荐**：找到填充链后按原版实现扁平列表（含 >160px 换行）。

### B-8 目标框 / 悬停名牌（`CONFIRMED_DIFFERENCE`，未实现）

**原版**（`target-box-evidence.json`，5 个组件，全部锚定 `HUD+0xE4/+0xE8`）：

| 组件 | VA | 原版行为 |
|---|---|---|
| 名字牌框 | `0x0040B850` | **代码绘制**（无 WIL 帧）：`0xA0A0A` 边框 + 名字文本；框宽贴文字宽 w，高 15px，位于锚点**上方** (anchor_y-0x1E .. anchor_y-0xF)，水平居中 `anchor_x+(48-w)/2` |
| 悬浮名字 | `0x0040B750` | 选择器 `0x566DD4`（ProgUse.wil）帧 2/3 |
| 悬停名牌 | `0x0040BB00` | 带 **3000ms** 保持门（`byte[HUD+0x620A0]`） |
| HP 条 | `0x0040A8A0` | 选择器元素 `0x5600FC + [HUD+0x8D]*0x144`，**帧号 = HP 值**（预渲染逐值条），400/300 中心公式 |

**Godot 现状**：
- `ObjectRenderer.Focused`（`ObjectRenderer.cs:40`）**只被 `GameScene.cs:9164` 赋值，全仓无任何读取** → **没有常驻目标框**。
- `ObjectRenderer.DrawName()`（`:573`）只在 `NameHovered` 时画名字 → 没有「目标名字牌框」，也没有 3000ms 悬停保持（Godot 是即时悬停）。
- 唯一的血条是 `MapObjectNode.DrawHealthBar()`（`:316`）：受击后 5 秒临时显示，用 **Interface 80 底 / 79 填充 + 裁剪**（源自 Zircon C# `MonsterObject.DrawHealth`），**与 EI 的「帧号 = HP 值」机制不同**。
- Godot 另有 `TargetOutlineColour` 圆点标记（移植版自加，原版无）。

**结论**：原版的目标框（名字牌框 + 逐值 HP 条 + 3000ms 悬停名牌）在 Godot **整体缺失**，
现有实现是另一套（hover 即时名字 + 受击临时血条）。

**修复方案**：按证据实现 —— 名字牌框（`0xA0A0A` 边框、贴文字宽、锚上方 15px）、
HP 条（`0x5600FC` 元素 + 帧号 = HP）、悬停 3000ms 门。属**新功能实现**，
建议单独一个 goal（需要逐类型选择器绑定 + 运行截图对照）。
**推荐**：纳入下一轮，不在本轮擅自半实现。

### B-9 原版客户端运行 A/B 与联机验收

- 原版为 Windows-only，本机无法运行 → 所有像素级结论保留版本门禁。
- 文档端口 7000 当前无实例（机器上只有并行 goal 的隔离实例监听 7001/3001，
  未接入以免干扰）→ 本轮修复的**联机**链路未跑。

## C. 阻塞（环境/资源，非决策）

| # | 项 | 阻塞原因 |
|---|---|---|
| C-1 | 目标 EI EXE/WIL/WIX 版本身份 | **已闭合**：NAS `/data/NAS/TMP/EI传奇3.0客户端/` 与本机 `LegacyEI/Data`、`mir2ei.before-path-fix-*` 逐文件 MD5 相同（Mir3.exe `264d848d…`、GameInter/Interface1c/inventory/Storeitem 的 wil+wix 全 SAME）。`/home/tetsuya/NAS` symlink 指向失效的 `/tmp/nas_mnt/NAS`，**改用 `/data/NAS`** |
| C-2 | 原版运行截图/抓包 | 无 Windows 环境 |
| C-3 | ~~旧版物品表~~ | **已取得**：`/data/NAS/TMP/Mud3/Envir/stditem.dat`（见 B-3） |
