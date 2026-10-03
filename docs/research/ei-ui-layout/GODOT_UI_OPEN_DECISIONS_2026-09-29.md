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
| A-10 | 背包 F161/162「关闭」是否偏差 | 判定 **不是确认差异**（保留现状） | `0x42BF85`：背包窗口输入 handler 后 `test eax,eax` 决定是否 `0x42ADB0(hud,0)`；点 X 命中其装饰 vtable（只播音）后仍落到同一背景路径 → 原版也会关。**注**：该结论依赖的「返回 0 = 未消费」约定在 §B-1 的复核里被标为**未闭合**（与交易 close/accept 的 return 描述冲突）。但「不是确认差异」仍成立——现有证据**不足以证明**原版不关，故保留现状、不据此改 | 本轮新证据 |
| A-11 | legacy 行会窗去掉「创建行会」页 | **去掉了**（`752a41cc`） | 原版 id4 的 9 个控件里没有建会入口；**原版建会是 GM 指令** `AddGuild <gname> <mastername>`（`ObjBase.pas:24263-24266` → `CmdCreateGuild`，`:19835`），普通玩家从 UI 也建不了会。Zircon 侧等价物是 `@createGuild`（`ServerLibrary/Envir/Commands/Command/Admin/CreateGuild.cs`）→ **能力未被移除**（与原版同）。故 legacy 隐藏现代建会页属 1:1 修复，非功能回归。真机截图佐证（`02-guild-window-after-F.png`） | `752a41cc` |
| A-12 | `WindowManager` 对已释放窗口崩溃 | 加 `IsAlive` 守卫（`Open/Close/Toggle/CloseTop/BringToFront/RefreshZOrder`） | 真机复现：按 R 关聊天窗时 `OpenWindows` 残留一个已释放窗口 → `RefreshZOrder` 写 `ZIndex` 抛 `ObjectDisposedException`（`WindowManager.cs:79`），整轮 Z 序刷新中断。属健壮性缺陷，非 UI 布局差异 | `607418c1` |
| A-13 | F350 聊天窗位置 | 改为 EI 构造实参 **(114,76)** | `layout.json` / main-init 实参 `0x427839` 给 `window.chat-pop` (114,76)；`LayoutHud` 末尾的既有约定就是「旧版窗口坐标来自 exe 构造参数、**不是居中布局**」，而 `LegacyChatDialog` 是**唯一漏掉**的一个（构造期用屏幕居中 → (114,106)）。x 巧合同为 114；y 差 30：居中值使窗口底边 106+388=494 压进 HUD 顶边 465 约 29px，原值 76 时底边 464 正好贴在 HUD 之上。真机截图量到 (114,~104)，与居中值一致、与证据不符 | 见 §11 |

## B. 待决（需要用户决策或需要目标资源/协议，本轮不擅自改）

### B-1 窗口「点击背景」的语义 —— **降级为 `UNVERIFIED`（我上轮的判定未经验证）**

**2026-09-30 补充证据（机制更清晰，结论仍不闭合）**：
- `0x0042BF85`（`0x42C4D4` 跳转表的 case 0 目标）是一个**3 参调用点**：
  `push ebp; lea edx,[esi+0x20]; push ebx; push edx; lea ecx,[esi+0x6554]; call 0x4300F0`
  → arg1=`esi+0x20`（消息结构：`[edi]`/`[edi+4]`/`[edi+8]`/`[edi+0xC]` 全 0 判定 + `byte[edi+0x3A]`
  + `word[edi+0x40]` 键码，含 0x14/0x15/0x46 特判）、arg2=ebx、arg3=ebp；
  与 `0x4300F0` 末尾的 **`ret 0xC`** 自洽（此前误把 `0x4306AE/0x4306B8` 的 `ret 8` 当成它的返回——那两个属同段内另一个 5-pop 函数）。
- `0x4300F0` 语义 = **窗口消息分发器**：先做 300ms 去抖（`[esi+0x23788]`）与 2000ms/1000ms
  键码过滤（`[esi+0x23784]`），随后 `0x417E60`（F280 gauge）、再沿 `[esi+0x5C]` 的
  `vtable+0x10` 逐个把消息交给子控件；**任一子控件返回非 0 → 本函数返回 1（已消费）**，
  全部返回 0 则继续下一个子控件。
