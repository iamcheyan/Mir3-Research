# 网页版传奇3客户端（完全还原 Godot 客户端）— 总体任务目标 v1

## 一、定位（用户拍板，纠正方向）

**目标：在浏览器里 100% 还原客户端的所有行为和 UI**——不是"网页风格的
游戏沙盒"，是**像素级/行为级复刻**：打开网页 = 打开客户端，同样的登录
界面、同样的 HUD、同样的操作手感。**底层逻辑沿用 Godot 的**（协议/数据/UI 布局
全部从 GodotClient 源码移植，不是重新设计）。

现有 webclient(:8822) 的自创 UI **作废重做**——它的可复用部分：地图位图管线
（WebData 渲染）、资源服务（/res）、地图 manifest、连接数据。UI 层全部推倒。

### 双 UI 参考（用户 2026-08-14 追加拍板）

网页模拟器必须支持**两套 UI 参考，可切换**：

| 模式 | 布局权威 | 贴图来源 | 说明 |
|---|---|---|---|
| **Zircon 模式**（主线） | `ui_tree.json`（uieditor --ui-export 导出的 Godot 控件树） | `zircon/Debug/Client/Data` 的 Interface.Zl → webres WebP | 我们 Godot 客户端的真实 UI |
| **EI 模式**（参考） | EI 原版客户端逆向（ui 贴图/窗口结构来自 EI 资源） | `MIR3_EI_ROOT` 的 Data 图库 | 现有 webclient 的 EI 风格，保留可切换 |

- 两模式共用同一套逻辑层（协议/状态机/世界数据），只换 UI 皮肤与布局数据
- 默认 Zircon 模式（我们自己的客户端才是正身）；EI 模式用于对照原版行为
- 设置面板提供切换开关，选择持久化（localStorage）

## 二、核心资产（全部已就绪，这是可行性的根据）

| 资产 | 位置 | 用途 |
|---|---|---|
| GodotClient 源码 | ~/development/zircon/GodotClient/ | **唯一 UI/逻辑权威**：DXControl 体系/窗口布局/键位/渲染流程全部从这里移植 |
| ui_tree.json | GodotClient/UI/ | uieditor 的导出器产物：60+ 窗口完整控件树（坐标/贴图/文字/字号）——网页 UI 的直接数据源 |
| ui_overlay.json | 同上 | 布局 overlay 机制（网页编辑器改布局 ↔ Godot 同步） |
| WebData 资源管线 | Mir3-Research/Tools/webres/ | Zl→WebP 位图转换（Interface.Zl 已验证 2.29x） |
| webclient 地图管线 | Mir3-Research/Tools/webclient/ | 627 地图位图+瓦片+manifest+连接数据（复用） |
| WS 网关 | Mir3-Research/Tools/wsgateway/ | **已全链路验证**：浏览器 WS:7001 → TCP:7000 透传，登录包通，RTT 开销 <0.2ms |
| zdocs 协议文档 | zircon/docs/codebase/protocol/ | C./S. 全部包的字段/时序/服务端处理（23 篇之一） |
| db_names.json | GodotClient/translations/ | 2605 条数据层中文名 |
| MonsterLookup.cs | GodotClient/Formats/ | 怪物 Image→(Mon-N.Zl, Shape) 帧映射+帧号公式 |
| 测试账号 | test@test.com/test123/TestHero(GM) | 真服联调 |

## 三、架构

```
浏览器（纯前端，无框架或轻量框架）
├─ UI 层：DXControl 体系的 Web 移植（见下）
│   ├─ 布局引擎：读 ui_tree.json + ui_overlay.json 渲染（逻辑画布 1024x768，
│   │   CSS transform 缩放——与 Godot UiScaler 同公式 clamp(min(h/768,w/1024),1,2)）
│   │   ⚠️ 不是自创界面：每个窗口/按钮/贴图的位置=ui_tree.json 的值，
│   │   │  缺的窗口用 --ui-export 补导出
│   ├─ 控件库：DXButton/DXLabel/DXImageControl/DXItemCell/DXWindow 的 Web 等价物
│   │   （行为对照 GodotClient/Controls/*.cs 逐个移植：点击/悬停/拖拽/模态）
│   └─ 贴图：全部走 WebData（Interface.Zl→WebP 帧号直查）
├─ 逻辑层：从 GodotClient 移植的状态机（不是重写！翻译 C#→TS/JS）
│   ├─ 场景：LoginScene→SelectScene→GameScene 流转（对照 Scripts/*.cs）
│   ├─ 网络：C./S. 包的序列化/反序列化（对照 Network/Packet.cs + zdocs 协议文档；
│   │   │  packet id 以 packet_id_dump 反射导出为准——zdocs 记录过手算不可靠的坑）
│   │   └─ 传输：WebSocket → wsgateway:7001 → ServerCore:7000（已验证）
│   ├─ 世界：地图加载/对象同步(ObjectMove/Turn/Remove)/聊天/物品——对照
│   │   │  GameScene.cs 的事件处理函数逐个移植
│   └─ 渲染：Canvas 瓦片地图（webclient 管线）+ 帧动画精灵（帧号公式同 Godot）
└─ 数据：db_names.json（中文名）+ client System.db 的 WebData 导出
```

