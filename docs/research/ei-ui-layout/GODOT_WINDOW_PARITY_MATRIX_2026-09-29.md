# GodotClient ↔ EI 原版 逐窗口一致性对照矩阵（2026-09-29）

> 本文件是「GodotClient 原版 1:1 一致性审计」的**可持续更新**交付物。
> 判定依据是**原版客户端**（EI 3.0 `Mir3.exe` 反汇编证据 + `GameInter.wil` 资源）
> 与 Zircon `Client/`（移植来源），**不是** Godot 版现状。
>
> 相关文件：
> - 原版逐窗口证据：本目录 `window_layout.json`、`*-render-evidence.json`、
>   `layout.json`、`UI_COVERAGE_MATRIX.md`
> - Preview 源码对照：`../../source-vs-reverse/README.md`（D0/D8：几何不可互推）
> - Zircon 侧总审计：`../../ORIGINAL_GODOT_PARITY_AUDIT.md`（渲染/网络）
> - Godot 侧实现入口：`GodotClient/Controls/LegacyUiSkin.cs`（legacy 分发器）、
>   各窗口 `ApplyLegacyEiLayout()`

## 0. 方法与证据分级

| 级别 | 含义 |
|---|---|
| `primary-static` | EI `Mir3.exe` 反汇编 / WIL 帧头字节直读，已闭合 |
| `primary-resource` | WIL 像素/帧头（本机 `mir2ei/LegacyEI/Data/GameInter.wil`，1103 帧，与 EI 一致） |
| `derived-tooling` | 由证据推导的工具产物（sim 预览），可能偏离 |
| `candidate` | 寄存器歧义 / 运行时决定 / 语义未证 |
| `runtime` | 只能由真实运行观测 |

### 0.1 目标 EI 客户端身份：已闭合（2026-09-29）

NAS（`/data/NAS`，SMB `//192.168.3.10/NAS`；注意 `/home/tetsuya/NAS` 这个
symlink 指向已失效的 `/tmp/nas_mnt/NAS`，**要用 `/data/NAS`**）下
`TMP/EI传奇3.0客户端/` 即目标 EI 客户端。逐文件 MD5 与本地对照：

| 文件 | NAS | 本地 `mir2ei.before-path-fix-*` / `LegacyEI/Data` | 结果 |
|---|---|---|---|
| `Mir3.exe` | `264d848da377c2172ffe1444bf31e7d0` | 同 | **SAME** |
| `mir3.dat` | `a6a842a71e73…` | 同 | **SAME** |
| `Mir3.ini` | `f5a7cc9b76a8…` | 同 | **SAME** |
| `Magic.exp` | `21e3f8a7d769…` | 同 | **SAME** |
| `MInfo.dat` | `c35f297f95db…` | 同 | **SAME** |
| `Weapon.ord` | `b9516d7727ff…` | 同 | **SAME** |
| `Data/GameInter.wil` + `.wix` | `818359f887c5` / `00f4f1f56c22` | 同 | **SAME** |
| `Data/Interface1c.wil` + `.wix` | `f1703234daa5` / `c86cb81f38f9` | 同 | **SAME** |
| `Data/inventory.wil` + `.wix` | `7e880dad8022` / `4c039e53af03` | 同 | **SAME** |
| `Data/Storeitem.wil` | `668d2f961be0` | 同 | **SAME** |

**结论**：本机 `LegacyEI/Data/*` 与 `mir2ei.before-path-fix-*` 就是目标 EI 3.0
客户端的同一份文件；此前"目标 EXE/WIL/WIX 版本身份未闭合"的门禁**解除**，
本轮所有 primary-static / primary-resource 结论不再需要版本保留意见。

**顺带修正 §8 冲突 C-3**：研究摘要称"Interface1c F268 在当前导出为空"，
但**目标客户端自己的 `Interface1c.wil` 里 F267/F268 都有内容**
（本机文件与目标逐字节相同）→ 该摘要要么指另一份导出，要么是错的；
而现代 `Data/Interface1c.Zl` 的 F267/F268 为 blank（Zircon 转换产物）。
两者都不是"目标资源为空"。

> 其余仍在的版本差异：`Data/*.Zl` 是 Zircon 从 WIL 转出的 BC7 重编码
> （见 §9 I-1 的量化：同号帧尺寸一致、肉眼一致、平均 RGB 差 ≈5），
> 属资源管线特性，不是 UI 差异。

## 1. 结论摘要

- **13 个 EI 主窗口 + HUD + 确认框 + 小地图**逐项对照完毕。
- **已修复 1 个窗口（行会 id4）的 2 处确认差异**（8 个动作控件缺失 + 成员列表几何），
  并顺带修复 legacy 背景帧被覆写导致窗口背景消失的缺陷（§6）；
  另修复任务详情正文颜色（§6.3）与 `--ui-audit` 的过期 HUD 断言（§6.2）。
- **发现并纠正 1 处研究文档错误**：技能书 id14 的窗口尺寸
  （`window_layout.json` / `window-initialization-evidence.json` 记 296×332，
  实为 **452×380**），Godot 侧原本就是对的（§8 C-1）。
- 其余 12 个窗口在**几何、帧号、控件位置、格子数量/尺寸**上与 primary-static 证据一致（§2）。
- **新发现 1 处确认差异**：任务列表行几何/配色（§9 Q-2）。
- 仍未闭合：背包逐物品图标映射（数据身份阻塞）、交易/背包关闭热区语义、
  行会解散业务、技能图鉴 flag、以及若干 `candidate` 语义（§9）。

