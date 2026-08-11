# Mir3 / Zircon System.db 数据库查看器（Web）— 完整任务目标

## 一、任务背景

你是 Zircon 私服项目的开发智能体。服务器上有一个游戏世界数据库 `System.db`（.NET BinaryFormatter 序列化格式，非 SQLite），存有全部游戏静态数据（怪物、物品、技能、地图、NPC、刷怪点、传送点、守卫、任务、掉落等）。当前只有命令行工具 `SystemDbProbe`（C#）能读它，生成的是 Markdown 文档，浏览体验差。你的任务是：**实现一个 Web 数据库查看工具**，让用户像浏览攻略站一样浏览、搜索、关联跳转游戏数据，并和已有的在线地图查看器打通（地图上直接看刷怪点/NPC/传送点）。

这是一个大型任务，需要你自主完成全部工作：写代码、构建、生成数据、启动服务、浏览器实测验证、写文档。不要只做一半就停，必须形成完整可交付结果。

## 二、权威参考：先读这几个文件

动手前**必须**先读（它们定义了格式、风格和可复用代码）：

1. **在线地图查看器**（参考它的架构和前端风格，这是你的模板）：
   - `/home/tetsuya/development/Mir3-Research/Tools/maps/mapviewer.py`（3279 行）
   - 入口：`/home/tetsuya/development/Mir3-Research/Tools/mapviewer.py`
   - 它用 Python 标准库 `http.server` + 单文件 HTML/JS 前端（无框架依赖），服务端渲染瓦片 + JSON API。注意它的 `load_catalog` / `load_connections` / `load_entities` 函数和 `HTML_TEMPLATE` 单文件前端模式。
   - 它运行时依赖：`Tools/common/wilsdk.py`（WIL 图库解码）、`Tools/maps/zlsdk.py`（ZL 图库解码）、`Tools/maps/mapnames.py`（地图中文名）。

2. **SystemDbProbe**（读取 System.db 的 C# 工具，你的数据导出基础）：
   - `/home/tetsuya/development/Mir3-Research/Tools/SystemDbProbe/Program.cs`（59KB）
   - 项目文件：`/home/tetsuya/development/Mir3-Research/Tools/SystemDbProbe/SystemDbProbe.csproj`
   - 它用 `Session(SessionMode.Users, root)` + `session.Initialize(LibraryCore 程序集, ServerLibrary 程序集)` + `session.GetCollection<T>()` 读取所有集合，已有 `--dump`（生成 Markdown）、`--minimap`、`--stores` 等模式。
   - **你的核心工作之一**：给它加一个 `--json <outdir>` 导出模式，把所有集合（表）导出为 JSON 文件，供 Web 服务读取。JSON 要扁平化（字段=值），引用关系（如怪物→掉落→物品）用索引 ID 表达。

3. **数据库结构文档**（集合清单、中文名、字段参考，SystemDbProbe 生成的）：
   - `/home/tetsuya/development/Mir3-Research/docs/database/_summary.md`（所有集合及记录数）
   - `/home/tetsuya/development/Mir3-Research/docs/database/data/*.md`（各集合字段样例）
   - `/home/tetsuya/development/Mir3-Research/docs/database/views/*.md`（怪物/物品/NPC/地图等业务视图）
   - 注意：这份文档是从旧库 `Debug/Server/Database/` 生成的（`Program.cs` 里 `root = "Debug/Server/Database/"`），**数据可能旧**，字段结构作参考即可，数据以新库为准。

4. **数据源（要读取的数据库）**：
   - 服务器实际使用的库：`/home/tetsuya/development/zircon/Debug/ServerCore/Database/System.db`（11.7MB，md5 1a7ee9e2…，627 地图 / 434 怪物 / 294 NPC / 2475 刷怪等）
   - 仓库根副本：`/home/tetsuya/development/zircon/System.db`（md5 与上面一致，可用它避免动运行中的库）
   - 玩家库（只读参考，一般不用导出）：`/home/tetsuya/development/zircon/Debug/ServerCore/Database/Users.db`
   - **重要**：服务器正在运行（今天刚启动过），读库用**只读方式**（`file:...?mode=ro` 或拷贝副本），绝不要写回。

## 三、功能需求

### 3.1 集合浏览（核心）
左侧集合树（或顶部分类导航），右侧数据表格：
- 按业务分类组织：**怪物图鉴、物品装备、技能魔法、地图信息、NPC位置、守卫信息、任务系统、系统数据**
- 每类下挂对应集合（如怪物类：MonsterInfo、MonsterInfoStat、DropInfo、RespawnInfo）
- 表格默认显示关键字段（每类 5-8 个），行数多时自动分页
- 支持按字段排序、关键字搜索（中英文名/ID）

