# GodotClient EI UI 真实联机运行验收（2026-09-30）

> 本文件记录一次**真实登录进游戏**的端到端运行验收，用于补上矩阵里
> 「联机链路」的 `UNVERIFIED` 缺口（见待决台账 B-9）。
> 所有结论来自真实进程：隔离服务端 + 800×600 客户端 + 真实按键/点击。

## 1. 环境

| 项 | 值 |
|---|---|
| 客户端 | `GodotClient`（commit `752a41cc`，legacy 模式默认） |
| 服务端 | **自建隔离实例**：`/tmp/godot-parity-srv`（由 `/tmp/ei-flow-srv` 复制，改 `Port=7002`/`UserCountPort=3002`），`dotnet ServerCore.dll` |
| 数据库 | 上述实例自带的 **副本**（未触碰生产/共享库，未改任何运行中服务端的数据） |
| 显示 | Xvfb `:101` 1280×960×24 + openbox；`scrot` 截图 |
| 客户端窗口 | 800×600（`--window`），客户区在屏幕 (128,100)-(928,700) |
| 账号/角色 | `test@test.com` / `EIFlow1`（该副本库里唯一的角色） |
| 输入注入 | `xdotool key f` / `xdotool mousemove X Y click 1` |

启动：
```bash
cd /tmp/godot-parity-srv && dotnet ServerCore.dll        # 监听 127.0.0.1:7002
godot-mono --path GodotClient -- --server 127.0.0.1 --port 7002 \
    --user test@test.com --pass test123 --char EIFlow1 --window
```

## 2. 流程与结果

| # | 步骤 | 结果 | 证据 |
|---|---|---|---|
| 1 | 启动 → WeMade 片头 → 登录 | 登录成功，`[Login] 登录成功, 角色数 1` | — |
| 2 | 选角屏 | EI 布局渲染（F50 背景、开始/创建/删除/结束按钮、1 个角色预览）；`--char TestHero` 不存在时正确拒绝 | 首轮截图 |
| 3 | 开始游戏 → StartGame 过场 | `[LegacySelect] 过场 StartGame.ogv 播放完毕` → 黑屏公告框（GameInter F0，19 字） | `parity-30-notice.png` |
| 4 | 点击公告框确认 ✔ | `[LegacySelect] 公告框底部对勾 -> 进入游戏` → `[Game] 进入游戏! 玩家: EIFlow1, 位置: (161,238), 地图: 1`（Bichon Town） | — |
| 5 | 进游戏后的 HUD | EI 主 HUD：双球体（HP/MP）、底部操作栏、AC/DC 数值、小地图、聊天栏 | `01-ingame-hud.png` |
| 6 | **按 Q** | 打开 **legacy 背包窗** | `03-bag-window-after-Q.png` |
| 7 | **按 F** | 打开 **legacy 行会窗** | `02-guild-window-after-F.png` |
| 8 | 背包与行会窗并存 | 两窗同帧可见、互不关闭 | `03-bag-window-after-Q.png` |

## 3. 验收点逐项核对

### 3.1 背包（任务书重点：格子数量/尺寸/起点）

`04-bag-grid-6x6-zoom.png` 是背包网格区的 2 倍放大。逐格点数：

- **列 = 6、行 = 6 → 36 格**（与 `inventory-window-render-evidence.json` 的
  `0x42F150`「0..0xD8 步进 0x24=36」、`0x42F2A0`「index%6 / ÷6」一致）
- 格子**无间隙**，36×36（`GridPadding=0`、`Step=36`）
- 网格起点窗口相对 **(25,41)**（= `win.x+0x19, win.y+0x29`）
- `负重 0/总量 1899` —— 原版格式 `负重:%d / 总量:%d`（`0x47BDFC`，mode-0 分支）
- `金钱 100000172` —— 原版金币框 `%d`（`0x47A214`）**且颜色 0x64C8F8 浅蓝**一致
- `[包袱]` —— 原版 mode-0 标签 `0x47BE10`
- `수리` 按钮 —— 原版 ctrl1 = F264/265 常驻美术（本模式不变帧）✓
- 右侧**锁链滚动轨** —— 原版 F280 位置 `(x+0xF8, y-0xA5) = (248,-165)` ✓

→ **背包可视几何与标签在真实运行中与原版一致**（矩阵 §6.4 由静态+lab 升级为真机）。

