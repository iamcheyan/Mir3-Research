# EI 主 HUD / 对话框差异矩阵（2026-09-24）

范围：EI 3.0 原版静态证据、Zircon `ui/legacy-layout-lab` 当前实现、`--legacy-ui --legacy-hud` 运行路径。运行资源固定为 `/home/tetsuya/mir2ei/Data`；NAS 资源未作为运行时输入。

证据等级：`primary-static` = 反汇编/静态调用；`primary-resource` = WIL/WIX 帧；`source-confirmed` = Zircon 源码；`runtime` = 本轮真实启动日志/截图。

| 项目 | EI 原版证据 | 当前 Zircon 实现 | 差异 / 根因 | 状态与优先级 |
|---|---|---|---|---|
| 主 HUD 根框 | `primary-main-hud-setrect.md`：`GameInter[50]`、逻辑底部 HUD `800×136`，根坐标相对 `(0,465)` | `MainPanel` 使用 F50；本轮把根尺寸固定为 `LegacyHudLayout.LogicalWidth/Height`（800×136），避免资源加载状态改变逻辑根框 | 本地 `/home/tetsuya/mir2ei/Data/GameInter.wil` 直接 WIL 头读取结果为 F50 `800×136`，与 EI primary 一致；帧画布尺寸仍不等于窗口逻辑锚点 | 代码已修；F50 资源差异已由独立 WIL 读取闭合；高 |
| 经验条 | `hud-bars-render-evidence.json`：F63；`primary-main-hud-setrect.md`：屏幕 `(61,586)-(400,597)`，相对 HUD `(61,121)`，填充按经验比例裁切 | `MainPanel.ExperienceBar` 使用 F63、339×11、`(61,121)`；`DrawImage=false`，由 `DrawExperienceFill` 按当前/最大经验裁切绘制 | 旧根自动尺寸为 1024×68 时，F63 位于根外，且 DXImageControl 默认整帧绘制会覆盖 BeforeDraw 的比例裁切；当前已固定 800×136 并禁止默认整帧覆盖 | 比例绘制代码已修，commit `c6655f37`；独立 HUD 实验场 25%/75% 填充方向和长度通过；Round 786 已收到两次真实 `GainedExperience`，网络来源与经验条更新链闭合 |
| 底部聊天栏 | `RESEARCH_LOG.md:2819`：F50 内主 HUD 聊天总区为屏幕 `(224,492)-(578,566)`，相对 F50 根 `(224,27)`、`354×74`；`chat-window-unified-model.json` / `chat-window-render-evidence.json` 只描述独立 F350 详细窗 | `GameScene.ReceiveChat → AddChatMessage → _chatLog.AddMessage` 与 `_legacyChatDialog.AddMessage` 共享同一接收事件；legacy `_chatLog` 现固定 `354×74`、裁剪并锚到 `_mainPanel.Position+(224,27)`；legacy `OnChat` 直接使用服务端已包装的 `p.Text`，不再重复添加发送者/类型前缀；HUD 行使用 8px、14px 行距、关闭 outline/阴影、保持不透明白色普通聊天文字，消息底色透明，由 F50 提供底板 | 原根因是 `_chatLog` 的现代 `400×150` 几何脱离 F50 聊天槽；消息链本身存在。修复后真实日志显示 `hudVisible=True`、连续 `hudMessages/hudLines` 增长，普通消息和 89 字长消息均进入 HUD；`ChatLogPanel` 的 `14px` 最小行高与 `ClipContents` 保持槽内裁剪，F50 不再叠加每条消息的白色背景 | 已修；1024×768 真实登录截图：`chat-hud-fixed-baseline.png`、`chat-hud-r-message-final.png`、`chat-hud-long-message-fixed.png`、`chat-hud-style-final.png`；普通消息发送者只出现一次。EI 公开静态证据未给出主 HUD 文本颜色字节，当前白色普通聊天色以 Zircon 原有 `LocalTextForeColour` 和可见运行结果为依据，保留该证据等级边界 |
| 主 HUD 输入框 | `RESEARCH_LOG.md:2819` 的 F50 根 `(0,465)` 与运行证据的 HUD 相对关系：输入条位于聊天槽下方，legacy 相对 `(223,105)`、`354×16`；原版文本编辑控件提交后清空并保留消息环 | `ChatTextBox.ApplyLegacyHudLayout` 使用 `354×16` 和 `_mainPanel.Position+(223,105)`；`DXTextInput` 负责焦点、光标、Enter、清空/失焦；新增 `InputHasFocus` 供全局快捷键判断 | 除原先的几何缩放差异外，发现 `GameScene._Input` 的 EI `R` 快捷键只排除了 F350 输入焦点，主 HUD 输入框获得焦点时输入 `R` 会误开 F350，后续字符落入错误窗口；现在同时保护 `_chatTextBox.InputHasFocus`。普通文本、含 `R` 文本、长文本均可输入，提交日志显示长度并在提交后清空 | 已修；真实截图：`chat-hud-fixed-focus.png`、`chat-hud-r-input-fixed.png`、`chat-hud-long-input-fixed.png`；日志含 `[ChatInput] focus`、`submit` 且无误开 F350 |
| 常驻 HUD 与 F350 关系 | F350 根 `572×388`；历史区 `(40,29)-(531,308)`，19 行、14px；输入 `(25,311)-(524,326)`；HUD 仅显示 F50 聊天槽，不是 F350 根的裁剪/子节点 | `_chatLog` 与 `_legacyChatDialog` 都由 `AddChatMessage` 接收；F350 行布局保持 19×14px；MailButton/cap9 与 R 仍路由 F350，主 HUD 输入和记录区保持独立 | 消息模型共享、显示窗口独立：HUD 使用 `354×74` 裁剪区，F350 保持 `572×388`；打开/关闭 F350 不清空 HUD。右侧 MailButton 实际点击日志为 `LegacyOpen requested=chat`，关闭后 HUD 消息仍在；R 仅在没有任一聊天输入焦点时打开/关闭 F350 | 已修；截图：`chat-hud-right-button-open-f350.png`、`chat-hud-f350-closed-final.png`；普通消息在 HUD/F350 两端均可见，入口命中区闭合 |

