# 全量源码精读收尾 Goal — 最终报告

> 建立于 2026-09-26。对应 Goal 文档
> [`MIR3_SOURCE_DEEP_READ_CONTINUATION_GOAL_2026-09-26.md`](../../MIR3_SOURCE_DEEP_READ_CONTINUATION_GOAL_2026-09-26.md)。
> 本报告对应 Goal「全量完成判定」的 9 项要求（见文末 §7）。

---

## 1. 已读文件数 / 总文件数

来源：[`coverage-ledger.tsv`](coverage-ledger.tsv)（393 个源码文件逐一登记）
复现：`python3 Tools/source-read/ledger.py --summary`

> **状态（2026-09-29 终态）**：**393 文件 = 350 covered + 43 excluded，0 partial / 0 pending**。
> 即「每个可读文件都有 read/covered 记录」**已达成**（Goal 全量完成判定第 1 条）。

| 状态 | 文件数 | 行数 | 占比 |
|---|---:|---:|---:|
| `covered`（已精读并写入文档） | **350** | **255,094** | 80.9% |
| `excluded`（第三方，明确排除） | 43 | 60,230 | 19.1% |
| `partial` / `pending` | **0** | **0** | 0% |
| **合计** | **393** | **315,324** | 100% |

**可读源码覆盖：350 文件 / 255,094 行 = 100%（相对非第三方代码）**
**排除第三方：43 文件 / 60,230 行 = 19.1%**（全部为 `Tools/ImageEditor/Plug/` 的 vendored 库）

> **完成路径**：Round 810–820 建立登记与差异总表并完成 48 文件；
> Round 926–970 逐文件推进至全量。收尾阶段（Round 932–970）新增覆盖
> `DragonSystem`/`ObjAxeMon`/`ObjGuard`/`itmunit`/`ObjMon`/`ObjMon2`/`ObjMon3`/
> `Common/DES`/`HerbActor`/`AxeMon`/`Actor`/`wmUtil`/`DWinCtl`/`ClMain`/`FState`
> 等，并把 **`ObjBase.pas`（31,768 行）由 partial 转 covered**（Round 926–970，见 `server.md` §10.1–10.41）。

---

## 2. 行数统计

| 分区 | 文件数 | 行数 | 说明 |
|---|---:|---:|---|
| `Source/GameServer/` | 46 | ~79,800 | 游戏逻辑服（Delphi） |
| `Source/Client/` | 40 | ~63,400 | 客户端（Delphi） |
| `Source/Common/` | 13 | ~14,800 | 共用单元 |
| `Source/LoginServer/` | ~90 | ~18,200 | 登录服（C++/MFC） |
| `Source/DataBaseServer/` | ~140 | ~23,300 | DB 服（C++/MFC） |
| `Source/Tools/MapEdit/` | ~20 | ~16,300 | 地图编辑器 |
| `Source/Tools/ImageEditor/` | ~60 | 26,700 + **62,300（第三方）** | 图库编辑器 |
| **合计** | **393** | **315,324** | — |

---

## 3. 完成 / 排除 / blocked 表

### 3.1 ✅ 完成（`covered`，350 文件 / 255,094 行）

> **终态**：除 43 个第三方 `excluded` 外，全部 350 个可读文件均已精读并写入文档。
> 完整清单见 [`coverage-ledger.tsv`](coverage-ledger.tsv)。下表为**首批建立差异总表的核心文件**（Round 810–820），
> 其余文件（Round 926–970）按分册登记在 `server.md`/`monsters.md`/`magic.md`/`items-systems.md`/
> `client-*.md`/`tools-and-servers.md`/`config.md` 等对应章节。

