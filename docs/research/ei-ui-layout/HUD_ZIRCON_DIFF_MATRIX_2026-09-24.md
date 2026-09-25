# EI 主 HUD / 对话框差异矩阵（2026-09-24）

范围：EI 3.0 原版静态证据、Zircon `ui/legacy-layout-lab` 当前实现、`--legacy-ui --legacy-hud` 运行路径。运行资源固定为 `/home/tetsuya/mir2ei/Data`；NAS 资源未作为运行时输入。

证据等级：`primary-static` = 反汇编/静态调用；`primary-resource` = WIL/WIX 帧；`source-confirmed` = Zircon 源码；`runtime` = 本轮真实启动日志/截图。

| 项目 | EI 原版证据 | 当前 Zircon 实现 | 差异 / 根因 | 状态与优先级 |
|---|---|---|---|---|
| 主 HUD 根框 | `primary-main-hud-setrect.md`：`GameInter[50]`、逻辑底部 HUD `800×136`，根坐标相对 `(0,465)` | `MainPanel` 使用 F50；本轮把根尺寸固定为 `LegacyHudLayout.LogicalWidth/Height`（800×136），避免资源加载状态改变逻辑根框 | 本地 `/home/tetsuya/mir2ei/Data/GameInter.wil` 直接 WIL 头读取结果为 F50 `800×136`，与 EI primary 一致；帧画布尺寸仍不等于窗口逻辑锚点 | 代码已修；F50 资源差异已由独立 WIL 读取闭合；高 |
| 经验条 | `hud-bars-render-evidence.json`：F63；`primary-main-hud-setrect.md`：屏幕 `(61,586)-(400,597)`，相对 HUD `(61,121)`，填充按经验比例裁切 | `MainPanel.ExperienceBar` 使用 F63、339×11、`(61,121)`；`DrawImage=false`，由 `DrawExperienceFill` 按当前/最大经验裁切绘制 | 旧根自动尺寸为 1024×68 时，F63 位于根外，且 DXImageControl 默认整帧绘制会覆盖 BeforeDraw 的比例裁切；当前已固定 800×136 并禁止默认整帧覆盖 | 比例绘制代码已修，commit `c6655f37`；独立 HUD 实验场 25%/75% 填充方向和长度通过；Round 786 已收到两次真实 `GainedExperience`，网络来源与经验条更新链闭合 |
| 底部聊天栏 | `chat-window-unified-model.json`、`chat-window-render-evidence.json`：F350 是独立详细窗；HUD 聊天显示与消息接收分开 | `GameScene.ReceiveChat → _chatLog.AddMessage`，同时转发 `_legacyChatDialog`；legacy 初始化保持 `_chatLog` 可见；同视野 BotRunner→TestHero 真实普通文本同时出现在底栏和 F350 | 旧实现把 `HideChatBar` 直接作用于 legacy `_chatLog`，会导致“接收链有数据但栏为空”；服务端普通公开聊天只发给 `SeenByPlayers` 且受 `MaxViewRange` 约束，启动顺序/视野未闭合时不能收到 | 接收链与同视野服务端分派已 runtime 闭合；`chat-bot-to-testhero-bottom.png`、`chat-bot-to-testhero-f350-proof.png`；此前空栏根因已定位为可见列表/视野前置，不再阻塞 |
| 右侧聊天入口 | EI cap9/id8 进入 F350；F350 根 572×388、19 行历史、输入框和 6 个命令控件 | `MainPanel.MailButton` 在 legacy 分支调用 `_legacyChatDialog.OpenChat/CloseChat`；R 键在焦点保护前切换同一窗口，关闭时释放 Viewport focus；入口打开和 R 重开均在 deferred redraw 后刷新窗口子树 | 旧实现的重复显示路径漏掉 `WindowManager.Open` 的显示刷新，并且自定义 `Close` 未显式清理可见状态；现已统一窗口打开刷新、关闭清理和启动后重挂载 | HUD MailButton 首次打开、R 关闭/重开、关闭按钮关闭均 runtime 通过；`f350-button-entry-final-clean.png`、`f350-button-r-closed.png`、`f350-button-r-reopened.png` |
| 背包根框/网格 | `inventory-window-render-evidence.json`：F250，根 284×324，六列、六行可视区；记录表与可视占位格分离；`bag-list-fill-chain-evidence.json`：46 条记录、首格标记和跨格占位 | `InventoryDialog` 使用 F250、284×324、六列六行可视；`DXItemGrid.UseLegacyFootprints` 依据 `Inventory.wil` 帧尺寸 first-fit 生成占位锚点，`DXItemCell` 将记录槽位与可视格索引分离；协议 `ClientUserItem`/`C.ItemMove`/`S.ItemMove` 仅携带 `Slot`、网格和移动结果，没有 EI cell-table 或 footprint 字段 | 2026-09-25 真实运行截图 `inventory-multicell-runtime.png` 显示 Armour 图标跨 2 列×3 行且占位格未重复绘制；`UserItem.Slot` 在服务端持久化并由 `ToClientInfo()` 原样下发，`PlayerObject.ItemMove()` 只按数组槽位交换/回写；服务端没有可直接还原 EI `[bag+0x324]` WORD cell-table 的协议输入 | 多格 footprint 运行表现已闭合；静态协议核对确认不能安全补齐 EI cell-table 映射，继续采用有证据约束的 first-fit 重建；服务器原始 cell-table 语义仍保留为证据限制；高 |
| F280 滚动控件 | `inventory-window-render-evidence.json::paint_geometry[0]`：GameInter F280，16×424；六行视口；滚动值参与行扫描 | 加入 F280 track，位置 `(248,-165)`；透明 hit/drag 控件使用 `DXVScrollBar`，`VisibleSize=6`、`Change=1`、`UseLegacyFootprints` 动态计算实际行数，ValueChanged 写回 `Grid.ScrollValue`；初始化顺序已修为先 `ApplyLegacyCoreTestLayouts()` 再绑定 `ItemGrid`/计算行数；PositionBar 已允许进入 `DXControl.Movable` 拖拽路径 | 原根因是 `ConfigureLegacyInventoryGrid()` 早于 `ApplyLegacyEiLayout()` 执行，导致 `_legacyEiLayout=false`、`UseLegacyFootprints=false`、`VisibleHeight=int.MaxValue`，真实数据始终退化为现代网格；第二个输入根因是 `DXButton.CanBePressed=false` 在基类拖拽逻辑前吞掉左键。两项均已修。临时客户端测试将同一真实 `Gold` 记录复制至 48 个槽位，first-fit 得到 8 行、滚动范围 0..2；滚轮到尾部、下边界稳定、拖柄回顶均通过 | 初始化顺序 commit `a96e4941`；拖柄 commit `90a4b151`；`inventory-scroll-overflow-before.png`、`inventory-scroll-overflow-wheel.png`、`inventory-scroll-overflow-down-arrow.png`、`inventory-scroll-overflow-drag-top.png` 已 runtime 保存；临时注入代码已完全回退，正式工作区不依赖测试数据 |
| 人物装备栏 | `status-window-render-evidence.json`、`equipment-slots-evidence.json`：F200/F201；11 个 client slot record 与 `EquipmentSlot` 0..10 一一对应，Weapon `(86,114,60×90)`、Armour `(38,70,53×84)`、Necklace `(94,71,49×33)`、Shoes `(64,264)`、Poison `(103,264)` 等 | `CharacterDialog` 使用证据中的 11 个窗口相对 RECT/尺寸；`DXItemCell` 保留记录槽位、跨格 footprint 与 `MoveItem`/`ToEquipment` 通路 | 大 hit record 已补齐为可见且可命中区域；2026-09-25 使用 `Wood Sword` 完成真实服务端背包/装备往返、替换、恢复和失败操作保护 | 几何、hit record 与端到端拖放均已闭合；Round 787，Zircon 临时夹具已回退 |
| 人物属性面板 | `status-window-render-evidence.json` 与 `status-option-names-evidence.json`：第一列 14 个标签/值，起点 `(x+0xFF,y+0x43)`、行距 15；第二列 11 个标签，起点 `(x+0x17F,y+0x1E)`、行距 15；`魔法`、`魔法防御力` 在 `0x0044BC80–0x0044CCCC` 仅绘制标签、没有值绘制 | 扩展态创建第一列 14 项和第二列 11 个标签；已证值使用 `PlayerStats`；`魔法躲避`、`毒物躲避`、三项恢复以及 `魔法`/`魔法防御力` 保持保守占位/标签-only，不冒称当前 Stat | 旧实现为 7 项/12 项、22px 单列，且和 F201 艺术层重叠；先前漏掉原版 `魔法躲避` 标签，并把 `毒物躲避` 错映为 `PoisonResistance`；现按 primary-static 的字符串/调用顺序补齐并撤回无证映射 | 几何/字段覆盖已改；14 个首列标签、16 个首列/次列值绘制计数与原版调用链对齐；无证字段仍显示 `—`，两行 label-only 不显示占位值，高 |