## 主 HUD 常驻聊天模型闭合（2026-09-25，本轮前置）

1. **根 RECT、锚点、背景、裁剪、层级**：EI `GameInter[50]` 是 `800×136`，根位于旧版 `(0,465)`；F50 内聊天总槽为 `(224,492)-(578,566)`，即根相对 `(224,27)`、`354×74`。聊天槽不另画 F350 背景，底色/边框来自 F50；文字应在独立透明控件内裁剪。主 HUD 在 UI layer 中先于聊天记录、再先于 HUD 输入条；F350 是之后打开的独立顶层窗口。证据：`RESEARCH_LOG.md:2819`、`hud-caption-action-tail-evidence.json`、`chat-window-render-evidence.json`。
2. **相对坐标与缩放**：F50 根保持 `800×136` 逻辑尺寸并随 viewport 居中；因此当前 Zircon 1024×768 逻辑 viewport 的聊天槽应为 `mainPanel.Position + (224,27)`，输入条应为 `mainPanel.Position + (223,105)`，均保持 `354×74` / `354×16`，不能再次套用 `LegacyUiSkin.ToGodot*` 的 1024/800、768/600 比例。血球相对 `(49,13)`、经验条 `(61,121)`，右侧操作按钮仍以 F50 根坐标为准。
3. **HUD 与 F350 消息关系**：原版 F350 是独立 id8 详细窗，历史最大 19 行、14px 步长，HUD 槽是独立显示面；两者消费同一收到的聊天消息，但各自维护可见行/滚动。新消息在位于底部时滚到底；F350 手动上滚后新消息不能强制跳回；关闭/重开 F350 不应删除 HUD 消息。证据：`chat-window-unified-model.json` 的 `message_list`/`draw_chain`、`chat-window-mouse-dispatch.json`。
4. **输入框模型**：F350 原版输入 RECT 是 `(25,311)-(524,326)`，字体由共享文字绘制器提供，行高 14px；HUD 输入是 F50 下方独立窄条，当前可确认的 legacy 相对槽为 `(223,105)-(577,121)`。空状态显示空文本、焦点显示光标，Enter 提交后清空并失焦；普通文本走 `C.Chat`，不发送拒绝/喊话模板作为本轮验收输入。证据：`chat-window-render-evidence.json`、`chat-input-command-dispatch-evidence.json`、服务端 `PlayerObject.Chat`。
5. **根因与闭合状态**：修复前 `GameScene.OnChat` 已订阅 `ChatEvent`，`ReceiveChat/AddChatMessage` 已同时写 `_chatLog` 和 `_legacyChatDialog`；可见差异是 `_chatLog` 的现代 `400×150` 几何脱离 F50 聊天槽，且 legacy `OnChat` 对服务端已包装的 `p.Text` 重复添加发送者。当前代码已改为共享 legacy 几何和 legacy 文本路径；HUD 行关闭 outline/阴影、消息底色透明且保持不透明，真实日志确认 `[LegacyChat] receive`、HUD 消息计数增长和槽内裁剪，不以降低透明度掩盖问题。
6. **右侧入口命中**：EI cap9 的 F102/F103 “聊天记录”命中区打开/关闭 id8/F350；不是 HUD 输入框，也不是现代好友/邮件窗口。当前 `MainPanel.MailButton` legacy 分支调用 `_legacyChatDialog.OpenChat/CloseChat`，R 键同一路由；HUD 输入仍是独立点击命中区。证据：`hud-caption-action-tail-evidence.json`、`chat-window-mouse-dispatch.json`、`GameScene.cs:4701-4714,10526-10536`。

