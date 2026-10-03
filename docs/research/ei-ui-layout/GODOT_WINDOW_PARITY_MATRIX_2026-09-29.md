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
| 3 | 交易 | `window_layout.json:14`；`trade-window-render-evidence.json::geometry` | F1050 484×330；每侧 5×6@36 stride36；accept (185,332) F1061/1062；cancel (225,332) F1064/1065（WIL 缺帧、纯热区）；close (532,350)（窗口外、只播音不关窗） | `TradeDialog.cs:115` | `size=(484,330) userGrid=(5,6)@(20,47) playerGrid=(5,6)@(252,47) close=(532,350) accept=(185,332)#1061`；close 热区本轮改为不关窗 | **MATCH**（close 语义已修，见 §6.6 / B-2） |
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
| 物品格悬停提示 | `bag-tooltip-verification-evidence.json`（链 `0x42FAB0`→`0x42F240`→`0x4341F0`；F340 浮动框 + `0x329696` 底 + 图标） | `GameScene._hoverItem`/`_hoverLabel`/`_hoverItemIcon`；`DXItemCell` 进入/离开即设/清（`SetHoverItem`），位置 `mouse+(10,10)` 且矩形左上各扩 5px，`BackColour` legacy = RGB(150,150,50)（= `0x329696` COLORREF），背包/腰带链按原版不画图标 | **MATCH**（2026-10-01 复核）。原版触发链反汇编：`0x42FAB0` **无延迟**——每帧用全局鼠标位置 `[0x7DA1C0/0x7DA1C4]` 做格命中，非空格则把 `0x4341F0` 画在 `mouse+(10,10)`；门 `[0x7243C4]==0`（UI 对象 `0x7243A4+0x20`，读点 5 处，语义仍 `candidate`；Godot 用 `dragged == null` 等价）。残余 `candidate`：该门字段的确切含义未闭合（不影响当前实现） |
| 目标框/悬停名牌 | `target-box-evidence.json`（名牌框 `0x40B850`、悬停 3000ms `0x40BB00`+设置方 `0x40BA60`、HP 条 `0x40A8A0`） | ① 名字牌：`RenderPrimitives.DrawTargetNamePlate` + `ObjectRenderer/PlayerRenderer.IsTarget`（commit `4cbf5360`）；② 悬停 3000ms 保留：`MapObjectNode.NameHoldUntilMs`/`RefreshNameHold` + `RenderPrimitives.HoverNameHoldMs`；③ HP 条：未实现 | 名字牌 = **已修复**（反汇编定案 + 真机仪表化验证，见 `GODOT_UI_RUNTIME_ACCEPTANCE_2026-09-30.md` §6）；悬停保留 = **已实现**（同文档 §6.4）；HP 条 = `BLOCKED`（库为运行时绑定，见 `GODOT_UI_OPEN_DECISIONS_2026-09-29.md` B-8）；ProgUse 帧 2/3 悬浮底板 = `LIKELY`（实测 32×4，语义未定，暂不实现） |
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
| B / Ctrl+B | 技能图鉴（= 12 槽技能条的一行图标） | **本轮补**：legacy 下 `Key.B` → toggle `_magicBar`（commit `684a6e67`）；此前落到 `Key.B`=MapBigWindow | **已修复**（§6.7） |
| 角色属性文本 | `status-window-render-evidence.json`；`status-attribute-colors-evidence.json` | `CharacterDialog` 14 行 (255,67+15i)/(331,67+15i) | **MATCH**（`--legacy-character-selftest` PASS：14 项全部匹配） |
| 鼠标交互全量（左/右/中键、双击、拖拽、滚轮、锁定） | 旧版 `Client/`（`MapControl.cs`/`DXItemCell.cs`/各 Dialog）+ EI 证据 | Godot 对应实现 | **69 条逐项 ✅**（见本仓库 [`MOUSE_INTERACTION_CATALOG.md`](../../MOUSE_INTERACTION_CATALOG.md) 2026-08-08 版：世界地图 17 条、物品格与窗口控件 22 条、对话框与全局 30 条；含右键（2.9 按控件语义路由、1.2 右键跑步、1.3 右键转身、1.11 右键取消目标、2.9 物品格右键、3.23 大图右键传送）、双击（2.8/2.22/3.14/3.24/3.25）、拖拽（2.19 窗口拖动、2.20 边缘缩放、2.21 滚动条、3.6 交易拖物）、滚轮（2.13/3.4））。**注**：该目录口径是「Godot vs `Client/`」，本矩阵口径是「Godot vs EI 原版」；EI 侧另无独立右键菜单（`LEGACY_CLICK_ACTION_CATALOG.md`：右键按控件语义） | MATCH（按 Client/ 口径）；EI 交叉见 `LEGACY_CLICK_ACTION_CATALOG.md` |

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

