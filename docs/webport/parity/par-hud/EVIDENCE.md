# par-hud 验收证据 (HUD + 聊天, 2026-08-14)

测试环境: webport :8823 (`?demo=1&uimode=zircon`) → wsgateway :7001 → ServerCore :7000
账号: test@test.com (GM), 角色 TestHero 道士 Lv255, 比奇城

## 浏览器自动化验证 (全通过)

| # | 测试 | 结果 |
|---|---|---|
| 1 | 主面板渲染 | GameInter 50 底图 @1024x68, 9 按钮帧 82/87/92/112/97/107/102/117/122 |
| 2 | HP/MP 条 | `9100/9100`、`3830/3830`, 填充 220px (满), 标签同步 (MainPanel.cs HealthChanged 语义) |
| 3 | 经验条 | `408.9/0` → 0px。Lv255 ≥ ExperienceList.length → Godot DrawExperienceFill 同样 early-return (PlayerObject.cs:2530), **行为一致** |
| 4 | 属性区 | AC `11-46`, 等级 255, 职业 道士 |
| 5 | 9 按钮 | character/inventory/spell/quest/mail/belt/group/menu/cashshop 全部开窗 (9/9 OK) |
| 6 | 小地图 | 帧 idx=1 标题"比奇城", 27 静态标记 (NPC+出口), 玩家绿点 [239,178] |
| 7 | 小地图尺寸 | 200↔300 切换 OK (MiniMapDialog.cs Resize 语义) |
| 8 | 小地图透明 | dialog opacity 1↔0.5, 按钮帧 130↔131 (MiniMapDialog.cs:457) |
| 9 | 大地图按钮 | `_openWins` +1 `bigmap` (BigMapDialog 语义, MiniMap.Zl 大图) |
| 10 | GM 点击传送 | mousedown+mouseup<6px → C.TeleportRing 18B → 玩家 [239,178]→[207,128], conn 存活 |
| 11 | 聊天频道循环 | 普通→私聊→编组→行会→喊话→全局→观察→普通 (7 频道, ChatTextBox.cs CycleMode) |
| 12 | Enter 发送 | 31 字节 C.Chat, 输入框清空, history=1 |
| 13 | ↑↓ 历史 | ↑召回 `hud final echo test`, ↓恢复草稿 `draft-xyz` (ChatTextBox.cs:79-95) |
| 14 | 服务器回显 | `TestHero: hud final echo test` 入 ChatLogPanel |

## StatsUpdate 竞态修复 (world.js)

登录 burst 的 `S.StatsUpdate` 早于 `enterWorld` 完成 (world.player 为 null) 被 early-return 丢弃 →
maxHp/maxMp 恒 0。修复: 早到缓存 `_pendingStats`, `enterWorld` 建立玩家后回放 (k=2→hp/maxHp, k=3→mp/maxMp)。
修复后 HP/MP 标签 `9100/9100`/`3830/3830` 正确。

## 截图

- `hud-final-main.webp` — 完整 HUD (大尺寸小地图 + 聊天区 + 主面板)
- `hud-final-inventory.webp` — 背包窗口 (fallbackWindow 真实数据)
- `hud-charwindow.webp` / `hud-mainpanel.webp` / `hud-full.webp` — 中间状态
