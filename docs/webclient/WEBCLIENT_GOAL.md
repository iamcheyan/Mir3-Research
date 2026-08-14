# 静态 Web 客户端「浏览器世界观测试台」— 完整任务目标

## 一、定位（用户拍板）

纯前端静态沙盒（**不连服务器**）：浏览器打开就能逛遍 627 张地图、玩四职业 255 级
GM 满配测试号、试全技能全装备、随地摆怪摆物——**测试游戏世界观的工具**。
素材包(.Zl/.map)一个字节不动，Web 用的一切都是提取转换产物（WebP 位图），
放 `Debug/Client/WebData/`（可随时重建的构建产物目录）。

阶段0 Spike 已完成（WEB_PORT_SPIKE_REPORT.md）：
- WASM 全量移植路线 ❌（Godot 4 官方硬阻断 C# Web 导出）——本 goal 即替代路线
- webres 工具已建（Interface.Zl→WebP 实测 2.29x 压缩），本 goal 扩展它
- WS 网关已验证（本 goal 不用，将来联机版直接拿来）

## 二、七大模块（全做）

### M1 全量地图位图（复用 mapviewer 渲染管线）
- `webres maps`：遍历 MapInfo 627 张，每张渲染合成位图（back+mid+front），
  大图（>50MB 位图）分瓦片（512px 块+manifest）；**断点续跑**（已渲染跳过，可反复执行）
- 先跑 10 张估算总耗时/体积写入报告；**预算红线 3G**（超了给分级方案：首批 50 张
  城镇+野外全画质，洞窟按需加载）
- `maps_manifest.json`：地图ID/中文名(mapnames.py)/尺寸/瓦片网格/连接端点
### M2 玩家系统（满配 GM 测试号）
- 四职业（战/法/道/刺）切换，各职业 M-Hum 帧系外观
- 8 方向跑动（方向键/WASD），跑/走动画帧（FrameSet 公式同 MonsterLookup 逻辑）
- 完整纸娃娃：盔甲+武器(M-Weapon1/2)+发型+头盔 四层叠加；**装备不限职业**，
  ItemInfo 各职业代表装备 20+ 件可穿（Storeitems.Zl 图标列表）
### M3 技能系统（174 全量）
- 技能栏：按职业分组滚动列表（MIcon.Zl 图标+中文名 db_names.json）
- 施法演示：Magic.Zl/MagicEx* 特效帧动画（映射查 MonsterLookup/zdocs 文档；
  找不到特效的用图标放大动画兜底）
### M4 NPC/怪物世界摆放
- NPC：dbeditor workspace NPCInfo.json 294 个按修正坐标摆放，头顶中文名，点击看信息
- 怪物：RespawnInfo 2475 条按 Region 摆放（同图可抽样显示），MonsterLookup 帧渲染，
  站立动画+点击显示中文名/等级/BOSS 标记
### M5 地图连接（世界观闭环）
- 连接数据：MovementInfo 1039 条（或 mvtoolkit 已产出的 map_links_v2.json）
- 出口格高亮标记；玩家踏上出口→过场渐变→切换地图（manifest 驱动）
- 从出生点（比奇）可走遍全世界（地表+地下城）
### M6 GM 命令面板（前端执行版）
- 传送：搜地图名/ID 跳转任意坐标
- 召唤怪物（434 全量）/ 刷物品（Ground.Zl 掉落图标）
- 隐身（半透明）/加速（速度滑条）开关
- @命令对照表（@move/@spawn/@make/@level…点击即执行对应前端动作）
### M7 图形/显示设置模拟（用户点名）
- 设置面板仿 ConfigDialog：
  - 分辨率档位 1280x720→3840x2160（画布等比缩放，验证 UI 不破）
  - 窗口/全屏/无边框（浏览器 F11 Fullscreen API）
  - V-Sync 开关（演示开关前后帧率差异）
  - **UI 缩放滑条** 0.75/1/1.5/2x（Godot 端 UiScaler 同公式 clamp(min(h/768,w/1024),1,2)）
- 特效/粒子开关（对应 ClientSettings.DrawEffects/DrawParticles，门控施法特效/粒子渲染）
- 所有设置即时生效 + localStorage 持久化
### M8 附加 UI（尽力搬运）
- 大地图（B 键）：全图缩略+NPC/出口标记+点击定位；小地图
- 聊天框：系统消息（切图/拾取/GM 命令回显）
- 腰带栏 Shift+1..8（使用有冷却动画）；自动药水面板（演示）
- 伙伴展示：召唤骷髅/神兽帧跟随玩家（GM 召唤物走同套）

## 三、技术栈与结构

- `Tools/webclient/`（Mir3-Research）：**纯静态站**（原生 JS/Canvas 或 DOM，零框架零构建；
  参考 mapviewer/dbeditor 的单文件服务模式）
- 服务：FastAPI :8822 出静态文件 + `/res/*`（WebP/瓦片按需）+ `manifest` API
- 渲染：地图=Canvas 瓦片拼接；人物/怪物=帧序列 Canvas 或 DOM 精灵；
  UI 窗口=DOM（贴图 img 引 /res/interface/）
- 移动端 390px 可浏览（桌面优先）

## 四、验收标准（全过）

1. maps_manifest 覆盖 627 张；磁盘 WebData ≤3G（或分级方案落地首批≥50 张+按需机制）
2. 比奇→3 张邻接图切换演示截图序列（/tmp/wc_map_*.png）
3. 四职业外观切换 4 张截图（帧系明显不同）
4. 技能栏 ≥170 条 + 任选 3 个技能施法特效截图
5. 纸娃娃 4 部位叠加正确（穿/脱武器盔甲对比截图）
6. GM 面板：传送 3 张图+摆怪+刷物截图
7. 4K 分辨率+2x UI 缩放无破版截图；特效开关前后对比截图
8. 大地图（NPC/出口标记）+ 聊天系统消息 + 腰带使用截图
9. 首屏加载 <5s（首图+必要资源），后续切图 <2s（本地实测）
10. 两仓库 commit+push（中文信息）；README 写使用说明+URL

## 五、边界

- 不动 zircon C# 代码与素材包；只写 Mir3-Research/Tools/webclient + WebData 产物
- 端口 8822；磁盘预算 3G（当前 82%，超线先停下来给分级方案）
- mapviewer/mvtoolkit 的渲染代码直接 import 复用（同仓库 Tools/）
- 不做联机（WS 网关已有，未来另立 goal）
- 长任务（627 张渲染）用 nohup/后台跑，别阻塞交互

## 六、执行顺序

M1（先 10 张样板+估算）→ M2+M5（玩家+连接，先比奇闭环）→ M4（世界摆放）→
M3（技能）→ M6（GM 面板）→ M7（图形设置）→ M8（附加 UI）→ 全量渲染收尾