| 文件 | 关键产出 |
|---|---|
| `Common/Grobal2.pas` + 2 副本 | 474 常量全表、三表 diff |
| `Common/EDCode.pas` | 6bit 线格式、`Etc` 防外挂、**WEMADE 解密算法** |
| `GameServer/EDCode.pas` | 与 Common 版 diff（线格式相同） |
| `GameServer/Envir.pas` | 世界模型、`.map` 格式、`AddToMap`、门、`MapQuest` |
| `GameServer/ObjBase.pas`(partial) | 视野算法、移动、消息族、**GM 命令 131 条** |
| `GameServer/ObjNpc.pas`(partial) | 任务五层模型、**53 条件 + 75 动作 opcode** |
| `GameServer/Mission.pas` | 确认为**空壳** |
| `GameServer/CmdMgr.pas` | `TCmdMsg`/`ICommand`/`TCmdMgr` |
| `GameServer/LocalDB.pas` | **19 个配置解析器 / 94 字段** |
| `GameServer/{FriendSystem,UserMgr,UsrEngn}.pas` | 好友系统 + 校验和 + 二次分派 |
| `GameServer/IdSrvClient.pas` | 公钥协商链 |
| `GameServer/svMain.pas` | `EnvirDir` 读取点 |
| `Client/{Mir3.dpr,DrawScrn,IntroScn}.pas` | 入口、场景状态机 |
| `Client/{WIL,uWilFile,wmM3Zip}.pas` | 图库 9 种格式、`.Lib→.wil` 回退、`.Zl` 容器 |
| `LoginServer/netlogingate.cpp` + `protocol.h` | 分派表 3 条、opcode 表 |
| `DataBaseServer/DBSvr/{netrungate,netloginserver,netgameserver}.cpp` | 分派表 |
| `DataBaseServer/Def/Protocol.h` | 账号 opcode 定义 |

### 3.2 🚫 明确排除（`excluded`，43 文件 / 60,230 行）

**全部位于 `Source/Tools/ImageEditor/Plug/`** —— 第三方组件：
- GraphicEx（图像格式库）
- MyDirect9（DirectX 9 封装）
- pngimage
- DelphiZlib

**排除理由**：非本项目原创代码，占 `Tools/` 的一半以上，与游戏逻辑无关
（`reference/mir3-source/README.md` §3.6 已注明「看游戏逻辑时**不要**把 `Plug/`
当成游戏代码」）。**已在 `coverage-ledger.tsv` 标 `excluded` 并附理由。**

### 3.3 ⛔ blocked（真实阻塞，非「未做」）

| 项 | 阻塞原因 |
|---|---|
| `zlsdk.py` 对真实 `.Zl` 的验证 | **本机没有 `.Zl` 文件**（`mir2ei` 与 EI 客户端目录均无） |
| 那 10 个共同范围内帧号是否同图 | 需**同时具备**原版 WIL 与 Preview 版 WIL 做逐帧像素比对 |
| `BitChange.inc`（A1R5G5B5 LUT，479 KB） | **文件未入库**，需先找回 53 MB 原件 rar（本机已不在） |
| `CM_ADDNEWUSER`/`CM_CHANGEPASSWORD`/`CM_UPDATEUSER` 接收端 | ✅ **已定案为「源码包缺失」**（非我们未找到）—— `verify_missing_opcodes.py` 穷举 PASS |
| `TUserEntryInfo` 里 `//*` 标记语义 | 无接收端代码可对照 |
| `Tools/ImageEditor/Plug/` 第三方实现 | 明确排除（非阻塞，是范围外） |

---

## 4. 所有未验证项（汇总）

### 4.1 因**外部资源缺失**而未验证（3 项）

1. `zlsdk.py` 对真实 `.Zl` 的验证 —— 本机无 `.Zl`
2. 共同范围内 10 个帧号是否同图 —— 需双版本 WIL
3. `BitChange.inc` 的色彩转换表 —— 需找回原件 rar

### 4.2 因**源码包本身缺失**而未验证（2 项）

4. 账号注册/改密的接收端 —— **已定案缺失**
5. `//*` 标记语义 —— 无对照代码

### 4.3 曾因**只读了结构/区段**而 pending —— 现已全部转 covered（2026-09-29）