### 本轮验收方法

- 运行根固定为 `/home/tetsuya/mir2ei`，环境变量 `MIR3_EI_ROOT`、`ZIRCON_UI_DATA_PATH`、`ZIRCON_LEGACY_UI_DATA_PATH` 均指向 `/home/tetsuya/mir2ei/Data`。
- 以完整 `1024×768` viewport、`--legacy-ui --legacy-hud` 真实登录；先建立同图同 `MaxViewRange` 的普通聊天发送端，再验证客户端 `StartGame Result=Success`、`ChatEvent`、`[LegacyChat]` 几何/消息日志。
- 截图必须保留完整 viewport：HUD 空状态、输入焦点、未提交、提交后清空并显示、连续消息、长消息裁剪、入口/F350 开关/返回；每张记录命令、状态和结论。
- 通过条件：HUD 文字落在 F50 `(224,27,354×74)`，5 行左右按 14px 视觉行距裁剪，输入为 `(223,105,354×16)`；F350 仍为 `572×388`、19 行、14px；普通消息发送者只出现一次；地图切换和 F350 开关不清空 HUD。
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

## 人物状态面板最终复测（2026-09-25）

本轮复测只使用 Zircon `ui/legacy-layout-lab`、`/home/tetsuya/mir2ei/login_game.sh legacy`、本地资源 `/home/tetsuya/mir2ei/Data`、Xvfb `:100` 和完整 `1024×768` viewport。`S.StartGame(Result=Success)` 后 stdout 记录 `hitRecords=11 paperDoll=(122,164)`、F200 `(244,328)`、F201 `(520,328)`；未见 ERROR/Exception/FAIL。

| 验收项 | 运行证据 | 结论 |
|---|---|---|
| 根框/人物/装备 | `status-equipment-final.png`、`status-body-hit-hover.png` | 收起态 F200 244×328、展开态 F201 520×328；Weapon 大命中区悬停出现真实 `Moonlight, Light in the Darkness` 物品详情，证明纸娃娃之上的 60×90 hit proxy 生效 |
| 属性双列与动态值 | `status-attributes-final.png` | 左列 14 标签/值，右列 11 标签；HP/MP 当前/上限、经验百分比、包袱/装备负重使用现有协议数据；无独立语义的字段不填假值 |
| 关闭/重开/Esc | `status-esc-final.png`、`status-reopen-final.png` | Esc 关闭后无残留 hover tooltip；再次打开保留 F201 展开态 |
| 装备格交互边界 | 源码 `CharacterDialog.cs`、`DXItemCell.cs` | 11 条 hit record 均由 DXItemCell 承载；锁定格中键解锁守卫已修正。为避免写入测试装备，本轮只做 hover/命中验证，未重复执行左键取下/替换 |

对应 Zircon 归档目录：`/home/tetsuya/development/zircon/.artifacts/ui-acceptance-2026-09-24/`。EI 专用耐久/强化/绑定角标仍无独立贴图证据，继续保持证据边界，不以现代 ZL 或自绘 fallback 宣称像素一致。

注：表中早先“无证字段显示 `—`”的措辞以本轮实现为准更正为“标签保留、值控件为空且隐藏”；截图 `status-attributes-final.png` 为最终行为证据。

跨地图/重新登录后的窗口状态保持、本轮左键装备拖放未重复执行；研究矩阵既有 Round 787 Wood Sword 往返记录仍有效但不属于本轮 hover-only 复测。目标 EI 专用状态角标和限制标记的独立贴图/绘制证据仍缺失，因此该部分不宣布像素级闭合。
## STATUS-02 跨地图/重新登录回归补证（2026-09-25）

在 `DISPLAY=:100`、完整 `1024×768` viewport、本地 `/home/tetsuya/mir2ei/login_game.sh legacy` 会话中，人物窗口保持 F200 属性态后执行 `@move D202`。stdout 记录 `MapIndex=137 -> D202 (Deserted Mine Lv 2)` 与 `MapView 加载 D202: 200x200`；`status-map-before.png` / `status-map-after.png` 证明切图后人物窗口仍可见，F200 属性态、装备区域和属性显示未被窗口重建清空。前置 `@move D201` 因本地服务端没有对应地图索引而失败，该尝试不计入通过。

