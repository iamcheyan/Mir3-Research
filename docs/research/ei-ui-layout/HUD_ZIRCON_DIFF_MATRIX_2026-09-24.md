# EI 主 HUD / 对话框差异矩阵（2026-09-24）

范围：EI 3.0 原版静态证据、Zircon `ui/legacy-layout-lab` 当前实现、`--legacy-ui --legacy-hud` 运行路径。运行资源固定为 `/home/tetsuya/mir2ei/Data`；NAS 资源未作为运行时输入。

证据等级：`primary-static` = 反汇编/静态调用；`primary-resource` = WIL/WIX 帧；`source-confirmed` = Zircon 源码；`runtime` = 本轮真实启动日志/截图。

| 项目 | EI 原版证据 | 当前 Zircon 实现 | 差异 / 根因 | 状态与优先级 |
|---|---|---|---|---|
| 主 HUD 根框 | `primary-main-hud-setrect.md`：`GameInter[50]`、逻辑底部 HUD `800×136`，根坐标相对 `(0,465)` | `MainPanel` 使用 F50；本轮把根尺寸固定为 `LegacyHudLayout.LogicalWidth/Height`（800×136），避免本地 WIL 帧头尺寸直接把根压成 `1024×68` | 本地 `/home/tetsuya/mir2ei/Data/GameInter.wil` 的 F50 头尺寸与 EI 证据记录不同；不能把帧画布尺寸当作目标根 RECT | 代码已修；需重启后像素复核；高 |
| 经验条 | `hud-bars-render-evidence.json`：F63；`primary-main-hud-setrect.md`：屏幕 `(61,586)-(400,597)`，相对 HUD `(61,121)`，填充按经验比例 | `MainPanel.ExperienceBar` 使用 F63、339×11、`(61,121)`；`DrawImage=false`，由 `DrawExperienceFill` 按当前/最大经验裁切绘制 | 旧根自动尺寸为 1024×68 时，F63 位于根外，且 DXImageControl 默认整帧绘制会覆盖 BeforeDraw 的比例裁切；当前已固定 800×136 并禁止默认整帧覆盖 | 比例绘制代码已修，commit `c6655f37`；独立 HUD 实验场以 `(250,1000)` 与 `(750,1000)` 分别运行，截图中填充连续段为 `x=99..202`（25%）与 `x=99..411`（75%），方向和长度均通过；实时网络经验增量来源仍未闭合 |
| 底部聊天栏 | `chat-window-unified-model.json`、`chat-window-render-evidence.json`：F350 是独立详细窗；HUD 聊天显示与消息接收分开 | `GameScene.ReceiveChat → _chatLog.AddMessage`，同时转发 `_legacyChatDialog`；legacy 初始化保持 `_chatLog` 可见；F350 真实截图中可见服务端 Announcement 文本 | 原实现把 `HideChatBar` 直接作用于 legacy `_chatLog`，可导致“接收链有数据但栏为空”；普通公开聊天不回显发送者自身，单客户端无法用普通文本闭合发送者视觉回显 | 接收链已修；F350/Announcement 已 runtime 验证；普通公开聊天需第二个可见玩家或观察者，当前环境未强行伪造 |
| 右侧聊天入口 | EI cap9/id8 进入 F350；F350 根 572×388、19 行历史、输入框和 6 个命令控件 | `MainPanel.MailButton` 在 legacy 分支调用 `_legacyChatDialog.OpenChat/CloseChat`；R 键在焦点保护前切换同一窗口，关闭时释放 Viewport focus；入口打开和 R 重开均在 deferred redraw 后刷新窗口子树 | 旧实现的重复显示路径漏掉 `WindowManager.Open` 的显示刷新，并且自定义 `Close` 未显式清理可见状态；现已统一窗口打开刷新、关闭清理和启动后重挂载 | HUD MailButton 首次打开、R 关闭/重开、关闭按钮关闭均 runtime 通过；`f350-button-entry-final-clean.png`、`f350-button-r-closed.png`、`f350-button-r-reopened.png` |
| 背包根框/网格 | `inventory-window-render-evidence.json`：F250，根 284×324，六列、六行可视区；记录表与可视占位格分离；`bag-list-fill-chain-evidence.json`：46 条记录、首格标记和跨格占位 | `InventoryDialog` F250、284×324、六列六行可视；legacy `DXItemGrid.UseLegacyFootprints` 使用 `Inventory.wil` 帧尺寸 first-fit 生成占位锚点并将 `ItemLibraryFile` 切到 `Inventory.wil`，`DXItemCell` 将记录槽位与可视格索引分离 | 服务器模型仍只提供记录槽位，未提供 EI 原始列/行字段；本地资源已按 selector 归属加载，但原始服务端位置和逐物品 footprint 仍未完全重建 | 占位/footprint 代码已修；离线布局截图已确认 F250/F280 同屏，需运行多格物品、拖放和滚动验收；高 |
| F280 滚动控件 | `inventory-window-render-evidence.json::paint_geometry[0]`：GameInter F280，16×424；六行视口；滚动值参与行扫描 | 加入 F280 track，位置 `(248,-165)`；透明 hit/drag 控件使用 `DXVScrollBar`，`VisibleSize=6`、`Change=1`、`UseLegacyFootprints` 动态计算实际行数，ValueChanged 写回 `Grid.ScrollValue` | 单机开发模式注入满级物品后，真实窗口显示 6×6 可视格；当前 first-fit 行数恰为 6，因此 `MaxValue-VisibleSize=0`，滚轮和下箭头稳定钳在 0，但没有移动范围。需超过 6 行的独立测试数据才能验证拖柄比例、内容移动和边界写回 | 轨道、六行裁剪和稳定无溢出边界已 runtime 验证；`inventory-dev-scroll-before.png`、`inventory-dev-scroll-wheel.png`、`inventory-dev-scroll-down-arrow.png`；移动行为仍阻塞 |
| 人物装备栏 | `status-window-render-evidence.json`：F200/F201；确认装备槽 Shoes `(64,264)`、Poison `(103,264)` 等 | `CharacterDialog` 保留 F200/F201 背景切换、8 个已证槽位和 F168/F171 切换按钮 | Weapon/Armour/Necklace 三个大 hit record 的完整拖放仍未迁移 | 收起/展开真实截图已通过：`character-runtime-collapsed.png`、`character-runtime-expanded.png`；装备拖放行为仍待验 |
| 人物属性面板 | `status-window-render-evidence.json`：第一列 13 个标签/格式项，起点 `(x+0xFF,y+0x43)`、行距 15；第二列 11 项，起点 `(x+0x17F,y+0x1E)`、行距 15 | 扩展态创建两列共 24 个可见文本项，使用 `PlayerStats`、当前 HP/MP、经验和负重；无法映射的中毒恢复显示 `—`，不猜值 | 旧实现为 7 项/12 项、22px 单列，且和 F201 艺术层重叠；原版部分全局字段与服务器 Stat 语义未闭合 | 几何/字段覆盖已改；未映射字段与原版多值魔法防御仍待独立证据；高 |

