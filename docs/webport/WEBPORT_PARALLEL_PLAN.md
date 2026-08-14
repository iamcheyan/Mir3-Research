# webport 并行军团作战图 — 五路 goal 划分与冲突协议（用户拍板：多 goal 并行加速）

## 一、总原则

用户要求：多个 goal 同时跑，每个负责一块功能，提前划清边界，分叉自动合并。
**划分依据 = 文件边界**（各 goal 只写自己领地内的文件，天然无冲突），
共享文件（main.js/net.js/ws.js/dx.js/frames.js）的改动统一走「接口层」纪律（§三）。

## 二、五路划分

| Goal | tmux 名 | 领地（可写文件） | 范围 |
|---|---|---|---|
| A 移动手感 | par-move | `themes/zircon/game.js`（输入/移动部分）、新建 `input.js` | 按住左键走/按住右键跑(contextmenu拦截)/点击寻路+攻击/WASD(若Godot有)/480ms格步/转向。对照 `GameScene.cs` _Input 逐函数 |
| B 动作系统 | par-anim | 新建 `anims.js`、`frames.js`(补缺) | MirAction17种→MirAnimation47种全分派(PlayerObject.cs:580-715 逐行移植)、GetAttackAnimation/GetMagicAnimation(Functions.cs:119/185)、Combat1-15、骑马/潜行/引导/钓鱼/驯兽、StanceTime 3s。GM号实测全技能施法动作+特效 |
| C HUD+聊天 | par-hud | `themes/zircon/` 下 HUD 相关(新建 hud.js/chat.js) | 底部按钮排+右上角图标区全可点(ui_tree.json坐标+Interface.Zl帧号)、HP/MP球/经验条实时、聊天框打字/Enter/频道/历史(ChatTextBox.cs逐方法)、小地图 |
| D 窗口系统 | par-win | 每窗口一个新文件 `themes/zircon/win-*.js` | 45+窗口逐个点亮: 背包/技能/角色/任务/行会/组队/NPC对话/商店/修理/仓库/交易/设置/GM面板。窗口内控件全可交互,DXWindow行为(拖动/置顶/模态) |
| E 键位+合并长 | par-keys | `keybinds.js`、**兼军团长** | KeyBindManager.cs 全表移植+验证；监控其余四路 commit,负责跨路合并(git pull --rebase 冲突仲裁以 Godot 源码为准)、index.html 版本号 bump、每 30min 推进度 |

## 三、冲突协议（自动合并的规矩）

1. **领地外的文件只读**；需要改共享文件(net.js/ws.js/dx.js/index.html)时：
   - 小改（加导出/加 case）：直接改，commit 信息标 `[shared]`，军团长 E 负责合并时优先保留
   - 大改：写到自己新文件里，通过 import 引用，不动共享文件
2. **每个 goal 每完成一个子模块立即 commit+push**（小步快跑，合并窗口短）
3. 军团长 E 每 20-30 分钟 `git pull --rebase` 一次，有冲突按「Godot 源码行为」仲裁
4. 五路都从 `ed1bb7a`(goal文档) 之后的最新 master 拉分支起步，起点统一
5. 验收不降级：每路完成定义仍是「与 Godot 真机对照操作一致」+ 录屏/日志证据存
   `docs/webport/parity/<路名>/`

## 四、启动

- 五个 tmux 会话：par-move / par-anim / par-hud / par-win / par-keys
- 各自 /goal set 引用本文件自己那一节 + WEBPORT_PARITY_SPRINT_GOAL.md 全局纪律
- 看门狗五条全注册
- 负载红线：5 并行 + 已有 3 个(yomu2/fudoki2/toolsphase) = 8 会话，
  若 load>6 暂停 par-win(最大块)先跑前四路

## 五、完成定义

五路全绿 + 军团长 E 合并出最终验证：打开 8823 与 Godot 并排，
任意点击/按键/施法/开关窗口行为一致。总验收文档 `docs/webport/parity/REPORT.md`。
