# EI 主 HUD / 对话框差异矩阵（2026-09-24）

范围：EI 3.0 原版静态证据、Zircon `ui/legacy-layout-lab` 当前实现、`--legacy-ui --legacy-hud` 运行路径。运行资源固定为 `/home/tetsuya/mir2ei/Data`；NAS 资源未作为运行时输入。

证据等级：`primary-static` = 反汇编/静态调用；`primary-resource` = WIL/WIX 帧；`source-confirmed` = Zircon 源码；`runtime` = 本轮真实启动日志/截图。

| 项目 | EI 原版证据 | 当前 Zircon 实现 | 差异 / 根因 | 状态与优先级 |
|---|---|---|---|---|
| 主 HUD 根框 | `primary-main-hud-setrect.md`：`GameInter[50]`、逻辑底部 HUD `800×136`，根坐标相对 `(0,465)` | `MainPanel` 使用 F50；本轮把根尺寸固定为 `LegacyHudLayout.LogicalWidth/Height`（800×136），避免资源加载状态改变逻辑根框 | 本地 `/home/tetsuya/mir2ei/Data/GameInter.wil` 直接 WIL 头读取结果为 F50 `800×136`，与 EI primary 一致；帧画布尺寸仍不等于窗口逻辑锚点 | 代码已修；F50 资源差异已由独立 WIL 读取闭合；高 |
| 经验条 | `hud-bars-render-evidence.json`：F63；`primary-main-hud-setrect.md`：屏幕 `(61,586)-(400,597)`，相对 HUD `(61,121)`，填充按经验比例裁切 | `MainPanel.ExperienceBar` 使用 F63、339×11、`(61,121)`；`DrawImage=false`，由 `DrawExperienceFill` 按当前/最大经验裁切绘制 | 旧根自动尺寸为 1024×68 时，F63 位于根外，且 DXImageControl 默认整帧绘制会覆盖 BeforeDraw 的比例裁切；当前已固定 800×136 并禁止默认整帧覆盖 | 比例绘制代码已修，commit `c6655f37`；独立 HUD 实验场 25%/75% 填充方向和长度通过；Round 786 已收到两次真实 `GainedExperience`，网络来源与经验条更新链闭合 |
| 底部聊天栏 | `chat-window-unified-model.json`、`chat-window-render-evidence.json`：F350 是独立详细窗；HUD 聊天显示与消息接收分开 | `GameScene.ReceiveChat → _chatLog.AddMessage`，同时转发 `_legacyChatDialog`；legacy 初始化保持 `_chatLog` 可见；同视野 BotRunner→TestHero 真实普通文本同时出现在底栏和 F350 | 旧实现把 `HideChatBar` 直接作用于 legacy `_chatLog`，会导致“接收链有数据但栏为空”；服务端普通公开聊天只发给 `SeenByPlayers` 且受 `MaxViewRange` 约束，启动顺序/视野未闭合时不能收到 | 接收链与同视野服务端分派已 runtime 闭合；`chat-bot-to-testhero-bottom.png`、`chat-bot-to-testhero-f350-proof.png`；此前空栏根因已定位为可见列表/视野前置，不再阻塞 |
| 右侧聊天入口 | EI cap9/id8 进入 F350；F350 根 572×388、19 行历史、输入框和 6 个命令控件 | `MainPanel.MailButton` 在 legacy 分支调用 `_legacyChatDialog.OpenChat/CloseChat`；R 键在焦点保护前切换同一窗口，关闭时释放 Viewport focus；入口打开和 R 重开均在 deferred redraw 后刷新窗口子树 | 旧实现的重复显示路径漏掉 `WindowManager.Open` 的显示刷新，并且自定义 `Close` 未显式清理可见状态；现已统一窗口打开刷新、关闭清理和启动后重挂载 | HUD MailButton 首次打开、R 关闭/重开、关闭按钮关闭均 runtime 通过；`f350-button-entry-final-clean.png`、`f350-button-r-closed.png`、`f350-button-r-reopened.png` |
| 背包根框/网格 | `inventory-window-render-evidence.json`：F250，根 284×324，六列、六行可视区；记录表与可视占位格分离；`bag-list-fill-chain-evidence.json`：46 条记录、首格标记和跨格占位 | `InventoryDialog` F250、284×324、六列六行可视；legacy `DXItemGrid.UseLegacyFootprints` 使用 `Inventory.wil` 帧尺寸 first-fit 生成占位锚点并将 `ItemLibraryFile` 切到 `Inventory.wil`，`DXItemCell` 将记录槽位与可视格索引分离 | 服务器模型仍只提供记录槽位，未提供 EI 原始列/行字段；本地资源已按 selector 归属加载，但原始服务端位置和逐物品 footprint 仍未完全重建 | 占位/footprint 代码已修；离线布局截图已确认 F250/F280 同屏，需运行多格物品、拖放和滚动验收；高 |
| F280 滚动控件 | `inventory-window-render-evidence.json::paint_geometry[0]`：GameInter F280，16×424；六行视口；滚动值参与行扫描 | 加入 F280 track，位置 `(248,-165)`；透明 hit/drag 控件使用 `DXVScrollBar`，`VisibleSize=6`、`Change=1`、`UseLegacyFootprints` 动态计算实际行数，ValueChanged 写回 `Grid.ScrollValue`；初始化顺序已修为先 `ApplyLegacyCoreTestLayouts()` 再绑定 `ItemGrid`/计算行数；PositionBar 已允许进入 `DXControl.Movable` 拖拽路径 | 原根因是 `ConfigureLegacyInventoryGrid()` 早于 `ApplyLegacyEiLayout()` 执行，导致 `_legacyEiLayout=false`、`UseLegacyFootprints=false`、`VisibleHeight=int.MaxValue`，真实数据始终退化为现代网格；第二个输入根因是 `DXButton.CanBePressed=false` 在基类拖拽逻辑前吞掉左键。两项均已修。临时客户端测试将同一真实 `Gold` 记录复制至 48 个槽位，first-fit 得到 8 行、滚动范围 0..2；滚轮到尾部、下边界稳定、拖柄回顶均通过 | 初始化顺序 commit `a96e4941`；拖柄 commit `90a4b151`；`inventory-scroll-overflow-before.png`、`inventory-scroll-overflow-wheel.png`、`inventory-scroll-overflow-down-arrow.png`、`inventory-scroll-overflow-drag-top.png` 已 runtime 保存；临时注入代码已完全回退，正式工作区不依赖测试数据 |
| 人物装备栏 | `status-window-render-evidence.json`、`equipment-slots-evidence.json`：F200/F201；11 个 client slot record 与 `EquipmentSlot` 0..10 一一对应，Weapon `(86,114,60×90)`、Armour `(38,70,53×84)`、Necklace `(94,71,49×33)`、Shoes `(64,264)`、Poison `(103,264)` 等 | `CharacterDialog` 使用证据中的 11 个窗口相对 RECT/尺寸；`DXItemCell` 保留记录槽位、跨格 footprint 与 `MoveItem`/`ToEquipment` 通路 | 大 hit record 已补齐为可见且可命中区域；2026-09-25 使用 `Wood Sword` 完成真实服务端背包/装备往返、替换、恢复和失败操作保护 | 几何、hit record 与端到端拖放均已闭合；Round 787，Zircon 临时夹具已回退 |
| 人物属性面板 | `status-window-render-evidence.json`：第一列 13 个标签/格式项，起点 `(x+0xFF,y+0x43)`、行距 15；第二列 11 项，起点 `(x+0x17F,y+0x1E)`、行距 15；“魔法”读取一个原始 word，“魔法防御力”读取六个原始 word | 扩展态创建两列共 24 个可见文本项，使用已闭合的 `PlayerStats` 字段；无法独立映射的中毒恢复/生命恢复/魔法恢复/魔法/魔法防御力显示 `—`，不猜值 | 旧实现为 7 项/12 项、22px 单列，且和 F201 艺术层重叠；原版 MC/MR 标签下的原始字段形状与当前 `Stat` 范围模型不一致 | 几何/字段覆盖已改；无证据字段已保守处理；剩余仅为原版字段到服务端语义的证据阻塞，高 |