## 2. 主对照矩阵（窗口级）

坐标系：EI 逻辑 800×600；Godot legacy 逻辑 800×600（`LegacyHudLayout.LogicalWidth/Height`），
运行时等比缩放。Godot 侧数值取自 `LegacyHudLayoutLab --legacy-audit` 的真实运行输出
（`.artifacts/godot-ui-parity-2026-09-29/legacy-audit-2026-09-29.log`）。

| # | 窗口 | 原版证据（文件:键/行） | 原版帧/尺寸 | Godot 实现 | Godot 实测 | 判定 |
|---|---|---|---|---|---|---|
| 0 | 背包 | `window_layout.json:11`；`inventory-window-render-evidence.json` | F250 284×324；可视 6×6@36px 起点(25,41)；46 条记录 | `InventoryDialog.cs:219` `ApplyLegacyEiLayout` | `size=(284,324) grid=(6,6)@(25,41)` | **MATCH**（格子几何）/ §9 I-1（记录模型） |
| 1 | 人物状态 | `window_layout.json:12`；`status-window-render-evidence.json`；`equipment-slots-evidence.json` | F200 244×328；8 个 38×38 装备格 + 3 非方格区（11 记录）；切换键 (176,264,36,36)；关闭 (212,298) | `CharacterDialog.cs:339` | `size=(244,328) toggle=(176,264)/(36,36) visibleSlots=11` | **MATCH** |
| 2 | 商店/仓库 | `window_layout.json:13`；`store-state-graph.json::states[2]` | F1000 300×304 @(0,184)；state2 网格 4×3 步距 38；购买键 (127,267,48,20) F1012；行距 46 | `NPCGoodsPanel.cs:136`、`StorageDialog.cs:262` | `goods screen=(0,184) size=(300,304) rowHeight=46 buy=(127,267)`；`storage grid=(4,25)@(21,42) step=38 firstCell=(22,43)` 可见 3 行 | **MATCH** |
| 3 | 交易 | `window_layout.json:14`；`trade-window-render-evidence.json::geometry` | F1050 484×330；每侧 5×6@36 stride36；accept (185,332) F1061/1062；cancel (225,332) F1064/1065；close (532,350) | `TradeDialog.cs:115` | `size=(484,330) userGrid=(5,6)@(20,47) playerGrid=(5,6)@(252,47) close=(532,350) accept=(185,332)#1061` | **MATCH** / §9 T-1（close 语义） |
| 4 | 行会 | `window_layout.json:15`；`social-window-render-evidence.json::windows[1]`；`guild-window-paint-evidence.json` | F600 596×446 @(102,22)；成员 1 列 x=win+35 y=win+60 行距=字高+5 上限 18；9 控件 paint 位置 | `GuildDialog.cs:95` | `size=(596,446) bg=(-214,-33) actions=8 rows=18/18 first=(35,60) step=21` | **本轮修复**（§6） |
| 6 | 组队 | `window_layout.json:17`；`social-window-render-evidence.json::windows[0]` | F900 256×244；成员 2 列 x=+45/+145 行距 20；5 控件 (226,214)/(17,197)/(80,197)/(159,197)/(9,52) | `GroupDialog.cs:114` | `size=(256,244) remove=(80,197) allow=(166,40) invite=(17,197) close=(226,214)` | **MATCH** |
| 8 | 聊天弹窗 | `window_layout.json:19`；`chat-window-render-evidence.json` | F350 572×388 **@(114,76)**；历史 clip (35,28,485,266) 文本(40,29) 行距14 19 行；输入 (25,311,499,15)；6 频道键 36×34 x=25+40k y=332；关闭 (532,350) | `LegacyChatDialog.cs:39` | 代码常量 `VisibleRows=19 LineStep=14`；`_historyClip=(35,28,485,266)`；按钮 `25+40i,332`；`_input=(25,311,499,15)`；**位置本轮修**：原为屏幕居中 (114,106) → 改 EI 实参 (114,76) | **MATCH**（规格与位置；位置修复见 §6.5） |
| 9 | NPC 对话 | `window_layout.json:22`；`npc-window-render-evidence.json` | F1100 552×176；正文原点 (150,40)；关闭 (7,141,28,26)；上箭头 (290,145,12,8)；下箭头 (306,136,12,8) | `NPCDialog.cs:108` | `size=(552,176) text=(150,40) close=(7,141) up=(290,145) down=(306,136)` | **MATCH** |
| 11 | 任务 | `window_layout.json:20`；`quest-window-render-evidence.json` | F700 340×440；详情 F705 @(65,294) 204×76 正文 (80,310)/15px/3 行；列表行 (65, 90+15·line) 上限 19；控件 (290,59)/(290,89) | `QuestDialog.cs:103` | `size=(340,440) scroll=(290,59)/(28,58) close=(304,404)` | **MATCH**（窗口/详情/控件）；列表行几何 §9 Q-2 `CONFIRMED_DIFFERENCE` |
| 12 | 设置 | `window_layout.json:21`；`system-window-render-evidence.json` | F750 248×264；8 toggle（(148,43/116/190/217) 32×22 与 +37 的 40×22）；2 滑条 (34,96)/(34,170)；关闭 (218,238) | `ConfigDialog.cs:141` | `size=(248,264) legacyHitRects=8 paintedIndicators=4 volumeSliders=2` | **MATCH** |
| 13 | 坐骑 | `window_layout.json`；`horse-window-render-evidence.json` | F850 296×332；4 动作 (28,244)/(74,244)/(133,244)/(192,244)；关闭 (252,293) | `HorseDialog.cs`（构造期几何） | `size=(296,332) buttons=(28,244),(74,244),(133,244),(192,244)` | **MATCH** |
| 14 | 技能书 | `window_layout.json`（本轮修正） | F400 **452×380** @(348,0)；8 分类页签 x=win+1..5 y=win+21+35k；F410/411 (61,303)；F412/413 (366,303)；F440/441 (399,340)；右页文本 (winX+235,winY+30) 行距 15 | `MagicDialog.cs:151` | `size=(452,380) background=F400 categories=8 nav=True rows=6` | **MATCH**（§8 C-1 文档纠错） |
| 15 | 公告 | `window_layout.json:23`；`notice-prompt-window-evidence.json` | F602 584×252 @(107,110)；关闭 (548,16)；动作 (496,27,40×20) F606/607；文本 (23,94) | `NoticeDialog.cs`（构造期几何） | `size=(584,252) frame=602@(-220,-2) close=(548,16) action=(496,27) text=(23,94)` | **MATCH** |
| — | 确认框 | `confirmation-prompt-evidence.json` | F950 360×190 居中 (220,151)；YES (51,125,44×20)/OK (147,125,64×20)/NO (244,125,44×20) | `ConfirmDialog.cs` legacy 分支 / `LogoutConfirmDialog` | `size=(360,190) loc=(220,151) YES(150)@(51,125) NO(153)@(244,125)` | **MATCH** |
| — | 小地图 | `minimap.json::minimap_widget_0x48512C` | D3D rect {672,0,800,128} | `MiniMapDialog.cs:70` + `GameScene.cs:5231` | `size=(128,128) loc=(672,0) panel=(128,128)` | **MATCH** |
| — | 主 HUD | `hud-label-evidence.json::caption_ctor_table`；`hud-caption-action-tail-evidence.json` | F50 800×136 @(0,465)；16 caption 帧/坐标/文案/动作全表 | `MainPanel.cs:132-159`、`MainPanel.cs:268` | `panel=50/(800,136) buttons=True legacyStats=True`；16 键位与 EI 表逐项一致 | **MATCH** / §9 H-1（cap2 语义） |