### 6.7 cap2/B 按原版 toggle 12 槽技能条（`684a6e67`）

原版 cap2（`0x42C241`）与 B（`0x42CE29`）只翻转 `[hud+0x6208]`，其唯一消费者
`0x42A850`（HUD paint `0x429607` 调用）在 flag==0 时 `je 0x42AAA4` **跳过整段**，
否则画**一行 12 个技能图标**（数据 `hud+0x52E45` 逐 byte；图标 = MIcon selector
`0x566C90` 帧 `byte+999`；步距 `0x28` 且索引 4/8 处额外 +0x28；缩放 `0x3F169697≈0.588`）。
12 槽 = F1–F12 技能条，与 Godot `_magicBar`（12 列）同一概念。

Godot 差异：cap2 打开技能书（与 cap8 重复）、B 打开大地图、技能条恒显。
修复：legacy 下 cap2 与 B 都 toggle `_magicBar`，且**默认隐藏**（对应 flag 初值 0）。

**真机验证**：默认无技能条 → 按 B 出现 12 槽 → 再按 B 隐藏
（`docs/evidence/godot-runtime-acceptance-2026-09-30/07-skillbar-toggle-by-B.png`）。

**2026-10-03 渲染对齐（`684a6e67` 只修了 toggle，外观仍是 Zircon）**：
此前 legacy 下的技能条仍画 `DXWindow` 底框 + `GameInter2` 学派边框 + 自绘 `1..12`
编号 + 栏组上下按钮（`GameInter2` 在 `LegacyEI/Data` 里根本不存在 → `MirSkin`
回退到现代 `GameInter2.Zl`，即「技能栏用的是 Zircon 的 UI」）。
本轮按 `0x42A850` 重写 legacy 绘制（`GodotClient/Controls/MagicBar.cs::DrawLegacyEi`）：

| 项 | EI 原版 | Godot legacy 现状 |
|---|---|---|
| 空槽 | `GameInter.wil` 帧 `20+i`（画面自带 `F1`..`F12`） | 同 |
| 有绑定 | `MIcon.wil` 帧 `999+技能ID` = `1000 + MagicInfo.Icon/2` | 同 |
| 步距 | `0x28`(40)，索引 4/8 前各额外 +40 | 同（560×40） |
| 尺寸 | 帧内容 40×40，1:1 原生尺寸 | 同 |
| 窗口底框 / 编号 / 冷却数字 / 栏组按钮 | 无 | 无（栏组仍由 Ctrl+F1..F4 切） |

**更正上文「缩放 `0x3F169697≈0.588`」**：该常量是 `0x466800` 写入的 **D3DMATERIAL9**
颜色/alpha（150/255；有绑定槽位用 100/255），不是缩放 —— 依据：结构体 68 字节
= D3DMATERIAL9，且同一槽位在 `0x402DC9` 用于纯色矩形填充。帧因此按 40×40 内容
1:1 绘制，与 40px 步距自洽。技能ID 映射与逐条名称交叉验证见
[`GODOT_UI_OPEN_DECISIONS_2026-09-29.md`](GODOT_UI_OPEN_DECISIONS_2026-09-29.md) §B-5。

**真机验证（2026-10-03）**：800×600 legacy 登录 `TestHero` → 按 `B` 出栏
（1/2/3 与 11/12 为金色技能图标，其余为 `F4`..`F10` 底板，4/8 前有分组空隙）→
点第 1 格发出 `[Magic] 发包 Fire Ball Magic=FireBall Set=1 Slot=1` + `ObjectMagic`。
`--ui-audit` 在 legacy 与 `--zircon-ui` 两种模式下均 `PASS`。

**位置：原版在屏幕左上角，不在主底栏旁（同日第二轮）**

