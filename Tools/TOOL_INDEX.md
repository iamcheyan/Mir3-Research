# Zircon 辅助开发工具总目录（TOOL_INDEX）

> 读者假设：你是一个从未见过本项目的 AI 或新人，只有这一篇文档。
> 本文回答：围绕 Zircon 我们建了哪些辅助开发工具、分别在哪、怎么跑、吃什么数据、
> 已知的坑。**运维类工具（goal watchdog / svc-dashboard）不在本文范围**——它们是
> 机器运维设施，不是 Zircon 游戏辅助工具，各自有自己的文档。
>
> 最后核对：2026-08-17（对照各工具 README 与实际代码）。
> 本文档是 Tools/ 的唯一总入口；各工具细节看各自目录的 README.md。

## 〇、30 秒速览

- **所有游戏辅助工具统一住在 `~/development/Mir3-Research/Tools/`**（公开仓库）。
- 游戏本体源码在 `~/development/zircon`（另一仓库），工具通过 symlink 复用其模型类。
- 常驻 Web 工具都有固定端口，起停命令见 §三；一次性脚本工具见 §四。
- Python 统一用 `/home/tetsuya/mir3-venv/bin/python`（3.13，带 fastapi/Pillow/
  texture2ddecoder）；dbeditor/uieditor 有各自 venv（run.sh 自动建）。
- 写 System.db 有铁律（服务端在跑绝不写 / 双库同步 / 先备份），见 §五。
- `Tools/` 顶层的同名 .py 是兼容转发 shim（真身在各专题子目录），别删。

## 一、目录结构总图

```
Mir3-Research/Tools/
├── TOOL_INDEX.md          ← 本文档（总目录）
├── README.md              ← 组织原则（新工具放专题子目录）
│
├── 【数据库】
│   ├── dbeditor/          System.db 在线编辑器（缓冲区工作流）    :8810
│   ├── dbviewer/          System.db 只读浏览器                    :8800
│   ├── SystemDbProbe/     C# db 导出器（--dump md / --json）
│   ├── DBImporter/        C# db 写回器（dbeditor 同步链的执行端）
│   ├── NpcMover/          C# NPC 坐标迁移工具（EI 坐标系）
│   └── questdata/         任务落地三件套（语义映射/manifest/导入器）
│
├── 【地图与资源】
│   ├── maps/              mapviewer 在线地图浏览器 + 地图审计脚本   :8899
│   │   └── mapedit/       地图编辑引擎（webclient 地图编辑功能的核心）
│   ├── web/               wilviewer 图库浏览器(:8765) + wiki 生成
│   ├── common/            zlsdk/wilsdk 解码基础库（Python 侧统一入口）
│   ├── item_icon_extractor/ C# zldecode 逐帧解码（BC7 兜底）
│   ├── resedit/           帧表公式提取器（frameformulas.py，CI 门禁）
│   ├── magiclab/          魔法特效实验室（174 技能回归画廊）
│   ├── lightlab/          光照/天气环境实验室
│   └── vision_item_desc/  视觉批量物品描述（grid 20 图/批 → gpt-5.6-luna）
│
├── 【Web 移植线】
│   ├── wsgateway/         WebSocket→TCP 透传网关（浏览器连真服）   :7001
│   ├── webclient/         静态世界测试台（627 地图漫游，不连服）   :8822
│   ├── webport/           网页客户端主线（零差异还原 Godot）       :8823
│   ├── webres/            Zl→WebP 资源瘦身管线（WebData 生产者）  :8821
│   └── portal/            工具门户（五工具健康检查）               :8840
│
├── 【UI 与客户端】
│   ├── uieditor/          Godot UI 所见即所得编辑器（F12 热重载） :8820
│   └── i18n/              ← 2026-08-17 新设：i18n 批量翻译 + NPC 链接中文化
│                           + zdocs 引用校验（自 zircon/scripts 迁入）
│
├── 【逆向研究（历史证据，一般不动）】
│   ├── reverse-engineering/  原版 EXE/UI/资源逆向 49 个脚本
│   ├── probes/              各类探针（AccountProbe/ClientProbe/...）
│   └── cache/               解码缓存（map_cn_full.json 等）
│
└── 顶层 *.py / *.sh        兼容转发 shim（真身在专题子目录，别删）
```

## 二、工具分类详解

### A. 数据库工具链（System.db 读写）

**System.db 不是 SQLite**——是 .NET BinaryFormatter 序列化，Python 打不开。
读取走 SystemDbProbe，写入走 DBImporter（或 dbeditor 的同步链）。