## 3. 容器/格子清单（原版权威值 vs Godot）

| 容器 | 原版列×行 | 格子/步距 | 起点（窗口相对） | 可见范围 | Godot | 判定 |
|---|---|---|---|---|---|---|
| 背包（可视） | 6×6 = 36 | 36×36 stride 36 | (25,41) | 6 行 | 同 | MATCH |
| 背包（记录容量） | 46 条（stride 0xC2C）；占位表 6×100 WORD | — | — | 滚动字段 this+0x58（F280 gauge，比例尺度 94） | 现代 48 项数组 + footprint first-fit 动态行 | §9 I-1 |
| 人物装备 | 8 个 38×38 | 38 | (27,264)(177,70)(27,186)(175,186)(27,227)(175,227)(64,264)(103,264) | 全可见 | 同（11 记录） | MATCH |
| 交易每侧 | 5×6 = 30 | 36 stride 36 | 左 (21,48)、右 (253,48) | 6 行 | 同 | MATCH |
| 仓库（state2） | 4×3 = 12/页 | 38 stride 38 | 列 22/60/98/136 行 43/81/119 | 3 行 | 同（分页 divisor 12） | MATCH |
| 商店购买列表 | 1×5 | 行距 46 | (4,40) | 5 行 | 同 | MATCH |
| 行会成员 | 1 列 | 行距=字高+5 | (35,60) | 18 行 | 本轮改为同 | 已修复 |
| 行会仓库页 | 11×N | padding 1 | (8,45) | 10 行 | 同（现代页） | MATCH（candidate：原版无该页） |
| 组队成员 | 2 列 | 列距 100 行距 20 | (45,90) | 引擎裁剪 | 同 | MATCH |
| 任务列表 | 1 列 | stride 0x104 | (win+0x41, line×3+0x12) | 19 行 | 同 | MATCH |
| 聊天历史 | 1 列 | 行距 14 | (40,29) | 19 行 | 同 | MATCH |
| NPC 条目 | 1 列 | 源 stride 18 | (150,40) | 16 条上限 | 同 | MATCH |
| 技能书右页 | 1 列 | 行距 15 | (winX+235,winY+30) | 至下一 `#` 段 | 同 | MATCH |
| 腰带 | 6 格 | 步距 37.5 | (3,2) | 1 行 | 同（`LegacyEiBeltSlots=6`） | MATCH |
| 小地图 | 128×128 | — | 屏幕 (672,0) | — | 同 | MATCH |

## 4. EI 窗口 id 空间 vs Godot（含原版没有的现代扩展窗口）

EI 主 UI 的窗口 id 空间是 **0..15**，由 `0x0042B3E4` 跳转表 + `0x0042C4D4`
子窗点击表 + `0x0042C494` caption 动作表三处共同定义
（`window-visibility-dispatch-evidence.json`、`window-paint-dispatch-identity.json`）：