- `0x42ADB0(this=UI, id)` = **按窗口 id 的显示/隐藏切换**（`cmp eax,0xF; jmp [eax*4+0x42B3E4]`；
  id 0 分支读 `[esi+0x6584]` 标志决定 `[bag].vtable+0x10(0/1)`）。
- 组合起来「子控件消费 → 调用方 toggle」在语意上仍不能解释为「点背景关窗」，
  且该路径更可能是**热键/焦点消息**而非鼠标点击 → **结论保持 `UNVERIFIED`**：
  实现侧仍不引入「点窗口背景关窗」。

**2026-09-30 复核更正**：上一轮我据 `0x42BF85` 的
`call 0x4300F0(bag, 鼠标); test eax,eax; je 0x42C198(尾部); … 0x42ADB0(hud,0)`
判定「handler 返回 0 → 关窗」，并把这条推广成「点窗口背景 = 关闭该窗口」。

**该判定未闭合**，理由：
1. `0x4300F0` 区间的返回指令有 `ret 0xc` / `ret 8` / `ret` 三种（`0x4301C3`…`0x4306DC`），
   说明那段包含**多个函数**；`0x4300F0` 的入口与 `ret 8` 尾部的对应关系未逐条核。
2. 语义自相矛盾：交易证据里 **accept 按钮「returns 0 (not consumed)」**、
   **close 按钮「returns 1 + consumed」**；若「非 0 → toggle」，则 accept 不关窗 ✓、
   但 close 会把窗口 toggle 成**隐藏**，与同一证据写的
   `close.behavior = "window stays open"` **冲突**。两者不能同时成立。
3. 因此「0/非 0 哪个代表已消费」以及「click 分派是否在 mouse-down」都还没定；
   在这一步之前**不能**据此改 Godot 的任何窗口关闭行为。

**待闭合**：逐条解 `0x42C198`（共享尾部语义）、`0x4300F0` 的 `ret 8` 尾部返回值、
以及 `0x42C4D4` 的调用点（`_Input` 的 mouse-down/up 分支）。

**因此**：B-1 降级为 `UNVERIFIED`，**不实现**（此前记录的「DXControl 无拖拽阈值」
仍是实现前必须解决的前置条件，但已不是当前瓶颈）。

（原记录保留在下）

**原版事实（primary-static，待复核）**：子窗口点击分派 `0x42C4D4` 每个 case 的形态一致 ——
先调该窗口自己的输入 handler，**返回 0 就 `0x42ADB0(hud, id)` 切换关闭该窗口**：

| id | 窗口 | 输入 handler | 关闭调用 |
|---|---|---|---|
| 0 | 背包 | `0x4300F0`（`0x42BF85`） | `0x42ADB0(hud,0)` |
| 1 | 状态 | `0x44CCD0`（`0x42BFB3`） | `0x42ADB0(hud,1)` |
| 3 | 交易 | `0x416EF0`（`0x42C00B`） | `0x42ADB0(hud,3)` |
| 4 | 行会 | `0x4258F0`（`0x42C039`） | 同形 |

**为什么没直接改（已核实前提）**：本轮查了 `DXControl._GuiInput`
（`Controls/DXControl.cs:262-290`）：`MouseClick` 在 **press 后 release 即触发**，
**没有任何拖拽距离阈值**（`_dragging` 只用于 `MouseMove` 分支，release 时照样
`MouseClick?.Invoke`）。所以在 Godot 里「窗内按下 → 拖动 → 在窗内松手」会误判为点击；
直接照搬 B-1 会让**每次拖拽窗口/物品都以关窗收尾**。

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

### B-2 交易 close 热区 (532,350) 的关窗行为 —— **已修复（`131a3514`）**

原版该热区**在 484×330 窗口矩形之外**，窗口命中测试 `0x42AAB0` 按窗口 rect 分派，
因此该热区实际**不可达**；其自身行为是「播音 + 消费点击，窗口保持打开」
（`trade-window-render-evidence.json::buttons.close.behavior`）。Godot 把同一坐标的
按钮绑成 `CloseTrade()`，多出一个非原版的「窗口外可点关闭」入口。

