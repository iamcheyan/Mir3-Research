# webport Phase 2+3 合并冲刺：战斗/对象世界 + 全窗口系统（到"完整还原"为止）— 完整任务目标

## 一、使命（用户拍板）

用户原话："直接搞完 把全部的弄完 没完之前不允许他停下来"。
即：**本 goal 不做小步交付，一口气把 Phase 2 + Phase 3 全部做完**——
战斗与对象世界 + 45/46 个游戏内窗口全部点亮，直到网页客户端在已实现范围内
与 Godot 客户端行为一致。中途不询问、不暂停、不分批交付；做完才收尾报告。

## 二、依据（先读这两份，是唯一事实基础）

1. `docs/webport/audit/AUDIT_REPORT.md`——像素级审计报告：
   - P0 行为缺陷：**发聊天即断线（C.Chat 缺字段）**——第一件事修掉
   - 结构一致率 90.7% 的部分保持，行为差异清单逐条对齐
   - 「未实现清单」= 本 goal 的全部范围
2. `docs/webport/WEBPORT_MASTER_GOAL.md`——总纲（双 UI 模式/纪律/文档要求）
3. `docs/webport/phase1-port-map.md`——Phase 1 移植对照表（延续其格式）

## 三、Phase 2：战斗与对象世界

### 对象系统（对照 GodotClient ObjectRenderer.cs / GameScene.cs 事件处理）
- [ ] 玩家/NPC/怪物渲染：帧动画（站立/走/跑/攻击/死亡各方向 8 向），
      帧号公式同 Godot（MonsterLookup.cs 的 Image→(库,Shape) 映射已实现，扩展到动画序列）
- [ ] ObjectMove/Turn/Remove 同步：位置插值平滑（Godot 的移动节奏，格 480ms）
- [ ] 名字/称号/血条（颜色规则同 Godot：自己绿/敌对红/GM 黄等）
- [ ] 掉落物品地面渲染+拾取（C.Pickup）

### 战斗
- [ ] C.Attack 挥砍（含方向判定/命中判定按服务端回包驱动）
- [ ] 伤害数字飘字（Godot 的 DamageLabel 样式：字体/颜色分级/上飘轨迹）
- [ ] 死亡动画+尸体停留时长同 Godot
- [ ] 技能施放：C.Spell + 特效帧播放（Effect 库帧号）
- [ ] 聊天修复（P0）：对照 Packet.cs 补齐 C.Chat 全字段，实机验证不再断线

### 物品
- [ ] 背包 InventoryDialog 完整移植（格子/数量角标/选中/拖拽换位）
- [ ] 装备穿脱（C.EquipItem）+ 纸娃娃帧叠加（武器/衣服/翅膀层次）
- [ ] 物品 Tooltip（对照 DXItemCell 的悬浮详情：名称/属性/耐久）

## 四、Phase 3：全窗口系统（45/46 个）

以 uieditor 导出的 `ui_tree.json` 为布局唯一权威（缺的窗口用 `--ui-export` 补导出，
**禁止手写布局数字**）。按优先级顺序点亮：

1. **核心 HUD**：聊天框（含频道/气泡历史）·主面板按钮排·小地图（V 键常驻：玩家/
   NPC/出口标记）·大地图（B 键：全图/连接/定位）·经验条/HP/MP 球
2. **角色系**：角色状态(C)·背包(B)·技能(V)·任务日志(Q)·行会·组队·师徒·婚姻
3. **交互系**：NPC 对话页（NPCPage 数据驱动：选项/翻页/任务接交）·商店买卖·
   修理·仓库·交易窗口·摆摊
5. **系统系**：设置（音量/画质/键位）·帮助·退出确认·GM 面板（@命令输入历史）
6. 键位系统：KeyBindManager 全部绑定（W 背包/Q 角色/E 技能/B 大包/V 小地图…）
   每个窗口打开/关闭/置顶/拖动/模态行为对照 Godot DXWindow 基类

**每个窗口的验收**：打开正常/数据对/交互通/网络链路对（对照 GodotClient/Controls
同名类）；截图存 `docs/webport/phase23/screenshots/`。

## 五、纪律（不变）

- UI 行为存疑：读 GodotClient 源码 > 跑真客户端 > 记录待问用户，禁止猜
- packet 结构一律查 `packet_id_dump/` 反射导出 + zdocs 协议文档
- 服务端零改动；测试号 test@test.com/test123/TestHero(GM)；ServerCore :7000 已跑
- 每完成一个大模块 commit 一次（中文信息），**但不停 goal**
- 移植对照文档持续更新 `docs/webport/phase23-port-map.md`（Godot 文件:行号↔Web 实现）
- 磁盘：截图/产物 <500MB
- 遇到必须用户决策的产品问题：记录到 `docs/webport/phase23-questions.md` 继续
  干别的，**不暂停等待**

## 六、完成定义（全部满足才算 complete）

1. 审计报告的「未实现清单」清零或明确标注"需服务端配合"（列原因）
2. P0 行为缺陷（C.Chat 断线）修复并实机验证
3. 45/46 窗口全部点亮（清单逐个打勾表）
4. 战斗全流程：登录→比奇→杀怪→掉落→拾取→穿装备→技能→聊天——全程与 Godot
   客户端并排录屏/截图对比
5. 移植对照文档完整
6. 最终报告 `docs/webport/phase23/REPORT.md`