| id | 原版窗口 | Godot legacy 对应 |
|---|---|---|
| 0 | 背包 F250 | `InventoryDialog` |
| 1 | 人物状态 F200 | `CharacterDialog` |
| 2 | 商店/仓库 F1000/1001 | `NPCGoodsPanel` + `StorageDialog` |
| 3 | 交易 F1050 | `TradeDialog` |
| 4 | 行会 F600 | `GuildDialog` |
| 5 | **空槽**（no-op） | — |
| 6 | 组队 F900 | `GroupDialog` |
| 7 | 第二状态窗 F200 @(560,0) | `_statusPreviewDialog`（`CharacterDialog` 复用） |
| 8 | 聊天弹窗 F350 | `LegacyChatDialog` |
| 9 | NPC 对话 F1100/1101/1102 | `NPCDialog` |
| 10 | **空槽**（no-op） | — |
| 11 | 任务 F700 | `QuestDialog` |
| 12 | 设置 F750 | `ConfigDialog` |
| 13 | 坐骑 F850 | `HorseDialog` |
| 14 | 技能书 F400 | `MagicDialog` |
| 15 | 公告 F602（render-only，无 hit 槽） | `NoticeDialog` |

**原版没有、Godot 才有的窗口**（邮件/拍卖/商城/伙伴/排行/寻宝/自动喝药/大图/
合并/坐骑驯服/钓鱼/地下城查找/称号/里程碑等）**没有 EI 对照物**，因此**不要求**
套用 EI 几何——它们是 Zircon 的现代扩展。判定为 `N/A`（非差异），
但仍需遵守现代 Zircon `Client/` 的布局（见 §7）。Preview 源码侧同样有一批
原版没有的窗口（`DFriendDlg`/`DMailDlg`/`DItemMarketDlg`…，见
`../../source-vs-reverse/README.md` D3），同样不作 EI 几何依据。

## 5. 交互行为对照

| 行为 | 原版证据 | Godot 实现/自检 | 判定 |
|---|---|---|---|
| 窗口显隐/Z 序 | `0x42AC30` show（追加链表尾）/`0x42AC50` hide（摘链）；绘制按链表头→尾（`draw-order-evidence.json`） | `WindowManager.Open/Close` + `OpenWindows` 列表 + `RefreshZOrder` | **MATCH**（模型等价） |
| 窗口提升 | `0x42B6A0`（拖拽起始）：先 `0x42B820` 清 `+0x34` 活动槽 → hide → show 追加尾 | `WindowManager.BringToFront` | **MATCH** |
| 「关全部」误读澄清 | `0x42B820` 只重置 `+0x34` 活动槽，**不动** `+0x30` 可见门、不摘链表节点 → 窗口**不互斥** | Godot 同样允许并存 | **MATCH**（原 `draw-order` 文字「关全部」为宽松表述，已按 `window-visibility-dispatch-evidence.json` 澄清） |
| HUD caption 悬停 | `caption-tooltip-0x96ffff-evidence.json`：常态不画（`+0x20=-1`）、悬停只画文字（淡黄底 0x96FFFF + 黑框） | `MainPanel` 按钮 `TooltipText` + DXControl 提示 | **MATCH**（`--legacy-tooltip-selftest` PASS：背包/商店/裁切三组） |
| 物品格悬停提示 | `bag-tooltip-verification-evidence.json` | `GameScene` 场景级 `_hoverItem` | `LIKELY_DIFFERENCE`（触发点/样式，见 `LEGACY_EI_UI_AUDIT_2026-09-23.md` ITEMTIP-01） |
| 目标框/悬停名牌 | `target-box-evidence.json`（名牌框 `0x40B850`、悬停 3000ms `0x40BB00`、HP 条 `0x40A8A0`） | `GameScene` 目标框/名牌 | 未逐项复核 → `UNVERIFIED` |
| 关闭框/键盘链 | `confirmation-prompt-evidence.json`（F950 三按钮 + 键盘/激活链） | `LogoutConfirmDialog` | **MATCH**（`--legacy-keychain-selftest` PASS：Tab 循环/回绕/跳过 disabled、帧表 150/153/156 与 44×20/44×20/64×20 匹配） |
| 分页/滚动 | 行会 `this+0x9C` 行偏移 + 18 行上限；仓库 divisor 12；背包 `this+0x58` + F280 gauge；聊天 ±19 行 | 各窗口 `DXVScrollBar`/`ScrollValue` | 行会本轮改为行偏移（§6.1）；仓库/背包/聊天 **MATCH**；背包 F280 见 §9 I-2 |
| 拖放 | 交易/背包/仓库 `GridType` 链接模型（`bag-list-fill-chain-evidence.json`） | `DXItemCell`/`DXItemGrid` `LinkedSourceGrid` | **MATCH**（`UIItemGridAudit`/`UIBeltLinkAudit` PASS） |
| 键盘入口 | `hud-label-evidence.json::caption_ctor_table`（16 caption 文案含键位）+ `hotkey-label-handler-consistency.json` | legacy 覆盖层 `GameScene._UnhandledKeyInput`（`LegacyUi` 分支，`GameScene.cs:10877-10988`）；其余走 `KeyBindManager` | **16/16 MATCH**（逐项见下） |

**legacy 键位逐项对照**（2026-09-30 复核；上一轮曾误记「整表反向」，实为 14/16 早已覆盖）：