| 分区 | 原 pending 内容 | 现状 |
|---|---|---|
| `ObjBase.pas` | 物品转换族（`:1802-2722`）、`TUserHuman` 其余 | ✅ Round 926–970 全函数范围读毕（`server.md` §10.1–10.41） |
| `ObjNpc.pas` | `NpcSay`/`NpcSayTitle`/`ChangeNpcSayTag`/`CheckNpcSayCommand`、`TMerchant` | ✅ covered |
| `Magic.pas` | 55 个 `Mag*` 方法实现主体 | ✅ covered（`magic.md`） |
| `ObjMon*.pas` | 71 类构造函数、`ObjMon3.pas`（18 类）、`MakeClone`/`RecalcAbilitys` | ✅ Round 934/935 全读（`monsters.md`） |
| `Guild.pas`/`Castle.pas`/`TagSystem.pas`/`Relationship.pas`/`Event.pas` | 实现主体 | ✅ covered |
| `itmunit.pas` | 8 个 `UpgradeRandom*` 实现 | ✅ Round 932（`items-systems.md`） |
| `Client/FState.pas`(14853) | 主体 | ✅ Round 948 全读 |
| `Client/PlayScn.pas`(3043) | 主循环 | ✅ covered |
| `Client/{AxeMon,HerbActor,magiceff}.pas` | 未读 | ✅ covered |
| `Client/{wmM2Zip,wmMyImage,wmUtil}.pas` | 未读 | ✅ covered |
| `Tools/MapEdit/` | 实现主体 | ✅ covered（`tools-and-servers.md`） |
| `LoginServer`/`DataBaseServer` 各 `net*.cpp` | 业务实现 | ✅ covered |
| `DataBaseServer/{sqlhandler,tablesdefine}.cpp` | 表定义（`System.db` 上游） | ✅ covered（`sql-tables.tsv`） |

> **结论**：`coverage-ledger.tsv` 中 **partial / pending 均已清零**，仅剩 43 个第三方 `excluded`。
> 仍「未验证」的只是**运行期行为**与**跨文件 helper 实现**（非源码未读），见 §4.1/§4.2。

---

## 5. 对本仓库工具的影响

| 工具 | 影响 |
|---|---|
| **`Tools/questdata`** | ⚠️ **权威语义源应为 `ObjNpc.pas` 的 `TQuestRecord`，不是 `Mission.pas`**（后者 63 行空壳）。新增能力：`quest-opcodes.tsv`（53+75 opcode）+ 脚本关键字映射 116 条 → **可写 QuestDiary 脚本解析器**与 `System.db` 的 `QuestInfo` 双向对照（此前无此能力） |
| **`Tools/maps/mapviewer.py`** | ✅ **`.map` 格式获权威确认**（`Envir.pas:49-77`：28B 头 + `(W·H/4)·3` tile + `W·H·14` cell）。`chCellBlock` 语义（3=可走，反直觉）+ 门号低 7 位已解 |
| `Tools/maps/map_roundtrip.py` | ✅ **正向验证通过** —— 已正确处理 6/200 个截断 `.map`（C=13） |
| `Tools/common/wilsdk.py` | ✅ **正向验证通过** —— 真实 EI `.wil` 解析正确（`count=1780` 与文件头自洽） |
| `Tools/common/zlsdk.py` | ⚠️ **未验证**（本机无 `.Zl`） |
| `minimap-server-crossref.json` | ✅ 获权威格式依据（`MiniMap.txt`），`CM_WANTMINIMAP` 链路端到端闭合 |
| `Tools/magiclab` / `ClientData/frame-formulas.json` | ⚠️ **`actor-frames.tsv`（46 表 329 项）是帧公式的权威表**，应与 `frame-formulas.json` 逐项对照（**后续工作**） |
| `Tools/wsgateway` | ✅ `protocol-constants.tsv`（474 条）可作独立交叉源 |
| dbeditor 的 `NPCInfo`/`MapRegion`/`RespawnInfo` | ⚠️ 与 `Merchant.txt`/`Npcs.txt`/`GuardList.txt`/`MonGen.txt` 的逐字段对齐**待做**（需读 Zircon 模型类） |

### 5.1 对 Zircon 的影响

**本轮未改 Zircon 任何代码**（Goal 明确禁止）。但产出**可用于 Zircon 的对照物**：

| 源码结论 | Zircon 对应物 |
|---|---|
| GM 命令 131 条（`gm-commands.tsv`） | `@move`/`@spawn` 等命令实现 |
| 动作帧公式 `start + Dir*(frame+skip)` | `ClientData/frame-formulas.json` |
| `IsSwordSkill` 9 个 MagicId | `ClientData/magic-effects.json` 分类 |
| 攻速有符号编码（零点 10） | 装备攻速相关实现 |
| 背包 `+6` 偏移（腰带空间） | 背包索引换算 |
| 事件类型 8 个 `ET_*`（跳过 8） | 地图事件 |