## 本轮静态核对

 - 构建：`dotnet build GodotClient/ZirconClient.csproj --no-incremental` 通过；仅保留既有 CS8632/CS0219 警告。服务端 `dotnet build ServerCore/ServerCore.csproj --no-restore` 通过，0 警告、0 错误。
 - 本地资源：最终运行使用 `MIR3_EI_ROOT=/home/tetsuya/mir2ei`、`ZIRCON_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`、`ZIRCON_LEGACY_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`；客户端日志确认 `GameInter.wil` 从该目录加载。运行服务端必须以 `/home/tetsuya/development/Debug/ServerCore` 为工作目录，否则相对 `Map/` 路径会导致地图加载为空并返回 `UnableToSpawn`。
 - 运行：在正确服务端工作目录和 Xvfb `:100` 下，客户端完整登录收到 `S.StartGame(Result=Success, Magics=174)`，并输出 `LegacyHud PASS`、`MapView 加载 D202: 200x200`；最新展开人物运行报告 viewport `1024×768`。截图保存在 Zircon `.artifacts/ui-acceptance-2026-09-24/`。
 - 重复场景防护：`LoginScene`、`SelectScene` 增加静态活动实例守卫，提交 `f1ec4d5e`；`DXWindow.ShowWindow` 增加子树重绘和 deferred 重绘，避免首次打开延迟纹理空白。
 - 经验条修复：`MainPanel.ExperienceBar.DrawImage=false`，避免 F63 默认整帧覆盖比例裁切；提交 `c6655f37`。