## 四、阶段划分（每阶段一个 OMP goal，可独立验收）

### Phase 1：登录到进游戏（最小可玩闭环）
- LoginScene 像素级还原：ui_tree.json 驱动布局+Interface 贴图+账号密码输入+
  登录流程（C.AccountLogin→S.AcceptLogin→服务器列表→C.SelectServer）
- SelectScene：角色列表/选人/进游戏（S.SelectStarted→StartGame 链）
- GameScene 最小：地图渲染（出生点）+ 主 HUD（聊天框/主面板按钮）+ 走路
  （C.Walk + S.ObjectWalk 回显）
- 验收：浏览器走完 注册→登录→选人→进比奇→走路，与 Godot 客户端同账号
  同操作截屏对比（同一场景并排截图，UI 位置一致率肉眼可判 ≥95%）

### Phase 2：战斗与对象世界
- 对象系统：玩家/NPC/怪物渲染（帧动画）+ ObjectMove/Turn/Remove 同步 +
  名字/血条（对照 ObjectRenderer.cs）
- 战斗：攻击（C.Attack）+ 伤害数字 + 死亡动画；技能施放（C.Spell+特效帧）
- 物品：地面掉落（拾取 C.Pickup）+ 背包（InventoryDialog 完整移植）+
  装备穿脱（C.EquipItem + 纸娃娃帧叠加）
- 验收：杀鸡掉肉捡起来穿装备全流程；背包窗口与 Godot 并排对比

### Phase 3：全窗口系统
- uieditor 已导出的 60+ 窗口逐个点亮：角色/技能/任务/行会/组队/大地图/
  小地图/设置/商店/NPC 对话/交易——每个窗口的打开/交互/网络链路对照
  GodotClient/Controls 同名类移植
- 键位系统：KeyBindManager 的全部绑定（W 背包 Q 角色...）
- 验收：60+ 窗口清单逐个打勾（开得了/看得对/点得动/网络通）

### Phase 4：体验完善
- 音效/BGM（Sound 目录 OGG 化+总线音量——对照 SoundCatalog/设置页）
- 断线重连/心跳（20s 踢号约束，zdocs/wsgateway TEST_RESULTS 有心跳结论）
- 移动端触屏（虚拟方向键+点击移动，UI 缩放同公式）
- 性能：资源按需加载/内存控制
- 验收：手机浏览器完整玩 10 分钟；掉线自动重连

## 五、纪律与文档（用户点名"记得写好文档"）

1. **每 Phase 产出一篇移植对照文档**（docs/webport/phase{N}-port-map.md）：
   Godot 文件:行号 ↔ Web 实现 的映射表 + 偏差清单（任何无法 1:1 的地方记录原因）
2. **新窗口必须先 --ui-export 导出再实现**——禁止手写布局数字
3. UI 行为存疑时：读 GodotClient 源码 > 跑 Godot 客户端实测 > 问用户，禁止猜
4. packet 结构一律查 packet_id_dump（反射导出）+ zdocs 协议文档，禁止手推
5. 每阶段结束：与 Godot 客户端并排截图对比存档（screenshots/webport/phase{N}/）
6. AGENTS.md 更新（webport 文档索引）

## 六、边界

- **服务端零改动**（wsgateway 独立进程已够；IP 坍缩问题等公网部署再议）
- 不做：外挂性质功能（加速/透视）；多开（一浏览器一连接）
- GodotClient 源码只读；产出在 Mir3-Research/Tools/webport/（新目录，
  webclient 的资源管线迁入，UI 层重写）
- 磁盘：WebData 复用现有+增量（预算 2G）
- 长期：此项目跨多个 goal——本文档是总纲，每 Phase 派发时引用本文档+该阶段细化

## 七、启动指令

第一个 goal = Phase 1（登录到进游戏闭环）。先把 webclient 可复用资产盘点清楚
（地图管线/资源服务），UI 层从 LoginScene 开始按 ui_tree.json 重做。