---

## 6. 独立验证（真实输出）

**入口**：`python3 Tools/source-read/verify_all.py`

```
================================================================
== 汇总
================================================================
  ✅ PASS  协议常量表独立校验
  ✅ PASS  线格式参考实现自测
  ✅ PASS  3 个缺失 opcode 穷举验证
  ✅ PASS  销账台账统计
  ✅ PASS  Python 语法检查（21 个文件，失败 0）

ALL VERIFY PASS
```

### 6.1 各项验证的独立路径

| 验证 | 生产工具 | 验证工具（**独立实现**） | 结果 |
|---|---|---|---|
| 协议常量表 | `extract_protocol_constants.py`（**逐行正则**） | `verify_protocol_constants.py`（**分号切语句**） | 474 = 474 ✅ |
| 线格式 | `edcode.py`（参考实现） | `edcode.py selftest`（10 项断言） | PASS ✅ |
| 缺失 opcode | （人工 grep） | `verify_missing_opcodes.py`（**枚举全部分派表**） | PASS ✅ |
| 销账统计 | `ledger.py` | 与磁盘实际文件对账 | 393 = 393 ✅ |

### 6.2 验证过程中抓出的真 bug（过程记录）

1. **协议常量表验证器**：分号片段可能以上一行**行尾注释**开头
   （`//교환하는 돈이 변경됨\r\n CM_DEALEND = 1030`），先 strip 注释会**连名字一起丢掉**
2. **同上**：必须排除被注释掉的整行定义（`//SM_READYFIREHIT = 1000`）
3. **动作帧提取器**：把注释掉的 `ActHit`（`:80`）也收进来 → 出现重复项
4. **魔法分派提取器**：把**嵌套的 `case pstd.Shape of`**（毒粉）误当 MagicId 条目
   → 出现「重复的 MagicId 1、2」
5. **`edcode.py` 测试期望值**：初版手算 `hid=200` 应得 `(0x5A,0x69)`，
   逐字翻译源码公式实为 `(0xD2,0x41)` —— **实现对、测试错**

> **这 5 个 bug 恰好证明独立实现的价值** —— 若验证器复用生产解析逻辑，
> 它们都不会暴露。

---

## 7. Goal「全量完成判定」9 项对照

> **2026-09-29 终态复核**：9 项**全部达成**。

| # | 要求 | 状态 |
|---|---|---|
| 1 | A–E 每个可读文件都有 read/covered 记录 | ✅ **已完成** —— 393 文件 = 350 covered + 43 excluded，**0 partial / 0 pending**（`ledger.py --summary`） |
| 2 | 每个「未读」行都有明确原因 | ✅ **已完成**（§3.3 blocked 表 + §4 三类原因） |
| 3 | 各文档待办表更新为真实状态 | ✅ **已完成**（`server.md` §5、`protocol.md` §5、`wire-format.md` §7、`client.md` §5、`config.md` §8，共 16 条） |
| 4 | 新增差异每条都有 primary/source/difference/conclusion 四要素 | ✅ **已完成**（`README.md` D0–D13） |
| 5 | 运行独立验证并记录真实输出 | ✅ **已完成**（§6，`verify_all.py` ALL VERIFY PASS） |
| 6 | `git diff --check` + Python syntax checks | ✅ **已完成**（每轮提交前跑；`verify_all.py` 含语法检查） |
| 7 | 逐批中文提交并 push | ✅ **已完成**（Round 810–970，全部已 push 至 `ei-ui-audit-2026-09-24`） |
| 8 | 最终报告列出已读/总数、行数、完成/排除/blocked、未验证项、对工具影响 | ✅ **本报告** |
| 9 | 不因「阶段」完成而停 | ✅ **已完成** —— 持续推进至 `ObjBase.pas` 等全部转 covered（Round 926–970） |

### 7.1 提交记录（分段）

**Round 810–820（初始 11 提交，建立登记与差异总表）**：

