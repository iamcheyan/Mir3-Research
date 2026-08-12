# dbviewer — System.db Web 数据库查看器

把 Zircon 服务器的 `System.db`（.NET BinaryFormatter 序列化格式）导出为 JSON，
并以 Web 界面浏览：集合分类树、分页表格、详情页 + 关联跳转、地图联动、统计视图、图片预览。

## 快速开始

```bash
# 1. 导出数据（调用 SystemDbProbe --json，输出到 /tmp/dbviewer_data）
bash Tools/dbviewer/export.sh

# 2. 启动服务（端口 8800）
python3 Tools/dbviewer/dbviewer.py --data /tmp/dbviewer_data --port 8800

# 3. 浏览器打开
#    http://127.0.0.1:8800/
```

依赖：Python 3.10+（纯标准库 `http.server`，无第三方依赖）、.NET SDK 10（导出阶段）。

## 架构

```
SystemDbProbe --json 导出（C#，一次性）
        ↓  <Type>.json × 77 + meta.json
Tools/dbviewer/dbviewer.py   ← 启动时全量载入内存 + 倒排索引
        ↓ JSON API（只读）
Tools/dbviewer/template.html  ← 单文件前端（无框架）
```

- **后端** `dbviewer.py`：`ThreadingHTTPServer`；数据目录参数 `--data`；
  缺数据时提示运行 `export.sh`；所有 API 返回 JSON。
- **前端** `template.html`：分类树（怪物图鉴 / 物品装备 / 技能魔法 / 地图信息 /
  NPC 位置 / 守卫信息 / 任务系统 / 系统数据）+ 表格 + 详情 + 关联面板。

### API

| 端点 | 说明 |
|---|---|
| `GET /` | 前端页面（内嵌地图中文名表） |
| `GET /api/meta` | 集合元数据：中文名、标识字段、字段类型/引用目标/中文名 |
| `GET /api/rows?type=&page=&per=&sort=&dir=&q=` | 分页行数据（支持排序、表内搜索） |
| `GET /api/row?type=&index=` | 单行详情 |
| `GET /api/related?type=&index=` | 关联：正向引用 + 反向引用 + 地图分层（刷怪/NPC/传送/守卫/安全区/矿点） |
| `GET /api/search?q=` | 全局搜索（所有集合的名称/标识字段） |
| `GET /api/stats` | 各集合记录数统计 |
| `GET /api/map-entities?map=` | 某地图的位置实体（供 mapviewer 合并渲染） |
| `GET /api/map-cn` | 地图文件名 → 中文名 |

## 关联跳转

- **怪物 → 掉落 → 物品 → 商店**：怪物详情「掉落」→ DropInfo → 物品详情
  （反向引用列出所有掉它的怪、卖它的商店 `StoreInfo` / `NPCGood`）。
- **地图 → 位置数据**：地图详情直接分组列出该地图的刷怪点 / NPC / 传送点 / 守卫 / 安全区 / 矿点。
- **NPC → 页面 → 按钮/检查/动作/商品**：任意引用字段（Index）都可点击跳转。

## 地图联动

位置类数据（刷怪 / NPC / 传送 / 守卫 / 安全区）在列表与详情中显示「地图名 + 坐标」，
并提供「地图 ↗」按钮跳转在线地图查看器：

```
http://127.0.0.1:8899/#map=<文件名>.map&cur=0&x=<世界像素X>&y=<世界像素Y>&hl=<实体名>
```

`x/y` 为世界像素坐标（格子 × 48 / × 32），`hl` 高亮同名实体（需 mapviewer 前端支持，
改动见 `Tools/maps/mapviewer.py` 的 `hl=` 参数解析与 `.ent.target` 高亮）。

mapviewer 的 `/api/entities` 会自动合并 dbviewer 的 `/api/map-entities`，
地图上直接显示数据库里的刷怪点 / NPC / 守卫标记。

## 图片预览

- 物品：`Storeitem.wil` 帧号 = `ItemInfo.Image`（经 wilviewer `http://127.0.0.1:8765`）
- NPC：`NPC.wil` 帧号 = `NPCInfo.Image`
- 怪物：EI 客户端 `Mon-N.wil` 帧布局与 Zircon 客户端不同，暂不预览（见已知限制）

## 注册为服务

见 `docs/database/DB_VIEWER.md`「服务注册」一节（示例为 omp `svc-dbviewer` 启动方式）。

## 数据更新

```bash
bash Tools/dbviewer/export.sh   # 重新导出（从 zircon 仓库根 System.db 副本，只读）
# 重启服务即可加载新数据
```

## 已知限制

- 怪物图片预览：EI 客户端图库帧布局与 Zircon 客户端不一致，`MonsterLookup.cs`
  的帧号不能直接用于 `Mon-N.wil`；后续可针对 Zircon ZL 图库单独实现。
- `MapRegion.PointRegion` 导出为质心 + 点数（避免几十 MB 逐点坐标），
  地图上的区域高亮粒度受限。
- 地图联动依赖 mapviewer 运行（8899）与 wilviewer 运行（8765，仅图片预览需要）；
  dbviewer 单独运行时其余功能不受影响。