| EI 键（caption 文案） | EI 语义 | Godot legacy 路径 | 判定 |
|---|---|---|---|
| Q / Ctrl+Q | 包袱栏 | `Key.Q` → Toggle InventoryDialog | MATCH |
| W / Ctrl+W | 状态栏 | `Key.W` → ToggleCharacterWindow | MATCH |
| E / Ctrl+E | 技能书 | `Key.E` → Toggle MagicDialog | MATCH |
| R / Ctrl+R | 聊天记录 | `Key.R` → LegacyChatDialog | MATCH |
| N / Ctrl+N | 设置栏 | `Key.N` → OpenConfigDialog | MATCH |
| G / Ctrl+G | 组队 | `Key.G` → GroupWindow | MATCH |
| D / Ctrl+D | 信息窗口(任务) | `Key.D` → Toggle QuestDialog | MATCH |
| C / Ctrl+C | 交易栏 | `Key.C` → TradeRequest | MATCH |
| S / Ctrl+S | 坐骑 | `Key.S` → ToggleHorseWindow | MATCH |
| T | 小地图切换 | `Key.T` → MiniMap toggle | MATCH |
| Z / Ctrl+Z | 腰带 | `KeyBindManager` `Key.Z`=BeltWindow | MATCH |
| V / Ctrl+V | 小地图 | `KeyBindManager` `Key.V`=MapMiniWindow | MATCH |
| Alt+Q | 退出游戏 | `KeyBindManager` `Alt+Q`=ExitGameWindow | MATCH |
| Alt+X | 注销人物 | `KeyBindManager` `Alt+X`=LogoutCharacter | MATCH |
| F / Ctrl+F | 行会 | **本轮补**：legacy 覆盖层加 `Key.F`→OpenGuildDialog（commit `7e2a2340`）；此前落到 `Key.F`=BlockListWindow | **已修复** |
| B / Ctrl+B | 技能图鉴 | 仍为 `KeyBindManager` `Key.B`=MapBigWindow | **未修复**（= §9 B-5，原版语义是 toggle 技能图标网格） |
| 角色属性文本 | `status-window-render-evidence.json`；`status-attribute-colors-evidence.json` | `CharacterDialog` 14 行 (255,67+15i)/(331,67+15i) | **MATCH**（`--legacy-character-selftest` PASS：14 项全部匹配） |

## 6. 本轮已修复

### 4.1 行会 id4：8 个动作控件缺失 + 成员列表几何（commit `b8c26340`）

**原版依据**
- `social-window-render-evidence.json::windows[1].paint_repositioned_controls`
  （paint 0x00425152-0x00425258，9 条 SetPosition 真值）
- `guild-window-paint-evidence.json`（0x00425040 paint 头 + 三态列表 0x425280/0x425440/0x425590 + 9 控件重定位）
- 反汇编复核（本机 `mir2ei.before-path-fix-20260927-2330/Mir3.exe`）：
  - `0x004252BD  mov [esp+0x14],0x12` → 可见行上限 **18**
  - `0x004252C5  add eax,5` → 行距 = 字体度量高 + 5
  - `0x004253FB  lea eax,[ecx+edx+0x3C]`、`0x00425409  add ecx,0x23`
    → **y = window.y+60+(row-scroll)×step，x = window.x+35**
  - `0x00425404  push 0x96FF`（命中标记行）/ `0x0042540E  push 0`（普通行 0xFFFFFF）

**Godot 差异**：legacy 下只换背景皮，内容仍是现代主页/页签树；
8 个动作控件完全缺失；成员行在 (22,128) 而非 (35,60)。

**修复**：`GuildDialog.ApplyLegacyEiLayout/BuildLegacyActionButtons/BuildLegacyPage`
（`GodotClient/Controls/GuildDialog.cs`）。

**附带修复的真实缺陷**：`ApplyGuild`/`SelectTab` 会把 `_background.Index` 覆写成
GameInter 261/262…（现代页签背景帧）。legacy 只有一张 F600，覆写后**窗口背景整块消失**
（截图实证：修复前窗口区域 = 实验场底色 (17,22,27)）。新增 `SetBackgroundFrame()`
在 legacy 下恒用 600，并把锚点固定为 alpha 可见区原点 -(214,33)。

**验证**：`--legacy-audit` PASS（`guild=True guildList=True`，
`rows=18/18 first=(35,60) step=21`）；Xvfb 1280×960 真实运行截图
`Zircon/.artifacts/godot-ui-parity-2026-09-29/legacy-guild.png`
（背景/标题/18 行/绿色 `[行会公告]` 行/8 按钮/滚动条/关闭键同帧可见）。

**未闭合**：行会解散（原版走掌门守卫 + 对话框 601 双确认；Zircon 无 disband 包，
当前只弹说明框、不发请求）。

### 6.2 `--ui-audit` 的 HUD 断言过期（测试卫生，commit `10cb0511`）

`UITestScene.AuditHud` 断言的是**已废弃的新版横向九键排布**
（CharacterButton (650,23)/(689,23)/(728,23)/(923,23)/(972,16)）。
HUD 切到 EI 基准后（`MainPanel.cs:132-159` 使用 `hud-label-evidence.json`
的 ctor 表坐标），该断言必然 FAIL（修复前实测
`[UIHudAudit] FAIL panel=(800,136) character=(648,70) click=True`，
且 `--zircon-ui` 下同样 FAIL，证明与 legacy 开关无关、是断言本身过期）。
已改为 EI 坐标：CharacterButton cap13 (648,70)、InventoryButton cap14 (648,32)、
SpellButton cap8 (703,16)、MenuButton cap11 (703,85)、CashShopButton cap15 (665,16)。

**验证**：`[UIHudAudit] PASS panel=(800, 136) buttons=16 click=hit`。

