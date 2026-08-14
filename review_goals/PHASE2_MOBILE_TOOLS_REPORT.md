# Phase 2 剩余三工具移动端收口 — 实施报告

- **执行日期**：2026-08-14
- **依据**：`TOOLS_MOBILE_ENHANCE_GOAL.md` §4 Phase 0 收尾（DBE-P0-01/02、UIE-P0-01、DBV-P0-01）
- **范围**：dbeditor（8810）、uieditor（8820）、dbviewer（8800）。webclient 未触碰。
- **证据**：`review_goals/tool_evidence/phase2/`（每工具 390×844 多视图 + 1280×800）
- **验证方式**：Chrome headless-shell CDP（9223），DOM 几何断言 + 截图。共享浏览器实例崩溃后
  改用 `chrome-headless-shell` 直连，覆盖范围与 Phase 1 相同（JS 布局分支均按 innerWidth 触发）。

## 1. dbeditor（DBE-P0-01/02）

- **移动端安全编辑壳（DBE-P0-01）**：新增 `.mobile-actions` 底部常驻栏（fixed、safe-area、
  44px 按钮）：列表视图 =「改动追踪(N)/同步到数据库」；详情视图 =「← 返回/未保存标记/保存」；
  改动视图 =「← 返回列表」。顶栏的桌面按钮在手机上隐藏（同步入口只走底部栏，防误触）。
  同步前的双确认（备份提示 + 服务端运行 409 拒绝）沿用既有逻辑，未改动。
- **溢出收口（DBE-P0-02）**：`el-dialog`（同步 720px/批量 460px）→ 94vw；`el-message-box` → 88vw；
  子表（含改动追踪 diff 表）包进 `.sub-table-wrap` 容器内横向滚动（min-width 560px 保列宽可读），
  页面级不再溢出。
- **顺带修复真 bug**：`backToList` 在模板三处引用但 app.js 从未定义/导出——
  所有「返回」按钮（桌面+手机）点击无效。已补定义并加入 setup 返回表。
- 缓存 bump：`style.css/template.js/app.js` → `?v=7`。
- **验证**：390 下 list(50 卡片)→detail(28 表单项)→编辑出 dirty 标记+保存启用→返回→
  改动追踪(el-empty)全程 `scrollWidth==innerWidth` 无溢出；底部栏 fixed 可见、按钮 44px。
  1280：el-table 8 列、侧栏 191px、顶栏按钮齐全、mobile-actions 不渲染。

## 2. uieditor（UIE-P0-01）

- 移动端（≤700px）原为「纯浏览模式」（右侧树隐藏、左栏 148px 常驻）。现改为：
  - **底部常驻操作栏**：☰(窗口树)/↶撤销/↷重做/⟲重置/⇅同步，全部 ≥44px，fixed+safe-area；
    撤销/重做/同步直连桌面同一处理函数；重置走 `#btn-reset` 复用含 confirm 的原逻辑。
  - **窗口树 ☰ 抽屉**：默认画布优先，☰ 呼出（min(78vw,300px)），选窗口后自动收起；
    顶栏桌面专用项（吸附/底图/撤销等）在手机收进底部栏。
  - 桌面顶栏按钮文案精简（同步到游戏（F12 热重载）→同步），`.tb-item` 类标记移动端隐藏项。
- 缓存 bump → `?v=3/v=4`。
- **验证**：390 下 ☰ 打开（46 窗口）→选窗口自动收起→画布 128 控件 50% 缩放渲染，
  底部栏按钮 44px、无页面溢出。1280：左 230px/右 300px 静态、顶栏 8 项齐全、mobile-actions display:none。

## 3. dbviewer（DBV-P0-01）

- **手机详情卡片**：`.detail-grid` 从 `minmax(380px,1fr)` 双列改为单列；`.fld` 从
  「150px 标签列 + 值行」（390px 必溢出）改为**上下堆叠**（k 上 v 下，word-break）。
- **侧栏 ☰ 抽屉**：280px 常驻分类树 → fixed 抽屉（min(84vw,300px)），选分类自动收起；
  右上角 44px ☰ 按钮 + backdrop + Esc。
- 宽表（关联面板）容器内滚动；表格单元格改 wrap（max-width 240px）。
- **验证**：390 下 ☰ 抽屉（8 分类）→怪物 MonsterInfo 表（50 行）→详情（25 字段单列堆叠、
  4 个关联面板）全程无页面溢出。1280：侧栏 280px 静态、详情双列 grid、`.fld` row 布局不变。

## 4. 已知边界

- dbeditor 服务端运行时（7000 有监听）同步按钮禁用——写库纪律不受本次改动影响。
- uieditor 画布触控（双指缩放画布本体，UIE-P1-01）属 Phase 1 后续增强，本次只做 P0 底栏。
- dbviewer 全局搜索结果页同样受益于卡片/滚动收口，未单独出图。
