# AGENTS.md — Mir3-Research 工具仓库全局入口（智能体必读）

> 读者假设：你是一个从未见过本项目的 AI，只有这一篇文档。本文告诉你：这是什么仓库、
> 每个工具在哪/怎么跑/吃什么数据、改数据库的纪律、已知的坑。
> 事实均来自各工具 README 与实际代码（2026-08-14 核对），不确定处标注"未验证"。
>
> 本文件是仓库全局入口。涉及数据库、资源和公开仓库安全的操作必须遵守本文约束。
>
> **跨会话记忆锚点**：`docs/PROJECT_MENTAL_MODEL.md` — 项目目标/架构分层真相/坐标系
> 约定/goal 军团状态/方法论的总账。主会话开工先读它；产生重大理解/决策随手更新它。

## 一、仓库定位

- **公开仓库**（github.com/iamcheyan/Mir3-Research，曾私有后转公开）：**不放任何密钥/.env**。
- 内容 = 传奇3（EI / Zircon）**逆向研究 + 工具集**：原版客户端 EXE/资源逆向、System.db
  读写工具链、Web 浏览器（dbeditor/dbviewer/mapviewer/wilviewer/uieditor/webclient）、
  任务设计文档（`docs/quest-design/` 341 任务）。
- **不含大型资源**：`.wil/.map/.dat/.Zl` 素材不在仓库，通过 NAS 环境变量解析（见 §三）。
- 游戏本体源码在 `~/development/zircon`（另一个仓库），本仓库通过 symlink 复用其模型类。

## 二、工具地图（Tools/ 下每个常驻服务一行）

| 工具 | 端口 | 启动 | 干什么 | 关键数据源 |
|---|---|---|---|---|
| `Tools/dbeditor` | 8810 | `cd Tools/dbeditor && ./run.sh`（FastAPI+Vue3，venv） | System.db 在线编辑器；保存只落 JSON 工作区，显式点「同步」才写库 | `workspace/*.json`（SystemDbProbe 导出快照）→ 双库 |
| `Tools/dbviewer` | 8800 | 先 `bash Tools/dbviewer/export.sh` 导出，再 `python3 dbviewer.py --data /tmp/dbviewer_data --port 8800` | System.db 只读浏览器（分类树/关联跳转/地图联动），纯标准库 | `/tmp/dbviewer_data/<Type>.json ×77`（SystemDbProbe --json 产物） |
| `Tools/maps/mapviewer.py` | 8899 | `mir3-venv/bin/python Tools/maps/mapviewer.py <Map目录> --data <Data目录>` | 在线地图浏览器（瓦片渲染/NPC 标记/刷怪热力/任务叠加/连通图谱） | NAS 客户端 Map+Data；dbeditor workspace 的 NPCInfo/MapRegion/MovementInfo |
| `Tools/web/wilviewer.py` | 8765 | `mir3-venv/bin/python Tools/web/wilviewer.py --root /tmp/nas_mnt/NAS/TMP/EI传奇3.0客户端 --port 8765` | WIL **和 .Zl** 图库浏览器（帧预览/解码走 zlsdk+zldecode） | 客户端图库目录（NAS 或 `zircon/Debug/Client/Data`） |
| `Tools/uieditor` | 8820 | `cd Tools/uieditor && ./run.sh`（FastAPI，venv） | Godot 客户端 UI 所见即所得编辑器；改完点同步→游戏内 F12 热重载 | `zircon/GodotClient/UI/ui_tree.json`（需先 `--ui-export` 导出） |
| `Tools/webclient` | 8822 | `cd Tools/webclient && mir3-venv/bin/python serve.py` | **静态世界测试台**：纯前端漫游 627 张地图+GM 满配玩家（详见其 README） | `zircon/Debug/Client/WebData/`（webres 产物，可重建） |
| `Tools/webport` | 8823 | `cd Tools/webport && /home/tetsuya/mir3-venv/bin/python serve.py` | **双 UI 参考模式网页客户端**（Zircon 主线=DXControl+Interface.Zl 贴图 / EI 参考=webclient 风格，右上角切换）；注册→登录→选人→进比奇→走路全链路真服联调已通 | wsgateway :7001→ServerCore :7000；`zircon/Debug/Client/WebData`；对照文档 `docs/webport/phase1-port-map.md`；**深度审计报告 `docs/webport/audit/AUDIT_REPORT.md`**（2026-08-14 像素/结构/行为/资源四维差异清单，后续零差异迭代唯一事实依据） |
| `Tools/webres` | 8821 | `serve.py`（原型服务）；`webres.py` 是构建器 | `.Zl/.map → WebP` 资源瘦身管线（WebData 的生产者） | `zircon/Debug/Client/{Data,Map}` |
| `Tools/wsgateway` | 7001 | `mir3-venv/bin/python wsgateway.py` | WebSocket→TCP 透传网关（浏览器连 ServerCore :7000），登录包已验证 | ServerCore :7000 |
|`Tools/portal`|8840|`python3 Tools/portal/portal.py`（纯标准库）|工具门户：五工具健康检查/数据源概要/只读标识/移动端等级；未启动服务显示启动命令（`Tools/common/webui` 共享移动壳的宿主之一）|各工具端口 TCP 探测 + `/api/files`·`/api/maps`·`/api/stats` 探针|