### 6.3 任务详情正文颜色（commit `2855e0ac`）

原版任务详情正文用 `0x7D0000` 绘制（`0x00447EF7` / `0x00447F51` / `0x00447F70`
三处 `push 0x7D0000`），按本引擎既有 `0x00BBGGRR` 约定（技能书 `0x0A320A`=暗绿、
`0x96C8FA`=浅蓝）即 **RGB(0,0,125) 深蓝**；Godot legacy 用的是 `Colors.White`。
已改为深蓝。

同时补齐了此前缺失的证据键：`quest-window-render-evidence.json` 新增
`detail_geometry`（primary-static：F705 @(65,294) 204×76、正文 (80,310)、行距 15、
3 行、色 0x7D0000）与 `list_row_geometry`（见 §9 Q-2）。

### 6.4 背包格子布局的运行验收（本轮核对，无需改动）

任务书特别要求「背包格子不能凭印象判断」。本轮按原版权威值逐项核对：

| 项 | 原版（primary-static） | Godot legacy 实测 | 判定 |
|---|---|---|---|
| 可视网格 | 6 列 × 6 行 = 36 格 | `GridSize=(6,6)`、`VisibleHeight=6` | MATCH |
| 格子像素/步距 | 36×36、stride 36 | `DXItemCell.CellWidth/Height=36`、`Step=36` | MATCH |
| 网格起点 | (win.x+0x19, win.y+0x29) = (25,41) | `Grid.Location=(25,41)` | MATCH |
| 首屏 36 个命中矩形 | (25+36·c, 41+36·r, 36, 36) | 逐格一致（`inventory-window-render-evidence.json` 的 index_to_rect） | MATCH |
| 记录容量 | **46 条**（stride 0xC2C）+ 6×100 WORD 占位表 | 现代 48 项数组 + footprint first-fit 动态行 | §9 I-1（模型差异，非几何） |
| 滚动控件 | F280 gauge 16×424、填充区 12×218、`(x+0xF8,y-0xA5)` | 自绘 16×424 轨道 + 16×34 拖柄 | §9 I-2 |

运行证据（两轮）：
- lab：`Zircon/.artifacts/godot-ui-parity-2026-09-29/legacy-inventory-grid.png`
  + `legacy-audit-2026-09-29.log` 的 `inventory size=(284,324) grid=(6,6)@(25,41)`；
- **真机联机**（2026-09-30）：`docs/evidence/godot-runtime-acceptance-2026-09-30/`
  `03-bag-window-after-Q.png` 与 `04-bag-grid-6x6-zoom.png` —— 进入游戏后按 Q 打开
  背包，放大图可**逐格点数 6 列×6 行 = 36 格**，并同帧可见
  `负重 0/总量 1899`、`金钱 100000172`（浅蓝 0x64C8F8）、`[包袱]`、`수리`、锁链滚动轨。

结论：**背包的可视格子数量、尺寸、间距、起点与原版一致**；
差异只在「记录容量/占位表模型」与「滚动 gauge 绘制」，二者均受数据身份或
未闭合证据阻塞（§9 I-1/I-2）。

### 6.5 真实联机验收暴露并修复的另外两处（2026-09-30）

| # | 缺陷 | 原版依据 / 症状 | 修复 |
|---|---|---|---|
| 1 | F350 聊天窗位置 | 原版 `window.chat-pop` 构造实参 (114,76)（`window_layout.json` / `0x427839`）；`LayoutHud` 末尾既有约定是「旧版窗口坐标来自 exe 构造参数，不是居中布局」，`LegacyChatDialog` 是唯一漏项 → 居中 (114,106) 使窗口底边压进 HUD 29px | `ApplyLegacyWindowLocations` 补 `Place(_legacyChatDialog, 114, 76)` |
| 2 | `WindowManager` 对已释放窗口崩溃 | 真机按 R 关聊天窗抛 `ObjectDisposedException`（`RefreshZOrder` → `SetZIndex`），整轮 Z 序刷新中断 | 新 `IsAlive` 守卫，六个入口先剔除失效引用 |

真机回归：同流程日志 `ObjectDisposedException` 计数 **0**（修复前 ≥2）。

## 7. 与 Zircon `Client/`（移植来源）的对照

| 项 | `Client/`（C#） | `GodotClient` 现代路径 | 判定 |
|---|---|---|---|
| 背包 | `InventoryDialog.cs:200` `GridSize=(6,8)` @(20,39) padding 1 | `InventoryDialog.cs:91` 同 | MATCH |
| 物品格 | `DXItemCell.CellWidth/Height=36` | `DXItemCell.cs:20-21` 36 | MATCH |
| 物品格图库 | `StoreItem` | 同 | MATCH |
| legacy 图库 | — | `Inventory.wil`（`UseLegacyFootprints`） | §9 I-1 |

## 8. 冲突与修正记录

