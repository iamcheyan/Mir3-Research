# 地图编辑器未知实体人工安置报告（2026-09-26）

## 结论

8899 地图编辑器已加入未知 NPC / 未知怪物候选面板、地图拖放候选、服务端校验、workspace NPC 移动和独立怪物 placement staging。真实运行验证使用：

`http://192.168.3.82:8899/#map=02.map&cur=0&x=12105&y=6098&g=1&m=1&f=1`

本次没有写入 `ServerCore/Database/System.db`、`Client/Data/System.db`、`.map` 地形文件或 `Users.db`。真实工作区 placement manifest 当前为空；NPC 拖放验收在保存前取消，避免改变用户工作区。

## 数据来源与未知集合

- NPC：`docs/research/ei-ui-layout/artifacts/website-alignment-2026-09-26/npc-manifest.json`，按 `npc_index` 去重；仅保留 pending-review / needs-evidence / unknown / unmatched、低置信度或缺少可靠目标坐标的候选，并 JOIN `Tools/dbeditor/workspace/NPCInfo.json`、`MapRegion.json`。
- 怪物：同目录 `monster-manifest.tsv` + workspace `MonsterInfo.json` / `RespawnInfo.json`；按 MonsterInfo 身份去重。身份冲突保留为 conflict；已有正式 RespawnInfo 不复制为未知刷新点；没有可靠 RespawnInfo 的 MonsterInfo 以 `no-respawn` 候选展示。
- 最终 `/api/unknown-entities` 统计：`unknown_npcs=208`、`placed_npcs=0`、`unknown_monsters=242`、`placements=0`。
- 当前 02.map 页面显示原有实体层共 27 个实体；未知候选列表分别渲染 180 行滚动窗口，标题显示全量候选数。

## 实现与 workspace schema

### NPC

`/unknown/npc/place` 复用 `WorkspaceEditor.move_npc()`：

- MapInfo 存在性、地图边界、`flag&3==3` 可行走校验；默认不 force。
- 更新 NPCInfo.Region、MapRegion.PointRegion/Map、MapInfo.Regions 回链。
- 记录 `npc-placement` 的旧/新地图坐标、状态、operator、validation、timestamp、history。
- 成功后刷新 workspace entity cache；候选从待定位状态变为已人工定位。撤销通过 `/unknown/undo` 恢复旧坐标，不删除 NPC。

### 怪物

`/unknown/monster/place` 写入独立文件：

`docs/research/map-editor-unknown-entities/UnknownEntityPlacements.json`

字段包括：

- 稳定 `placement_id`（`monster:<index>:<map>:<x>:<y>`，可用传入 ID 覆盖）；
- `monster_index`、地图、坐标；
- `count`、`range`、`delay`、`drop_set`、`announce`、`source_note`；
- `status`、`validation`、`history`、operator、timestamp。

同一 placement 使用 upsert；重复保存不增加行，字段改变追加 history。撤销将状态改为 `undone`，保留审计历史。不会修改 RespawnInfo。

文件写入采用临时文件 + `os.replace`，并使用进程内锁；非法 map、目录穿越、越界、阻挡格、非法数量/范围/延迟会拒绝。

## API 摘要

所有新 API 使用现有 200 JSON 错误约定并返回 `Cache-Control: no-store`。

- `GET /api/unknown-entities`
  - 返回 `ok`、`source_dir`、`placement_manifest`、`unknown_npcs[]`、`unknown_monsters[]`、`placements[]`、`counts`。
- `POST /unknown/npc/place`
  - 输入：`npc`、`map`、`x`、`y`、可选 `previous_status` / `operator`。
  - 成功：workspace move 结果 + placement + 最新 manifest。
- `POST /unknown/monster/place`
  - 输入：`monster_index`、`map`、`x`、`y`、可选 `count`、`range`、`delay`、`drop_set`、`announce`、`source_note`、`placement_id`、`operator`。
  - 成功：独立 placement；不写 System.db。
- `POST /unknown/undo`
  - 输入：`placement_id`、可选 `operator`。
  - NPC 恢复 workspace 旧坐标；怪物 placement 标记 `undone`。

## UI 验收

