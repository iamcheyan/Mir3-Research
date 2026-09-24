# EI 主 HUD / 对话框差异矩阵（2026-09-24）

范围：EI 3.0 原版静态证据、Zircon `ui/legacy-layout-lab` 当前实现、`--legacy-ui --legacy-hud` 运行路径。运行资源固定为 `/home/tetsuya/mir2ei/Data`；NAS 资源未作为运行时输入。

证据等级：`primary-static` = 反汇编/静态调用；`primary-resource` = WIL/WIX 帧；`source-confirmed` = Zircon 源码；`runtime` = 本轮真实启动日志/截图。

| 项目 | EI 原版证据 | 当前 Zircon 实现 | 差异 / 根因 | 状态与优先级 |
|---|---|---|---|---|
| 主 HUD 根框 | `primary-main-hud-setrect.md`：`GameInter[50]`、逻辑底部 HUD `800×136`，根坐标相对 `(0,465)` | `MainPanel` 使用 F50；本轮把根尺寸固定为 `LegacyHudLayout.LogicalWidth/Height`（800×136），避免本地 WIL 帧头尺寸直接把根压成 `1024×68` | 本地 `/home/tetsuya/mir2ei/Data/GameInter.wil` 的 F50 头尺寸与 EI 证据记录不同；不能把帧画布尺寸当作目标根 RECT | 代码已修；需重启后像素复核；高 |
| 经验条 | `hud-bars-render-evidence.json`：F63；`primary-main-hud-setrect.md`：屏幕 `(61,586)-(400,597)`，相对 HUD `(61,121)`，填充按经验比例 | `MainPanel.ExperienceBar` 使用 F63、339×11、`(61,121)`，`DrawExperienceFill` 按当前/最大经验裁切绘制 | 旧根自动尺寸为 1024×68 时，F63 位于根外，形成“经验条错位/不可见”；当前已固定 800×136 | 代码已修；本轮因客户端存在重复登录/选择场景覆盖，未取得新 HUD 像素截图；高 |
| 底部聊天栏 | `chat-window-unified-model.json`、`chat-window-render-evidence.json`：F350 是独立详细窗；HUD 聊天显示与消息接收分开 | `GameScene.ReceiveChat → _chatLog.AddMessage`，同时转发 `_legacyChatDialog`；legacy 初始化保持 `_chatLog` 可见；直达 F350 运行截图中可见服务端 Announcement 文本 | 原实现把 `HideChatBar` 直接作用于 legacy `_chatLog`，可导致“接收链有数据但栏为空”；普通公开聊天不回显发送者自身，单客户端无法用普通文本闭合发送者视觉回显 | 接收链已修；F350/Announcement 已 runtime 验证；普通公开聊天需第二个可见玩家或观察者，当前环境未强行伪造 |
| 右侧聊天入口 | EI cap9/id8 进入 F350；F350 根 572×388、19 行历史、输入框和 6 个命令控件 | `MainPanel.MailButton` 在 legacy 分支调用 `_legacyChatDialog.OpenChat/CloseChat`；R 键仍走同一窗口 | 原实现只切换 `_chatLog.Visible`，未打开 F350 | 代码已修；`--legacy-open=chat` 真实截图确认 F350 根/链条/输入框；HUD 点击与 R/关闭后 R 重开受当前 Xvfb 键盘注入不稳定影响 |
| 背包根框/网格 | `inventory-window-render-evidence.json`：F250，根 284×324，六列、六行可视区；记录表与可视占位格分离；`bag-list-fill-chain-evidence.json`：46 条记录、首格标记和跨格占位 | `InventoryDialog` F250、284×324、六列六行可视；legacy `DXItemGrid.UseLegacyFootprints` 使用 `Inventory.wil` 帧尺寸 first-fit 生成占位锚点并将 `ItemLibraryFile` 切到 `Inventory.wil`，`DXItemCell` 将记录槽位与可视格索引分离 | 服务器模型仍只提供记录槽位，未提供 EI 原始列/行字段；本地资源已按 selector 归属加载，但原始服务端位置和逐物品 footprint 仍未完全重建 | 占位/footprint 代码已修；离线布局截图已确认 F250/F280 同屏，需运行多格物品、拖放和滚动验收；高 |
| F280 滚动控件 | `inventory-window-render-evidence.json::paint_geometry[0]`：GameInter F280，16×424；六行视口；滚动值参与行扫描 | 加入 F280 track，位置 `(248,-165)`；透明 hit/drag 控件使用 `DXVScrollBar`，`VisibleSize=6`、`Change=1`、`UseLegacyFootprints` 动态计算实际行数，ValueChanged 写回 `Grid.ScrollValue` | 轨道资源与交互已分离；原版 94 定点 gauge 与记录列/行服务端位置仍未完全重建 | 滚动语义可达部分已修；需运行拖动/滚轮/边界验收；高 |
| 人物装备栏 | `status-window-render-evidence.json`：F200/F201；确认装备槽 Shoes `(64,264)`、Poison `(103,264)` 等 | `CharacterDialog` 保留 F200/F201 背景切换、8 个已证槽位和 F168/F171 切换按钮 | Weapon/Armour/Necklace 三个大 hit record 的完整拖放仍未迁移 | 几何已修；行为仍待验；高 |
| 人物属性面板 | `status-window-render-evidence.json`：第一列 13 个标签/格式项，起点 `(x+0xFF,y+0x43)`、行距 15；第二列 11 项，起点 `(x+0x17F,y+0x1E)`、行距 15 | 扩展态创建两列共 24 个可见文本项，使用 `PlayerStats`、当前 HP/MP、经验和负重；无法映射的中毒恢复显示 `—`，不猜值 | 旧实现为 7 项/12 项、22px 单列，且和 F201 艺术层重叠；原版部分全局字段与服务器 Stat 语义未闭合 | 几何/字段覆盖已改；未映射字段与原版多值魔法防御仍待独立证据；高 |