原版 `0x42A850` 给每格传的 pos 就是 `(runningX, 2|3)`（`0x42A8ED` 写 `0x40000000`=2.0，
`0x42A9D8` 写 `0x40400000`=3.0）。`0x4542F0` 里的
`pos[0] += size[0]*0.5 - 400`、`pos[1] = 300 - (pos[1] + size[1]*0.5)`
（常量 `0x476474`=400.0、`0x476470`=**300.0**、`0x476364`=0.5）只是把**绝对屏幕坐标**
换算到居中世界空间，**不是**把条子放到屏幕中部。

反证（同一条绘制路径 `0x4542F0` 的另一个调用点 `0x428F80`）：该元素传
`pos=(220,400)`、`size=(358,165)`，而它自己的屏幕矩形是 `(220,400)-(578,565)`
（`[esp+0x10..0x1C]` 的 4 个整数与 float 参数一一对应）。按上式换算回来
`x = 220 + 358/2 = 399`、`y = 400 + 165/2 = 482.5` 正好是那个矩形的**中心** ——
即 `pos` 就是元素在屏幕上的左上角，投影是 `screen = world + (400, 300)`（1:1，y 轴翻转）。
所以技能条的屏幕位置就是 `(0, 2)`（有绑定）/ `(0, 3)`（空槽底板）——**屏幕左上角固定行**。

Godot 侧：legacy 下 `MagicBar.LegacyEiAnchor = (0,0)`，每格 y 直接用原版数值
（`EiIconTop=2` / `EiPlateTop=3`），控件 560×44；现代模式仍锚在主底栏左上方。
`RunUiLayoutAudit` 已按模式分支（`GameScene.cs` 常驻偏移断言）。

**像素级验证（2026-10-03，800×600 legacy 真机截图 vs `LegacyEI/Data` 源帧）**：

| 槽 | 期望 | 实测 |
|---|---|---|
| i=3..9（空槽，帧 23..29） | x = i·40 + 分组间隔，y=3 | **0 个像素不符**（7/7 帧全等，每帧 1588 个不透明像素） |
| i=0,1,2,10,11（有绑定） | y=2 | **0 个像素不符**，且逐帧唯一匹配到 MIcon **1000/1004/1008/1029/1016** |

MIcon 帧反查技能：1000→ID1 火球术、1004→ID5 大火球、1008→ID9 地域火、
1029→ID30 召唤神兽、1016→ID17 召唤骷髅 —— 与 `MagicInfo.Icon` 的
`1000 + Icon/2`（FireBall 0、AdamantineFireBall 8、ScorchedEarth 16、
SummonShinsu 58、SummonSkeleton 32）逐条吻合，**图标映射第二次独立验证通过**。

**补充负结果**：全 `.text` 中带 `cmp reg,4` + `cmp reg,8` 分组判断的代码只有
`0x42A893` 这一处（即绘制本身）→ 原版没有用同一几何的**点击命中**逻辑，
该行在原版应为**纯显示**；Godot 的「点格子施法」是 Zircon 侧既有能力，本次未改动。

**审计口径**：`MagicBar` 的常驻锚点断言在 `RunUiLayoutAudit`
（`GameScene.cs`，参数是 `--ui-layout-audit`，**不是** `--ui-audit`）里已按模式分支。
legacy 真机实测输出 `magic=(0, 0)/(560, 44)` 与 `LegacyEiAnchor` 一致。
**注意**：该审计当前恒为 `FAIL`，但失败项是**既有**的
`chatScroll=True`（`_chatLog.IsScrollChromeVisible`），与技能栏无关 ——
已在改动前的代码（`MagicBar` 仍锚 `(0,419)`）上复跑得到同样的 `FAIL ... chatScroll=True`。
UITestScene 的 `--ui-audit` 在 legacy 与 `--zircon-ui` 下均 `PASS`。

### 6.6 交易 close 热区改为「只播音不关窗」（`131a3514`）