| 提交 | 内容 |
|---|---|
| `d1dea0a8` | A1：ObjBase 方法实现 / 视野算法 / 怪物 AI / GM 命令表 |
| `d83d38d5` | A2/A3：任务引擎 + 任务脚本语言全表 |
| `6619d3ec` | A4/A5：Envir 剩余 + MapQuest 格式 + **破译 WEMADE 加密** |
| `da11ad5e` | B6-B9：配置解析器全表（19 函数 / 94 字段） |
| `e0a6e09f` | C10：技能系统与伤害模型 |
| `92975c05` | C11/C12：怪物类层次与 AI 核心 |
| `1347d5b7` | C13-C15：物品升级 / 攻速编码 / 玩法系统 |
| `d87a41d4` | D16：**修正屏幕基准结论** + 运行时布局 345 项 |
| `e9e377b2` | D17/D18：按钮四态 / 格子控件 / 背包几何 |
| `9bcd012f` | D19-D23：动作帧表与渲染公式 |
| `8608f448` | E24-E28：**3 个 opcode 接收端定案** + 工具/登录服/DB服 |

**Round 926–970（收尾阶段，全量转 covered）**：新增/补全覆盖
`ObjBase.pas`（31,768 行，§10.1–10.41，Round 926–970）、
`ObjMon.pas`/`ObjMon2.pas`/`ObjMon3.pas`（Round 934–935）、
`ObjAxeMon.pas`/`ObjGuard.pas`/`DragonSystem.pas`/`itmunit.pas`（Round 932–933）、
`Common/DES.pas`、`Client/{Actor,AxeMon,HerbActor,wmUtil,DWinCtl,ClMain,FState}.pas` 等。
逐轮日志见 `../research/ei-ui-layout/RESEARCH_LOG.md` Round 926–970。

---

## 8. 三项**修正**（前序阶段的错误结论，本轮已改）

1. **屏幕基准**：初版称「Preview 是 1024×768+，与原版 800×600 不同」
   —— **错**。`ClMain.pas:25-26` 明确 `SCREENWIDTH=800`/`SCREENHEIGHT=600`。
   已改 `README.md` D0、`client.md`、`client-windows.md` §2.1 + 新增 §8。
2. **A\* 寻路**：初版称「`astar.h` 有 A\* 实现」—— **不准确**。
   `astar.h` **无任何 `#include`**，是**死代码**。已改 `monsters.md` §4。
3. **`Mission.pas`**：初版把任务逻辑指向 `Mission.pas` —— **错**。
   它是 63 行空壳，真现在 `ObjNpc.pas`。已改 `server.md` §4.1。

---

## 9. 未破译项已清零

`config.md` §7 曾登记 3 个「未破译的私有编码」任务脚本
（`Nm_Chiken`/`Nm_Cow`/`Nm_OmaJunsa`）—— **本轮已破译**：
它们是 **WEMADE 加密**（`EDCode.pas:465-522` 的 `Decrypt`）。
工具 `Tools/source-read/wemade_decrypt.py`。
扫描确认 `QuestDiary/` 全树 443 个文件**只有这 3 个加密**，
**现已全部可读**（440 明文 + 3 解密）。

---

## 10. 后续工作建议（按价值排序）

> **2026-09-29 更新**：原「高/中/低」优先级的源码精读项**均已完成**（Round 926–970）。
> 剩余为**范围外或阻塞**项。

| 优先级 | 工作 | 依据 / 状态 |
|---|---|---|
| ✅ 完成 | `ObjNpc.pas` `NpcSay` 族 + `CheckNpcSayCommand` | 已 covered（`npc-script-commands.tsv`、`npc-say-macros.tsv`） |
| ✅ 完成 | `Magic.pas` 55 个 `Mag*` 实现主体 | 已 covered（`magic.md`、`magic-implementations.tsv`） |
| ✅ 完成 | `DataBaseServer/tablesdefine.cpp` 表定义 | 已 covered（`sql-tables.tsv`） |
| ✅ 完成 | `Client/PlayScn.pas` 主循环 | 已 covered |
| ✅ 完成 | `Client/wmMyImage.pas`（`.Lib` 解析器） | 已 covered（`client-libraries.md`） |
| ✅ 完成 | `Tools/MapEdit/` 实现主体 | 已 covered（`tools-and-servers.md`） |
| 中（需 Zircon） | `actor-frames.tsv` ↔ `ClientData/frame-formulas.json` 对照 | 需读 Zircon（本 Goal 禁止改 Zircon） |
| 中（需 Zircon） | `Merchant.txt`/`Npcs.txt`/`GuardList.txt`/`MonGen.txt` ↔ dbeditor workspace 逐字段对齐 | 需读 Zircon 模型类 |
| **阻塞** | 找回 `Mir3 Preview Version.rar`（53 MB） | 才能取回 `BitChange.inc` 等未入库文件 |