| # | 主题 | 旧值 | 修正值 | 依据 |
|---|---|---|---|---|
| C-1 | 技能书 id14 窗口尺寸 | 296×332 @(0,0) | **452×380 @(348,0)** | main-init 调用点 `0x004278E1-0x00427904` 9 参 push 序列（同 NPC wrapper 0x0043ED00 的已验证参数位）；`GameInter` F400 alpha bbox (30,67)-(481,445)=451×378；11 控件最大右边 419/最大底边 352 均超出 296×332。**Godot 侧原本即 452×380，正确。** 已改 `window_layout.json` 与 `window-initialization-evidence.json`（保留 `notes`/`correction` 原文）。 |
| C-2 | 行会成员行原点 | `guild-window-paint-evidence.json` 写 (x+0x22, y+0x3B) | **(x+0x23, y+0x3C) = (35,60)** | 反汇编 `0x00425409 add ecx,0x23` / `0x004253FB +0x3C`；与 `social-window-render-evidence.json::windows[1]` 一致。 |
| C-3 | Interface1c F267/268 内容 | 研究摘要称“F268 当前导出为空” | 本机 `LegacyEI/Data/Interface1c.wil` F267 76×88、F268 60×106 均有内容；现代 `Data/Interface1c.Zl` 两项 blank | **已裁决（§0.1）**：本机 Interface1c.wil 与目标客户端逐字节相同（MD5 `f1703234daa5`），故「目标资源为空」不成立 —— 该摘要指的是别的导出或写错；现代 ZL 的 blank 是 Zircon 转换产物。结论：以目标 WIL 为准，F267/268 有内容。 |
| C-4 | 背包滚动字段 this+0x58 | 旧注“仅 reset 清零、恒零” | EI-301：输入 handler 写 `trunc(position×94)`，paint 按 `value/(94-1)` 归一化 | 见 `inventory-window-render-evidence.json` + `trade-split-handle-evidence.json`；94 是共享定点尺度，不是 94 行。 |
| C-5 | 背包占位表基址 | this+0x2C4 | bag+0x324 | `bag-list-fill-chain-evidence.json`（EI-293）。 |
| C-6 | 背包 mode3 文案 | [木柴] | **[储存]** | 全二进制无「木柴」。 |

## 9. 未修复 / 未验证 / 阻塞

| # | 项 | 状态 | 证据与原因 |
|---|---|---|---|
| I-1 | 背包逐物品图标映射与记录模型 | **机制 MATCH**（残余为部署数据差异） | ①帧号空间同一：Zircon `ItemInfo.Image` 与 EI `stditem.dat::Looks` 同号（抽样：Gold 0=金币 0、Iron Sword 1043=铁剑 1043、Candle 290=蜡烛 290；按 (Price,Weight) 配对的 533 件里 364 件数值相等，不等的多为**同价同重的不同物品**误配，另有 `Commoner Outfit(M)` 941 vs `布衣（男）` 940 这类 1 之差待查）。②图标库内容同一：`Data/Inventory.Zl` 的 0..1439 帧与目标 `inventory.wil` 同号帧尺寸一致（496/499 可解码项）、肉眼一致、平均 RGB 差 ≈5（BC7 重编码）。③原版 46 条记录 + 6×100 WORD 占位表 vs Godot 48 项数组 + footprint first-fit（首屏 36 格命中矩形逐格一致）。**残余**：本机服务端物品库是 Zircon 上游英文物品集（1078 件），目标 EI 是 `stditem.dat` 中文 1143 件，逐物品 1:1 属**部署数据**问题，不是客户端缺陷。 |
| I-1b | `Commoner Outfit` 941 vs `布衣（男）` 940 的 1 之差 | `UNVERIFIED` | 需逐条核对 Zircon `Image` 与 EI `Looks` 的对应（可能 Zircon 插入了额外帧）。不影响客户端实现。 |
| I-2 | 背包 F280 gauge 轨道/拖柄 | `CONFIRMED_DIFFERENCE`（未修） | 原版 F280 16×424、填充区 12×218、`(x+0xF8, y-0xA5)`、值=this+0x58；Godot legacy 隐藏旧 `WeightBar`，自绘 16×424 轨道 + 16×34 拖柄。原版绘制调用相对父对象的最终屏幕换算仍未闭合（`INV-04`）。 |
| T-1 | 交易 close 热区语义 | `CONFIRMED_DIFFERENCE`（未修） | `trade-window-render-evidence.json::buttons`：close (532,350) 在 484 宽窗口**之外**、只播音不关窗；Godot 绑定 `WindowManager.Close`。修掉会移除一个非原版入口，属产品行为取舍 → 待决策。 |
| I-3 | 背包 F161/162 / F264/265 / F267/268 语义 | `CONFIRMED_DIFFERENCE`（未修） | `inventory-mode-tabs-evidence.json`：三者为装饰性子控件，单击只播音，模式由服务端消息写；Godot 把 F161/162 绑成关闭、F264/265 无业务、F267/268 缺失。同上属产品行为取舍。 |
| H-1 | HUD cap2「技能图鉴」动作 | `candidate`（未修） | EI cap2 点击只翻转 `[esi+0x6208]` 布尔 flag（消费者未闭合）；Godot 映射为打开技能书（与 cap8 重复）。语义未证，不擅自改。 |
| G-1 | 行会解散业务 | `BLOCKED`（协议） | 原版掌门守卫 + 对话框 601 双确认；Zircon 无 disband 客户端包。 |
| Q-1 | 任务详情面板几何 | **已闭合（证据补齐）** | 2026-09-29 反汇编 `0x00447D58-0x00447F90` 恢复 primary-static 几何并写入 `quest-window-render-evidence.json::detail_geometry`：F705 @(win.x+0x41, win.y+0x126)=(65,294)，面板 204×76；正文 (win.x+0x50, win.y+0x136+15·row)=(80,310+15·row)，行距 15、3 行、色 0x7D0000。Godot `QuestDialog.RefreshLegacyDetail` 与该值一致（颜色差异见 §6.3）。 |
| Q-2 | 任务列表行几何与配色 | `CONFIRMED_DIFFERENCE`（未修） | 原版列表行 **x=win.x+0x41=65、y=win.y+0x5A+15·line=90+15·line、行距 15、可见 19 行**，色 `0x1919C8`/`0x19197D`（`0x00447618` `lea eax,[ecx+ecx*2+0x12]` + `0x00447622` `lea eax,[eax+eax*4]` = ×5；`0x0044761F` `add ecx,0x41`；`0x004475DE` `cmp ecx,0x13`）。**旧证据文字「row = line×3+0x12」漏了 ×5**，已在 `list_row_geometry` 更正。Godot legacy 仍渲染现代分组列表（x=8/18/28、金色/白色、分组标题/描述），与 F700 背景不匹配。 |
| S-1 | 技能书根尺寸与页签 | 已澄清 | 见 C-1；Godot 452×380 与 8 页签坐标全部匹配。 |
| N-1 | NPC `mode=1 && overflow=1` 的 14px 行距分支 | `candidate` | 需 token/layout state；当前统一 21px。 |
| — | 目标 EI EXE/WIL/WIX 版本身份 | **已闭合** | 见 §0.1：NAS `TMP/EI传奇3.0客户端/` 与本机逐文件 MD5 相同。 |
| — | 原版客户端运行 A/B | `UNVERIFIED` | 原版为 Windows-only，本机无法运行（见 `../../ORIGINAL_GODOT_PARITY_AUDIT.md` P-002）。目标客户端文件已在 NAS 可取（§0.1），如需 A/B 需 Windows 主机。 |
| — | 行会/背包的**联机**验收 | **已跑通**（2026-09-30） | 自建隔离服务端 `/tmp/godot-parity-srv`（`Port=7002`，DB 为副本）+ 800×600 客户端 + 角色 `EIFlow1`：登录→选角→StartGame 过场→公告框点击→进游戏 Bichon Town；按 Q 开 legacy 背包（**真机逐格点数 6×6=36**、负重/总量、金钱 100000172、[包袱]、수리、锁链轨），按 F 开 legacy 行会窗。详见 [`GODOT_UI_RUNTIME_ACCEPTANCE_2026-09-30.md`](GODOT_UI_RUNTIME_ACCEPTANCE_2026-09-30.md)。**该路径暴露并修复了 lab 测不到的缺陷**（legacy 行会窗残留现代建会页 → `752a41cc`）。 |
| — | 任务窗的联机验收 | `UNVERIFIED` | 本轮真机未打开任务窗（该角色无任务数据）。 |

