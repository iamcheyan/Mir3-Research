# EI 主 HUD / 对话框差异矩阵（2026-09-24）

范围：EI 3.0 原版静态证据、Zircon `ui/legacy-layout-lab` 当前实现、`--legacy-ui --legacy-hud` 运行路径。运行资源固定为 `/home/tetsuya/mir2ei/Data`；NAS 资源未作为运行时输入。

证据等级：`primary-static` = 反汇编/静态调用；`primary-resource` = WIL/WIX 帧；`source-confirmed` = Zircon 源码；`runtime` = 本轮真实启动日志/截图。

| 项目 | EI 原版证据 | 当前 Zircon 实现 | 差异 / 根因 | 状态与优先级 |
|---|---|---|---|---|
| 主 HUD 根框 | `primary-main-hud-setrect.md`：`GameInter[50]`、逻辑底部 HUD `800×136`，根坐标相对 `(0,465)` | `MainPanel` 使用 F50；本轮把根尺寸固定为 `LegacyHudLayout.LogicalWidth/Height`（800×136），避免本地 WIL 帧头尺寸直接把根压成 `1024×68` | 本地 `/home/tetsuya/mir2ei/Data/GameInter.wil` 的 F50 头尺寸与 EI 证据记录不同；不能把帧画布尺寸当作目标根 RECT | 代码已修；需重启后像素复核；高 |
| 经验条 | `hud-bars-render-evidence.json`：F63；`primary-main-hud-setrect.md`：屏幕 `(61,586)-(400,597)`，相对 HUD `(61,121)`，填充按经验比例 | `MainPanel.ExperienceBar` 使用 F63、339×11、`(61,121)`，`DrawExperienceFill` 按当前/最大经验裁切绘制 | 旧根自动尺寸为 1024×68 时，F63 位于根外，形成“经验条错位/不可见”；当前已固定 800×136 | 代码已修；本轮因客户端存在重复登录/选择场景覆盖，未取得新 HUD 像素截图；高 |
| 底部聊天栏 | `chat-window-unified-model.json`、`chat-window-render-evidence.json`：F350 是独立详细窗；HUD 聊天显示与消息接收分开 | `GameScene.ReceiveChat → _chatLog.AddMessage`，同时转发 `_legacyChatDialog`；legacy 初始化保持 `_chatLog` 可见；隐藏设置不再误隐藏 legacy HUD | 原实现把 `HideChatBar` 直接作用于 legacy `_chatLog`，可导致“接收链有数据但栏为空” | 已修；需用普通聊天文本做 runtime 复测；高 |
| 右侧聊天入口 | EI cap9/id8 进入 F350；F350 根 572×388、19 行历史、输入框和 6 个命令控件 | `MainPanel.MailButton` 在 legacy 分支调用 `_legacyChatDialog.OpenChat/CloseChat`；R 键仍走同一窗口 | 原实现只切换 `_chatLog.Visible`，未打开 F350 | 已修；点击/R/关闭后再次点击需 runtime 验收；高 |
| 背包根框/网格 | `inventory-window-render-evidence.json`：F250，根 284×324，六列、六行可视区；记录表与可视占位格分离 | `InventoryDialog` F250、284×324、六列六行可视；`ConfigureLegacyInventoryGrid` 按注入记录数量计算总行数 | 记录索引仍直接作为 `DXItemCell.Slot`；跨格 footprint/占位表尚无协议模型字段，不能声称完全 EI 等价 | F250/视口已对齐；滚动路径已接线；footprint 仍阻断；高 |
| F280 滚动控件 | `inventory-window-render-evidence.json::paint_geometry[0]`：GameInter F280，16×424；六行视口；滚动值参与行扫描 | 加入 F280 track，位置 `(248,-165)`；透明 hit/drag 控件使用 `DXVScrollBar`，`VisibleSize=6`、`Change=1`，ValueChanged 写回 `Grid.ScrollValue` | 轨道资源与交互已分离；原版 94 定点 gauge 与完整占位扫描仍未完全重建 | 已修可滚动语义的可达部分；需运行拖动/滚轮/边界验收；高 |
| 人物装备栏 | `status-window-render-evidence.json`：F200/F201；确认装备槽 Shoes `(64,264)`、Poison `(103,264)` 等 | `CharacterDialog` 保留 F200/F201 背景切换、8 个已证槽位和 F168/F171 切换按钮 | Weapon/Armour/Necklace 三个大 hit record 的完整拖放仍未迁移 | 几何已修；行为仍待验；高 |
| 人物属性面板 | `status-window-render-evidence.json`：第一列 13 个标签/格式项，起点 `(x+0xFF,y+0x43)`、行距 15；第二列 11 项，起点 `(x+0x17F,y+0x1E)`、行距 15 | 扩展态创建两列共 24 个可见文本项，使用 `PlayerStats`、当前 HP/MP、经验和负重；无法映射的中毒恢复显示 `—`，不猜值 | 旧实现为 7 项/12 项、22px 单列，且和 F201 艺术层重叠；原版部分全局字段与服务器 Stat 语义未闭合 | 几何/字段覆盖已改；未映射字段与原版多值魔法防御仍待独立证据；高 |

## 本轮静态核对

- 构建：`dotnet build GodotClient/ZirconClient.csproj --no-incremental` 通过；仅保留既有 CS8632/CS0219 警告。
- 本地资源：`MIR3_EI_ROOT=/home/tetsuya/mir2ei`、`ZIRCON_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`、`ZIRCON_LEGACY_UI_DATA_PATH=/home/tetsuya/mir2ei/Data`；实际 WIL fallback 日志确认 `GameInter.wil` 从该目录加载。
- 运行：本地服务端监听 7000；客户端收到 `S.StartGame(Result=Success)`、`MapView` 首帧和 `LegacyHud` 诊断。客户端日志同时出现重复 Login/Select 流程，导致选择场景覆盖截图，故本轮不把选择场景截图冒称 HUD 验收。

## 未闭合项目

1. 需要隔离客户端重复 Login/Select 实例后，重新取得完整 1024×768 游戏 HUD 截图。
2. 需要普通安全聊天文本闭合 `ReceiveChat → ChatLogPanel` 的视觉验收，并保存 F350 三路径截图。
3. 背包需补齐原版记录索引与占位表、跨格物品 footprint、F280 原版数值比例；当前实现明确不冒充已完成。
4. 人物属性原始全局字段到 Zircon `Stat` 的完整语义映射仍需证据；当前 `—` 是阻塞标记，不是猜测值。
5. 本地 F50 资源帧头尺寸与 EI primary 记录存在版本/资源差异，需用独立 WIL 对照决定是否存在正确 EI F50 资源族。
