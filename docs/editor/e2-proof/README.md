# Goal E2 验收存证（2026-08-16）

NPC 摆放编辑全链路：mapviewer 拖拽/点图放置 → workspace JSON → `sync.sh` 入库 → 游戏内生效。验收标准见 `../EDITOR_GOALS_MASTER.md` §6.3（全过）；坑与数据模型事实见 §3.11。

| 文件 | 内容 | 产生方式 |
|---|---|---|
| `ui-drag-moved.png` | 编辑模式拖拽 NPC13 Mr.Kang (402,356)→(404,358)，格吸附+高亮 | chrome-headless-shell :19223 + puppeteer-core 合成 MouseEvent（§3.9/§3.11：CDP `page.click` 在本机不触发） |
| `ui-create-npc.png` | 「点图放置」新建 NPCInfo#368（名称/Image/EntryPage datalist 绑定 NPCPage），地图出现新标记 | 同上 |
| `ui-final.png` | 变更列表面板：待同步 diff（表/行/字段）+ 表回滚按钮 | 同上 |
| `ingame-npc-moved.png` | 端到端终验：sync 2026.08.16.3 后起服，webport `?demo=1` GM `@MOVE 0 394 353`，视野内 NPCObject 恰在编辑位 (398,351)（David 397,363 同框对照） | verify-final.cjs 断言 + 截图 |

端到端时序（4 次 sync 全走 `sync.sh`，零直写 .db，`Tools/dbeditor/sync_report.txt` 为证）：

1. place.py move 13 → 396,352（当时未做通行校验）→ sync 2026.08.16.2 起服：NPC **不可见**——实证服务器 `Spawn` 对阻挡格(flag&3!=3)照常出生但不广播（§3.11 首条）。
2. 引擎补通行校验（拒绝/`--force` 旁路）→ move 13 → (398,351)（通行格）→ sync **2026.08.16.3** → 起服 → webport 实测 NPC@398,351 ✅（`ingame-npc-moved.png`）。
3. 还原：move 13 → (402,356) → sync **2026.08.16.4** → workspace diff=0，库回到基线（仅 NPC13 坐标与 E2 前一致；他人 15 条 MiniMap pending 保留未动）。

引擎级验证（先于 UI）：沙盒 `~/.e2-scratch/ws_test` move/create/delete/diff/rollback 全绿；DBImporter dry-run `应用 1/1 处变更`；round-trip SystemDbProbe 重导出语义一致。