## 本轮静态核对

 - 构建：`dotnet build GodotClient/ZirconClient.csproj --no-incremental` 通过；仅保留既有 CS8632/CS0219 警告。服务端 `dotnet build ServerCore/ServerCore.csproj --no-restore` 通过，0 警告、0 错误。
 - 本地资源：最终运行使用 `MIR3_EI_ROOT=/home/tetsuya/mir2ei`、`ZIRCON_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`、`ZIRCON_LEGACY_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`；客户端日志确认 `GameInter.wil` 从该目录加载。运行服务端必须以 `/home/tetsuya/development/Debug/ServerCore` 为工作目录，否则相对 `Map/` 路径会导致地图加载为空并返回 `UnableToSpawn`。
 - 运行：在正确服务端工作目录和 Xvfb `:100` 下，客户端完整登录收到 `S.StartGame(Result=Success, Magics=174)`，并输出 `LegacyHud PASS`、`MapView 加载 D202: 200x200`。最终基线截图保存在 Zircon `.artifacts/ui-acceptance-2026-09-24/game-final-correct-cwd.png`。
 - 重复场景防护：`LoginScene`、`SelectScene` 增加静态活动实例守卫，提交 `f1ec4d5e`；`DXWindow.ShowWindow` 增加子树重绘和 deferred 重绘，避免首次打开延迟纹理空白。

## 未闭合项目

1. 经验条需在完整 HUD 截图中以不同经验值复核填充长度和方向；当前静态 `LegacyHud PASS` 已确认 F63/339×11/(61,121)。
2. 已取得 `--legacy-open=chat` 的 F350 真实截图，窗口根和服务端 Announcement 文本可见；普通公开聊天文本不回显发送者自身，单客户端无法完成 `ReceiveChat → ChatLogPanel` 的普通文本视觉闭环；HUD 点击、R、关闭后再次打开仍需稳定输入注入复测。
3. 背包需运行多格物品、拖放、滚轮、拖柄和边界验收；当前离线截图已确认 F250/F280 资源与 6×6 视口，服务端记录索引到 EI 原始列/行仍未完全重建。
4. 人物装备栏需在真实游戏中验收；当前已保留 F200/F201、8 个已证槽位和切换按钮，Weapon/Armour/Necklace 大 hit record 行为仍未迁移。
5. 人物属性原始全局字段到 Zircon `Stat` 的完整语义映射仍需独立证据；无法映射字段继续显示 `—`，不猜值。
6. 本地 F50 资源帧头尺寸与 EI primary 记录存在版本/资源差异，需用独立 WIL 对照决定是否存在正确 EI F50 资源族。