修复：legacy 下该热区不关窗（保留 DXButton 以得到原版一致的点击音效），
关闭入口保留 Esc / `WindowManager.CloseTop`。

**验证**：`dotnet build` + `--legacy-audit` 全项 PASS（trade=True）。
**点击行为本身 UNVERIFIED** —— 需要第二玩家才能真正进入交易态（见 B-9）。

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

**2026-09-30 反汇编补充（量纲悬案已闭合）**：`0x4300F0` 的 F280 gauge 命中分支
（`0x430681 lea ecx,[esi+0x278]; call 0x417C80` 返回非 0，即拖柄被拖动）执行

```
fld  [esi+0x284]        ; gauge 位置（0..1）
fmul [0x476650]         ; = 94.0f
call 0x468520           ; 取整
mov  [esi+0x58], eax    ; 背包滚动字段 = round/截断(gauge 位置 × 94)
```

→ **`[bag+0x58]` 与 gauge 位置成正比、上界恰为 94**，即 94 是**行单位**的滚动上界
（100 行占位 − 6 可视行），不是定点尺度；`0x476650 = 94.0f` 就是 gauge→行的换算常数。
拖柄的屏幕几何仍依赖 `0x4179B0` 的相对父对象换算（未闭合部分保留）。

未闭合：原版 `0x4179B0` 把 (x,y) 当**相对父对象**的起点，其最终屏幕矩形尚未确定
（见 `trade-window-closure-evidence.json` 的 split 量纲 tension；「94 是行数还是定点尺度」
一节已由上面的 `×94.0` 公式闭合）。

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

### B-5 HUD cap2「技能图鉴」动作（`H-1`）—— 消费者已闭合，**已修复**

**原版（primary-static，2026-09-30 解出）**：
- cap2（`0x42C241`）与 B 键（`0x42CE29`）都只翻转 `[hud+0x6208]` 布尔 flag；
  初值由 `0x42711D` 写 **0**（`xor ebx,ebx` 后 `mov [esi+0x6208],ebx`）。
- 该 flag 的唯一消费者在 HUD paint 内（`0x429607` → `0x42A850`）：
  `[hud+0x6208] == 0` 时 `je 0x42AAA4` **直接跳过整段图标绘制** → 默认不显示。
- flag != 0 时画的是**一行 12 个技能图标**：
  - 数据 = `hud+0x52E45` 起逐字节（每个 icon 索引一个 byte）；
  - 图标 = selector `0x566C90`（**MIcon**，本机 1106 帧）帧 **`byte + 0x3E7`(999)**；
  - 步距 = `0x28`(40)，且索引 4/8 处额外 +0x28 → **每 4 个一组多一个间隔**；
  - 缩放 `0x3F169697 ≈ 0.588`（64×64 图标 → ≈37.6px），循环上限 `esi+ebp < 0xC`(12)。

**12 槽 = F1–F12 技能条**；Godot 的 `MagicBar` 正是「12 列技能条」→ 同一概念。

**Godot 差异**：`cap2` 此前打开**技能书**（与 cap8 重复）；`B` 打开**大地图**；
技能条恒显。

**修复**（本轮）：
1. legacy 下 `cap2`(SkillEntryButton) → toggle `_magicBar`（不再开技能书）；
2. legacy 下 `B`/Ctrl+B → toggle `_magicBar`（大地图仍可由小地图按钮打开）；
3. legacy 下 `_magicBar` **默认隐藏**（对应 flag 初值 0），由 cap2/B 显示。

**残余（2026-10-03 已闭合）**：EI 用 MIcon 帧 `999+技能ID`（64×64 画布 / 40×40 内容），
Godot `MagicBar` 原来用 `MagicInfo.Icon`（40×40 书页帧）+ GameInter2 现代边框 →
图标**帧号空间与尺寸不同**。本轮把三段证据补齐：
1. **`0x466800` 不是缩放矩阵**：它 `rep stosd` 清零 `0x44`(68) 字节后只写 8 个 float
   （`[0]=[4]=[0x10]=[0x14]=arg2`、`[8]=[0x18]=arg3`、`[0xC]=[0x1C]=arg4`），
   68 字节 = **D3DMATERIAL9**（4×D3DCOLORVALUE 16B + Power 4B），且该指针最终进
   `0x4542F0` 的 `[surface+0x40](this, material)`。同一槽位在 `0x402DC9` 被用于
   **纯色矩形填充** → 是颜色/alpha，不是缩放。
   数值也自洽：`0x3EC8C8C9=100/255`、`0x3F169697=150/255`、`0x3F48C8C9=200/255`。