无端口的常用工具：

| 工具 | 类型 | 干什么 |
|---|---|---|
| `Tools/SystemDbProbe` | C# | System.db 读取器（`--dump` markdown / `--json` 导出，dbviewer/dbeditor 的数据源头） |
| `Tools/DBImporter` | C# | dbeditor 的写回器：校验→备份→双库写→round-trip |
| `Tools/NpcMover` | C# | NPC 坐标迁移到 EI 坐标系（294 NPC 审计表在 `audit-report.md`，已写入 DB） |
| `Tools/questdata` | Python 脚本组 | 任务落地三件套：`gen_semantic_map.py`（中文名↔DB Index）/ `gen_quest_manifest.py`（341 任务逐环）/ `import_quest.py`（QuestInfo 入库，>50 条拒收防呆） |
| `Tools/common/zlsdk.py` | Python 库 | .Zl 图库读取（ZL2 容器/DXT/BC7），Python 侧统一入口，勿手写解析 |
| `Tools/common/wilsdk.py` | Python 库 | WIL/WIX 解码库 |
| `Tools/item_icon_extractor` | C# | `zldecode`：.Zl 逐帧解码成 BMP（BC7 兜底），zlsdk 内部 subprocess 调用 |
| `Tools/reverse-engineering/` | Python 脚本组 | 原版 EXE/UI/资源证据提取（历史逆向产物，一般不用动） |
| `scripts/goal_watchdog.sh` | bash+systemd timer | omp goal 会话看门狗（详见 §六） |

端口全景（改绑定先 `ss -tlnp` 查占用）：80 svc-dashboard / 7000 游戏服 / 7001 wsgateway /
8765 wilviewer / 8800 dbviewer / 8810 dbeditor / 8820 uieditor / 8821 webres / 8822 webclient /
8823 webport / 8830 yomu / 8831 fudoki / 8840 portal / 8899 mapviewer。

1. **`Tools/dbeditor/workspace/*.json` = System.db 的导出快照 + 编辑缓冲区**。
   - 由 SystemDbProbe `--json` 导出（每表一个 JSON，`_baseline/` 是基线）；
   - dbeditor 的所有编辑**只写这里**并自动 git commit（可 diff/回滚）；
   - 用户显式点「同步到数据库」→ `sync.sh` → DBImporter 校验/备份/写库（见 §四）；
   - **其它工具（mapviewer/questdata/webclient）把它当第一数据源**读 NPCInfo(294)/
     MapRegion(5009)/MovementInfo(1039) 等——它比 mir2ei 的 `wiki_all.json` 新鲜
     （含 NpcMover 坐标修正）。`wiki_all.json` 是静态快照会过期，只做兜底。
