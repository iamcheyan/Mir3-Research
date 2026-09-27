# 交接：Mir3 Preview 源码全量精读 Goal（2026-09-27 暂停交接）

> **本文件用途**：原「全量源码精读」goal 已被**用户主动暂停**，交接给下一位 agent 继续。
> 本文件**自包含** —— 读完这一篇即可接管，不必先看别的文档（但恢复阅读时**必须**
> 先读 §2 的「必读前置」）。
>
> **⚠️ 重要诚告**：本文件由**暂停时的会话**（不是原 goal 会话本体）撰写。
> 原 goal 是 82 机器上的 omp goal 会话，本机（`192.168.3.82`→ 实际为
> `/home/tetsuya`）的 DimAgent 会话代它执行了 Round 810–833。
> 凡本文件**无法从仓库产物确证**的内容，一律标 **`待核实`** 或 **`未知`**，
> **不臆测**。§9 集中列出所有无法确证项。

---

## 1. 原 Goal / Session 状态

| 项 | 值 |
|---|---|
| **状态** | **已暂停（paused by user）** —— 2026-09-27，用户明确要求「先交接并 push，之后由新的 agent 继续阅读」 |
| **goal 文档 1** | `MIR3_SOURCE_DEEP_READ_GOAL_2026-09-26.md` |
| **goal 文档 2（收尾版，权威）** | `MIR3_SOURCE_DEEP_READ_CONTINUATION_GOAL_2026-09-26.md` |
| **goal 文档位置** | ⚠️ **不在仓库内**，在 `/home/tetsuya/development/`（仓库的**上一级**目录） |
| **goal 文档是否提交过** | ❌ **从未提交**（`git log --all -- 'MIR3_SOURCE_DEEP_READ*'` 为空，`.gitignore` 未忽略，untracked 里也没有） |
| **工作目录** | `/home/tetsuya/development/Mir3-Research` |
| **分支** | `ei-ui-audit-2026-09-24`（远端 `origin` = `git@github.com:iamcheyan/Mir3-Research.git`） |
| **本次执行会话** | DimAgent 会话，工作范围 Round 810–833（另有他人并行 goal 做了 Round 802–809 与网络检索审计） |
| **goal 是否被 watchdog 接管** | ❓ **未知** —— 原 goal 是 82 机器上的 tmux+omp+watchdog 体系（见 `docs/PROJECT_MENTAL_MODEL.md` §七）。本机 `~/.omp/logs/goal-completed.log` 里**没有**本精读 goal 的记录，只有 4 个 `status=complete` 的会话（时间戳 2026-09-26 15:00/16:25/17:30/18:30，workdir 均为 `Mir3-Research`）。**无法确证这些是否就是本 goal 的会话**，也无法确证 watchdog 数组行是否已移除。恢复前请用 `crontab -l` 与 `~/.hermes/scripts/mir3-goal-watchdog.sh` 的 `GOALS` 数组核对。 |

### 1.1 用户对原 goal 的原始要求（摘自 goal 文档，逐字）

> 继续把 Mir3 Preview 源码全部读完。不要因为阶段 0–6 已完成、报告已经有总结、
> 或者一轮任务完成就停下来。可以连续运行 20–30 小时。只有真实文件/资源/源码包缺失、
> 无法访问或确实需要用户提供外部材料时，才把单项标为 blocked；其余所有可读源码必须
> 继续精读、写文档、做与 EI 3.0 反编译证据的差异对照。

**注意**：用户已**暂停**此 goal。下一位 agent **不要**在没有新指令的情况下自行恢复长跑。

---

## 2. 必读前置（恢复阅读前按顺序读）

| # | 文件 | 为什么要读 |
|---|---|---|
| 1 | `AGENTS.md`（仓库根） | 写库纪律、端口、NAS 环境变量、已知坑 |
| 2 | `docs/PROJECT_MENTAL_MODEL.md`（尤其 **§十二**） | 项目全貌 + Preview 源码精读的定位与结论 |
| 3 | `docs/source-vs-reverse/README.md` | **差异总表 D0–D13**、两份证据的身份对照（**§0** 的三条硬约束） |
| 4 | `docs/source-vs-reverse/FINAL_REPORT.md` | 上一轮收尾报告（**注意：其统计数字已过时**，见 §3.1 说明） |
| 5 | `docs/research/ei-ui-layout/RESEARCH_LOG.md`（**尾部 Round 826–833**） | 逐轮工作日志，**总 11,801 行**，是本 goal 最细的过程记录 |
| 6 | `docs/source-vs-reverse/coverage-ledger.tsv` | **393 个源码文件的销账台账**（下任 agent 的工作清单本体） |
| 7 | `docs/source-vs-reverse/verification.md` | 9 项**明确未验证**清单 |

### 2.1 ⚠️ 三条硬约束（不遵守必然出错）

1. **`Source/**` 是混合编码**。以 CP949 韩文为主，**混有 GB18030 中文注释**
   （实例：`Grobal2.pas:419` 的 `c9cf` 同时是合法 CP949 双字节）。
   **整文件一刀切判定必然出错**。必须用 `Tools/source-read/read_src.py`（逐行计分 + 混合行重解）。
2. **`rg`/`grep` 对中文/韩文关键字直接失效**（编码不匹配）。
   要搜中文/韩文内容必须走 `read_src.py`。
