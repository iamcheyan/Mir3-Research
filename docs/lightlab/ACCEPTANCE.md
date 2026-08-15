# Light Lab 验收汇总（Goal E5 · 2026-08-15）

任务书：`LIGHT_LAB_GOAL.md` §6 验收标准逐项核销。

## 验收清单

- [x] **P0 天气素材 WebP 可显示；env-snapshot.json 627 图 + 24 火把数据齐全**
  - `Tools/webclient/static/assets/weather/`：snow(500)/rain(509)/splash1-5(510-514)/
    lightning(540)/fog(550) 共 9 帧无损 WebP + manifest.json，zlsdk 从 ProgUse.Zl 提取
  - `env-snapshot.json`（docs/ 权威 + static/assets/ 镜像）：627 图
    {FileName, Description, Light, Weather}（Light: Default 580/Night 44/Light 3；
    Weather 全 None）+ 24 个 Light 物品（Amount 15×2、25×22）
  - 生成器 `Tools/lightlab/build_env_assets.py`（可重跑刷新）
- [x] **P1 四维面板实时联动，叠加顺序与 Godot 一致**
  - 入口 `http://127.0.0.1:8822/static/env.html`（页面/cjs 全 E5 领地新文件，零改 E4 文件）
  - 实测记录（__ENV 编程钩子 + 面板控件模拟 + canvas 像素采样）：
    - 环境光：Night→ambient 0.25；严格模式→15/255=0.0588；Default 随 DayTime 0→1 亮度 17→65
    - 天气：雨+雪+雾+雷 1.5s 稳态 439 粒子（雨 222+水花 63+雪 146+雾 8）；闪电竖条列 280-297
    - 光源：火把 25 光圈内 (147,160,99) 暖亮 / 圈外 (16,13,11)；微光/特效光/格子光开关生效
    - 特殊态：死亡=IndianRed 相乘（R/G=2.47）；深渊=玩家 (255,255,255) 全亮+远处 (0,0,0) 纯黑
    - 叠加序：地图→对象→天气(Z850，被光照层暗化/红染)→光照(Z900)→深渊特效(原版画入光照层)
- [x] **P2 web 采样画廊 + Godot 无头对照 + PARITY_REPORT.md**
  - `gallery/` 27 张：A 组环境光梯度 9、B 组天气 6、C 组光源 5、D 组特殊态 2、E 组组合 5
  - `godot/` 6 张：zircon-light-{night,twilight,default,dead,abyss}.png + weather 图
    （82 机 Xvfb+llvmpipe，5 stage PASS；abyss 探针 0.369<0.5 为软渲染阈值偏紧，见报告 §2）
  - `PARITY_REPORT.md`：18 项三方对照 + 9 个数值锚点；发现 2 条 Godot/原版真实偏差
    （深渊特效被光照层压暗 Z3301<3401；Default 无下限）
- [x] **P3 测试图改 Weather=RainFogLightning 经 dbeditor 管线写回 + 游戏内验证**
  - 02_0062「唯我独尊」（PK 测试图）：面板预览 → PUT /api/row/MapInfo/1166 → POST /api/sync
    → 停服校验/备份/round-trip 语义一致/双库安装 85970aef
  - 游戏内：Godot 客户端 --auto-login 连服，GM @move 02_0062，
    日志 `[Light] map=02_0062 setting=Default weather=RainFogLightning dayTime=0`，
    截图 `ingame_020062_rainfoglightning.png`
  - 验证后已回滚 Weather=None（sync e0108a7d，快照刷新 627 全 None）
  - 附带发现：夜图闪电固有不可见（纹理亮度 77×0.25≈19≈背景）
- [x] **P4 两份文档更新**：`docs/GODOT_WEATHER_DAYLIGHT_GUIDE.md`（627 统计/AmbientFor 现值/
  TownWeatherTestMode 移除注记/§12 特殊态）；总纲 §3.8 六条新坑；本文件

## 使用速记

- 打开实验室：浏览器 `http://127.0.0.1:8822/static/env.html`（webclient :8822 需在跑：
  `bash scripts/services.sh start webclient`）
- 改库流程：面板选图 → 目标 Weather/Light → 「生成变更预览」→ 停服 → 「写入 workspace + 同步」
  （dbeditor :8810 需在跑且 7000 无监听；hub 管的服务用 `hub stop zircon-core` 停）
- 回滚：把字段改回原值再 sync（rollback API 在 baseline 重置后无效，总纲 §3.8）

## 交付物清单

| 路径 | 内容 |
|---|---|
| `Tools/webclient/static/env.html` | 实验室页面（E5 领地） |
| `Tools/webclient/static/js/env-lab.js` | 引擎：天气粒子/光照层/特殊态/面板/dbeditor 出口 |
| `Tools/webclient/static/css/env-lab.css` | 样式 |
| `Tools/webclient/static/assets/weather/` | 9 帧 WebP + manifest |
| `Tools/webclient/static/assets/env-snapshot.json` | 前端数据镜像 |
| `Tools/lightlab/build_env_assets.py` | 素材+快照生成器 |
| `docs/lightlab/env-snapshot.json` | 权威快照（627+24） |
| `docs/lightlab/PARITY_REPORT.md` | 三方对照 18 项 |
| `docs/lightlab/gallery/` | web 27 张采样 |
| `docs/lightlab/godot/` | 无头审计 6 张 |
| `docs/lightlab/ingame_020062_rainfoglightning.png` | 游戏内天气生效截图 |
| `docs/GODOT_WEATHER_DAYLIGHT_GUIDE.md` | 更新（§1/§5/§6/§12） |
| `Tools/dbeditor/app.py` | [shared] CORS 白名单 webclient:8822 |