2. **NAS 资源环境变量**（素材不在仓库，靠这些解析）：
   ```bash
   export MIR3_EI_ROOT=/home/tetsuya/NAS/TMP/EI传奇3.0客户端   # 82服务器实际用 /data/NAS/TMP/...
   export MIR3_MUD3_ROOT=/home/tetsuya/NAS/TMP/Mud3             # 原版服务端文本配置(GB18030!)
   export MIR3_ZIRCON_ROOT=/home/tetsuya/development/Zircon     # 注意 zircon 实际目录是小写
   export MIR3_NAS_TMP=/data/NAS/TMP                            # [shared E0] 82机NAS挂载点(旧机是/home/tetsuya/NAS→/tmp/nas_mnt,82上已悬空); mapviewer瓦片缓存等按它解析
   NAS 上还有 `EI3.0英雄杀服务端/Mud3/Envir/`（MapInfo.txt/Mongen.txt 等权威文本，
   **GB18030 编码**，Python 读先 `bytes → decode('gb18030')`）。
3. **Python 环境统一用 `/home/tetsuya/mir3-venv/bin/python`**（Python 3.13.5，装了
   fastapi/uvicorn/Pillow/numpy/texture2ddecoder 等；系统 python3 是 3.11 无 pip）。
   dbeditor/uieditor 用各自的 `venv/`（`run.sh` 会用 uv 自动建）。
4. **System.db 不是 SQLite**——.NET BinaryFormatter 序列化，Python 打不开；读走
   SystemDbProbe/dbviewer，写走 DBImporter/sync.sh。
5. 双库位置：服务端 `zircon/Debug/ServerCore/Database/{System.db,Users.db}`，
   客户端副本 `zircon/Debug/Client/Data/System.db`。System.db=世界静态数据，
   Users.db=玩家账号（**绝不写**）。

## 四、写库纪律（违反会毁数据，无例外）

1. **服务端在跑（`ss -tlnp | grep 7000` 有监听）→ 绝不写库**。dbeditor 同步会在双端
   校验拒绝（API 409 + importer 退出码 2）；手写工具自己负责先停服。
2. **流程固定**：停服 → 备份双库 → 干跑 → 写测试副本 → round-trip 读回验证 → 写真库
   → **双库同步**（服务端写完必须 `cp` 到 `Debug/Client/Data/System.db`，否则客户端
   NPCPage/ToolTip 显示分叉）→ 重启服务端 → 游戏内实测。
3. 优先走 dbeditor 的缓冲区工作流（编辑落 JSON → 显式同步），**不要绕过缓冲区直写 .db**。
4. MirDB 是**全量重写**（无增量），写前必备份；`Session.Initialize` 必须传
   LibraryCore + ServerLibrary **两个程序集**（缺一个 `GetCollection` 静默返回 0 行不报错）。
   完整模板见 Hermes skill `mir3-project` 的 `references/systemdb-direct-write.md`。

## 五、与 zircon 仓库的关系

- `Mir3-Research/LibraryCore` 和 `ServerLibrary` 是 **symlink → `~/development/zircon/`** 同名目录
  （C# 工具直接复用游戏模型类编译；zircon 代码变更会传导到本仓库工具）。
- 工具的运行时数据（System.db/图库/WebData）都在 zircon 的 `Debug/` 下。
- 改 zircon C# 后必须重新 `dotnet build`（服务端还要 `-o Debug/ServerCore`），否则跑的是旧程序集。
- zircon 推送远程是 `fork`/origin=iamcheyan/Zircon，upstream=Suprcode/Zircon（合并上游
  逻辑冲突必须先问用户）。

## 六、goal_watchdog 体系（本仓库 scripts/ 是它的家）

- `scripts/goal_watchdog.sh` 由 **crontab 每 5 分钟**跑一次（`crontab -l` 可见）。
- **GOALS 数组**（脚本 67 行起）每行 5 字段：`goal_id|jsonl路径|tmux会话名|workdir|标签`。
  新开 goal = 加一行 + commit；主动停 goal = kill omp 进程 + `touch ~/.omp/mir3-goal-watchdog.<前8位>.off` + 删数组行（kill 和 off 缺一不可，否则看门狗 5 分钟内复活它）。
- goal 达到终态（complete/blocked/error）时看门狗**自动** kill 进程+tmux 会话并追加记录到
  `~/.omp/logs/goal-completed.log`——**会话自动消失是正常回收不是故障**。
- 全局停用：`touch ~/.omp/mir3-goal-watchdog.off`。
- 监控面板：svc-dashboard（:80）的 Goal 页签。

## 七、已知坑（每条都真实踩过）

1. **MirDB Session 只传一个程序集 = 静默 0 张表**（bgmfill 实测 627→0）：必须
   LibraryCore+ServerLibrary 双程序集；root 用绝对路径带尾斜杠。
2. **改了后端代码 ≠ 生效**（dbeditor 2026-08-14 复发两次）：patch 完直接 curl 测的是旧进程。
   流程：`ss -tlnp | grep <端口>` 取 pid → kill → 重启 → curl 验证新字段真的出现。
3. **手机/异端改静态 JS/CSS 必须 bump `?v=N`**：否则浏览器缓存旧 JS，用户报"没变化"
   时第一怀疑缓存，第二才是查进程。
4. **Vue3 异步 fetch 帧号更新普通 Map 不触发重渲染**：图标帧号/中文名这类计算字段必须
   由后端列表接口**同步注入**（dbeditor 的 `__zh`/`__frame` 模式）。
5. **mapviewer 视口锚定陷阱**：实体坐标 ×48/32 换算成像素后远超视口，异步 fetch 完成
   前跑的锚定会被覆盖——验收必须实际滚动到实体质心截图，别只 curl API。
6. **wsgateway 的 packet id 必须从实际部署 dll 反射导出**（`packet_id_dump/`），手算
   Packet.cs 会漂移。
7. **WebData 磁盘预算红线 3G**：当前 2.2G；serve.py 有 30s 磁盘守卫超限返回 507。
   全量渲染估算 22G——只能用分级方案（126 张核心图离线 + 其余按需）。
8. **System.db 直接写工具的root路径**：zircon 目录名**小写**，工具里硬编码大写 `Zircon`
   在 Linux 上静默失败（UI 图库全透明那个 bug 同根因）——路径一律动态解析。
9. **GB18030**：NAS/Mud3 的中文文本配置不是 UTF-8，直接 `open().read()` 会乱码或炸。

## 八、常用命令速查

```bash
# 查所有工具端口占用
ss -tlnp | grep -E ':(80|7000|7001|8765|8800|8810|8820|8821|8822|8899) '