3. **`.pas` 里没有窗口几何** —— 全在二进制 `.dfm`，且**不在偏移 0**（前 17 字节元信息头）。
   用 `Tools/source-read/dfm_parse.py`。

`Mud3-Config/**` 是 **GB18030**，读法：`bytes → decode('gb18030')`。

---

## 3. 已覆盖内容及证据位置

### 3.1 统计数字（两个数字不同，务必用后者）

| 来源 | covered | partial | excluded | pending | 说明 |
|---|---:|---:|---:|---:|---|
| `FINAL_REPORT.md`（2026-09-26 早） | 27 / 29,884 行 | 21 / 99,738 | 43 / 60,230 | 302 / 125,472 | **已过时** |
| **`coverage-ledger.tsv`（当前，权威）** | **33 / 42,730 行** | **23 / 100,421** | 43 / 60,230 | **294 / 111,943** | ✅ **以此为准** |

- **总规模**：393 文件 / 315,324 行
- **已读覆盖（covered + partial）**：**56 文件 / 143,151 行 = 45.4%**
- **明确排除**：43 文件 / 60,230 行 = 19.1%（全部是 `Source/Tools/ImageEditor/Plug/` 第三方组件）
- **剩余待读**：**294 文件 / 111,943 行 = 35.5%**

复现命令：`python3 Tools/source-read/ledger.py --summary`

> ⚠️ **2026-09-27 已修复的事故**：改 note 时曾把 `LocalDB.pas` / `ObjNpc.pas`
> 从 `covered` **误降为 `partial`**（covered 42,730 → 33,672）。
> 已修复并给 `ledger.py` 加了**防降级守卫**（以 git HEAD 为基线，`covered` 不可被
> 静默降级，需显式 `--allow-downgrade`）。**下任 agent 改台账时注意：note 要合并而非覆盖。**

### 3.2 本 goal 的提交（Round 810–833 部分）

`git log --oneline --grep='全量精读续'` 共 **13 个提交**。最近 8 个：

```
835bad6b 全量精读续: NPC 脚本语言全表（128 条命令）
746a162b 全量精读续: 物品升级概率系统（CalcUpgradeProbability）
8653129a 全量精读续: TAnimal 怪物 AI 实现 + TUserHuman 对象内部机制
0fadd312 全量精读续: ObjBase.pas 全量 API 地图
7a79c518 全量精读续: Castle / TagSystem / Relationship / Event
ea670fa2 全量精读续: SQL 表定义（System.db 上游）
3447f091 全量精读续: Guild.pas 常量与数据模型
03029684 全量精读续: 客户端渲染类层次 + 特效运行时（Round 826）
```

### 3.3 产出文档与证据位置

**差异/精读文档**（`docs/source-vs-reverse/`，共 33 个文件）：