### 3.2 行会（本轮修复的回归）

`02-guild-window-after-F.png`：F600 背景 + `문파` 烘焙标题 + 底部 8 个韩文动作控件
（골드 지불 / 골드 수락 / 문파 석제 / 문파 제해 + 문파 표기 / 문파 제공 / 전위 수락 / 문파 해제）
+ 滚动条 + 关闭键；成员列表区为空（该角色无行会）。

- 修复前（`b8c26340` 状态）同一步骤显示的是**现代「创建行会」页**
  （步骤 1..4 / 加入新手行会 / 创建行会）+ EI 8 按钮的混合 UI。
- 修复后（`752a41cc`）混合 UI 消失 ✓。原版该窗**没有**创建行会入口，
  无行会即空列表 —— 属 1:1 行为。

### 3.3 窗口互斥/叠放

背包与行会窗**同帧并存**，证实 Godot 与 EI 一致：
`0x42B820`（窗口切换前的「demote-all」）只重置 `+0x34` 活动槽，
**不动 `+0x30` 可见门、不摘链表节点** → 原版窗口**不互斥**
（`window-visibility-dispatch-evidence.json::close_all_first`）。矩阵 §5 的 MATCH 得到真机印证。

## 4. 本轮真机验收暴露并已修复的缺陷

| 缺陷 | 症状 | 修复 |
|---|---|---|
| legacy 行会窗残留现代建会页 | 无行会角色按 F 看到「步骤 1..4 / 创建行会」混合 UI | `ApplyLegacyEiLayout` 末尾补 `RefreshRows()`（commit `752a41cc`） |

> 说明：该缺陷**只在真实联机路径出现**（构造期先跑现代 RefreshRows、之后无行会数据
> 就不再刷新），`LegacyHudLayoutLab --legacy-audit` 与 `--ui-audit` 都测不到 ——
> 印证了「不能只靠 lab/静态检查宣称完成」。

## 4.1 证据文件

本目录 `docs/evidence/godot-runtime-acceptance-2026-09-30/`（客户区 800×600 裁剪）：

| 文件 | 内容 |
|---|---|
| `01-ingame-hud.png` | 进入 Bichon Town 后的 EI 主 HUD |
| `02-guild-window-after-F.png` | 按 F → legacy 行会窗（修复后，无建会页） |
| `03-bag-window-after-Q.png` | 按 Q → legacy 背包窗 + 行会窗并存 |
| `04-bag-grid-6x6-zoom.png` | 背包网格 2×放大（可逐格点数 6×6） |

## 4.2 逐窗口热键真机扫描（2026-09-30）

进游戏后逐个按 EI caption 热键，验证打开的是**对应的 EI 窗口**（同一会话截图）：

| 键 | EI 语义 | 真机结果 | 判定 |
|---|---|---|---|
| Q | 包袱栏 | legacy 背包 F250（6×6=36 格、负重/总量、金钱、[包袱]、수리、锁链轨） | MATCH |
| W | 状态栏 | 人物状态 F200（纸娃娃 + 装备槽 + 属性文本） | MATCH |
| E | 技能书 | 技能书 F400（书页 + 左页列表 + 右页详情文本） | MATCH |
| R | 聊天记录 | F350 聊天弹窗（需先取消聊天输入焦点，见下） | MATCH |
| N | 设置栏 | 设置 F750（배경음악/효과음/환경음/그림자 四组 ON/OFF + 滑条） | MATCH |
| G | 组队 | 组队 F900（인원 관리/모집） | MATCH |
| D | 信息窗口(任务) | 任务 F700（羊皮卷） | MATCH |
| S | 坐骑 | 坐骑 F850（말타기/말내리기/말숨기기/말꺼내기 + 무게/스태미너 双 gauge + 关闭键） | MATCH |
| F | 行会 | 行会 F600（8 个韩文动作控件） | MATCH（本轮补） |
| Z / V / Alt+Q / Alt+X | 腰带 / 小地图 / 退出 / 注销 | 走 `KeyBindManager` 默认表，与本轮一致 | MATCH |

证据：`docs/evidence/godot-runtime-acceptance-2026-09-30/05-window-sweep-hotkeys.png`
（W/E/N/G/D/S 六窗带标注，2×3）。