# dbeditor 同步到数据库（必须先停服）
cd Tools/dbeditor && ./sync.sh

# 导出 dbviewer 数据
bash Tools/dbviewer/export.sh

# uieditor 数据源重导出（zircon 客户端 UI 变更后）
cd ~/development/zircon && godot-mono --path GodotClient res://Scenes/UITestScene.tscn -- --ui-export

# 重建 WebData
cd Tools/webres && mir3-venv/bin/python webres.py data && mir3-venv/bin/python webres.py sprites --what all
```

```bash
# [shared E0] 一键重建 /tmp 脆弱缓存三件套（Tools/cache/ + /tmp 双写）
make cache          # = bash scripts/gen_caches.sh（--thumbs 连总览缩略图）

# [shared E0] 统一服务管理（11个服务注册表；hub socket 对 shell 不公开故 nohup+pidfile 自治）
bash scripts/services.sh status
bash scripts/services.sh start mapviewer     # start/stop/restart/log 同构, 无参=全部
```

## 九、别做什么

- 别往仓库提交密钥/`.env`/大型二进制资源（公开仓库）。
- 别绕过 dbeditor 缓冲区直写 System.db；别写 Users.db（除 mkacc 建号等明确授权场景，且停服）。
- 别在服务端运行时碰两个 .db 的任何一个。
- 别手写 .Zl/WIL 解析器（用 `common/zlsdk.py`/`wilsdk.py`）。
- 别重新调研"Web 移植路线"——WASM 全量移植已被官方硬阻断，结论在
  `zircon/docs/WEB_PORT_SPIKE_REPORT.md`，现路线是静态 webclient + 将来 wsgateway 联机。