### 桌面 1280×800

- fresh query-string reload（`?v=unknown-final-desktop`）后无 pageerror / console error。
- 页面标题：`银杏山谷 — 02.map`。
- URL 中 `map=02.map`、`cur=0`、`x=12105`、`y=6098`、`g=1`、`m=1`、`f=1` 保留。
- NPC、怪物面板显示候选、status、confidence、原因、source、已有 placement 数量。
- 从 `#13 康先生` 行实际鼠标拖至地图，UI 显示待确认面板：`02 · 249,190`；随后点击“取消”，没有写 workspace。
- 未知 NPC 和未知怪物使用不同颜色/虚线样式；已有实体仍在地图层。
- 截图：`evidence/desktop-unknown-panels.jpg`。

### 手机 390×844

- fresh query-string reload（`?v=unknown-final-mobile`）无页面异常。
- 两个未知面板均可见，宽度 374px，页面没有水平溢出（`scrollWidth <= innerWidth`）。
- URL 路由和地图仍可加载；移动端布局将右侧面板改为静态全宽堆叠。
- 截图：`evidence/mobile-unknown-panels.webp`。

## 后端验证

```text
python3 -m py_compile Tools/maps/mapedit/data.py Tools/maps/mapedit/npcedit.py Tools/maps/mapedit/api.py
→ OK

python3 -m unittest discover -s Tools/maps/mapedit/tests -p 'test_unknown_entities.py' -v
→ Ran 4 tests ... OK
```

覆盖：

1. manifest 候选去重、人工定位 NPC 状态识别；
2. 怪物 placement 幂等 upsert、字段更新 history、undo 保留历史；
3. 越界、阻挡格、目录穿越拒绝；
4. NPC 跨地图移动及 MapInfo.Region 回链。

API smoke：

```text
GET /api/unknown-entities → HTTP 200, Cache-Control: no-store, 237742 bytes
GET /api/entities?map=02.map → HTTP 200, 14045 bytes
GET /api/respawns?map=02.map → HTTP 200, 3304 bytes
```

动态渲染脚本通过 `new Function()` 解析检查，170731 字节、2872 行，parse ok；最终服务重启后再次 fresh-load 验收，pageerror 和 console error 均为空。

## 运行信息与变更边界

- 8899 服务：`Tools/maps/mapviewer.py --port 8899 --no-prewarm-tiles`。
- 最终服务父 PID：`3022733`（服务脚本报告就绪 PID；prefork worker 同属该启动组）。
- 当前工作树包含用户既有修改，未 reset / clean / stash，未覆盖网站对齐产物。
- 本 Goal 新增/修改范围：
  - `Tools/maps/mapedit/api.py`
  - `Tools/maps/mapedit/data.py`
  - `Tools/maps/mapedit/npcedit.py`
  - `Tools/maps/mapedit/templates.py`
  - `Tools/maps/mapedit/tests/test_unknown_entities.py`
  - 本报告目录及证据截图
- 本次 Goal commit：`234ef4b5`（`地图编辑器支持未知实体人工安置`）。
- commit 完整 SHA：`234ef4b5c8db7661868aa5f4cb7c8328de2acdc8`。
- `origin/ei-ui-audit-2026-09-24`：`5f467a4b51f3f65badb1ed9de757b61018eccc5a`。
- commit 仅包含本 Goal allowlist；其它会话 WIP 未暂存、未重写。

## 未解决风险

1. 浏览器缓存会保留旧 inline script；验收/部署后应使用版本 query 或清缓存。项目 AGENTS.md 已明确要求静态 JS/CSS bump 版本；本次验收使用 `?v=...`。
2. 真实 NPC 保存仍依赖当前 workspace 的 MapRegion/地图 walkability；本次只完成拖放到待确认状态，未故意改变生产 workspace。
3. 怪物候选中 `monster_index=null` 的身份冲突条目可审阅，但保存前仍需用户选择稳定 MonsterInfo index；后端不会伪造 MonsterInfo。
4. placement manifest 属于 staging，后续写入 RespawnInfo 必须遵循停服、备份、副本、round-trip、双库同步流程；本 Goal 不实现该写回。