| 文件 | 内容 |
|---|---|
| `README.md` | **差异总表 D0–D13** + 两份证据身份对照 + 三条硬约束 |
| `protocol.md` / `protocol-constants.tsv` | 协议 opcode（**474 常量**全表） |
| `wire-format.md` | `TDefaultMessage` / 6bit 线格式 / `Etc` 防外挂 |
| `client.md` | 客户端骨架与场景 |
| `client-windows.md` / `client-windows.tsv` | 窗口与控件（352 条声明） |
| `client-controls.md` | DWinCtl 输入优先级 / 像素级命中 / `TClickSound` |
| `client-libraries.md` | **四种容器格式全部解出**（`.Lib` DES / `.wil` WEMADE / `.Zl` / Mir2 压缩） |
| `client-internals.md` | `PlayScn.pas` 五层 Surface 管线 + 光照 |
| `client-rendering.md` / `client-render-classes.tsv` | 60 个渲染类 |
| `client-runtime-layout.tsv` | 运行时布局 |
| `server.md` | **服务端主文档（94 KB，§1–§18）** —— 含 ObjBase API 地图、TUserHuman 内部机制、NPC 脚本语言全表 |
| `config.md` / `config-parsers.tsv` | 19 个配置解析器 |
| `magic.md` / `magic-*.tsv` | 技能系统与实现 |
| `monsters.md` / `monster-classes.tsv` | **怪物 AI**（`TAnimal` 贪心步进寻路，非 A*） |
| `items-systems.md` | 物品/行会/城堡/邮件/恋人/事件/**升级概率表** |
| `tools-and-servers.md` / `sql-tables.tsv` | 工具与服务器 + **SQL 表定义 11 表 165 字段** |
| `npc-script-commands.tsv` | **NPC 脚本语言 128 条命令**（53 条件 + 75 动作） |
| `gm-commands.tsv` | GM 命令表 |
| `quest-opcodes.tsv` / `quest-macros-coverage.tsv` | 任务 opcode 与宏覆盖 |
| `npc-say-macros.tsv` | NPC 对话宏 |
| `verification.md` | **独立验证记录 + 9 项明确未验证清单** |
| `FINAL_REPORT.md` | 上一轮收尾报告（统计已过时） |
| `coverage-ledger.tsv` | **销账台账（工作清单本体）** |

**工具**（`Tools/source-read/`，29 个脚本）：`read_src.py`（编码解码，**核心**）、
`dfm_parse.py`、`ledger.py`（台账）、`verify_all.py`、`edcode.py`、`wemade_decrypt.py`、
以及 15 个 `extract_*.py` 提取器与 4 个 `verify_*.py` 校验器。

**研究日志**：`docs/research/ei-ui-layout/RESEARCH_LOG.md`（11,801 行，Round 802–833）

### 3.4 本轮已闭合的重要结论（可直接引用，不必重做）

| 结论 | 位置 |
|---|---|
| **客户端是 800×600**（`ClMain.pas:25-26`），DFM 的 1095×975 只是编辑期画布 | `README.md` §0 |
| **`UNITX=48` / `UNITY=32`** 核实（`Grobal2.pas:1214-1215`）→ 印证 mapviewer 坐标换算 | `monsters.md` / `client-rendering.md` |
| **协议常量 474 个**（非 392），31 个跨前缀重复值 | `protocol-constants.tsv` |
| `0x409` = `CM_WANTMINIMAP`（3000ms 冷却逐字节一致，闭合原版悬案） | `PROJECT_MENTAL_MODEL.md` §12.2 |
| `0x418`/`0x419` = `CM_FRIEND_EDIT`/`CM_FRIEND_LIST`（**业务名修正**） | 同上 |
| **WEMADE 加密已破解**（`F0 39 AB 8E` 种子，`ProcLen` = 文件长 −8 大端） | `verification.md` |
| **`.Lib` 用 DES 加密**（`lom2com`，与 WEMADE 是**不同机制**） | `client-libraries.md` §8 |
| **四种容器格式全部解出**（`.Lib`/`.wil`/`.Zl`/Mir2 压缩） | `client-libraries.md` §8–10 |
| **`AxeMon.pas`（客户端）≠ `GameServer/ObjAxeMon.pas`** | `client-rendering.md` |
| **`astar.h` 是死代码**（从未被 `#include`）；真寻路是**贪心步进** | `monsters.md` §9 |
| **`Mission.pas` 是 63 行空壳**；真任务逻辑在 `ObjNpc.pas` 的 `TQuestRecord` | `PROJECT_MENTAL_MODEL.md` §12.5 |
| **`{NAME}` 类脚本宏 43 个里 42 个零实现**（只有 `$USERNAME` 存在） | `quest-macros-coverage.tsv` |
| **NPC 脚本命令 128 条**（53 条件 + 75 动作），**无重复值但大量 ID 空缺** | `npc-script-commands.tsv` |
| **`ApplyLightMap` 完全是 no-op**（绘制调用被注释） | `client-internals.md` §7 |
| **`TAnimal` 是怪物 AI 层**，玩家类 `TUserHuman` **继承自怪物类** | `server.md` §16 |
| **物品升级概率表**（11 档，`iBase=10000`），含**两处未回退的临时值** | `items-systems.md` §16 |
| **`System.db` 上游 SQL 11 表 165 字段**；七元素体系（`ATOM` + 火/冰/雷/风/圣/暗/幻） | `sql-tables.tsv` |
| 行会战有效期 **3 小时**；城堡战**每日 20:00 检查 / 持续 3 小时**；税率 **10%**（2003-07-15 从 5% 上调） | `items-systems.md` §12 |

---

## 4. 尚未阅读 / 待办（逐项列出）

> **数据来源**：`docs/source-vs-reverse/coverage-ledger.tsv`（393 行逐一登记）。
> 下面的每一项都对应台账里的真实 `status`，**不是推测**。

### 4.0 剩余量按目录分布（pending = 294 文件 / 111,943 行）

| 区域 | pending 文件 | pending 行数 |
|---|---:|---:|
| `Source/Tools/ImageEditor/`（**非 Plug**） | 25 | **34,683** |
| **`Source/DataBaseServer/`** | **107** | **19,119** |
| **`Source/LoginServer/`** | **90** | **17,286** |
| `Source/Tools/MapEdit/` | 23 | 16,341 |
| `Source/GameServer/` | 20 | 9,495 |
| `Source/Common/` | 10 | 8,273 |
| `Source/Client/` | 19 | 6,746 |

> **判断**：`LoginServer/`(90) + `DataBaseServer/`(107) = **197 文件但仍只占 36,405 行**
> —— 多为小文件（平均 ~183 行），**适合批量扫读**，是本 goal 收尾的高性价比区。

### 4.1 A. GameServer 核心对象与世界（goal 清单 §A）

| 项 | 状态 | 说明 |
|---|---|---|
| `ObjBase.pas`（31,768 行）方法实现 | **partial** | ✅ 已读：接口段 3 类 526 方法、`TAnimal` AI、`TUserHuman` 内部机制、升级概率。**❌ 未读：实现主体 `:1411-31768`（约 30,357 行）** —— **最大单块待办** |
| `ObjNpc.pas`（6,409 行）完整实现 | **covered** | 五层任务模型 / `CheckQuestCondition` / `53+75` opcode / `GotoQuest` / `CheckNpcSayCommand` 28 宏 + Round 833 四级嵌套结构与四段式脚本。**`TMerchant` 实现待读**（台账 note 已标） |
| `TQuestRequire` / 任务数据结构 | **covered** | `ObjNpc.pas:41-89` |
| `Envir.pas`（1,540 行）剩余方法 | **covered** | 台账标 Round 812 已读完剩余方法 |
| `svMain.pas`（1,880 行）启动流程 | **covered** | — |

### 4.2 B. 配置解析与数据落地（goal 清单 §B）

| 项 | 状态 | 说明 |
|---|---|---|
| 19 个配置解析器（`MonGen.txt`/`Merchant.txt`/`Npcs.txt`/`GuardList.txt`/`MapInfo.txt`/`MiniMap.txt`/`StartPoint.txt`/`SafePoint.txt`/`MakeItem.txt`/`DecoItem.txt`/`DragonItem.txt`/`MapQuest.txt`/`StartupQuest.txt` 等） | **covered** | `config.md` + `config-parsers.tsv`（Round 809/811/812/813） |
| `Mud3-Config/Envir3/` 边界 | **covered** | 已确认「源码 grep 0 命中」的边界 |
| **`Envir3/QuestDiary/` 语法与 `CheckNpcSayCommand` 对照** | ⚠️ **待核实** | 台账中未见专门行；`config.md` 与 `quest-macros-coverage.tsv` 有部分相关内容，**是否逐文件登记 blocked 需下任 agent 核实** |

### 4.3 C. 战斗、技能、怪物 AI（goal 清单 §C）

| 项 | 状态 | 说明 |
|---|---|---|
| `Magic.pas`（1,756 行） | **covered** | ✅ **已核实完全覆盖**：`implementation` 段的
`TMagicManager.Mag*` 实现函数共 **16 个，`magic-implementations.tsv` 已登记全部 16 个，
未读 0 个**（复现：见 §9 验证命令）。另有 3 个非 `Mag*` 的 `TMagicManager` 函数。详见 `magic.md` |
| `ObjMon.pas`（3,097 行）/ `ObjMon2.pas`（1,817）/ `ObjMon3.pas`（3,197） | **partial** | 三个文件均在台账且为 `partial`。`monsters.md` 已含 `TAnimal` 基类骨架（Round 831）。**❌ 具体怪物 AI 实现待读** —— 需查台账 note 列确认已读区段 |
| `_Oranze Library/astar.h` 与实际调用点 | **已闭合** | 结论：**死代码**，从未 `#include`（`monsters.md` §9） |
| `itmunit.pas`（897 行） | **partial** | — |
| `UserSystem.pas`（153 行） | **pending** | 小文件 |
| `UserMgr.pas`（726 行） | **covered** | — |
| `UsrEngn.pas`（3,696 行） | **covered** | — |
| **`Guild.pas`（3,600 行）** | **partial** | ✅ 常量全表 + `TGuild` 数据模型 + 两条业务规则。**❌ 各方法实现主体待读** |
| **`Castle.pas`（1,241 行）** | **partial** | ✅ 常量 + 税率 + 攻城时序 + 布防。**❌ 实现主体待读** |
| **`DragonSystem.pas`（604 行）** | **partial** | 细节待核 |
| **`Event.pas`（323 行）** | **partial** | ✅ 基类字段。**❌ `EventType` 取值表、派生类待读** |
| **`TagSystem.pas`（1,678 行）** | **partial** | ✅ 常量 + `TTagInfo` 四态 + 分页握手。**❌ `Add`/`Delete`/`SetInfo` 实现待读** |
| **`Relationship.pas`（471 行）** | **partial** | ✅ `MAX_LOVERCOUNT=1` + `TRelationShipInfo`。**❌ 其余类待读** |
| `FriendSystem.pas`（988 行） | **covered** | — |

> ⚠️ goal 文档 §C.15 明确要求「每个文件**至少读完实现主链，不得只读声明**」。
> **上表 5 个 `partial` 的系统（Guild/Castle/Event/TagSystem/Relationship）
> 目前都只读了声明与常量，未满足该要求** —— 这是明确的遗留缺口。

### 4.4 D. 客户端剩余实现（goal 清单 §D）

| 项 | 状态 | 说明 |
|---|---|---|
| **`FState.pas`（14,853 行）** | **partial** | ✅ 窗口声明/帧号。**❌ 剩余主体实现待读** |
| **`DWinCtl.pas`（7,804 行）** | **partial** | ✅ 输入优先级/像素命中/`TClickSound`/`TDButton` 四态/`TDGrid`。**❌ pressed/hover/disabled、移动/关闭、z 序、IME 派发待读** |
| `PlayScn.pas`（3,043 行） | **covered** | 五层 Surface 管线 + 光照 |
| **`Actor.pas`（4,743 行）** | **partial** | 细节待核 |
| **`AxeMon.pas`（4,217 行）** | **partial** | ✅ 35 个类清单。**❌ 各类 `DrawEff`/`Run` 实现待读** |
| **`HerbActor.pas`（993 行）** | **partial** | ✅ 10 个类清单。**❌ 实现待读** |
| **`magiceff.pas`（1,621 行）** | **partial** | ✅ 基类 + `TMagicEff` 运行时。**❌ 其余 12 个特效类实现待读** |
| `wmM2Zip.pas`（302 行） | **covered** | — |
| `wmMyImage.pas`（741 行） | **covered** | — |
| **`wmUtil.pas`（4,497 行）** | **partial** | ✅ 6 函数 + ZIP 双路径。**❌ 4,200 行查找表与 `Move` 重载待读** |
| `uWilFile.pas`（582 行） | **covered** | 57 路径加载逻辑 |

### 4.5 E. 工具、数据库、登录、GM 命令（goal 清单 §E）

| 项 | 状态 | 说明 |
|---|---|---|
| **`Source/Tools/MapEdit/`（23 文件 / 16,341 行）** | **pending（全部）** | `MapEdit.dpr`、`Wil/WIL.pas`、`glight.pas` 等**一行未读** |
| **`Source/Tools/ImageEditor/`（非 Plug，25 文件 / 34,683 行）** | **pending（全部）** | 最大 pending 块。Plug 已排除（43 文件 / 60,230 行） |
| **`Source/LoginServer/`（90 文件 / 17,286 行）** | **pending（全部）** | 登录服务实现链 |
| **`Source/DataBaseServer/`（107 文件 / 19,119 行）** | **绝大部分 pending** | ✅ 仅 `DBSvr/tablesdefine.cpp`(covered) 与 `tablesdefine.h`(pending)；**`tablesdefine.cpp` 已提取 11 表 165 字段** |
| `CmdMgr.pas`（629 行）GM 命令表 | **covered** | `gm-commands.tsv` |
| **`CM_ADDNEWUSER` / `CM_CHANGEPASSWORD` / `CM_UPDATEUSER` 接收端** | ⚠️ **待核实** | goal 要求「源码包里找不到就明确记录『源码包缺失』，不要猜接收端」。**是否已有该记录，台账/文档中未确证** |
| `Source/Common/`（10 文件 / 8,273 行 pending） | **pending** | 细节待核（`Grobal2.pas` 已 covered） |
| `Source/Client/`（19 文件 / 6,746 行 pending） | **pending** | 未逐个列出 |

### 4.6 Blocked（**真实缺失，不可伪造**）

| 项 | 原因 |
|---|---|
| `Mir3 Preview Version.rar`（53 MB 原始包） | **本机已不在**（`PROJECT_MENTAL_MODEL.md` §12.7） |
| `BitChange.inc`（479 KB，A1R5G5B5 色转换 LUT，`WIL.pas:9` 有 `{$INCLUDE}`） | 同上，被排除 |
| `Mir3.exe`、`magic.dat`、`SQL/`（System.db 上游） | 同上，被排除 |
| 真实 `.Lib` / `.WZX` / `.Zl` 文件的运行期验证 | **本机没有这些文件** |
| `Tools/common/zlsdk.py` 的正向验证 | 同上（无 `.Zl` 可验） |

> 取回方法见 `reference/mir3-source/README.md` §5。

---

## 5. 阅读方法与约束

### 5.1 工具用法

```bash
# 读源码（编码自动处理，必须用它读中文/韩文）
python3 Tools/source-read/read_src.py show Source/GameServer/ObjBase.pas --start 305 --end 400

# 台账统计
python3 Tools/source-read/ledger.py --summary

# 独立验证（协议常量 / 线格式 / opcode / 台账 / Python 语法）
python3 Tools/source-read/verify_all.py

# DFM 几何解析
python3 Tools/source-read/dfm_parse.py <file.dfm>
```

**验证 Magic 覆盖率**（2026-09-27 用它确证 `Magic.pas` 已全覆盖）：

```bash
python3 - <<'EOF'
import re, sys, csv
sys.path.insert(0, 'Tools/source-read')
import read_src
t, _ = read_src.read_text('reference/mir3-source/Source/GameServer/Magic.pas')
lines = t.split('\n')
impl = next(i for i, l in enumerate(lines, 1) if l.strip().lower() == 'implementation')
ti = set(re.findall(r'^\s*function\s+TMagicManager\.(Mag\w+)', '\n'.join(lines[impl:]), re.M))
done = {r['func'] for r in csv.DictReader(
    open('docs/source-vs-reverse/magic-implementations.tsv', encoding='utf-8'), delimiter='\t')}
print('实现', len(ti), '已登记', len(done), '未读', sorted(ti - done))
EOF
```

> ⚠️ **注意**：实现段的方法名是 **`TMagicManager.MagXxx`**（带类名限定），
> 不是裸的 `function MagXxx`。用裸模式搜会得到 0 结果（**本会话踩过**）。

**每次新增提取器**：放进 `Tools/source-read/extract_*.py`，产出 `docs/source-vs-reverse/*.tsv`。

### 5.2 硬约束（来自 goal 文档 + AGENTS.md）

- ✅ **只读研究**：不改 Zircon C#、不写 `System.db`/`Users.db`/`.map`
- ✅ **不停 7000 端口服务**
- ✅ **不覆盖其他会话的 WIP**（改动只允许在本 goal 的 `docs/source-vs-reverse/`、
  `Tools/source-read/` 与 `RESEARCH_LOG.md`）
- ✅ **提交前逐文件检查**（`git add <显式路径>`，**绝不用 `git add -A`/`.`**）
- ✅ **中文提交信息**；提交信息里的反引号/`$` 会破坏 zsh —— **写进
  `/tmp/commit_msg.txt` 再 `git commit -F`**
- ✅ 保持模型不切换、不启动额外代理、不付费调用

### 5.3 差异对照纪律（goal 文档 §「全量完成判定」第 4 条）

**每条差异必须有四要素**：`primary`（原版证据） / `source`（源码证据） /
`difference`（差异） / `conclusion`（如何处理）。

**证据等级**：源码 = `secondary-source`，**不得覆盖**原版 `primary-static` 结论。

### 5.4 每个文件的交付格式（goal 文档 §「每个文件的交付格式」）

不写「已阅读」。至少落盘：文件与行范围 / 职责入口 / 关键类型与字段语义 /
调用链·状态流·数据流 / 与 EI primary-static 对照 / 与 Zircon 对照 /
一致·差异·版本边界 / 未验证项与原因 / 可复用结论与对现有工具的影响。

**大型文件按区段推进，每段完成即写文档 + `RESEARCH_LOG`**，不要只在最终总结里出现。

### 5.5 每轮收尾动作（本会话固定流程，建议沿用）

1. 写文档（`docs/source-vs-reverse/<域>.md` 追加 §N）
2. 追加 `RESEARCH_LOG.md` 的一节（`## Round NNN (全量精读续) — 日期：标题`）
3. 更新 `coverage-ledger.tsv`（**⚠️ note 要合并旧成果，不可覆盖；`covered` 不可降级**）
4. `git diff --check` + `python3 -c "import ast;ast.parse(...)"`
5. `git add <显式路径>` → `git commit -F /tmp/commit_msg.txt`
6. `git push origin ei-ui-audit-2026-09-24`

---

## 6. 下一位 agent 的可执行续读步骤

### 第 0 步：确认 Goal 是否真的要继续

**用户已暂停本 goal。** 恢复前请向用户确认。若用户要求继续，按下面执行。

### 第 1 步：环境与状态检查（约 5 分钟）

```bash
cd /home/tetsuya/development/Mir3-Research
git status --short --branch          # 确认分支与领先/落后
git log --oneline -8
python3 Tools/source-read/ledger.py --summary
python3 Tools/source-read/verify_all.py
```

**⚠️ 工作区有 6 处**未提交改动**（见 §8），**属于其他 goal 的 WIP，不要
`git add`、不要 commit、不要丢弃**。用 `git status` 确认它们仍在。

### 第 2 步：按性价比排序的续读队列（建议）

> 排序理由：**行数收益 / 完成度缺口**。可按用户偏好调整。

| 优先 | 目标 | 预计量 | 为什么先做 |
|---:|---|---:|---|
| **P0** | 5 个 `partial` 系统的**实现主链**：`Guild` / `Castle` / `TagSystem` / `Relationship` / `Event` | ~7,300 行 | goal §C.15 **明确要求「不得只读声明」**，现只读声明 → **直接违规项** |
| **P1** | `LoginServer/`(90) + `DataBaseServer/`(107) 批量扫读 | 197 文件 / 36,405 行 | **文件数最多**，占 pending 文件 67%，平均 ~183 行/文件，适合批量 |
| **P2** | `Source/Tools/ImageEditor/`（非 Plug） | 25 文件 / **34,683 行** | **单块行数最大**；需先区分主工程与第三方 |
| **P3** | `Source/Tools/MapEdit/` | 23 文件 / 16,341 行 | goal §E.24 点名（`MapEdit.dpr`/`Wil/WIL.pas`/`glight.pas`） |
| **P4** | `ObjBase.pas` 实现主体 `:1411-31768` | ~30,357 行 | **单文件最大**；按协议域分批（建议：物品族 → 消息族 → 移动族 → 战斗族） |
| **P5** | 客户端 6 个 `partial` 补完：`FState`(14,853) / `DWinCtl`(7,804) / `AxeMon`(4,217) / `Actor`(4,743) / `magiceff`(1,621) / `HerbActor`(993) | ~34,231 行 | goal §D 点名 |
| **P6** | `Source/Client/` 19 文件 / `Source/Common/` 10 文件 pending | 15,019 行 | 扫尾 |

### 第 3 步：每轮执行循环

1. 从队列取**一个**项 → `read_src.py` 读 → 提取器（如需）
2. 写 `docs/source-vs-reverse/<域>.md` 新 §N（四要素对照齐全）
3. 追加 `RESEARCH_LOG.md` Round NNN 一节
4. 更新 `coverage-ledger.tsv`（**合并 note，不降级 `covered`**）
5. 验证 + 提交 + push（§5.5 流程）

### 第 4 步：无法确定时的恢复线索

| 想找什么 | 去哪找 |
|---|---|
| 某文件**已读到哪** | `coverage-ledger.tsv` 的 note 列 + `RESEARCH_LOG.md` grep 文件名 |
| 某结论**的证据** | `docs/source-vs-reverse/*.md`，用 `grep -n '<关键字>'` |
| goal **原始要求** | `/home/tetsuya/development/MIR3_SOURCE_DEEP_READ_CONTINUATION_GOAL_2026-09-26.md`（**不在仓库**） |
| 原 goal **会话本体** | `~/.omp/logs/goal-completed.log`（4 条 `workdir=Mir3-Research` 记录）+ `~/.omp/agent/sessions/` 下的 jsonl |
| 某提取器**怎么用** | `Tools/source-read/extract_*.py` 的 docstring |

---

## 7. 验收清单（下任 agent 交付前逐项打勾）

### 7.1 Goal 文档的「全量完成判定」9 条（原样抄录）

- [ ] **1.** A–E 每个可读文件都有 `read/covered` 记录
- [ ] **2.** 每个「未读」行都有明确原因：已读 / 第三方排除 / 文件不存在 / 编码·资源阻塞
- [ ] **3.** `server.md` / `client.md` / `config.md` / `README.md` / `verification.md`
      的待办表**被更新为真实状态**
- [ ] **4.** 新增差异每条都有 `primary` / `source` / `difference` / `conclusion` 四要素
- [ ] **5.** 运行独立验证（协议、格式、统计、引用路径）并**记录真实输出**
- [ ] **6.** 运行 `git diff --check` 与 Python syntax checks
- [ ] **7.** 提交**逐批中文提交**并 push
- [ ] **8.** 最终报告列出：已读文件数/总数、行数统计、完成·排除·blocked 表、
      所有未验证项、对 `Tools/questdata`·`mapviewer`·`Zircon` 的影响
- [ ] **9.** **不因「阶段」完成而停**，只有全量完成或**每个剩余文件都有明确 blocked 证据**才能停

### 7.2 每轮自检（每轮必做）

- [ ] 文档是真的写清了**职责 + 调用链 + 四要素对照**，不是「已阅读」四个字
- [ ] `coverage-ledger.tsv` 的 note **合并**旧成果（不是覆盖）
- [ ] `covered` 状态**未被降级**（若有告警，检查是否误改）
- [ ] `RESEARCH_LOG.md` 已追加本轮小节
- [ ] `git add` 用的是**显式路径**，未夹带其他 goal 的 6 个 WIP 文件
- [ ] `python3 Tools/source-read/verify_all.py` 全绿
- [ ] push 成功

### 7.3 交接完成自检（本次）

- [x] 读 `AGENTS.md`、`docs/PROJECT_MENTAL_MODEL.md`、`docs/source-vs-reverse/README.md`、
      `FINAL_REPORT.md`、`RESEARCH_LOG.md` 尾部、`coverage-ledger.tsv`、goal 文档（仓库外）
- [x] 核实工作区真实状态（分支 / 领先 3 / 6 处 WIP）
- [x] 交接文档已写入 `docs/handoffs/`
- [x] 仅 `git add` 交接文档
- [x] push 前审查将发布的 4 个提交
- [x] 核实远端 SHA + 文档远端可读

---

## 8. 当前分支 / 工作区风险

### 8.1 分支状态

| 项 | 值 |
|---|---|
| 分支 | `ei-ui-audit-2026-09-24` |
| push 前 | **领先 origin 3 个提交** |
| 本次交接提交 | 见 §10（交接完成后回填） |

### 8.2 ⚠️ 6 处未提交改动（**不属本 goal，禁止触碰**）

| 文件 | 归属证据 |
|---|---|
| `Tools/NpcMover/write_alignment_reports.py` | 最近提交 `94fd8e53 同步NPC离线批准与远端SHA`、`32bfdada 批准精确Merchant NPC离线计划` |
| `Tools/SystemDbProbe/Program.cs` | 同上（NpcMover/NPC 对齐体系） |
| `Tools/maps/mapedit/map_links_v2.json` | 地图编辑器体系 |
| `docs/research/ei-ui-layout/NPC_MONSTER_ALL_MAPS_ALIGNMENT_REPORT_2026-09-25.md` | NPC/怪物对齐报告 |
| `docs/research/ei-ui-layout/artifacts/npc-monster-alignment-2026-09-25/npc-merchant-approval-evidence.json` | 同上 |
| `?? docs/research/map-editor-unknown-entities/UnknownEntityPlacements.json`（未跟踪） | 地图编辑器未知实体 |

**这些是另一个 goal（NPC/怪物对齐 + 地图编辑器）的在制品**，
与本精读 goal 无关。**下任 agent 在本分支工作时要持续保护它们**：
不要 `git add -A`、不要 `git stash`、不要 `git checkout --`、不要 `git clean`。

### 8.3 多 goal 共享工作树风险

`docs/PROJECT_MENTAL_MODEL.md` §八.5 已记录「多 goal 共享工作树 git 互踩」这一坑。
本仓库**同时有多个 goal 在同一分支上工作**（证据：本 goal 的提交与网络检索审计的
提交交错，且工作区有第三方 WIP）。**风险**：

- 提交时可能夹带别人的改动 → **必须显式路径 `git add`**
- push 时可能推送别人的提交 → 本次 task 已由用户**明确授权**推送当前分支已有的本地提交
- 下任 agent 若遇到 push 被拒（远端更新），**先 `git fetch` 看清再决定**，不要 `push -f`

### 8.4 台账完整性风险（已加护栏）

`ledger.py` 曾有「新 note 覆盖旧成果」问题，**2026-09-27 已修复并加防降级守卫**
（见 §3.1 说明）。但守卫**只保护 `covered`**，`partial`→`pending` 仍可被误改，
下任 agent 改台账时请自查统计数字是否合理。

---

## 9. ⚠️ 未知 / 待核实项（**不臆测，集中列出**）

| # | 项 | 为何未知 / 如何核实 |
|---|---|---|
| 1 | **原 goal 的 tmux 会话名、omp session id、watchdog 数组行是否已移除** | 本机 `goal-completed.log` 无本精读 goal 记录；需 `crontab -l` + 读 `~/.hermes/scripts/mir3-goal-watchdog.sh` 的 `GOALS` 数组 |
| 2 | ~~**`Magic.pas` 里 `Mag*` 实现的实际覆盖率**~~ | ✅ **已核实（2026-09-27）**：实现段 16 个 `TMagicManager.Mag*` 全部已登记，**未读 0 个**。验证命令见 §5.1「验证 Magic 覆盖率」 |
| 3 | **`ObjMon*.pas` 已读的具体区段** | 三个文件确实存在且均为 `partial`，但**已读区段需查 `coverage-ledger.tsv` 的 note 列**（本文件未逐条核对，不臆测） |
| 4 | **`CM_ADDNEWUSER`/`CM_CHANGEPASSWORD`/`CM_UPDATEUSER` 接收端是否已登记「源码包缺失」** | goal §E.28 明确要求记录，**是否已做未确证** |
| 5 | **`Envir3/QuestDiary/` 逐文件 blocked 登记是否完成** | goal §B.9 要求，**台账中未见对应行** |
| 6 | `Source/Client/` 19 个 pending 文件、`Source/Common/` 10 个 pending 文件**分别是哪些** | 本文件只给了聚合数，未逐个列出（**没有臆造文件名**） |
| 7 | 原 goal 会话**实际跑过的 Round 编号范围**（是否为 810–833，还是包含更早） | 本会话执行的是 Round 810–833；更早的 Round 802–809 由他人并行 goal 完成（**基于 commit 时间线的推断，非确证**） |
| 8 | 4 条 `goal-completed.log` 记录**是否对应本 goal** | 时间戳与 workdir 吻合但无法确证 |

> **给下任 agent 的请求**：#2–#6 请**实际查台账与文档后填写**，
> **不要照抄本表当成结论**。

---

## 10. 本次交接的提交与远端

> ✅ **已于 2026-09-27 完成 push 并核实。**

| 项 | 值 |
|---|---|
| 交接文档路径 | `docs/handoffs/MIR3_SOURCE_DEEP_READ_HANDOFF_2026-09-27.md` |
| **交接提交 SHA** | **`f0397cca`**（权威值以 `git rev-parse HEAD` 为准；本提交曾 amend 回填本表一次，见下表说明） |
| **远端 SHA** | 与本地 HEAD 一致（用 `git ls-remote origin refs/heads/ei-ui-audit-2026-09-24` 核对） |
| 远端分支 | `origin/ei-ui-audit-2026-09-24` |
| push 前远端 SHA | `bae6ba68877577445dcf8f2c25db09900b363fef` |
| push 方式 | `git push origin ei-ui-audit-2026-09-24`（`bae6ba68..dc4adcbc`），随后对**本交接提交**做了一次 `--amend` 回填本表，再用 `--force-with-lease`（仅重写我方提交 `dc4adcbc`→`f0397cca`，3 个审计提交未动） |
| **随本次 push 一起发布的本地提交** | **4 个**（见下表） |
| 是否夹带其他改动 | ❌ 否 —— `git diff --cached --name-status` 仅 1 行：`A docs/handoffs/MIR3_SOURCE_DEEP_READ_HANDOFF_2026-09-27.md` |
| 远端可读性核实 | ✅ `git show origin/ei-ui-audit-2026-09-24:docs/handoffs/MIR3_SOURCE_DEEP_READ_HANDOFF_2026-09-27.md` 正常读取，**MD5 与本地一致**（具体值见 §10.3；SHA 与文档内容互指，故 MD5 每次 amend 都会变，以命令输出为准） |

### 10.1 本次发布的 4 个提交

| SHA | 文件数 | 说明 | 归属 |
|---|---:|---|---|
| `402008f4` | 22 | 网络检索闭合审计 第二轮: 逐类检索 + 4 条无名称证据通道 | 其他 goal（用户已授权一并发布） |
| `24d69ad9` | 17 | 网络检索闭合审计 第三轮: 地图码全集 + 刷新传播 + 族级检索收尾 | 其他 goal（同上） |
| `285d0a5b` | 12 | 网络检索闭合审计 第四轮: 族级检索佐证 + 来源注册表补全 | 其他 goal（同上） |
| **`f0397cca`** | **1** | **交接: Mir3 Preview 源码全量精读 Goal（用户已暂停）**（原为 `dc4adcbc`，amend 回填本表后 SHA 变更） | **本次交接** |

### 10.2 未发布的 6 处工作区改动（仍保留在本地）

push 后 `git status --porcelain` 仍为这 6 项，**与 push 前完全一致**（5 个 `M` + 1 个 `??`），
**未被提交、未被丢弃**（详见 §8.2）。

### 10.3 交接完成时的最终核实（下任 agent 可复现）

```bash
cd /home/tetsuya/development/Mir3-Research
git rev-parse HEAD                                    # 应 = 下表 SHA
git ls-remote origin refs/heads/ei-ui-audit-2026-09-24 # 应与 HEAD 一致
git log --oneline -4 origin/ei-ui-audit-2026-09-24     # 应见下面 4 个提交
git show origin/ei-ui-audit-2026-09-24:docs/handoffs/MIR3_SOURCE_DEEP_READ_HANDOFF_2026-09-27.md | md5sum
md5sum docs/handoffs/MIR3_SOURCE_DEEP_READ_HANDOFF_2026-09-27.md   # 两者应相等
git status --porcelain                                 # 应仍为 6 处 WIP
```

| 核实项 | 结果 |
|---|---|
| 分支 | `ei-ui-audit-2026-09-24` |
| 交接提交 = 远端 SHA | 见 `git rev-parse HEAD` / `git ls-remote`（两者相等） |
| 远端 4 个提交 | `交接(f0397cca)` ← `审计第四轮(285d0a5b)` ← `审计第三轮(24d69ad9)` ← `审计第二轮(402008f4)` ← 基线 `bae6ba68` |
| 文档远端可读 | ✅ 是 |
| 6 处 WIP | ✅ 原样保留，未提交未丢弃 |

---

## 11. 一句话给下任 agent

**源码还剩 294 文件 / 111,943 行（35.5%）没读；最该先补的是 5 个只读了声明的
服务端系统（Guild/Castle/TagSystem/Relationship/Event），因为 goal 明确要求
「不得只读声明」——目前这是直接违规项。只读研究，别碰数据库，别动那 6 个 WIP 文件。**