| 工具 | 类型 | 用途 | 启动/用法 |
|---|---|---|---|
| **dbeditor** | Web :8810 | System.db 在线编辑器。编辑只落 JSON 工作区（`workspace/*.json` + git 自动 commit），显式点「同步到数据库」才写库 | `cd Tools/dbeditor && ./run.sh`（自动 uv venv） |
| **dbviewer** | Web :8800 | System.db 只读浏览器（分类树/搜索/表关联跳转/地图联动），纯标准库 | `bash Tools/dbviewer/export.sh` 先导出到 /tmp/dbviewer_data，再 `python3 dbviewer.py --data /tmp/dbviewer_data --port 8800` |
| **SystemDbProbe** | C# CLI | db 静态导出：`--dump` 生成 markdown 文档，`--json` 每表一个 JSON（dbviewer/dbeditor 数据源头） | `dotnet run --project Tools/SystemDbProbe -- --json <输出目录>` |
| **DBImporter** | C# CLI | dbeditor 写回执行端：校验→备份→双库写→round-trip 读回 | 由 `dbeditor/sync.sh` 调用，一般不手跑 |
| **NpcMover** | C# CLI | NPC 坐标迁移到 EI 坐标系（294 NPC 审计表已入库） | `dotnet run --project Tools/NpcMover`（详见 audit-report.md） |
| **questdata** | Python ×3 | 任务落地：`gen_semantic_map.py`（中文名↔DB Index）/ `gen_quest_manifest.py`（341 任务逐环）/ `import_quest.py`（QuestInfo 入库，>50 条拒收防呆） | 各脚本独立跑，数据源 workspace JSON |

**dbeditor 缓冲区工作流（用户拍板，勿重开讨论）**：编辑 → 保存只落 JSON（可 diff/回滚）→ 用户显式点「同步到数据库」→ 引用校验 → 备份 → 服务端+客户端双库写入 → round-trip 验证 → 游戏内实测。**服务端在跑（:7000 监听）→ 同步被拒**。其他工具（mapviewer/questdata/webclient）把 workspace JSON 当第一数据源。

### B. 地图与资源工具