## 本轮静态核对

 - 构建：`dotnet build GodotClient/ZirconClient.csproj --no-incremental` 通过；仅保留既有 CS8632/CS0219 警告。服务端 `dotnet build ServerCore/ServerCore.csproj --no-restore` 通过，0 警告、0 错误。
 - 本地资源：最终运行使用 `MIR3_EI_ROOT=/home/tetsuya/mir2ei`、`ZIRCON_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`、`ZIRCON_LEGACY_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`；客户端日志确认 `GameInter.wil` 从该目录加载。运行服务端必须以 `/home/tetsuya/development/Debug/ServerCore` 为工作目录，否则相对 `Map/` 路径会导致地图加载为空并返回 `UnableToSpawn`。
 - 运行：在正确服务端工作目录和 Xvfb `:100` 下，客户端完整登录收到 `S.StartGame(Result=Success, Magics=174)`，并输出 `LegacyHud PASS`、`MapView 加载 D202: 200x200`；最新展开人物运行报告 viewport `1024×768`。截图保存在 Zircon `.artifacts/ui-acceptance-2026-09-24/`。
 - 重复场景防护：`LoginScene`、`SelectScene` 增加静态活动实例守卫，提交 `f1ec4d5e`；`DXWindow.ShowWindow` 增加子树重绘和 deferred 重绘，避免首次打开延迟纹理空白。
 - 经验条修复：`MainPanel.ExperienceBar.DrawImage=false`，避免 F63 默认整帧覆盖比例裁切；提交 `c6655f37`。

## 未闭合项目

1. 经验条比例绘制代码已修；独立 HUD 实验场已用第二组经验值完成动态填充复测：`experience-render-quarter.png` 与 `experience-render-threequarter.png`。实时登录客户端的经验包/命令增量仍未取得，不能把实验场结果冒称网络链路验收。
2. 已取得 F350 直达、HUD MailButton 鼠标打开、关闭按钮关闭、R 关闭后再次打开的真实截图；入口点击坐标为完整 1024×768 窗口中的 `845,659`，截图保存在 `.artifacts/ui-acceptance-2026-09-24/`。
3. 经验条动态复测尝试使用实际登录客户端和 `@level 2`；服务端日志确认测试账号 `Admin=False`，命令未产生等级/经验更新，前后 HUD bar crop 像素无变化；独立实验场已证明渲染器在 25%/75% 两个值下按比例裁切。
4. F280 轨道和 6×6 物品布局已用单机开发模式真实截图；滚轮/下箭头操作不再导致窗口消失，但当前 first-fit 没有超过 6 行，无法宣称内容滚动和拖柄边界通过。
5. 人物收起/展开真实截图已通过；Weapon/Armour/Necklace 大 hit record 行为仍未迁移。
6. 人物属性原始全局字段到 Zircon `Stat` 的完整语义映射仍需独立证据；无法映射字段继续显示 `—`，不猜值。
7. 本地 F50 资源帧头尺寸与 EI primary 记录存在版本/资源差异，需用独立 WIL 对照决定是否存在正确 EI F50 资源族。
