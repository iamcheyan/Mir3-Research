# Phase 3 深度项报告 — UIE-P1-01 / MAP-P1-01 / DBV-P1-02

> 2026-08-14 · 承接 PHASE1_MOBILE_SHELL_REPORT.md / PHASE2_MOBILE_TOOLS_REPORT.md
> 验收方式：CDP（chrome-headless-shell :9223）DOM 几何断言 + 合成手势，证据 `tool_evidence/phase2/*deeplink* / *touch* / *quest-step*`。

## 1. UIE-P1-01 uieditor 画布触控

- `Tools/uieditor/app.py`：挂载 `/_webui` 静态路由（共享壳）。
- `static/index.html`：head 引入 `/_webui/gesture.js`（无 defer，body 内联脚本依赖 window.WU）；`style.css?v=5`、`app.js?v=5` 缓存 bump。
- `static/style.css`：`pointer:coarse` 下 `#canvas-viewport { touch-action:none }`。
- `static/app.js`：`pointer:coarse` 时 `WU.gesture(#canvas-viewport)` — 单指平移（scrollLeft/Top）、双指阶梯缩放（0.5/1/2 复用 `applyZoom`）、双击放大。桌面鼠标路径零改动（touch-action:auto、无手势绑定）。
- 验证（390×844，pointer:coarse + touch 合成事件）：pan Δ100px ✓；pinch-out 50%→100% ✓；double-tap 100%→200% ✓；1280×800 回归：`touch-action:auto`、`#mobile-actions:none`、无横向溢出 ✓。

## 2. MAP-P1-01 mapviewer 任务步骤播放

- `renderQuestPanel` 重写：顶部 `⏮ 上一步 / ▶ 逐步播放(4s 自动) / 下一步 ⏭` 导航；每步骤行 `▶ 定位` 按钮 + `data-step`；当前步骤 `.qstep.current` 高亮。
- `questStepList()` 与面板行一一对应（每个 monster 取首个有图文件的点、每个 region 一步）；`gotoQuestStep` 循环播放并写 hash 跳图。
- **修复真 bug（tile 模式锚点失效）**：`render()` tile 分支漏掉 `applyAnchor()`（fullmap 分支有，`miniPan`/实体质心路径也有）——所有带 x/y 的 hash 深链（任务跳转、dbviewer 联动）在大图上一律落在左上角。现在 `drawTiles() → applyAnchor() → drawQuest() → drawTiles()`。
- 验证：quest 9（单步）定位 0.map x=8304 落点 scroll=expected ✓ 标记 1 ✓；quest 10（双步）s0→s1→⏮→自动播放→停止 全链路 ✓；390 面板无横向溢出 ✓。

## 3. DBV-P1-02 dbviewer↔mapviewer 地图深链

**根因是数据层断裂**：导出 JSON 里 Region/SourceRegion/Map 引用是 `{Index, Name}` 桩，坐标在 MapRegion 全行（`Map.Name` + `PointRegion.CenterX/CenterY`）——`extractLocation` 全灭（详情无「位置信息」面板、列表无位置链接），服务端 `map_entities` 同样读不到坐标（返回 0 实体）。

- `dbviewer.py`：`_build_region_index()`（MapRegion byIndex）+ `loc_of(t,row)` 解析器；`/api/rows`、`/api/row`、`/api/related(mapLayers)`、`/api/search` 按位置类注入 `__loc`；`map_entities` 改用解析器（map=0 现在 80 实体，原 0）。
- `template.html`：`extractLocation` 优先 `row.__loc`；**修复深链竞态**——`loadAll` 现按 hash 路由（`#/detail/...` 直达，此前被默认 MonsterInfo 表格覆盖）。
- 端到端验证：`#/detail/NPCInfo/13`（Mr. Kang）→「在地图上查看」生成 `#map=0.map&x=6336&y=7552&hl=Mr.%20Kang` → mapviewer 落点 scroll=expected ✓ `.ent.target`="Mr. Kang" 视口内 ✓；NPCInfo 列表 50 行全带位置链接 ✓；390 详情无溢出 ✓。

## 遗留（未在本期范围）

- MAP-P0-02 真机 iOS/Android + Tailscale 链路（本次为 CDP 仿真）。
- WIL-P1-01 帧搜索 / WIL-P1-02 动画导出。
- dbviewer 位置列无表头 th（历史形态，非本期引入）。

## 证据（tool_evidence/phase2/）

|文件|内容|
|---|---|
|uieditor-390x844-touch.png / uieditor-1280x800.png|画布手势 / 桌面回归|
|mapviewer-quest-step-playback-1280.png / mapviewer-quest-step-390.png|步骤播放高亮|
|dbviewer-detail-deeplink-1280.png / -390.png|详情位置面板 + 深链|
|mapviewer-hl-landing-1280.png|深链落点 + hl 实体高亮|
