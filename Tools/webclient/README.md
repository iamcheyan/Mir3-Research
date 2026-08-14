# webclient — 浏览器世界观测试台

纯前端静态站点（vanilla JS，零框架）+ FastAPI 资源服务。无游戏服务器连接，模拟 GM
满配测试玩家漫游完整 Mir3 (Zircon) 世界：地图导航、纸娃娃、技能特效、NPC/怪物、
地图切换、GM 面板、显示设置、大地图/小地图/聊天/腰带/伙伴。

## 启动

```bash
cd Tools/webclient
/home/tetsuya/mir3-venv/bin/python serve.py     # 127.0.0.1:8822
```

浏览器打开 <http://127.0.0.1:8822/>。资源产品在
`/home/tetsuya/development/zircon/Debug/Client/WebData/`（构建方式见 `Tools/webres/`）。

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

## 地图瓦片分级方案

全量 627 图实测外推 ≈ 22GB / 26h+，超 3G 预算（见 `WebData/maps/_estimate.json`）。
分级方案：126 张核心图（主城 + 全部 NPC 图 + respawn 覆盖图，≈2.15GB）离线预渲染，
其余 501 张由 serve.py 按需渲染（单瓦片 0.5–3s，首次进入新图时逐瓦片补齐）。

## 验收

```bash
node Tools/webclient/accept.mjs     # 截图 /tmp/wc_*.png + /tmp/wc_report.json
```