| 工具 | 类型 | 用途 | 启动/用法 |
|---|---|---|---|
| **mapviewer** | Web :8899 | 在线地图浏览器：瓦片渲染/NPC 标记/刷怪热力/任务叠加/连通图谱/等级总览/坐标拾取。六大增强 commit 73ff8ab | `mir3-venv/bin/python Tools/maps/mapviewer.py <Map目录> --data <Data目录>` |
| **maps/** 脚本组 | Python | map audit / catalog / minimap / 路线 / 一致性检查 | 各自独立跑 |
| **mapedit/** | Python 包 | 地图编辑引擎（webclient M9 NPC 拖拽编辑入库的核心） | 被 webclient serve.py 引用 |
| **wilviewer** | Web :8765 | WIL **和 .Zl** 图库浏览器（帧预览/实时解码） | `mir3-venv/bin/python Tools/web/wilviewer.py --root <客户端目录> --port 8765 |
| **zlsdk / wilsdk** | Python 库 | .Zl（ZL2/DXT/BC7）/ WIL 解码库，**Python 侧统一入口，勿手写解析** | `from Tools.common import zlsdk`（或直接 `import zlsdk`，参考 shim） |
| **zldecode** (item_icon_extractor) | C# CLI | .Zl 逐帧→BMP（BC7 走 C# 兜底），zlsdk 内部 subprocess 调用 | `zldecode <libPath> <outDir> [frames...]`；build: `dotnet build` |
| **resedit** | Python | 帧表公式提取器：从 Zircon C# 源码提取 FrameSet 分派表 → `ClientData/frame-formulas.json`（webport/wilviewer 共用）；`--check` 是 CI 门禁 | `python3 Tools/resedit/frameformulas.py [--check]` |
| **magiclab** | Node+Py | 魔法特效实验室：batch_run.mjs CDP 驱动采集 174 技能截图 → dHash 对比基线 → REGRESSION.md；merge_effects.py 合并特效 JSON | `node Tools/magiclab/batch_run.mjs [--baseline]` |
| **lightlab** | Python | 天气/环境素材提取（雪/雨/闪电/雾 WebP）+ 环境快照 → webclient /env 页面 | `python3 Tools/lightlab/build_env_assets.py` |
| **vision_item_desc** | Python | 视觉批量物品描述：20 图/格 → codex gpt-5.6-luna → 回写 item_catalog.json | `python3 Tools/vision_item_desc/batch_vision_desc.py`（resume-safe） |

### C. Web 移植线（工具也是移植本身）

| 工具 | 端口 | 用途 | 启动 |
|---|---|---|---|
| **wsgateway** | :7001 | WebSocket→TCP 透传网关（浏览器连 ServerCore :7000）。登录包字节级已验证；packet id 必须从部署 dll 反射导出 | `mir3-venv/bin/python wsgateway.py` |
| **webclient** | :8822 | **静态世界测试台**：627 地图漫游 + GM 满配玩家 + NPC/怪物摆放 + lab 页面（magic/light/env）。不连服。注意：不是最终客户端基础（用户明确批评过自创 UI） | `cd Tools/webclient && mir3-venv/bin/python serve.py` |
| **webport** | :8823 | **网页客户端主线**：零差异还原 Godot 行为，双 UI 参考模式（Zircon 主线=DXControl+Interface.Zl；EI 参考=webclient 风格，右上角切换）。注册→登录→选人→进比奇→走路全链路真服联调已通。审计报告 `docs/webport/audit/AUDIT_REPORT.md` 是零差异迭代唯一事实依据 | `cd Tools/webport && mir3-venv/bin/python serve.py` |
| **webres** | :8821 | Zl→WebP 资源瘦身管线（WebData 生产者，全量 8G→2.1G q90；Interface.Zl lossless 2.29x） | `webres.py` 构建 / `serve.py` 原型服务 |
| **portal** | :8840 | 工具门户：五工具健康检查/数据源概要/只读标识/移动端等级 | `python3 Tools/portal/portal.py` |

**WebData 磁盘预算红线 3G**（当前 2.2G）：全量渲染估算 22G，只能分级（126 核心图离线 + 其余按需）。素材包(.Zl/.map)一字节不动，Web 用的一切是 `Debug/Client/WebData/` 提取转换产物。

### D. UI 与客户端工具

| 工具 | 类型 | 用途 | 启动/用法 |
|---|---|---|---|
| **uieditor** | Web :8820 | Godot UI 所见即所得编辑器：`--ui-export` 导出控件树 → 浏览器拖拽改 → 保存 ui_overlay.json → 游戏内 F12 热重载（零重启迭代） | `cd Tools/uieditor && ./run.sh`（先在 GodotClient 加 `--ui-export` 生成 ui_tree.json） |
| **i18n/** | Python ×6 | **2026-08-17 自 zircon/scripts 迁入**：i18n 四件套（gen_keys 生成映射→auto_replace 自动替换→apply_keys 补键+替换→translate 批量翻译）+ translate_npc_links（NPC 对话链接中文化）+ verify_doc_citations（zdocs 23 篇文档的 路径:行号 引用校验） | 各脚本独立跑；脚本内部 `os.chdir('/home/tetsuya/development/zircon')`，翻译批次 TSV 在 `translations/` |

### E. 逆向研究（历史证据归档，一般不动）

| 目录 | 内容 |
|---|---|
| **reverse-engineering/** | 原版 EXE/UI/资源逆向 49 个脚本（disasm/extract/analyze/bind vtable 等），产物写入 `docs/research/ei-ui-layout/`。历史文档大量引用顶层 shim 路径，**shim 因此保留** |
| **probes/** | 独立探针：AccountProbe / ClientProbe / ServerProbe / MapFlagsProbe / CharacterEditor / BotProvisioner 等 |
| **cache/** | 解码缓存（map_cn_full.json / minimap 等），可重建 |

## 三、常驻服务速查（端口全景）

```
80    svc-dashboard（运维面板，非本目录）        7000  ServerCore 游戏服（zircon）
7001  wsgateway    WebSocket 透传               8765  wilviewer    图库浏览
8800  dbviewer     DB 只读浏览                  8810  dbeditor     DB 在线编辑
8820  uieditor     UI 编辑器                    8821  webres       资源管线
8822  webclient    世界测试台                   8823  webport      网页客户端主线
8840  portal      工具门户                      8899  mapviewer    地图浏览
```

启动检查：`ss -tlnp | grep -E ':(7001|8765|8800|8810|8820|8821|8822|8823|8840|8899) '`
**改绑定前先查占用**；重启服务必须 kill 旧 pid 再起（改后端代码 ≠ 生效是高频坑）。

## 四、一次性脚本 vs 常驻服务

- **常驻服务**（§三端口表）用各自 run.sh / serve.py 启动，可长期挂着。
- **一次性脚本**（maps/ 脚本组、questdata 三件套、i18n、resedit、magiclab 采集）跑完即出产物，
  产物入仓库（docs/ 或 ClientData/）。
- **兼容 shim**：`Tools/` 顶层 76 个 .py + 3 个 .sh/.cmd 全是转发入口（`runpy`/`exec` 到
  专题子目录真身）。删 shim 会让历史文档里的命令失效——**别删**。

## 四b、zdocs 文档库（知识型"工具"）

`zircon/docs/codebase/` 23 篇原版代码深度文档（战斗公式/怪物 AI/协议全链路/行会战/掉落/
基础设施），每篇含 路径:行号 引用+伪代码+Godot 对比列，`_index.md` 是索引。
**移植任何功能前先查这里**，别现翻源码。引用有效性用
`Tools/i18n/verify_doc_citations.py` 校验（注意其 ROOT 指向 zircon 仓库）。

## 五、写库纪律（违反毁数据，无例外）

1. **服务端在跑（:7000 监听）→ 绝不写 System.db**。dbeditor 同步会双端校验拒绝。
2. 流程固定：停服 → 备份双库 → 干跑 → 测试副本 → round-trip → 写真库 → **双库同步**
   （服务端 `Debug/ServerCore/Database/System.db` 写完必须 `cp` 到 `Debug/Client/Data/System.db`）→
   重启 → 游戏内实测。
3. 优先走 dbeditor 缓冲区工作流，**不要绕过缓冲区直写 .db**。
4. MirDB 全量重写（无增量）；`Session.Initialize` 必须传 **LibraryCore + ServerLibrary 两个程序集**
   （缺一个 GetCollection 静默返回 0 行）。
5. Users.db = 玩家账号，**绝不写**。

## 六、已知坑（每条都真实踩过）

1. **MirDB Session 单程序集 = 静默 0 表**：必须双程序集，root 用绝对路径带尾斜杠。
2. **改后端代码 ≠ 生效**：先 `ss -tlnp` 查 pid → kill → 重启 → curl 验证新字段。
3. **手机/异端改静态 JS/CSS 必须 bump `?v=N`**：否则浏览器缓存旧 JS。
4. **Vue3 异步 fetch 帧号不触发重渲染**：计算字段必须后端列表接口同步注入（__zh/__frame 模式）。
5. **mapviewer 视口锚定陷阱**：异步 fetch 完成前跑的锚定会被覆盖；验收必须实际滚动截图。
6. **wsgateway packet id 必须从部署 dll 反射导出**（packet_id_dump/），手算 Packet.cs 会漂移。
7. **WebData 预算红线 3G**：serve.py 30s 磁盘守卫超限返回 507。
8. **路径大小写**：zircon 目录是小写，工具硬编码大写 Zircon 会静默失败。
9. **GB18030**：NAS/Mud3 中文文本配置不是 UTF-8，直接 open().read() 会乱码。
10. **顶层 shim 别删**：历史研究文档（docs/research/ei-ui-layout/ 等）大量引用顶层路径。
11. **共享浏览器守护进程会被并行 agent 抢占**：截图走命名会话 + cdp captureScreenshot 自写路径。
12. **验收 Web UI 不能只 curl**：无头浏览器双视口（1440x900 / 390x844）逐页截图 + console
    pageerror 清零才算过。

## 七、与 zircon 仓库的协作关系

- `Mir3-Research/LibraryCore` / `ServerLibrary` 是 **symlink → zircon 同名目录**：C# 工具直接
  复用游戏模型类编译；zircon 代码变更会传导到本仓库工具。
- 工具运行时数据（System.db / 图库 / WebData）都在 zircon 的 `Debug/` 下。
- 改 zircon C# 后必须重新 `dotnet build`（服务端还要 `-o Debug/ServerExe` 覆盖运行目录）。
- zircon 仓库内部保留的兼容转发：`zircon/scripts/*.py` → `Tools/i18n/`（2026-08-17 迁移）。

## 八、新工具入驻规范

1. 新工具必须放明确的专题子目录，输入/输出/依赖/运行命令写进所在目录 README.md。
2. 不要把生成的 JSON/PNG/缓存/反编译中间文件散落在源码目录——产物入 docs/ 或 cache/。
3. 顶层同名文件只能是兼容转发入口（shim 模板见现有文件）。
4. 常驻服务选端口前先 `ss -tlnp` 查占用，并更新本文档 §三端口表。
5. 涉及写 System.db 的工具必须走 §五纪律。