2. **帧按原生尺寸 1:1 绘制**：MIcon 64×64 帧的实心内容只有左上 **40×40**
   （alpha bbox 实测 45/46 帧 = `(0,0,40,40)`），与 `0x28`(40) 步距**正好对齐**；
   原先「0.588 缩放 → 37.6px」与 40px 步距自相矛盾。
3. **EI 技能ID ↔ Zircon `MagicInfo.Icon`**：技能书帧 = `2*ID-2`，即 `Icon` 本身就是
   EI 书页帧号 → `ID = Icon/2 + 1`，技能条帧 = `999 + ID = 1000 + Icon/2`。
   逐条名称交叉验证全部一致：Swordsmanship↔#3 基本剑术、Slaying↔#7 攻杀剑术、
   Thrusting↔#12 刺杀剑术、HalfMoon↔#25 半月弯刀、FlamingSword↔#26 烈火剑法、
   ShoulderDash↔#27 野蛮冲撞、DragonRise↔#35 翔空剑法、FireBall↔#1 火球术 …；
   `Magic.exp` 的 50 条 ID 与 MIcon 帧 1000..1105 一一对应
   （EI 无 28 号技能 ⇔ MIcon 无 1027 帧）。
4. **空槽底板 = `GameInter.wil` 帧 20..31**：12 帧 64×64（内容 40×40），画面里已烘焙
   `F1`..`F12` 字样；`LegacyEI/Data/*.wil` 全库只有 GameInter 满足「20 起连续 12 帧 64×64」。
   `0x42A9A4` 的 `edi+esi` = `0x14+i` 即帧 `20+i`，取不到时（`0x42A8C3`）同样退回该底板。

5. **位置 = 屏幕左上角**（2026-10-03 第二轮）：每格 pos 为 `(runningX, 2|3)`，
   `0x4542F0` 的 `x-400` / `y=300-y` 只是绝对屏幕坐标 ↔ 居中世界空间的换算
   （常量 `0x476474`=400.0、`0x476470`=300.0）；同一路径的 `0x428F80` 元素
   pos=(220,400)/size=(358,165) 换算回来正好落在它自己的屏幕矩形
   `(220,400)-(578,565)` 中心 → 投影为 `screen = world + (400,300)`，pos 即屏幕左上角。
   故原版是**屏幕左上角固定行**，挂在主底栏旁是 Zircon 的排布。
   Godot legacy 已改为 `LegacyEiAnchor=(0,0)` + 每格 y=2/3。
   另：全 `.text` 只有 `0x42A893` 一处带 4/8 分组判断 → 原版无同几何点击命中，该行为纯显示。

**像素级验收**：800×600 legacy 真机截图与 `LegacyEI/Data` 源帧逐像素比对 ——
7 个空槽（帧 23..29）@y=3、5 个有绑定槽 @y=2 全部 **0 像素不符**，且后者逐帧唯一匹配到
MIcon 1000/1004/1008/1029/1016（= ID 1/5/9/30/17 = 火球术/大火球/地域火/召唤神兽/召唤骷髅），
与 `1000 + MagicInfo.Icon/2` 逐条吻合。
Godot 实现：`GodotClient/Controls/MagicBar.cs::DrawLegacyEi`（仅 legacy 模式）。

### B-6 行会解散（`G-1`）

原版走掌门守卫 + 对话框 601 双确认；Zircon **没有 disband 客户端包**（`ClientPackets`
里只有 GuildLeave/GuildTransferLeader 等）。
**需要**：是否新增 `C.GuildDisband` + 服务端处理？这是**协议/持久化改动**，超出审计范围。

### B-7 任务列表 legacy 渲染（`Q-2`）—— **数据源已闭合；Godot 侧受协议约束（`BLOCKED-协议`）**

**2026-09-30 第五轮：找到数据源（前四轮的缺口是查错了窗口基址）**

