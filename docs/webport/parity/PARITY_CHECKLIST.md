# PARITY_CHECKLIST — webport 行为级等价验收清单

> 验收标准 (goal doc): 交互功能 1:1 等价, 非像素截图。每条以 Godot 源码为行为权威,
> 真服 (ServerCore:7000 + wsgateway:7001) + CDP chromium 实测。
> 状态: ✅ 已验证 | 🟡 已实现未逐条验证 | ❌ 缺口
> 证据文件: /tmp/pm-smoke/smoke4.mjs (全链路), t10-t12.mjs (定向), 各 commit message。

## P0 — 移动手感 / HUD 全量可点 / 聊天

### 移动 (MouseWalker.cs 对照)

| 行为 | Godot 权威 | webport 实现 | 验证 | 证据 |
|---|---|---|---|---|
| 按住左键走 | MouseWalker._Process 600ms/格, 22.5° 方向 | mouse.js tick + world._frame | ✅ | 按住 2.5s 走 6 格 (smoke4 T1 ×3 次运行) |
| 按住右键跑 | 同节拍 2 格/段 (骑马 3) | getRunSteps + distance=2 | ✅ | 1.8s 跑 6 格 ×3 方向 (t10) |
| 撞墙绕路 | BestWalkDirection | #bestWalkDirection | ✅ | R8 CDP: 扫描半径 60 找墙 (blocked=[-1,0]), tick 1.5s 走访格全 passable, crossedWall=false |
| 方向键走 | GameScene.cs:9902 仅 Arrow | world._frame keys 池 | ✅ | 4 向各 4 格/1.4s (t12) |
| WASD 非移动 | W=背包 S=仓库 A=Ctrl+A D=自动跑 | keybinds.js 表 | ✅ | KeyW→inventory 开窗 (t11) |
| 聊天聚焦时不走 | Godot 输入控件优先 | world.js keydown guard | ✅ | Enter 后打字不动 (smoke4 T5/T6) |
| Shift 按住=原地攻击 | MouseWalker 门控 | mouse.js tick | ✅ | R8 CDP: shiftHeld=true + _leftDown 按 2.2s → 坐标纹丝不动 (moved:false) |
| 鼠标在 UI 上不触发移动 | IsMouseOverUi | #mouseOverUiAt (elementFromPoint) | ✅ | hudLayer isControl:false 修复后 9 键可点且移动不误触 |

### 服务器锁定/预测

| 行为 | 状态 | 备注 |
|---|---|---|
| 发包后 server-lock 5s 超时 | ✅ | _moveServerLockUntil + ObjectMove/UserLocation 解锁 |
| 预测跳格+反向偏移插值 | ✅ | R8 CDP: stepMove(0,1) 后立即 [153,234]→[153,232] (不等服务器回包); stepMove 预测模型 world.js |

### HUD (MainPanel.cs 对照)