**发现的一处交互细节**：聊天输入框获得焦点时按 R 会被当作**输入文本**而不是热键
（`GameScene.cs:10877-10882` 的 `InputHasFocus` 分支）—— 这与原版一致（聊天框有焦点时
字母键应当输入文本），不是缺陷；真机扫描时需先点击世界取消焦点。

## 5. 仍未覆盖（本轮真机范围之外）

- **原版客户端 A/B**：无 Windows 环境（`../../ORIGINAL_GODOT_PARITY_AUDIT.md` P-002）。
- **目标框/悬停名牌**：Godot 侧原本整体缺失；本轮已实现其中**名字牌**（见 §6），
  HP 条（`0x5600FC` 元素）与悬停 3000ms 保持仍未实现（B-8）。
- **背包 F280 gauge 拖柄几何**：真机只看清轨道位置，拖柄比例仍需原版运行时对照（B-4）。
- **多角色/多职业/装备外观**：本副本库只有 1 个角色，未跑逐职业矩阵。
- **封包级验收**：本轮只验证客户端表现，未抓包比对「相同操作 → 相同封包」。

## 6. 续轮补充：B-8 目标名字牌已实现并验证

### 6.1 原版行为（反汇编定案，2026-09-30）

`0x0040B850` 对**当前目标**（调用点 `0x41C063` 传入 `[ROOT+0x364444]`）画名字（文本位于对象 +8）：

- **不是矩形边框**。此前文档把「`0xA0A0A` 边框 + 文本」当成框，实际是**同一段文本画多次**：
  `0x40B8E7`、`0x40B93C`、`0x40B991`、`0x40B9E6` … 每处都是 `push 0xa0a0a` 后 `call 0x45DE50`，
  rect 每笔 ±1 偏移（`SetRect` 调用点 `0x40B8AB`/`0x40B8DC`/`0x40B931`/`0x40B986`/`0x40B9DB`…），
  即「近黑名字 + 1px 描边」。
- 几何：`left = anchor_x+(48-w)/2`、`right = anchor_x+(w+48)/2`、`top = anchor_y-0x1E`、`bottom = anchor_y-0xF`
  → 宽 w+48、高 15px、中心 = `anchor_x+24`（48 宽瓦片中心）、位于 `anchor_y` 上方 15~30px。
- 颜色 `0xA0A0A`（`0x00BBGGRR`）→ **RGB(10,10,10) 近黑**（同一约定见 `0x96C8FF` = RGB(255,200,150) 的职业文本）。

### 6.2 Godot 实现

- `RenderPrimitives.DrawTargetNamePlate(canvas, text)`：名字画 3 次（`(-1,-1)`/`(+1,+1)`/`(0,0)`），
  颜色 RGB(10,10,10)，水平居中 `x=24`、垂直居中于 y 带 **-30..-15**（Godot 节点原点 == 原版 anchor）。
- `ObjectRenderer.IsTarget` / `PlayerRenderer.IsTarget` + `GameScene._Process` 每帧
  `IsTarget = ReferenceEquals(ob, _combatController.TargetObject)`（怪物/NPC/物品对象与其它玩家都设）。
- 与 hover 名字是两个独立组件：hover 名字基线更低（`NameAboveHealthBarBaseline`/`OriginalNameBaseline`），
  与原版一致（原版目标名字牌同样独立于悬浮名字）。

### 6.3 真机验证（2026-09-30）

因原版颜色近黑、在暗色林地上肉眼不可见，验证分两步：

1. **仪表化验证（几何/门控）**：临时把名字牌颜色改成品红后进游戏，基线无名字牌；
   左键点选「牛」（`[Combat] 选中目标: 牛 ObjectID=522`）后，牛瓦片上方 y -30~-15 带
   出现品红「牛」，中心与瓦片对齐，且连续两帧（间隔 1s）持续存在。
   证据：`docs/evidence/godot-runtime-acceptance-2026-09-30/08-target-nameplate-instrumented-magenta.png`
2. **出厂颜色复核**：恢复 `0xA0A0A` 后与基线一致（近黑在暗底不可见，与原版行为一致）。
   证据：`.../09-target-nameplate-as-shipped-dark.png`

**判定**：B-8 的「名字牌」子项 = **已修复并有真机证据**；HP 条、悬停 3000ms 保持、
悬浮名字 ProgUse 帧 2/3（实测 32×4 小条）仍未实现，见待决台账 B-8。