## 本轮静态核对

 - 构建：`dotnet build GodotClient/ZirconClient.csproj --no-incremental` 通过；仅保留既有 CS8632/CS0219 警告。服务端 `dotnet build ServerCore/ServerCore.csproj --no-restore` 通过，0 警告、0 错误。
 - 本地资源：最终运行使用 `MIR3_EI_ROOT=/home/tetsuya/mir2ei`、`ZIRCON_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`、`ZIRCON_LEGACY_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`；客户端日志确认 `GameInter.wil` 从该目录加载。运行服务端必须以 `/home/tetsuya/development/Debug/ServerCore` 为工作目录，否则相对 `Map/` 路径会导致地图加载为空并返回 `UnableToSpawn`。
 - 运行：在正确服务端工作目录和 Xvfb `:100` 下，客户端完整登录收到 `S.StartGame(Result=Success, Magics=174)`，并输出 `LegacyHud PASS`、`MapView 加载 D202: 200x200`；最新展开人物运行报告 viewport `1024×768`。截图保存在 Zircon `.artifacts/ui-acceptance-2026-09-24/`。
 - 重复场景防护：`LoginScene`、`SelectScene` 增加静态活动实例守卫，提交 `f1ec4d5e`；`DXWindow.ShowWindow` 增加子树重绘和 deferred 重绘，避免首次打开延迟纹理空白。
 - 经验条修复：`MainPanel.ExperienceBar.DrawImage=false`，避免 F63 默认整帧覆盖比例裁切；提交 `c6655f37`。

 - 聊天滚动资源复核（Round 798）：本地 `GameInter.wil` 的 F380 是 `16×502` 锁链轨道，F381/F382/F383 为空；因此 Zircon 不再把 F380 整轨误绘成上下按钮，改为证据约束的 `19×14` 透明命中区并输出缺失帧日志。轨道、滚轮、上下命中区、边界、拖动释放和手动上滚后的新消息锚点均已在当前构建真实运行中验证；EI 原版按钮具体像素仍受目标 WIL/WIX 身份不可达阻塞。