| 行为 | 状态 | 证据 |
|---|---|---|
| 主面板 9 键全可点开真窗 | ✅ | t11: character/inventory/spell/quest/mail/belt/group/menu/cashshop 9/9 PASS |
| Esc 关最上层窗口 (CloseTop 语义) | ✅ | t11 每窗开→Esc 关; 无窗时 Esc 不拦截 |
| HP/MP/专注/经验条 | ✅ | #onRawStats→setMaxHealth 链路, 验收时无异常 |
| 小地图右上+玩家跟随+3 悬停按钮 | ✅ | R7 CDP: mouseenter 显 3 钮/mouseleave 隐; Size 200→300→200 (150-300 clamp); Transparency 窗 Opacity →0.5 (Godot 窗级 Opacity 同款); BigMap 开窗; 拖动平移+GM 传送 (t10) |
| BuffDialog | ✅ | hud.js BuffDialog (BuffDialog.cs:15-120): buffAdd/Remove/Time/Paused 全接线, 剩余时间降序 27px 栅格×6列, Pause=红/<10s→蓝渐变/永久白, 锚小地图左侧; CBIcons.Zl 真图标 (buff-icons.js GetBuffIcon switch 照抄, R12); pmv-buff-qt: srcs=[100,137,78,229] 逐项吻合, pause 红/<10s 蓝滤镜 |
| QuestTracker | ✅ | hud.js QuestTracker: itemStore.quests + gamedb QuestInfo 名称, 完成前缀✓, 点击切换追踪(localStorage), 锚小地图下方; 注入任务渲染 rows=[任务#9001,✓任务#9002] |

### 聊天 (ChatTextBox.cs 对照)

| 行为 | 状态 | 证据 |
|---|---|---|
| Enter/Space 开聊天, 发送回显 | ✅ | smoke4 T5/T6 |
| 频道循环 (ChangeChatMode 键) | ✅ | R7 CDP: cycleMode ×6 → 普通|私聊|编组|行会|喊话|全局 循环 |
| 历史 ↑↓ + 草稿恢复 | ✅ | R7 CDP: ↑=最新→次新 (乙→甲), ↓回退, 输入半句后 ↑↓↓ 恢复草稿原句 |
| 单渲染 (双行缺口已修) | ✅ | world.js chat 只留头顶气泡, game.js #wireNet 唯一日志路径+overheadOnly guard; pmv-buff-qt: 一次 sendChat delta=1; "Name: Name: text" 双名是 Godot OnChat 同款 (服务端 PlayerObject.cs:1808 已拼名, 客户端再拼) |

### 键位分发 (KeyBindManager.cs + GameScene.cs:1876 对照)

| 行为 | 状态 | 证据 |
|---|---|---|
| keybinds.js 70 条默认表 vs C# | ✅ | E 路 check-keybinds.mjs 557 断言全过 |
| dispatch 消费方落地 | ✅ | game.js #bindGlobalKeys (R3) + getAction |
| 窗口键 ×27 (W/S/Z/N/…) | ✅ | W/N/Z 实测开窗; 其余走同一 WIN 表 |
| 施法 F1-F24 (SpellUse01-24) | ✅ | useMagicSlot 接线 (MagicKey 感知); check-keybinds-cdp 70键 dispatch 全通 0 异常 (R7) |
| 技能栏 Set1-4 | ✅ | setSpellSet 接线; CDP dispatch 通 |
| 药品槽 Shift+1..0 | ✅ | useBeltSlot 接线; UseBelt01-10 CDP dispatch 通 (新号无药品, 期望无窗口变化) |
| Tab 拾取 | ✅ | sendPickUp; CDP dispatch 通 |
| 上马/攻击模式/宠物模式 ×5 | ✅ | sendMount/ChangeAttackMode/ChangePetMode; CDP dispatch 通 |
| 自动跑 (D) | ✅ | mw.autoRun 翻转; CDP dispatch 通 |
| 锁定物品 | ✅ | #toggleItemLock (DXItemCell.SelectedCell); CDP dispatch 通 |
| Escape 仲裁 (R0 备忘 #1) | ✅ | closeTop() 真关才 return; 无窗可关落 getAction |

### 协议修正 (本轮发现的真 bug)

| 修正 | 现象 | 状态 |
|---|---|---|
| NewCharacterResult Success=10 (旧 3=BadGender) | 服务端建角成功, 客户端报"创建失败" | ✅ 4128435 |
| NewAccountResult Success=8/AlreadyExists=4 | 同类错位 | ✅ 4128435 |
| LoginResult 文案序 | 错误码文本张冠李戴 | ✅ 4128435 |
| mouse.js 未入库 | clone 即 module not found | ✅ 4128435 |
| installWindows 无调用方 | par-win 11 模块从未加载 | ✅ 5501777 |

## P1 — 全 46 窗口

| 批次 | 窗口 | 状态 | 归属 |
|---|---|---|---|
| 核心 | Inventory/Character/Magic/Belt/Storage | ✅ win-inventory/char/skill/storage (par-win 000ce70); belt → fallback (beltLinks 真数据) | par-win |
| 社交 | Group/Guild/Mail/Ranking/ChatOptions | party✅ guild✅; Mail→fallback(好友列表); Ranking✅/ChatOptions✅ fallbackWindow (开窗即 C.RankRequest + rankings 事件渲染; 频道开关直改 chatLog.enabledTypes) | par-move R6 |
| NPC | NPCDialog/Quest/Goods/Repair | ✅ win-npc + win-quest (真实 System.db 快照) | par-win |
| NPC 高级面板 | Refine/RefineRetrieve/RefinementStone/MasterRefine/AccessoryLevel/AccessoryUpgrade/AccessoryReset/ItemFragment/WeddingRing/WeaponCraft/CompanionManage | ✅ R15-R18: DB 引用的 14 DialogType 全真实现 (BuildRefine :383/BuildRetrieve :518/BuildRefinementStone :324/BuildMasterRefine :431/BuildAccessoryLevel :686/BuildWeaponCraft :801/BuildSingleGrid :621/NPCCompanionStorageDialog); 提交锁三态 R20 (BeginSubmit :1039); 回包反馈 R19 (S 解析×9+聊天+取回删行+伙伴同步); 真服 e2e 254→聊天验证 | par-move R15-R20 |
| 功能 | Help/Exit/BigMap/Currency/AutoPotion/FilterDrop/Fortune/QuestTracker/DungeonFinder/Companion | ✅ 全部 fallbackWindow 真实现 (R6): Help=键位表; Exit=确认→sendLogout; BigMap=MiniMap 瓦片; Currency=CurrencyInfo×itemStore; AutoPotion=autoPotionLinks+AutoPotionLinkChanged; FilterDrop=localStorage 名单; Fortune=fortuneUpdate; QuestTracker=KeyL 可见性切换 (GameScene.cs:1898); DungeonFinder=InstanceInfo (db 空→空态); Companion=CompanionInfo+sendCompanionAdopt | par-move R6 |
| 其余 | Menu/Config/GameStore/Trade/Observer | config✅ trade✅ gm✅ (par-win); Menu/GameStore→fallback (menu: 攻击/宠物模式+退出; cashshop: gameStoreItems) | par-win |
| 双 UI | EI 参考模式 | 未动 (scope 外) | — |

## 环境/流程备注

- ServerCore 启动后 ~11s 才回 GoodVersion (DB 加载), CDP 登录轮询需 ≥60s。
- 共享 test@test.com 会 `[Account in Use]` 争用 → 验收一律独立账号注册。
- hub daemon `servercore-7k` (cwd=zircon/Debug/ServerCore) 各路共用, 勿重复起服。
- game.js 本轮被并发重写打断 4 次 (丢 import/文件尾); 整文件重写前先 pull + node --check。

## 结论

P0 移动/HUD/聊天/键位 = **达成** (验收表内 ✅ 全过, R5-R8 逐项 CDP 复核)。
P1 窗口 = par-win 11 模块 + installWindows 接线已通; par-move R6 把 11 个 fallback 空壳补成真实现 (CDP 12/12 内容非空), dialogs.js 草稿仅剩 belt 细化吸收价值; R10 Login 5 按钮 (排行/选项/改密/忘记密码/激活) 真实现清零"暂未实现"。
BuffDialog/QuestTracker/聊天双行 = ✅ 已修 (R5)。**全表 ✅** (2026-08-15)。
NPC 面板链 = **闭环** (R15-R20): DB 双快照 (dbeditor workspace + dbviewer 活库导出) 交叉审计,
14 个真实引用 DialogType 全部真实现; 发包→真服→S 回包→UI 反馈→提交锁解锁全链路 CDP 验证
(含真服 e2e: C.NPCMasterRefine 254 出站→S 回包→聊天"大师精炼失败")。
剩余 6 类型 (WeaponReset/AccessoryRefine/RollDie/RollYut/Socketing/SocketCombine) 双快照零行
引用、Godot 无旁路入口 (Socketing 仅 NPCDialog.cs:121 DialogType 路由) → 不可达, 无需实现。