## 10. 验证方法（可复现）

```bash
# 构建
cd /home/tetsuya/development/zircon
dotnet build GodotClient/ZirconClient.csproj

# legacy 全窗口几何 + 行会列表真实运行自检（headless）
godot-mono --headless --path GodotClient --scene Scenes/LegacyHudLayoutLab.tscn -- --legacy-audit

# 现代 UI 回归
godot-mono --headless --path GodotClient --scene Scenes/UITestScene.tscn -- --ui-audit --quit-after 8

# 行会 legacy 截图（Xvfb :100 + openbox + scrot）
godot-mono --path GodotClient --scene Scenes/LegacyHudLayoutLab.tscn -- --legacy-open=guild --legacy-guild-sample
```

证据索引：
- `Zircon/.artifacts/godot-ui-parity-2026-09-29/legacy-audit-2026-09-29.log`
- `Zircon/.artifacts/godot-ui-parity-2026-09-29/legacy-guild.png`

## 11. 提交记录

| 仓库 | 分支 | commit | 内容 |
|---|---|---|---|
| Zircon | `master` | `b8c26340` | fix(ei行会)：按原版 F600 恢复 8 个动作控件与成员列表几何 + legacy 背景帧修复 |
| Zircon | `master` | `10cb0511` | test(ui审计)：UIHudAudit 改用 EI HUD 坐标，恢复回归有效性 |
| Zircon | `master` | `2855e0ac` | fix(ei任务)：详情正文改用原版 0x7D0000 深蓝 |
| Mir3-Research | `ei-ui-audit-2026-09-24` | `b29f8645` | 本矩阵 + C-1 文档纠错（C-2 为证据文件 1px 偏差，已在 §8 记录） |
| Mir3-Research | `ei-ui-audit-2026-09-24` | `1991d074` | 矩阵补窗口 id 空间/交互行为两节 + 交叉引用修正 |
| Mir3-Research | `ei-ui-audit-2026-09-24` | `40474946` | `quest-window-render-evidence.json` 补 `detail_geometry`/`list_row_geometry` + 矩阵更新 |
| Mir3-Research | `ei-ui-audit-2026-09-24` | `effa3171`（随源码精读 Round 958 入库） | RESEARCH_LOG Round UI-1 |

远端核对（`git ls-remote` + `git merge-base --is-ancestor`，2026-09-29 收尾时）：
- `iamcheyan/Zircon` `refs/heads/master` = `2855e0acbcadaec230168b1f25c90d1ed41a8612`
  （`b8c26340` / `10cb0511` / `2855e0ac` 均为其祖先，已逐一验证）
- `iamcheyan/Mir3-Research` `refs/heads/ei-ui-audit-2026-09-24` 在收尾时已被并行的
  「源码精读」goal 推进到 `e2f9bb245916754a09b93799a4191360c4bdbcb9`；
  本 goal 的 `b29f8645` / `1991d074` / `40474946` 均验证为其祖先。