## 当前仍保留的限制

1. 经验条比例绘制和 `GainedExperience` 网络更新链已由 Round 786 的管理员真实击杀闭合；标准账号 Round 795 在 S13 邮件阶段因 `server_success=false` 未进入 S16，标准运行根若要复现真实击杀仍需提供与当前怪物数据匹配的 `Mon-*.Zl` 夹具。该项是运行资源/账号路径限制，不是 HUD 绘制逻辑阻塞。
2. 背包已通过真实 Armour 跨 2 列×3 行截图和 48 槽滚动夹具验证 footprint/滚动表现。协议核对确认 Zircon `ClientUserItem` 只有 `Slot` 等记录字段，`C.ItemMove`/`S.ItemMove` 只有网格、源/目标槽位、合并和成功状态；服务端 `UserItem.Slot` 持久化并由 `ToClientInfo()` 原样下发，`PlayerObject.ItemMove()` 按数组槽位处理。EI 的 46 条记录和 `[bag+0x324]` 六列 WORD cell-table（含首格 `slot+0x3E8` 标记）没有对应网络字段或服务端语义闭环，因此当前实现继续采用有证据约束的 first-fit 重建，不把它宣称为原版网络布局还原。
3. 人物属性中 `魔法躲避`、`毒物躲避`、`中毒恢复`、`生命恢复`、`魔法恢复` 的原始字段尚未获得独立 Zircon `Stat` 语义映射，继续显示 `—`。原版 `魔法`、`魔法防御力` 在该绘制区间为 label-only，不绘制值占位符。
4. 属性验收日志中的 `ERR_CANT_OPEN` 已确认来自 `drivers/alsa/audio_driver_alsa.cpp:90`，Xvfb 无音频设备时回退 dummy driver；不属于 UI 资源阻塞，记录于 `RESEARCH_LOG.md` Round 793。

## 已闭合验收记录

1. F350 直达、HUD MailButton 鼠标打开、关闭按钮、R 键关闭/重开和输入焦点均已真实验证。
2. F280 初始化顺序、滚轮、拖柄、边界和多行内容均已真实验证。
3. 人物 11 个装备槽、装备拖放往返、属性窗口收起/展开及保守字段显示均已真实验证。
4. F50/F60/F61/F63 资源帧头已由独立 WIL/WIX 读取闭合；运行资源固定为 `/home/tetsuya/mir2ei/Data`。
