# Yomu + Fudoki 移动端深度优化 — 完整任务目标

## 一、背景

两个 PWA 今天刚完成核心修复（yomu：书籍列表/搜索/目录 P0+墨水屏 UI；fudoki：备份键/IIFE/TTS/同步）。
用户主要在手机上使用，要求移动端体验做深做透。**最后起本地 web 服务让用户手机实测**。

## 二、Yomu 移动端（~/development/yomu）

已有：墨水屏 UI 重构（今日上午 goal 完成）。本 goal 深化：

1. **阅读体验**（最重要）：
   - 上下滑动翻页流畅度（滚动惯性、防误触）、点击左右屏幕边缘翻页（可选设置）
   - 字号/行距/页边距设置面板（移动端友好样式，保存 localStorage）
   - 亮度/背景色（白/米黄/绿/黑 四档护眼底色）
   - 阅读进度条+回到顶部按钮
   - 沉浸模式：隐藏全部 chrome 只留正文（点屏幕中央呼出菜单）
2. **书架/书库**：
   - 下拉刷新、触控目标 ≥44px、卡片长按菜单（删除/详情）
   - 搜索框固定顶部不随滚动消失
   - 下载进度 toast+书架角标
3. **Android WebView 兼容**（android/ 目录存在）：测试关键 CSS（100dvh、safe-area-inset）
   在旧 WebView 的降级，viewpoert-fit=cover 刘海屏适配
4. PWA：manifest + 简单 SW（离线打开已下载书）——yomu 若无 manifest 则补

## 三、Fudoki 移动端（~/development/fudoki）

已有：static/mobile.css 625 行（≤768px 覆盖）。本 goal 深化：

1. **诊断先行**：无头浏览器 390x844 逐页走查（主界面/文档列表/编辑器/词典/TTS/设置/登录），
   列出布局破碎点清单再修（截图存 docs/mobile-audit/）
2. **编辑器**：EasyMDE 在移动端的工具栏精简/预览切换大按钮；软键盘弹出时视口处理
3. **TTS 控制**：底部常驻迷你控制条（播放/暂停/进度），滚动不消失
4. **词典**：词卡移动端布局（长文折行/滚动区域限制）
5. **手势**：左右滑切换文档（可选）；下拉刷新文档列表
6. 登录页 mobile.css 补齐（login.html 常被漏）
7. PWA install prompt + iOS 图标（manifest 若缺）

## 四、共同验收

1. 两站各 390x844 全页走查截图（每页一张，无横向滚动条、无遮挡、触控目标达标）
2. yomu：阅读页沉浸模式开/关对比图；四档背景色截图
3. fudoki：TTS 迷你条+词典词卡+编辑器三张关键截图
4. Lighthouse 移动端跑分（性能/可安装性记录基线，不设硬指标）
5. **最后起服务**：yomu `python3 -m http.server 8830`（或其现有启动方式）、
   fudoki `python3 -m http.server 8831`（后台 nohup，绑定 0.0.0.0），
   输出手机可访问的 URL（http://192.168.3.82:8830 / :8831）
6. 两仓库 commit+push（中文信息）

## 五、边界

- 不重做上午已完成的功能修复；纯移动端体验层
- fudoki 的 Firebase/后端逻辑不碰
- yomu 数据(data/novels)不碰
- 端口 8830/8831 避开已占用（8810-8822 系）
