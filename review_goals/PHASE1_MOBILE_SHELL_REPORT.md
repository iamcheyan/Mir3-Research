# Phase 1 移动端共享壳 + 门户健康检查 — 实施报告

- **执行日期**：2026-08-14
- **依据 Goal**：`TOOLS_MOBILE_ENHANCE_GOAL.md` §3（统一方案）、§4 Phase 0/1、
  §5（先做共享移动壳 + 门户健康检查，再按 mapviewer → wilviewer 推进）
- **范围**：共享 `Tools/common/webui/`、新门户 `Tools/portal/`（8840）、
  mapviewer（8899）、wilviewer（8765）。按要求未触碰 webclient。
- **验收截图**：`review_goals/tool_evidence/phase1/`（每工具 390×844 + 1280×800 + 交互路径）

## 1. 交付内容

### 1.1 共享移动端壳 `Tools/common/webui/`（Goal §3.1）

| 文件 | 职责 |
|---|---|
| `tokens.css` | 设计令牌：`--touch-target:44px`、safe-area、层级 z-index、颜色兜底。纯变量，不改任何元素样式 |
| `mobile-shell.css` | 组件基线：`.wu-backdrop/.wu-sheet/.wu-drawer/.wu-bottomnav/.wu-card/.wu-badge/.wu-status-dot`；`@media (pointer:coarse)` 下 44px 触控目标 + `touch-action:manipulation`；`prefers-reduced-motion` 关动画；焦点可见 |
| `gesture.js` | 统一触控手势 `WU.gesture(el,{pan,pinch,doubleTap,tap})`：Pointer Events，**只处理 touch/pen**，鼠标零拦截（桌面零回归）；双指阶梯缩放（1.3 阈值）+ 双击放大 + 280ms 延迟 tap |
| `portal.js` | 门户健康渲染 + localStorage 最近访问 |

分发方式：各工具服务自带 `/_webui/*` 只读路由（白名单文件名，`..`/`/` 拒绝），
无构建步骤、无第三方依赖。

### 1.2 工具门户 `Tools/portal/portal.py`（8840，WIL-P0-02 / Goal §3.3）

- 纯标准库；`/api/health` 服务端 TCP 探测 + 数据源探针：
  - mapviewer → `/api/maps`（当前 544 张地图）
  - wilviewer → `/api/files`（当前 86 库 · 1,052,081 帧 · 587 音效）
  - dbviewer → `/api/stats`（当前 77 个分类 · 31,871 行）
- 首页卡片：健康点、只读/可写徽标、移动端等级徽标、端口、数据源概要；
  **未启动的服务显示红点 + 可复制的启动命令**（手机用户不再只看到连接拒绝）。
- 30 秒自动刷新；最近访问（localStorage）。

### 1.3 mapviewer（MAP-P0-01 / MAP-P0-02）

- `viewport meta`（原先缺失——源码里 `@media (max-width:640px)` 因此从未生效）。
- ≤640px：`#view-tabs`（地图/总览/连通）固定为**底部导航**（48px 触控目标）；
  图层/任务/图例控件收进 `☰ 图层` 底部抽屉（backdrop + Esc 关闭）；
  固定面板（cat/conn/quest/legend/pick/statusbar/toast）全部收口进视口；
  小地图隐藏。
- `@media (pointer:coarse)`：`#viewport touch-action:none`，接入 `WU.gesture`：
  单指平移、双指阶梯缩放（以手势中点为锚，复用 Ctrl+滚轮的 anchor 逻辑）、
  双击放大；连通图谱 SVG 同样接入（viewBox 平移/缩放）。
- 桌面（fine pointer ≥641px）：工具栏/布局像素级不变（`#layer-group{display:contents}`
  包裹零布局影响；`#btn-layers` 隐藏；鼠标拖拽/滚轮/双击路径未动）。

### 1.4 wilviewer（WIL-P0-01）

- `viewport meta` + 共享壳。
- ≤780px：左侧图库树变 ☰ 抽屉（`wu-backdrop` 遮罩、Esc 关闭、**选库自动收起**）；
  工具栏收窄（文字标签隐藏、range 90px、当前库信息整行省略）；
  帧详情 modal 适配 390px（86vw 预览、44px 按钮、meta 换行）；
  HUD 800×600 证据画布 modal 可滚动、monitor 等比缩放。
- `pointer:coarse`：选中帧出现 `🔍 详情` 按钮（44px）——触屏无双击的替代路径。
- 桌面（≥781px）：300px 侧栏原位、toggle/遮罩隐藏、布局不变。

## 2. 验收证据（DOM 几何 + 截图）

| 检查 | 结果 |
|---|---|
| mapviewer 390×844 页面级溢出 | `scrollWidth 390 == innerWidth 390`，无溢出（地图/总览/连通三视图均测） |
| mapviewer 底部导航 | fixed，390×58，触控目标 48px |
| mapviewer 图层抽屉 | 点击打开（6 个图层控件），backdrop/Esc 关闭 |
| mapviewer 触控手势（合成 PointerEvent） | 单指平移 Δscroll=120px；双指捏合 100%→50%；双击 25%→50%（阶梯缩放按锚点生效） |
| mapviewer 总览 | 627 张卡片网格，无溢出 |
| mapviewer 桌面 1280 | 工具栏 static 41px、view-tabs static、layer-group `display:contents`、viewport touch-action auto、无页面溢出（sw 1310 为 tile spacer 在 `#viewport overflow:auto` 内部的既有行为，非页面溢出） |
| wilviewer 390×844 | 无溢出；侧栏离屏；抽屉打开 86 库可选；选库自动收起；DMon-1 网格 224 cell 加载 |
| wilviewer 帧工作流 | 点帧 → selbar「🔍 详情」44px → 详情 modal 内接视口（rect 88..302×69..775，`fitsViewport:true`） |
| wilviewer 动画条 | 390 下打开正常（预览 140px 高），无溢出 |
| wilviewer 桌面 1280 | 侧栏 300px static、toggle/backdrop 隐藏、标签可见、网格加载、无溢出 |
| 门户 390/1280 | 5 卡片全 up、数据源概要正确、无溢出；未启动态显示红点 + 启动命令（可复制） |

截图清单（`review_goals/tool_evidence/phase1/`）：

- `mapviewer-390x844.png` / `-mapsel` / `-layers` / `-overview` / `-graph` + `mapviewer-1280x800.png`
- `wilviewer-390x844.png` / `-drawer` / `-grid` / `-detail` + `wilviewer-1280x800.png`
- `portal-390x844.png` / `-down-hint` + `portal-1280x800.png`

## 3. 服务状态（重启后）

- mapviewer：`mapviewer8899`（hub 守护，8899 就绪）
- wilviewer：`wilviewer8765`（hub 守护，8765 就绪）
- portal：`portal8840`（hub 守护，8840 就绪）

启动命令（AGENTS §八风格）：

```bash
# 门户（健康检查 + 工具入口）
python3 Tools/portal/portal.py            # :8840
```

## 4. 未尽事项（后续 Phase）

- dbeditor / uieditor 的 P0 收口（DBE-P0-01/02、UIE-P0-01/02）与 dbviewer 详情卡片（DBV-P0-01）。
- wilviewer `/compare`、`/ui` 证据页未做移动重排（研究型页面，桌面优先）。
- mapviewer QuestInfo 叠加、测距（MAP-P1-01/02）；wilviewer 帧搜索/动画导出增强（WIL-P1-01/02/03）。
- 真机 iOS/Android + Tailscale 链路验证（本次为 CDP 仿真，与原审查同基线）。