停止客户端后再次经同一 `login_game.sh legacy` 入口登录 `TestHero`，最终构建复测 stdout 记录 `S.StartGame Result=Success` 与 D202 加载；`status-relogin-final2.png` 与最新 `status-relogin-final3-open.png` 证明重新登录后状态窗可以重新打开并显示装备页，且无关闭前遗留 tooltip。截图只证明重新建立窗口的可用性，不证明跨进程展开态持久化；原版是否持久化仍无独立语义证据。

当前状态标记结论不变：EI 专用耐久、强化、绑定、职业/等级限制角标仍缺少目标版独立贴图与绘制链，不能以现代 ZL 或自绘 fallback 宣称像素一致。对应 Zircon 归档：`/home/tetsuya/development/zircon/.artifacts/ui-acceptance-2026-09-24/status-map-before.png`、`status-map-after.png`、`status-relogin-final2.png`、`status-relogin-final3-open.png`。
## STATUS-03 最终源码构建与登录冒烟（2026-09-25）

恢复临时 `OperationAudit` 选择夹具后的正式源码执行 `dotnet build GodotClient/ZirconClient.csproj --no-incremental`，0 errors（仅现有 nullable/unused warnings）。随后在 `DISPLAY=:100`、1024×768 窗口、`/home/tetsuya/mir2ei` 资源环境下直接登录 `TestHero`；stdout 记录 `S.StartGame Result=Success`、`进入游戏`、`[LegacyCharacter] ... root=(244,328) ... hitRecords=11` 与 `[ProductionScreenshot] PASS ... viewport=1022x739`。归档 `status-runtime-final-2026-09-25.png` 是 Zircon runtime evidence，不是 EI 原版截图；退出仅见 Godot renderer RID 泄漏诊断，无人物面板异常、ERROR/Exception/FAIL。
## STATUS-04 装备往返证据边界（2026-09-25）

恢复源码后直接运行 `--operation-audit`，登录与窗口初始化成功；诊断夹具按背包首件选到 `Healing Potion (II)`，因没有兼容的已装备目标而安全退出，未发送装备移动包。此前同一源码链使用临时、可回退的 Wood Sword 选择夹具完成六步往返，stdout 断言 `forward=True reverse=True equipmentRestored=True equipmentSlotCanonical=True failedSortPreserved=True failedSplitPreserved=True failedDeletePreserved=True pass=True`；夹具已恢复、正式源码无差异。该记录证明 DXItemCell/GameScene 安全往返链，不构成 EI 状态角标贴图证据；耐久/强化/绑定/职业等级限制贴图与绘制链仍阻塞。
## STATUS-05 EI 装备状态标记资源边界（2026-09-25）

新增 `status-marker-resource-audit.json`，复核 `0x0044B560-0x0044B6AD` 的 11 槽循环，并独立反汇编 `0x00430A40-0x00430B69`：`item_record+0x22` 只选择 82/83/139 三个图库上下文，最终进入 `0x00460240` 物品图像合成；两段闭合路径都没有耐久、强化、绑定、职业/等级限制或红点 marker 分支。对本地 `Interface1c.wil`、`GameInter.wil`、`inventory.wil` 的小帧扫描只能排除误认，不能赋予候选帧状态语义。

因此 Zircon `DXItemCell` 增加 `DrawItemBadgesEnabled`，EI `CharacterDialog` 装备槽明确关闭通用 `Interface` 47/48/49/103 角标；背包等非 EI 状态窗口不变。该改动是证据边界修复，不是新增 EI 角标。目标版各状态的独立贴图、调用链和逐状态运行截图仍阻塞像素级闭合。
## STATUS-06 装备槽悬停/按下运行证据（2026-09-25）

真实 `/home/tetsuya/mir2ei/login_game.sh legacy`、1024×768 会话中对空 Torch 槽 `(177,70,38×38)` 做中心悬停和鼠标按下；`status-slot-hover-guard.png`、`status-slot-pressed-guard.png` 归档于 Zircon `.artifacts/ui-acceptance-2026-09-24/`。两态均保持同一 38×38 命中矩形，未触发物品移动或写库。当前绿色边框/半透明红底来自 `DXItemCell.UpdateBorder` fallback；EI 选中覆盖层只有 `status-window-render-evidence.json` 的 primary-static-candidate 资源选择证据，未宣称像素级一致。