### 3.2 详情页 + 关联跳转（重点）
点行进入详情页：显示该记录全部字段（字段中文名 + 值）。
**关联跳转**（这是灵魂功能，必须做）：
- 怪物详情 → 它的掉落（DropInfo）→ 掉落物品（ItemInfo）→ 哪些商店卖（StoreInfo/NPCGood）→ 哪些怪也掉
- 地图详情 → 该地图的刷怪点（RespawnInfo）、NPC（NPCInfo）、传送点（MovementInfo）、守卫（GuardInfo）、安全区（SafeZoneInfo）
- NPC 详情 → 它关联的页面/按钮/商店
- 任意有引用关系的字段（Index/索引 ID）都做成可点击跳转

### 3.3 地图联动（与 mapviewer 打通）
- 位置类数据（刷怪/NPC/传送/守卫/安全区）在列表和详情里显示「地图名 + 坐标」
- 提供「在地图上查看」按钮，跳转到地图查看器并定位：`http://127.0.0.1:8899/?map=<文件名>&x=<x>&y=<y>&highlight=<类型:ID>`
- 先确认 mapviewer 的 URL 参数格式（读它的 JS 前端代码），若它不支持定位参数，则在 dbviewer 里内嵌一个简化版地图小窗（可选，优先级低）

### 3.4 图片预览（可选但加分）
- 物品图标 / 怪物图槽：用 `wilsdk.py`/`zlsdk.py` 解码显示缩略图（参考 wilviewer.py 的 `/sprite?` 端点实现）
- 优先级低，若时间紧张可只做怪物/物品详情页的单图预览

### 3.5 统计视图
- 每个集合记录数、地图数、怪物数等概览（参考 `docs/database/views/monsters.md` 风格做成页面）

## 四、技术方案（推荐）

```
SystemDbProbe 加 --json 导出模式（C#，一次性生成）
        ↓
  Tools/dbviewer/ 目录：
    - export 脚本（调用 SystemDbProbe --json，输出到 /tmp/dbviewer_data/ 或仓库内）
    - dbviewer.py（Python 标准库 http.server，仿 mapviewer 架构）
    - 单文件前端 HTML/JS（内嵌在 dbviewer.py 或独立 template）
```

要求：
- **纯 Python 标准库**（http.server），不引入 Flask/FastAPI 等依赖（机器上可能没有，且 mapviewer 就是这么做的）
- 前端单文件或极简文件集，无框架依赖（参考 mapviewer 的 HTML_TEMPLATE 风格）
- 数据加载：启动时把 JSON 全量载入内存（几十 MB 可接受），API 只读
- 端口：**8800**（避免与 mapviewer 8899、wilviewer 8765、simulator 8477 冲突）
- 服务支持 `--data <dir>` 参数指定 JSON 数据目录；若数据缺失自动提示运行导出命令
- 所有 API 返回 JSON，前端 fetch 渲染

## 五、验证要求（必须真实执行）

1. `dotnet build Tools/SystemDbProbe/SystemDbProbe.csproj` 通过，`--json` 导出成功，输出目录有各集合 JSON 文件
2. 启动 dbviewer.py，浏览器实测（可用 curl 验证 API + 无头浏览器或 curl 验证页面）：
   - 集合列表加载正常
   - 至少验证：怪物详情 → 掉落 → 物品的关联跳转链路
   - 地图详情 → 刷怪点列表
   - 搜索功能
3. 把工具注册为可启动服务（参考现有的 svc-* 服务模式，看 `~/.omp/logs/svc-mapviewer.log` 是怎么起的；或在仓库 README 写明启动命令）

## 六、交付物

1. `Tools/dbviewer/` 目录：dbviewer.py + 前端 + README（启动方法、依赖、架构说明）
2. SystemDbProbe 的 `--json` 模式源码改动（提交到 git）
3. 一份使用文档 `docs/database/DB_VIEWER.md`：截图说明各功能页
4. 所有代码 commit 并推送（仓库：zircon 仓库或 Mir3-Research，按改动所在仓库决定；commit 信息用中文）

## 七、工作约定

- 工作目录以 `/home/tetsuya/development/Mir3-Research` 为主（SystemDbProbe、mapviewer 都在这里）；zircon 仓库的 System.db 是数据源
- 不要动运行中的服务器（dotnet ServerCore 正在跑），读库用副本或只读模式
- 不要修改 mapviewer.py / wilviewer.py 现有文件（除非打通地图联动确有必要）
- 中文注释、中文 commit
- 碰到格式问题先读 `Tools/common/wilsdk.py` / `docs/database/data/` 样例再动手
- 完成后保持 dbviewer 服务运行（后台），并把访问地址和验证结果写在最终总结里

## 八、最终总结要求

完成时输出：
1. 交付清单（文件 + commit）
2. 服务地址（http://127.0.0.1:8800/）
3. 功能验证结果（哪些页面/链路实测通过）
4. 已知限制和后续建议