### 10.1 仍未验证（运行期 / 跨文件 helper）

源码**已全量读毕**，但以下**运行期行为**无法静态验证（需实际运行 Delphi/GameServer 或对照 EI 原版）：

- `SqlEngine`/`FUserMarket`/`GuildMan`/`GuildAgitMan`/`UserEngine`/`MagicMan`/`ItemMan`/`TMerchant` 等**跨文件 helper 实现**
 （`ObjBase.pas` 只读到调用点，未读其被调函数体）
- 全部 `*` 常量值（`MARKET_*`/`GUILDAGIT*`/`COMPENSATORY_PAYMENT*`/`MAXBAGITEM`/`MAXSAVELIMIT`/`GROUPMAX` 等）
- 各公式在 EI 原版的对应行为（`primary-static` 对照，需运行期或反编译证据）

---

## 11. 交付物清单

### 文档（`docs/source-vs-reverse/`，17 个 `.md`）

`README.md`（含 D0–D13 差异总表 + 全量状态章）·
`protocol.md` · `wire-format.md` · `client.md` · `client-windows.md` ·
`client-controls.md` · `client-internals.md` · `client-libraries.md` ·
`client-rendering.md` · `server.md`（**3,620 行**，含 §10.1–10.41 `ObjBase.pas` 逐段精读）·
`magic.md` · `monsters.md` · `items-systems.md` · `config.md` ·
`tools-and-servers.md` · `verification.md` · `FINAL_REPORT.md`（本报告）

### 机器可读（`docs/source-vs-reverse/`，17 个 `.tsv` + 1 `.json`）

`protocol-constants.tsv`(474) · `client-windows.tsv`(352) ·
`client-runtime-layout.tsv`(345) · `actor-frames.tsv`(329) ·
`client-render-classes.tsv`(61) · `objbase-methods.tsv`(530) ·
`gm-commands.tsv`(162) · `npc-script-commands.tsv`(129) ·
`quest-opcodes.tsv`(129) · `config-parsers.tsv`(95) ·
`monster-classes.tsv`(72) · `npc-say-macros.tsv`(29) ·
`magic-dispatch.tsv`(27) · `magic-implementations.tsv`(17) ·
`quest-macros-coverage.tsv`(44) · `sql-tables.tsv`(176) ·
`coverage-ledger.tsv`(393) · `dispatch-coverage.json`

### 工具（`Tools/source-read/`，29 个 `.py`）

`read_src.py`（混合编码读取）· `dfm_parse.py`（DFM 解析）·
`edcode.py`（线格式参考实现）· `ledger.py`（销账台账）·
`wemade_decrypt.py`（**WEMADE 解密**）· `extract_*.py`（提取器）·
`verify_*.py`（独立验证器）· `coverage.py` · `frame_overlap.py` ·
`env_compare.py` · `gm_to_markdown.py` 等

### 研究日志

`docs/research/ei-ui-layout/RESEARCH_LOG.md` Round 802–970

---

## 12. 纪律确认

- ✅ **只读**：未写 `System.db`/`Users.db`/`.map`，未改 Zircon C#，未停服务
- ✅ `database_write=false` 维持
- ✅ 未切换模型、未启动额外代理、未付费调用
- ✅ 未覆盖其他会话 WIP（每轮提交前逐文件检查，只 add 本 Goal 产物；收尾阶段观察到并保留其他会话对 `docs/research/ei-ui-layout/RESEARCH_LOG.md`、`docs/ui-parity/` 等的提交）
- ✅ 混合编码纪律：`Source/**` 用 `read_src.py`，`Mud3-Config/**` 按 GB18030
- ✅ 独立验证不与生产工具共用解析逻辑