原版 F1050 的 close 热区行为是「命中 → 播音 + 消费点击，窗口保持打开」
（`trade-window-render-evidence.json::buttons.close.behavior`，primary-static），
且其坐标 (532,350) 在 484 宽窗口之外、按窗口 rect 分派**不可达**。
Godot 此前把同一坐标按钮绑成 `CloseTrade()` → 多出一个非原版入口。
legacy 下改为不关窗（保留按钮以获得一致的点击音效）；Esc 仍是关闭入口。
验证：`--legacy-audit` trade=True；点击行为需第二玩家 → UNVERIFIED。

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
| I-2 | 背包 F280 gauge 轨道/拖柄 | **已闭合（MATCH）**（`2026-10-01`） | ①量纲（早前闭合）：`[bag+0x58] = trunc([bag+0x284] × 94.0f)`，94 = 100 行占位 − 6 可视行。②**rect 身份（本次闭合）**：`window_layout.json` 记录的是**原始 wrapper 输入**，其 `position_basis.final_screen_rect` 称「由共享构造器 `0x00423B30` 用 WIL 尺寸与锚点分支计算」。反汇编 `0x423B30` 证实：`0x423C27 lea eax,[esi+0x18]` + `call [0x4762b0](SetRect)` → **`this+0x18` 是 RECT{left,top,right,bottom}**，直接写成 `(x, y, x+w, y+h)`（w/h 取 `[esi+0x40]/[esi+0x44]`，来自入参或 WIL 尺寸）；末尾按 `arg&0xff`(0..3) 的**锚点分支**（跳转表 `0x423C8C` → `0x423C44/56/68/7A`）**只写 `[esi+0x50]`/`[esi+0x51]` 两个字节**（值 `0x96/0xB4/0xD2/0xFF`，alpha 类常量），**从不修改矩形** → **原始 (x,y) 就是最终屏幕矩形原点**。③原版 gauge 屏幕矩形：调用点 `0x0042EB91-0x0042EBB0` 读 `bag+0x18`(x)/`bag+0x1C`(y) 后 `add eax,0xF8` / `sub edx,0xA5`，连同 `[bag+0x58]`(值) 与 `0x5E`(=94, 上界) 传给 `0x4179B0` → **屏幕矩形 = bag屏幕原点 + (0xF8, −0xA5)，尺寸 16×424（F280）**。④端口实现：`InventoryDialog` legacy `_legacyScrollTrack`/`_legacyScrollBar` 用 `GameInter F280`、`Size=(16,424)`、**`Location=(248,−165)` = (0xF8,−0xA5)** —— 与原版一致。⑤**运行期验证**：在联机背包截图（F250 实测命中点 (644,96)）中按预测原点 (892,−69) 做 F280 分段模板匹配，取可见段（因控件 y 为负，上部越出屏幕）：段100→(892,31)、段200→(892,131)、段300→(892,231)，**偏移全部 (0,0)**，差 9.3–9.4（/255）。 |
| T-1 | 交易 close 热区语义 | **已修复（`131a3514`）** | `trade-window-render-evidence.json::buttons`：close (532,350) 在 484 宽窗口**之外**、只播音不关窗。Godot 现为 `TradeDialog.cs:37`：`if (_legacyEiLayout) return; CloseTrade();` —— legacy 下命中不关窗（Esc / `WindowManager.CloseTop` 仍是关闭入口），非 legacy 维持旧行为。**判定 MATCH**。 |
| I-3 | 背包 F161/162 / F264/265 / F267/268 语义 | `CONFIRMED_DIFFERENCE`（**已收窄为「点击无音效」**） | `inventory-mode-tabs-evidence.json`：三个页签是**装饰性子控件**（= 背包构造 `0x42E838` 的 `push 3; lea eax,[esi+0x5C]; push 0xB4` 三元素数组，本次交叉确认），单击只播音、不改模式；模式由服务端消息决定。Godot 侧 `InventoryDialog` 由 `InvMode`（外部/服务端驱动，`:25/:524`）绘制对应模式美术与标签（`:283/:312`），视觉一致；**唯一残余差**：点击页签区域原版有音效、Godot 无（纯音频差异，不影响可见状态）。 |
| H-1 | HUD cap2「技能图鉴」动作 | **已修复（`684a6e67`）** | EI cap2 点击只翻转 `[esi+0x6208]` 布尔 flag；原版该行 = 12 槽技能条（默认隐藏，由 cap2 / B 键 toggle），技能书是 cap8 / F100-101 的语义。Godot legacy 下 cap2/B 现已改为 toggle 12 槽技能条（`GameScene.cs:4611-4612`、`:4801-4807`），默认隐藏、不再打开技能书；非 legacy 维持旧行为。**判定 MATCH**。 |
| S-3 | HUD caption 按钮三态帧（16 键位条） | **已修复（`4ac1c1dc`）** | 同按钮类字段语义（`0x417640` + 鼠标 `0x417780/0x4177C0/0x4177F0`）：普通=`+0x20`=arg8、悬停=`+0x18`=arg2+文字、按下=`+0x1C`=arg3。16 个 caption 的 `arg8=-1`、`arg9=0`（证据 `hud-label-evidence.json::paint_state_machine.hud_caption_result`），按钮美术**已烘焙进 HUD 背景 F50**（像素比对 F80 在 F50 内最佳匹配 (203,2)）→ 普通/悬停都不该叠画帧。Godot `MainPanel.CreateButton` 已置 `Index=-1/HoverIndex=-1`（`PressedIndex` 仍取第二参=arg3）。验证：真机同点位（screen 320..430,552..585）对比——图标本体与 F50 烘焙细框保留、去掉多画的一层亮灰底板；证据 `docs/evidence/godot-runtime-acceptance-2026-09-30/15-hud-caption-overlay-before-after.png`。 |
| S-4 | 聊天窗频道键常态外观 | **已修复（`4abe4569`）** | 原版 ctor 实参（`0x414164` 起每键一组）：`arg8=-1`（普通态不画）、`arg2=360+2k`（亮绿=屏蔽/激活态）、`arg3=361+2k`（金色=按下态）、`arg9=0`（悬停不画帧，只画文字）；背景 **F350 在窗口相对 (25+40k,332) 处已烘焙灰白图标**（本轮直接解码 WIL 像素确认）。Godot 此前 `Index=360` 常显绿帧 → 改为 `Index/HoverIndex=-1`、`PressedIndex=arg3`。验证：真机聊天窗截图前后对比（亮绿 → 白/灰烘焙态，形状一致），证据 `.../14-chat-channel-icons-before-after.png`。 |
| S-5 | 坐骑窗 4 动作钮 + 关闭钮的三态帧 | **已修复（`2cd3b13b`）** | 实参 `(arg2,arg3,arg8)`：动作钮 (860,861,-1)/(862,863,-1)/(864,865,-1)/(866,867,-1)，关闭 (161,162,-1)，均 `arg9=0`。模板搜索确认 F850 内确有这些按钮美术（F860→(135,333) diff 15.9、F161→(359,382) diff 33.2，与窗口相对坐标精确对位）→ 普通/悬停都不该叠画帧。Godot `HorseDialog` 已置 `Index/HoverIndex=-1`、`PressedIndex` 保留 arg3。验证：真机开坐骑窗截图对比——4 动作钮与 ✕ 由亮灰叠画底板变为 F850 烘焙样式且仍清晰可见，证据 `.../16-horse-buttons-before-after.png`。 |
| S-6 | 各窗口**关闭钮**的叠画 | **部分修复后回退（`a891c010`）** | 初版（`b23d3399`）按「模板命中 F161」给 12 窗置 `Index=-1`，**过度套用**：真机逐窗截图（8 窗）发现**任务窗与行会窗的 ✕ 并未烘焙** → 改后 ✕ 消失（露出底色/黑块）；任务窗的滚动钮与两个操作图标同因（F723/721 是该窗控件自身绘制的美术）。另按「窗口到帧」精确位置比对，仓库/菜单/NPC 的 F161 diff 为 46-61（明显高于已验证烘焙的 32-34）→ 一并回退。**保留**（真机验证 ✕ 仍可见）：背包/角色/技能书/设置/组队/坐骑/聊天 的关闭钮，以及公告（精确位置 diff 32.0）与交易（原版本就纯热区）。详见报告 10.5。 |
| S-7 | 行会 8 个动作钮的三态帧 | **已修复（`2b541999`）** | 原版实参（`0x424EE7` 起每钮一组）`arg8=-1`、`arg9=0`，`(arg2,arg3)=(610,611)/(612,613)/…/(624,625)`；模板搜索：F610/612/614/616/618/620/622/624 在 F600 内最佳匹配 **diff 7.6–12.0**（两行 y=409/435 与规格表一致）→ 已烘焙。改动：`Index/HoverIndex=-1`、`PressedIndex=spec.pressed`。验证：真机开行会窗前后对比，8 钮由亮灰叠画底板变为 F600 烘焙样式且韩文标签清晰，证据 `.../19-guild-action-buttons-before-after.png`。 |
| S-8 | 商店购买钮 + 两处审计判据 | **已修复（`09a6b8bc`）** | 原版商店购买钮 `arg8=-1`、`arg9=0`，F1012 已烘焙进 F1000（模板搜索 **diff 6.4** @ (233,371)）→ `Index/HoverIndex=-1`、`PressedIndex=1013`。同时把两处**编码了旧叠画行为**的审计判据改为证据语义：`NPCDialog` 的 close（`Index==161`→`-1/-1/162`）、`GuildDialog` 的 8 动作钮（`Index==arg2`→`-1/-1/arg2+1`）。验证：`--legacy-audit` 由 FAIL 转 **PASS**（19 项子审计全 True，含 npc/guild/goods）。 |
| S-9 | 技能书导航钮 / 背包动作钮的叠画 | **已修复（`fd81d6a7`）/ 背包钮判定为无需改动** | 真机**隐藏法**判定：技能书 8 页签隐藏前后**完全一致** → F400 已烘焙（端口叠画的是红色变体，原版为蓝色烘焙）→ 页签 + 3 个导航钮（410/411、412/413、440/441）置 `Index/HoverIndex=-1` + `Modulate`，页签补 `FixedSize=true`（否则 Index 置 -1 会被 Index setter 把 Size 重算为 0、点击区失效）；**背包动作钮（수리，264/265）隐藏后文字消失 → 未烘焙 → 保持绘制不改**。验证：真机页签由红色叠画帧变为 F400 烘焙蓝色美术（证据 21）；`--legacy-audit` PASS。 |
| S-10 | 任务窗两个操作图标（F723/724、F721/722）的显示条件 | **已修复（`ebb02ed5`）** | **F700 已烘焙**这两个圆石按钮（白色右箭头与白色 ✕）——像素裁切确认；此前「隐藏后变黑」的黑块实为端口 `DXVScrollBar.BackColour=Colors.Black` 压在图标上。修正：4 个重叠控件（滚动条上下箭头 + 两个 `_legacyAcceptButton`/`_legacyPageButton`）置 `Index/HoverIndex=-1` + `Modulate=alpha0`，`_scroll.BackColour` 置透明。验证：真机由「绿色叠画+黑底」变为「F700 烘焙白色箭头/✕」（证据 22）；`--legacy-audit` PASS。 |
| S-11 | 角色窗"切换视图"钮（F168/169）的三态 | **已修复（`92a58841`）** | 该钮属**另一控件类 `0x417880`**（调用点 `0x44CD9F`：`push -1; push 0xA9(169); push 0xA8(168)`），其字段映射为 `+0x18=arg1(悬停)`、`+0x1C=arg2(按下)`、`+0x20=arg3(-1 → 普通态不画)`、`+0x25` 默认 0——与 `0x417550` 同类语义、仅实参顺序不同。真机隐藏法确认背景 F200 已烘焙白色箭头 → 端口此前画的绿色 171/172 属多余叠画。修正：`Index/HoverIndex=-1`、`PressedIndex=169`、`Modulate=alpha0`，并删除按视图改 PressedIndex(169/172) 的行。验证：真机由绿色箭头变为 F200 烘焙白色箭头（证据 23）；`--legacy-audit` PASS。另：全库 `0x417880` 调用点 42 处，仅 4 处 `arg3=-1`，其中仅本钮在端口实现（其余 398/399、760/761 等端口未使用）。 |
| S-12 | 技能书右页 Magic.exp 段落与所选技能**不匹配** | **已修复（`650fe5bb`）** | 真机联机复现：左页选中「焦土烈焰」→ 右页显示 `#34 [莲月剑法]`（完全不同技能的文本）。根因：EI 的 `Magic.exp` 只有 **50 段**，而 Zircon 有 **174 个魔法**，「段号 = 技能 id」不成立（Zircon Fire Ball id=23，EI 的 `#1` 才是 `[火球术]`）。修正：改为**按技能名匹配**（段落首行形如 `[莲月剑法] 属性 : …`，载入时按方括号内名字建索引），调用点传 `info.Local() ?? info.Name`。验证（真机联机、TestHero、服务端注入满级数据）：选中「火球术」→ 右页 `[火球术] 属性 : 自然系 / 元素 : 火(火 : 火力) / 修炼1级需要等级 : 7 …` 与所选一致（证据 24）；EI 表内无的技能（如焦土烈焰）段落为 null，不再显示错误文本；`--legacy-audit` PASS。 |
| G-1 | 行会解散业务 | `BLOCKED`（协议） | 原版掌门守卫 + 对话框 601 双确认；Zircon 无 disband 客户端包。 |
| Q-1 | 任务详情面板几何 | **已闭合（证据补齐）** | 2026-09-29 反汇编 `0x00447D58-0x00447F90` 恢复 primary-static 几何并写入 `quest-window-render-evidence.json::detail_geometry`：F705 @(win.x+0x41, win.y+0x126)=(65,294)，面板 204×76；正文 (win.x+0x50, win.y+0x136+15·row)=(80,310+15·row)，行距 15、3 行、色 0x7D0000。Godot `QuestDialog.RefreshLegacyDetail` 与该值一致（颜色差异见 §6.3）。 |
| Q-2 | 任务列表行几何与配色 | **已修复（`5767fe7c`）** | 原版列表行 **x=win.x+0x41=65、y=win.y+0x5A+15·line=90+15·line、行距 15、可见 19 行**（`0x00447618` `lea eax,[ecx+ecx*2+0x12]` = line*3+0x12；`0x00447622` `lea eax,[eax+eax*4]` = **×5**；`0x0044761F` `add ecx,0x41`；`0x004475DE` `cmp ecx,0x13`），配色 0x00BBGGRR：**选中 `0x1919C8`=RGB(25,25,200)、普通 `0x19197D`=RGB(25,25,125)**。修复前 Godot legacy 渲染**现代分组列表**（x=8/18/28、金色/白色、分组标题 + 行下任务描述），与 F700 该区域的**空白羊皮纸**（证据 28）不符。修复：legacy 分支改为**扁平行列表**（无分组标题/描述），几何/配色按上式；现代路径不变。验证：`--legacy-quest-rows-selftest` PASS —— 用客户端 DB **38 个真实 QuestInfo** 渲染 3 行，位置 (65,90)/(65,105)/(65,120)、普通色 RGB(25,25,125)、选中行 RGB(25,25,200)；`--legacy-audit` PASS；端口实机窗口与 EI F700 原图逐像素对齐（证据 27）。 |
| S-1 | 技能书根尺寸与页签 | 已澄清 | 见 C-1；Godot 452×380 与 8 页签坐标全部匹配。 |
| N-1 | NPC `mode=1 && overflow=1` 的 14px 行距分支 | **已修复（`9491984a`）** | 条件已由反汇编闭合（`dialogue_text_layout_contract`/`0x440AA0`）：`mode=1 ⇔ 正文含 {NPCIMG`（与字面量 `0x47C568` 比较）；`overflow=1 ⇔ 未截断段数 (raw_segment_count − 6) > 16`；`行距 = 14 仅当两者成立，否则 21`。Godot 侧新增 `NPCDialog.ComputeLegacyLinePitch(raw)`（按原文裸行数判定，不计自动换行），`_legacyPitch` 被第二列偏移/行级滚动/可视行数/两列切换共用。验证：10行/无图=21、10行/有图=21、22行+图=14（23−6=17>16 边界）、30行+图=14、30行/无图=21；`--legacy-npc-selftest` 集成通过且既有检查全 PASS（`offsetY=-21*18` 证明默认路径未变）。 |
| S-2 | 选角屏按钮三态帧（普通/悬停/按下） | **已修复（`41cd2543`）** | 原版 `0x417640` 绘制状态机 + 鼠标处理（`0x417780` 悬停置 `+0x25=1`、`0x4177C0` 按下置 2、`0x4177F0` 释放置 0）定性：普通态画 `+0x20`=ctor **arg8**、悬停态画 `+0x18`=**arg2**+文字、按下态画 `+0x1C`=**arg3**。Godot `MakeSelectIconButton(normal,hover,pressed)` 此前 5 处传成 `(arg8,arg3,arg2)`（悬停↔按下写反），已修正；同时修正 `--legacy-select-selftest` 中同样写反的期望表（含 `classMap` 帧号 91/94/97）。验证：自检 FAIL→**PASS**（9 钮 Index/HoverIndex/Location/Size 全匹配）。 |
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