- 前几轮扫描的是 `winmgr(=ROOT+0x2A548C)+0x516E8` —— 那是 winmgr 里该窗口的**槽位**；
  **封包处理器直接用 `ebx + 0x2D8614`**（ebx = 客户端根对象），所以按 `0x516E8` 找不到数据路径。
- 处理器在 `0x41F92B`（同一 switch 的兄弟分支见 `0x41F96C`）：
  ```
  lea  ecx,[esp+0x171C]        ; 栈上缓冲
  add  esi,0x10                ; 跳过包内 16 字节
  push 0x2800 ; push ecx ; push esi ; call 0x452810   ; 拷贝字符串
  mov  edx,[esp+0x16] ; and edx,0xFFFF               ; 16 位条目 id
  mov  byte [esp+eax+0x171C],0                       ; NUL 结尾
  push edx ; push eax                                ; (id, text)
  lea  ecx,[ebx+0x2D8614]                            ; ← 任务窗
  call 0x44F480                                      ; AddEntry / 重建列表
  ```
- `0x44F480`：先释放既有节点（文本用 `0x4680F8` 释放 ✓），空文本直接返回；
  否则 `push 0x2F`（`'/'`）**按 '/' 切分服务端字符串**后逐条追加到 `+0x648` 的列表
  （列表节点 16B：vtable `0x476AD4/0x476AD8`、文本 `@+4`、prev `@+8`、next `@+0xC`；
  列表对象 `@+0x648`，vtable `0x476AB8`，Add 在槽 3 = `0x44FEF0`）。`+0x64C` 是头指针，
  全 `.text` 仅 6 处引用（2 处构造 + 窗口自身方法）→ 外部只经窗口方法写入。
- **结论**：原版每个条目的文本 = **服务端下发的字符串**（16 位 id + 文本，'/' 分隔），
  客户端不做本地拼装；渲染仍是已记录的扁平行（x=65、y=90+15·line、19 行、>160px 换行、
  `0x1919C8`/`0x19197D` 交替色）。
- **对 Godot 的影响**：要 1:1 需要同样的服务端数据；Zircon 协议是否下发等价的任务字符串
  属**协议/数据决策**（并可能改动持久化行为）→ 按既定纪律**标 `BLOCKED-协议` 并跳过**，
  不改渲染层（避免用本地拼装伪造 entry 文本）。

原版列表行：x=65、y=90+15·line、行距 15、可见 19 行、色 `0x1919C8`/`0x19197D`
（0x00BBGGRR → RGB(200,25,25)/RGB(125,25,25)），条目文本 >160px（`0x004475B8 cmp eax,0xa0`）
时换行（`0x44755C` 起的 wrap 路径）。
Godot legacy 仍渲染现代分组列表（x=8/18/28、金色/白色、分组标题/描述）。

**待确认**：原版列表**每条 entry 显示什么文本**（entry+4 指向的字符串是任务名？
含状态？）——需要继续追 quest-list 的服务器填充链（`[bag/quest+0x54]` 的写入点）。
**在那之前**：不擅自改，避免「按猜测换文本」。
**推荐**：找到填充链后按原版实现扁平列表（含 >160px 换行）。

**2026-09-30 补充扫描**：`window.quest` 对象 = winmgr 基址 + `0x516E8`
（winmgr = ROOT `0x47EF18` + `0x2A548C`）。扫描 `.text` 全量引用：
`disp32 0x516E8` 命中 **23 处，全部落在 UI 区**（`0x426DD4`…`0x42B768`，
含 init/可见性分派/位置分派/表项），**没有一处是网络消息处理器**；
`imm32 0x775A8C` / `0x775AE0`（对象与列表头的绝对地址）**0 命中**。
→ 原版任务列表**不是**消息处理器按窗口偏移直接填充的；入口更可能是回调/注册表，
或列表数据来自另一对象。entry 文本语义仍未闭合，保持 `CONFIRMED_DIFFERENCE`（未修）。

**第三/四轮排查（2026-09-30，均未命中）**：
- 列出全部 23 处 `[winmgr+0x516E8]` 引用并逐处反汇编 ±40B：**没有一处**在同一段里
  访问列表头 `+0x54` 或游标 `+0x1E4/+0x1E8`。