## 未闭合项目

1. 经验条比例绘制代码已修；独立 HUD 实验场已用第二组经验值完成动态填充复测：`experience-render-quarter.png` 与 `experience-render-threequarter.png`。2026-09-25 使用本地临时 `Mon-*.Zl` 夹具完成真实击杀，客户端收到两次 `GainedExperience`，经验网络更新链闭合；证据见 `RESEARCH_LOG.md` Round 786 与 Zircon `.artifacts/ui-acceptance-2026-09-24/experience-after-gained-runtime.png`。标准运行根仍需提供 `Mon-*.Zl` 才能复现。
2. 已取得 F350 直达、HUD MailButton 鼠标打开、关闭按钮关闭、R 关闭后再次打开的真实截图；入口点击坐标为完整 1024×768 窗口中的 `845,659`，截图保存在 `.artifacts/ui-acceptance-2026-09-24/`。
3. 经验条早期动态复测曾使用实际登录客户端和 `@level 2`；该次因测试账号 `Admin=False` 未产生更新，不能作为经验验收证据。后续 Round 786 已通过管理员刷怪/真实击杀收到 `GainedExperience`，以 Round 786 记录为准。
4. F280 两个根因均已闭合：旧版窗口布局应用晚于 `ConfigureLegacyInventoryGrid()`，以及 `DXButton.CanBePressed=false` 在 `DXControl` 进入 Movable 拖拽前吞掉滑块左键；分别由 `a96e4941`、`90a4b151` 修复。独立客户端临时测试将真实 `Gold` `ClientUserItem` 复制到 48 槽位，验证 8 行、范围 0..2、滚轮内容换行、下边界稳定、拖柄回顶；临时注入已回退。
5. 人物收起/展开真实截图已通过；本次补齐 `Weapon`、`Armour`、`Necklace` 三个大 hit record 及全部 11 个 EI 装备槽的窗口相对尺寸；截图 `character-equipment-slots-w-continue.png`、`character-equipment-slots-expanded-continue.png`。2026-09-25 使用 `Wood Sword` 完成真实背包前移/回移、卸下/穿戴/恢复原装备及失败操作保护，服务端 `ItemMove` 回包和最终断言均通过；证据见 `RESEARCH_LOG.md` Round 787。
6. 人物属性已证字段映射保留；“中毒恢复/生命恢复/魔法恢复/魔法/魔法防御力”均不再冒称 Zircon `Stat`，统一显示 `—`。原版“魔法”一个 word、 “魔法防御力”六个 word 的字段形状见 Round 790；待独立交叉证据后再决定是否恢复映射。
7. F50 资源帧头差异已由 `Tools/common/wilsdk.py` 直接读取 `/home/tetsuya/mir2ei/Data/GameInter.wil/.wix` 闭合：库计数 1103，F50=`800×136`、F60/F61=`56×110`、F63=`164×6`，与 EI primary HUD 证据一致；不再作为未闭合项目。
8. 2026-09-25 继续验收闭合：先启动 BotRunner 的 Bot01，再启动 TestHero 图形客户端，使 `SeenByPlayers` 建立；两者 map index 1、约 `(119,231)` 同一 `MaxViewRange` 内。TestHero 日志收到 `Net 入队: Chat`，底部截图 `chat-bot-to-testhero-bottom.png` 显示 `[Normal] Bot01: ...`，F350 截图 `chat-bot-to-testhero-f350-proof.png` 同样显示普通文本。此前同图但视野列表未建立/角色超出范围的截图不作为反例；聊天验收阻塞解除。

9. 2026-09-25 F350 输入焦点补修：`DXTextInput._GuiInput()` 左键按下显式聚焦内部 `LineEdit`；`GameScene._Input()` 在 F350 输入框聚焦时不再吞裸 `R`。修复后点击输入区提交 `@monster Chicken 1` 的服务端日志文本完整，截图 `f350-input-complete.png`、`f350-command-complete.png`；服务端命令本身因当前命令表返回不存在提示，不将其误记为刷怪/经验验收。
