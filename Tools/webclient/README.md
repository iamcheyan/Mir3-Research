# webclient — 浏览器世界观测试台

纯前端静态站点（vanilla JS，零框架）+ FastAPI 资源服务。**不连游戏服务器**：模拟
GM 满配测试玩家（四职业 255 级、全技能全装备）漫游完整 Mir3 (Zircon) 世界——
627 张地图切换、纸娃娃、技能特效、NPC/怪物摆放、GM 面板、显示设置、大地图/聊天/腰带。

用途：**测试游戏世界观的工具**。将来联机版走 wsgateway（已验证，见 `Tools/wsgateway/`），
本工具不做联机。WASM 全量移植路线已被 Godot 4 官方硬阻断（结论存档
`zircon/docs/WEB_PORT_SPIKE_REPORT.md`），本工具即替代路线。

## 启动

```bash
cd Tools/webclient
/home/tetsuya/mir3-venv/bin/python serve.py     # 0.0.0.0:8822
```

浏览器打开 <http://127.0.0.1:8822/>（手机经 tailscale 用 `http://100.76.219.104:8822/`）。

资源产品在 `/home/tetsuya/development/zircon/Debug/Client/WebData/`（2.2G，可随时重建，
构建方式见 `Tools/webres/` 与该目录下 README.md；磁盘预算红线 3G，serve.py 超 30s
磁盘守卫返回 507）。

## 九大模块清单（对应 goal 文档 M1-M8 + 验收）

| 模块 | 内容 | 代码 |
|---|---|---|
| M1 全量地图 | 627 张地图瓦片渲染（512px 瓦片按需加载，缺瓦片本帧占位） | `camera.js` `res.js` |
| M2 玩家系统 | 四职业切换、8 方向走/跑、完整纸娃娃（背武→身→头→前武四层，同 C# PlayerRenderer 帧公式） | `sprites.js` `world.js` |
| M3 技能系统 | 174 技能全量（MIcon.Zl 图标+中文名），施法特效帧动画 | `ui.js` `render.js` |
| M4 NPC/怪物世界 | NPC 294 个按修正坐标摆放（头顶中文名），怪物按 RespawnInfo 摆放+点击看信息 | `world.js` |
| M5 地图连接 | MovementInfo 1039 条出口格高亮，踏上出口→渐变切图，比奇出发可走遍世界 | `world.js` `main.js` |
| M6 GM 面板 | 传送/召唤怪物(434)/刷物品/隐身/加速/@命令前端执行版 | `ui.js` |
| M7 图形设置 | 分辨率档位、V-Sync 开关（rAF↔250Hz）、UI 缩放（同 UiScaler 公式）、特效粒子门控 | `ui.js` `main.js` |
| M8 附加 UI | 大地图(B)/小地图/聊天框/腰带 Shift+1..8/自动药水/伙伴（骷髅/神兽跟随） | `ui.js` |
| 验收管线 | 无头自动验收截图序列 + 报告 | `accept.mjs` `shot.js` |

## 操作

| 输入 | 功能 |
|---|---|
| 方向键 / WASD | 8 方向移动（跑步=按住 Shift） |
| B | 大地图（NPC/出口标记，点击传送） |
| G / S / E / ESC | GM 面板 / 技能 / 装备 / 关闭面板 |
| Enter | 聊天输入框（@命令） |
| Shift+1..8 | 腰带快捷栏（药水演示自动饮用） |
| 鼠标点击实体 | 对象信息（NPC/怪物/物品：中文名、等级、BOSS） |

@命令：`@move 地图 [x y]` `@spawn 怪物名 [数量]` `@make 物品名 [数量]`
`@level 等级` `@hide` `@speed 倍率` `@pet 骷髅|神兽` `@where`。

## 验收标准与跑法

完整验收标准（10 条，覆盖 manifest 627 张/切图序列/四职业截图/技能≥170 条/纸娃娃
叠加/GM 面板/4K+2x 缩放不破版/首屏<5s 等）见 goal 文档
`Mir3-Research/docs/webclient/WEBCLIENT_GOAL.md` §四。

自动验收（需 serve.py 已启动）：

```bash
node Tools/webclient/accept.mjs
# 产物: /tmp/wc_*.png 截图序列 + /tmp/wc_report.json（含首屏/切图耗时与 JS 错误收集）
```

页面 JS 报错会被 pageerror/console error 收集进报告的 `errors` 数组——验收以
`errors` 为空 + 全部截图产出为准。

## 架构

```
static/js/
  data.js    常量 + 数据加载 + C# 同源帧公式 (DrawFrame/ArmourFrame/WeaponFrame/Hair/Helmet)
  res.js     瓦片/精灵帧加载 (LRU 图像缓存) + 帧元数据 manifest 缓存
  camera.js  画布/镜头/分辨率档位/瓦片拼接 (缺瓦片本帧占位, 就绪后自动补)
  sprites.js 人物纸娃娃层序 (背武→身→头→前武, 依 PlayerRenderer.DrawPlayerAt)
  world.js   玩家/实体/行走(walk 位)/出口检测/召唤/掉落/伙伴
  render.js  主渲染: Y 排序实体 + 出口高亮 + 施法特效 (全非阻塞, 缺帧下一帧补)
  input.js   键盘/鼠标 (8 方向合成)
  ui.js      GM/技能/装备/设置面板 + 腰带 + 球体 + 聊天 + 大地图 + 自动药水
  main.js    组装 + 主循环 (V-Sync 开= rAF, 关= 250Hz 定时器) + 切图渐变 + @命令
  shot.js    window.WC 验收辅助 (teleport/setClass/wear/cast/waitForTiles)
```

服务端 `serve.py`：静态站 + `/res/data/*.json` + `/res/maps/{图}/{x}_{y}.webp`
（按需渲染单瓦片 + 30s 磁盘守卫 507）+ `/res/sprites/{库}/{帧}.webp`（按需抽帧）
+ `/api/disk`。渲染管线复用 `Tools/maps/mapviewer.py` 与 `Tools/common/zlsdk.py`。

## 边界（goal 文档 §五，勿越）

- 不动 zircon C# 代码与素材包（.Zl/.map 一字节不动）；只写本目录 + WebData 产物。
- 不做联机（WS 网关已有，未来另立 goal）。
- 磁盘预算 3G：超线先停下来给分级方案（当前方案=126 张核心图离线全渲染+501 张按需）。