- 按节点 stride 搜 `push 0x104`：34 处命中，全部是通用大小/常量（`0x104` 也出现在
  技能窗列表），无法据此定位任务列表。
- 客户端二进制里的文件名串只有 `.\Data\{CreateChr,StartGame,ei_login,wemade,~Mir3Patch}.dat`
  + `Chat.txt` + `Magic.exp` + `MInfo.Dat` + `Manual.exe`（`Manual.exe` 是独立帮助程序，
  不是任务列表来源）。
→ 结论：**原版任务列表的数据来源仍未闭合**；已排除「消息处理器按窗口偏移填充」、
  「客户端本地文件读取」两条路径。下一步需要从 `0x42C4D4` 的注册表/回调反查。

### B-8 目标框 / 悬停名牌（`CONFIRMED_DIFFERENCE`，**名字牌已实现，HP 条仍缺**）

**原版**（`target-box-evidence.json`，5 个组件，全部锚定 `HUD+0xE4/+0xE8`）：

| 组件 | VA | 原版行为 |
|---|---|---|
| 名字牌框 | `0x0040B850` | **对当前目标**（`[ROOT+0x364444]`，调用点 `0x41C063`）画名字：**同一段文本画 3 次**（rect ±1 偏移）形成 1px 描边，三次颜色都是 `0xA0A0A`（`0x00BBGGRR` → RGB(10,10,10)）；矩形 = `(anchor_x+(48-w)/2, anchor_y-0x1E) … (anchor_x+(w+48)/2, anchor_y-0xF)`，即宽 w+48、高 15px、水平中心 `anchor_x+24`、位于 `anchor_y` 上方 15~30px。**不是矩形边框**（2026-09-30 反汇编定案） |
| 悬浮名字 | `0x0040B750` | 选择器 `0x566DD4`（ProgUse.wil）帧 2/3 |
| 悬停名牌 | `0x0040BB00` | 带 **3000ms** 保持门（`byte[HUD+0x620A0]`） |
| HP 条 | `0x0040A8A0` | 选择器元素 `0x5600FC + [HUD+0x8D]*0x144`，**帧号 = HP 值**，400/300 中心公式 |
| 悬停实体重绘 | `0x00437DF0` | `word[this+0x13C]` vs `[this+0xE4]` |

**Godot 现状（修复前）**：`ObjectRenderer.Focused` 只被赋值从未被读取 → 无目标框；
`DrawName` 只在 `NameHovered` 时画名字 → 目标的名字**鼠标一移开就消失**；
唯一的血条是受击 5 秒的 Interface 80/79 裁剪（源自 Zircon C# 客户端）。

**本轮已实现**（`IsTarget` 状态 + `RenderPrimitives.DrawTargetNamePlate`）：
- GameScene 每帧把 `ob.IsTarget = (ob == _combatController.TargetObject)`（其它玩家同理）；
- `ObjectRenderer` / `PlayerRenderer` 对当前目标画名字牌：名字画 3 次（`(-1,-1)`/`(+1,+1)`/`(0,0)`），
  颜色 RGB(10,10,10)，水平居中于 `x=24`，垂直居中于 y 带 **-30..-15**（= 原版矩形换算到
  Godot 节点坐标；Godot 节点原点 == 原版 anchor，见下）。

