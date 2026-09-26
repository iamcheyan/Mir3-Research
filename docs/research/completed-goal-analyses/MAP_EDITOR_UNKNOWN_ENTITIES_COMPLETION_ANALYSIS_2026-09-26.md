# 地图编辑器未知实体功能：完成分析（2026-09-26）

## 结论

8899 地图编辑器已经加入未知 NPC/未知怪物候选审阅和人工安置功能，完成桌面/手机界面、API、workspace/staging 管线和验收。默认不写真实 System.db，避免用户尚未确认的手工摆放污染生产数据。

## 功能范围

### 未知 NPC

- 从网站对齐 manifest 读取 pending-review、needs-evidence、unknown、unmatched、低置信度和缺少目标坐标的候选。
- 侧栏显示 NPC Index、名称、当前地图/坐标、状态、confidence、原因和来源。
- 可拖到地图视口，显示 ghost 和目标格。
- 保存路径复用 `WorkspaceEditor.move_npc()`，具备 MapInfo、边界、walkable、单点 Region 和 MapInfo.Regions 回链校验。
- 提供 placement history 和 undo。
- 本轮浏览器拖放测试最后取消保存，因此没有改用户工作区 NPC 坐标。

### 未知怪物

- 按 MonsterInfo 身份去重展示 pending/conflict/no-respawn 候选。
- 支持地图、坐标、Count、Range、Delay、DropSet、Announce 等 staging 字段。
- 写入独立 `UnknownEntityPlacements.json`，使用原子替换、稳定 placement id、upsert、history 和 undo。
- 不覆盖已有 RespawnInfo，不伪造 MonsterInfo Index，不直接写数据库。

## 验收统计

- unknown NPC：208
- unknown monster：242
- 02.map 已知实体层：27
- unknown 列表显示 180 行滚动窗口（标题保留全量数量）
- 后端测试：4 项全部通过
- `GET /api/unknown-entities`：HTTP 200
- `GET /api/entities?map=02.map`：HTTP 200
- `GET /api/respawns?map=02.map`：HTTP 200
- 桌面 1280×800：通过
- 手机 390×844：通过，无横向溢出
- console/pageerror：0

## 证据和提交

- 报告：`docs/research/map-editor-unknown-entities/MAP_EDITOR_UNKNOWN_ENTITIES_REPORT_2026-09-26.md`
- 桌面截图：`evidence/desktop-unknown-panels.jpg`
- 手机截图：`evidence/mobile-unknown-panels.webp`
- 实现提交：`3aacc8a25f793e087b09a9fed06efe6162884ff6`
- 验收补充提交：`6b549265`

## 数据安全边界

本 Goal 没有写入：

- ServerCore/Client `System.db`
- `Users.db`
- `.map` 地形文件
- 生产 RespawnInfo
- 未经用户确认的 NPC 坐标

## 关闭判定

地图编辑器未知实体功能已完成并可用于人工审阅；后续用户实际拖放产生的 placement 属于新的数据录入工作，不应自动视为生产写库批准。