**本轮（续）已实现 —— 悬停名字 3000ms 保留**
- `0x0040BA60`（设置悬停名字）= `0x45E200(lib 0x8AB7A8, 0x90, &HUD+0x61C8C, &HUD+0x620A0, buf)`
  + `sprintf(HUD+0x621A4, "%[^`]%*c %[^`]%*c …", HUD+0x621A4, 0x622A8, 0x623AC, 0x624B0,
  0x625B4, 0x626B8, 0x627BC, 0x628C0)`（8 个反引号分隔字段，缓冲步长 0x104）
  + 结尾 `mov dword ptr [esi+0x6209C], 0` → **重置计时器**；
- `0x0040BB00` 每帧 `[HUD+0x6209C] += 帧间隔`，`> 0xBB8 (3000)` 时
  `memset(HUD+0x620A0, 0, 0x104)` + `memset(HUD+0x621A4, 0, 0x820)` 清名；
- 绘制锚点：`(anchor_x-0x2C, anchor_y-0x37)` 起，文本水平居中。
- Godot 实现：`MapObjectNode.NameHoldUntilMs` / `RefreshNameHold()` / `NameHoldActive`
  （`PlayerRenderer` 因不继承 MapObjectNode 各存一份），
  `RenderPrimitives.HoverNameHoldMs = 3000`；GameScene 每帧对悬停对象调 `RefreshNameHold()`，
  节点 `_Process` 到期清标记并重绘；`ObjectRenderer.DrawName` 与 `PlayerRenderer` 的
  名字/公会/聊天行都改用 `NameHovered || NameHoldActive`。

**仍未实现（记录）**：
- **目标 HP 条 —— 记为 `BLOCKED`（库身份不可静态确定）**。2026-09-30 补充反汇编：
  - `0x0040A8A0` 经 `0x4542A0`（ecx=`0x5600FC`，`type=byte[HUD+0x8D]`）取库，再 `0x466130(lib, frame)` 取帧；
  - **帧号 = `0x2710 (10000) + (A % 0x190 (400))`**（`0x40F6D2-0x40F6E5`：
    `A = [HUD+0x629C8]*400 − byte[HUD+0x8A]*3000 + [HUD+0xC4] − 0xAA0`，只存 `A` 到 `+0x62A20`）；
  - 矩形 = `SetRect(anchor_x+frame.offX, anchor_y+frame.offY, …+frame.w, …+frame.h)`
    （帧自带的 offset/size，与其它精灵同一规则）；
  - 每类型的 9 个配置字节（`HUD+0x61BAA…61BB6`）含 RGB 与 alpha，`×0.003922f`（即 /255）
    → **该条是可按类型染色的单通道图**；
  - 库来自 `0x5600FC + type*0x144`（**静态数组 140 槽，按 14 一组**：
    `0x43B770` 起始槽 = `(byte[ebx+0x124]+1)*14`，加载走 `0x4660E0(slot, 0x56B22C+idx*0x104, 1)`）；
  - `type` 来自运行时类型库 `0x8AA5A8`（记录步长 0x30，匹配 `word[rec+0xC] == type`），
    而 `0x5600FC`/`0x56B22C`/`0x8AA5A8` 全在 `.data` 的**零填充区**（rsize 仅 0x5000，vsize 0x49EFD4）
    → **路径表与类型库均在运行时由服务端数据构建，二进制里没有静态文件名**；
  - 资源侧核对：EI `Data/` 内 86 个 WIL 中 **无 ≥10400 帧的库**（`Mon-1.wil`/`MonS-1.wil` 恰为
    10000 帧，正好卡在 10000 之前）；客户端根的 `MInfo.dat`(42152B) 是编码/压缩数据，无明文路径。
  - **结论**：忠实实现需要运行时取得该库，当前环境（无 Windows）不可得 → `BLOCKED`。
    下一轮可选路径：在 Windows 上抓 `0x5600FC+type*0x144` 的库指针/文件名；
    或从服务端（Mud3 Envir）的怪物类型配置反查类型→库映射。
  - **2026-10-01 追加排除（缩小搜索空间）**：
    (a) 86 个 EI WIL 中**没有 ≥10400 帧的单文件库**（`Mon-1/MonS-1` 恰 10000，卡在 10000 之前）；
    (b) 若该库是多文件 MirLibrary 且第二文件是 `MonS-N.wil`（同 10000 帧）→ 帧 10000..10003
        应等于 `MonS-1` 帧 0..3，实测为 68×70 之类**怪物精灵**、帧 4..7 为空 → **不是血条**；
    (c) 对全部 86 个 WIL 做「宽扁」（`w >= 4h 且 h<=40`）形状扫描：**0 个候选** →
        血条不在任何库的 0..7 帧处（与「索引在 10000+」一致，但也说明它不是单文件库的表头帧）。
    → 剩余可能：多文件 MirLibrary 的其它组合、或运行时由服务端下发的资源集合；
      仍需 Windows 运行时取值，维持 `BLOCKED`。
- **悬浮名字底板（`0x0040B750`）**：反汇编显示它用选择器 `0x566DD4` 逐帧取
  `0x466130(sel, 2)` / `0x466130(sel, 3)`，命中则用 `0x45FD50` 画在
  `(anchor_x+7, anchor_y-0x38)`；两帧实际尺寸为 **32×4**（WIL 头 offsetX=-24/-24, offsetY=-16），
  即很小的横条，与「名字底板」不符 → **语义仍不确定，标 `LIKELY`，暂不实现**（避免猜测性硬编码）。

**锚点推导（2026-09-30，已可直接落地）**
- 原版 box：`left = anchor_x + (48-w)/2`、`right = anchor_x + (w+48)/2`、
  `top = anchor_y - 0x1E`、`bottom = anchor_y - 0xF` → 中心 = `anchor_x + 24`（48 宽瓦片的中心）。
- Godot `DrawName` 用 `new Vector2(24f, y)` 画名字 → **Godot 节点原点 == 原版 anchor（瓦片左边）**，
  故 box 直接落到 `origin.x + 24`（水平居中）、`origin.y - 30 .. -15`。

### B-10 状态窗装备槽数量 —— **已核实为 `MATCH`（原假设有误，2026-10-01 更正）**

- **原假设（错误）**：以为 Godot 建 17 个装备槽（源自类注释 `CharacterDialog.cs:14` 的
  "17 个基础装备槽 (EquipmentSlot 0-16, 钓鱼槽 17-21 不建格)"），与 EI 各窗数组（11/24/46）不符。
- **核实结果**：`Grid = new DXItemCell[17]` 只是**创建池**（`CharacterDialog.cs:292-294`）；
  真正判定可见性的是 `AuditLegacyEiLayout`（`:627-676`）：`expectedSlots` 是 **11 项**
  （Weapon 60×90 / Armour 53×84 / Necklace 49×33 / Helmet / Torch / BraceletL / BraceletR /
  RingL / RingR / Shoes / Poison），并要求每项 `cell.Visible`、位置与尺寸与原版一致 →
  审计输出 `visibleSlots=11` 且 `ok` 要求 `visibleSlots == expectedSlots.Count`。
- **与原版一致**：矩阵 §3 第 1 行（人物状态）记录的 EI 权威值为
  「F200 244×328；**8 个 38×38 装备格 + 3 非方格区（11 记录）**」；
  本次另由构造反汇编佐证：id1 窗（`0x44AF50`）槽记录数组 = **11 × 0xC24**
  （见 `ei-window-slot-arrays-2026-10-01.json`）——与"11 记录"吻合，
  也把 id1 与「人物状态窗」身份绑定（此前 B-10 的待办项）。
- **结论**：`MATCH`，无需改动。原 B-10 的 `LIKELY_DIFFERENCE` 作废。

### B-11 确认框输入框位置（`LIKELY_DIFFERENCE`，锚点来源已更正）

- 旧的读法「输入框锚点 = mouse+0xDF/+0x23A」**是误读**（2026-10-01 更正）：
  `0x00418568`/`0x0042761C`/`0x0042B191` 的 X/Y 来源是全局量对
  **`[0x8AB7F0]`/`[0x8AB7F4]`**（一个 RECT 的 left/top）；同一对地址在
  `0x4118E0`/`0x411E2C` 处配合 `GetCursorPos`(IAT `0x476240`) + `PtInRect`(IAT `0x4762B4`)
  做命中测试 → 它是 RECT，不是鼠标坐标。
- MoveWindow 参数：`MoveWindow(chatHwnd=[0x8AA48C], rect.left+0xDF, rect.top+0x23A, 0x162, 0x10, 1)`
  （354×16 ✓）。**三个调用点常量完全相同**（转账金额 / 丢金币 / 建行会名称）→
  输入框位置**与具体对话框无关**，故 Godot 现在「框内水平居中、按钮上方」的摆放**可疑**。
- **未闭合**：该 rect 的身份（应为 UI 对象的客户端区 rect）与其运行时值 → 最终屏幕位置未知；
  且这三个对话框在隔离测试服上难以到达 → 不做结构性改动（把输入框挂到 UI 层属结构变更）。
- **处理**：Godot 侧仅更正注释与诊断文本（`LogoutConfirmDialog`，commit `23d073b1`，无行为变更）；
  事项保留为 `LIKELY_DIFFERENCE`，待 rect 身份闭合后再定位置。

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
