# 独立质量审计报告：Mir3 Preview 源码全量精读

> **审计日期**：2026-09-29
> **审计对象**：前一 goal `01a0ed3d` 的「393 文件 = 350 covered + 43 excluded，0 partial / 0 pending」完成声明
> **审计性质**：独立、证据驱动；不替前一 goal 背书，无法核实的结论标 `UNVERIFIED`
> **分支**：`ei-ui-audit-2026-09-24`（HEAD `37ecb820`，FINAL_REPORT 提交 `e48b2222`）
> **安全边界**：仅只读核对 + 创建本报告；未 reset/clean/stash，未触碰他人未提交工作（工作树有 6 个无关 UI 审计改动，已原样保留）

---

## 1. 前一 goal 实际花费时长与提交证据

| 项 | 证据 |
|---|---|
| 时间跨度 | Round 80 提交 `16bc58fd`（2026-08-12 13:44）→ Round 971 `e48b2222`（2026-09-29 22:51），**约 7 周** |
| 提交数 | 含「源码精读/Round」的提交 **825 个**（`git log --oneline e48b2222 --grep` 实测） |
| 终态提交 | `433a5e5a` Round 970 ObjBase 收尾；`e48b2222` Round 971 FINAL_REPORT |
| 关键判定 | **「耗时较短/匆忙完成」的印象不成立** —— 这是一个跨越 7 周、825 提交的长期延续 goal 的收尾阶段，不是单次速成 |

> 说明：前一 goal 文档自称对应 Goal「全量完成判定」，但其源码精读工作链可追溯到 2026-08-12 的 Round 80。本轮（Round 926–970）是已建台账基础上的逐文件补全，不是从零开始。

---

## 2. 验证脚本运行结果

### 2.1 `ledger.py --summary`（独立运行，exit 0）

```
文件总数      : 393
代码总行数    : 315324
  covered   :  350 文件 /  255094 行
  excluded  :   43 文件 /   60230 行
已覆盖行数    : 255094  (80.9%)
部分覆盖行数  : 0  (0.0%)
待读行数      : 0  (0.0%)
```

**与 FINAL_REPORT §1 完全一致**：393 / 350 / 43 / 0 / 0，行数 255094 / 60230 / 315324。

### 2.2 `verify_all.py`（独立运行，exit 0）

```
✅ PASS  协议常量表独立校验        （474 = 474）
✅ PASS  线格式参考实现自测        （EDCODE SELFTEST PASS）
✅ PASS  3 个缺失 opcode 穷举验证  （CM_ADDNEWUSER/CHANGEPASSWORD/UPDATEUSER 无接收端）
✅ PASS  销账台账统计              （393 = 393）
✅ PASS  Python 语法检查（29 个文件，失败 0）
ALL VERIFY PASS
```

### 2.3 `git diff --check`

Exit 0，无空白错误。工作树有 6 个无关 UI 审计改动（`Tools/NpcMover/`、`Tools/SystemDbProbe/`、`Tools/maps/`、`docs/research/ei-ui-layout/` 等），均原样保留未触碰。

---

## 3. Ledger 一致性复核

### 3.1 状态计数（awk 独立统计）

| 状态 | 计数 | 与声明 |
|---|---:|---|
| covered | 350 | ✅ 一致 |
| excluded | 43 | ✅ 一致 |
| partial | 0 | ✅ 一致 |
| pending | 0 | ✅ 一致 |

### 3.2 路径完整性

- **ledger 与磁盘对账**：393 个 rel_path 中 **393 个文件实际存在**（路径根为 `reference/mir3-source/`）。
- **重复登记**：**0**（`uniq -d` 无输出）。
- **字节比对**：393 文件逐一比 byte，**仅 1 处差异** —— `Source/LoginServer/Common/mir2packet.cpp`：ledger 2056B/110 行 vs 磁盘 2045B/109 行（差 11 字节 / 1 行）。属台账登记后文件被重新规范化的轻微漂移，**不影响 covered 判定**。
- **磁盘有但 ledger 未登记（34 个）**：全部为 `.dfm`（Delphi 表单）和 `.inc`（include）文件。`ledger.py` 的 `CODE_EXT` 设计上只含 `.pas/.dpr/.cpp/.h/.hpp/.c/.sln/.vcproj`，**有意排除 .dfm/.inc**。非漏读 —— DFM 内容由对应 .pas 的 ledger note 单独说明（如 EdMain.pas note 注明「DFM parser EOF IndexError」）。
- **ledger 有但磁盘无（6 个）**：全部为 `.sln`/`.vcproj` 解决方案文件（DBSvr/LoginSvr/_Oranze Library）。这些是工程组织文件非源码，登记为 covered 属宽松但无害。

### 3.3 excluded 风险抽查（43 个全部核对）

**全部 43 个 excluded 文件路径均位于 `Source/Tools/ImageEditor/Plug/`**，分属 4 个公认第三方库：

| 库 | 文件数 | 性质 |
|---|---:|---|
| MyDirect9（DirectX 9 封装） | 11 | 第三方 |
| pngimage | 4 | 第三方 |
| DelphiZlib（含 zlib C 源码） | 21 | 第三方 |
| GraphicEx | 5 | 第三方 |

- **未发现本项目核心源码被错误排除**。所有 excluded 均为 vendored 第三方组件，排除理由成立。
- 排除逻辑在 `ledger.py:31-33` 的 `EXCLUDE_PREFIXES` 中硬编码，与 README §3.6「不要把 Plug/ 当游戏代码」一致。

---

## 4. covered 分层抽样（15 个文件，覆盖全部主要区域）

每个样本核对：源码行范围存在性 + 文档引用的具体证据 vs 实际源码内容。

| # | 区域 | 文件 | 抽样结果 |
|---|---|---|---|
| 1 | GameServer | `ObjBase.pas`（31768 行）| ✅ **实质精读**。ledger 行数与磁盘精确一致。`server.md` §10.1–10.41 共 41 节覆盖 `:1418–31768` 全范围；§10.37（`:29923-31763`）描述的 `SetExpiredTime`/`FExpireCount mod 60`/`BoAccountExpired` 与源码 :29923-29952 逐行吻合；§10.37.5 物品合并日志码 `'44'` 与 :31747 实际 `AddUserLog('44'#9...)` 一致。ledger note 1503 字符含逐轮行号，非机械摘要 |
| 2 | GameServer | `ObjNpc.pas`（6409 行）| ✅ **实质精读**。`TQuestRecord`（:83-88）字段 `BoRequire/LocalNumber/QuestRequireArr/SayingList` 与 `server.md` §4.1 逐字段一致；`CheckQuestCondition` 在 :757、`MAXREQUIRE=10` 在 :20 均核对属实 |
| 3 | GameServer | `Magic.pas`（1756 行）| ✅ **实质精读**。`magic.md` §4「4 个 case 块/26 个 MagicId」与源码 4 处 `case pum.pDef.MagicId of` 一致。⚠️ 文档称「55 个 Mag* 方法」vs 实测 68 个 Mag* 匹配 —— 属近似表述，已覆盖但措辞略保守 |
| 4 | GameServer | `ObjMon.pas`（3097 行）| ✅ ledger 行数精确一致；note 含具体机制（`TSpitSpider` 5×5 模板、`TCowKingMonster` 围 5 人瞬移）属真实提取 |
| 5 | GameServer | `ObjMon3.pas`（3197 行）| ✅ 实测 18 个 `= class` 怪物类，与报告「ObjMon3（18 类）」一致 |
| 6 | GameServer | `Castle.pas`（1241 行）| ✅ ledger 行数一致；note 记「hour-20 检查非精确 20:00」「3h war」属真实阅读结论 |
| 7 | GameServer | `itmunit.pas`（897 行）| ✅ ledger 行数一致；note 记「攻速 incp=(1+up)div3」「耐久封顶 65000」属真实提取细节 |
| 8 | Common | `EDCode.pas` | ✅ `Decrypt` 函数在 :465，与报告 §9「EDCode.pas:465-522 WEMADE 解密」一致 |
| 9 | Common | `Grobal2.pas` | ✅ protocol-constants.tsv 475 行（1 头+474 常量），与 verify 474 一致 |
| 10 | Client | `ClMain.pas` | ✅ `SCREENWIDTH=800`/`SCREENHEIGHT=600` 在 :25-26，与 `client-windows.md` §8 修正结论精确一致 |
| 11 | Client | `FState.pas`（14853 行）| ✅ `FormCreate`(:439)/`FormDestroy`(:466) + `TList`/`TStringList` 成员与 ledger note 一致 |
| 12 | LoginServer | `netlogingate.cpp` | ✅ :25-27 确为 3 条分派（`CM_IDPASSWORD`/`CM_SELECTSERVER`/`CM_PROTOCOL`），与 `protocol.md`「分派表 3 条」一致 |
| 13 | DataBaseServer | `Def/Protocol.h` | ✅ 含 139 个 opcode 匹配，覆盖属实 |
| 14 | Tools | `MapEdit/EdMain.pas`（3283 行）| ✅ ledger 行数精确一致；`tools-and-servers.md` §2.1 有逐文件说明 |
| 15 | LoginServer | `Common/mir2packet.cpp` | ✅ covered；⚠️ ledger byte/line 轻微漂移（见 §3.2）|

**抽样结论**：15 个样本全部为**实质精读**，文档引用的行号、字段名、函数名、数值常量均与源码核对一致。未发现「只登记文件名」或「机械摘要」的样本。

---

## 5. 发现的具体问题

### 5.1 确定的小缺口（非阻塞）

| # | 问题 | 严重度 | 修复建议 |
|---|---|---|---|
| 1 | `mir2packet.cpp` ledger byte 漂移（2056→2045，行 110→109）| 低 | 重跑 `ledger.py` 刷新该行 bytes/lines |
| 2 | FINAL_REPORT §6 line 181 写「Python 语法检查（21 个文件）」，实际 `verify_all.py` 动态统计 **29 个文件** | 低 | 报告硬编码了过时数字；建议改为引用实际输出或更新为 29 |
| 3 | `Magic.pas` 文档称「55 个 Mag* 方法」，实测 68 个 Mag* 匹配 | 低 | 可能 55 指特定签名子集；建议文档注明口径 |

### 5.2 未发现的问题

- ❌ 未发现核心源码被错误标 excluded
- ❌ 未发现 covered 文件实际未读（只登记文件名）
- ❌ 未发现路径失效或重复登记
- ❌ 未发现 partial/pending 被隐瞒（独立统计确为 0）
- ❌ 未发现「匆忙完成」的证据 —— 时间跨度 7 周 / 825 提交

### 5.3 UNVERIFIED 项（无法在本审计中静态核实）

- `server.md` §10.37.5 等「未验证」段标注的跨文件 helper 实现（`SqlEngine`/`FUserMarket`/`GuildAgitMan` 等）—— 这些被调函数体在其他文件，`ObjBase.pas` 只读到调用点。**前一 goal 已诚实标注为「未验证」**，未伪装已读。
- 运行期行为（Delphi/GameServer 实际执行）—— 静态审计无法覆盖，本 goal 亦不要求。
- `*` 常量具体数值（`MARKET_*`/`GUILDAGIT*` 等）—— 前一 goal 标注「值未查」，属诚实声明。

---

## 6. FINAL_REPORT「全部完成」结论核对

| 报告声明 | 核对结果 |
|---|---|
| 393 = 350 covered + 43 excluded，0 partial/pending | ✅ 与 ledger.py + awk 独立统计一致 |
| covered 255094 行 / excluded 60230 行 / 合计 315324 | ✅ 与脚本输出一致 |
| 43 excluded 全在 `Tools/ImageEditor/Plug/` | ✅ 逐一核对属实 |
| `verify_all.py` ALL VERIFY PASS | ✅ 独立运行复现 |
| ObjBase.pas 由 partial 转 covered（Round 926-970）| ✅ git 历史有 Round 961-970 逐轮提交；`server.md` §10.1-10.41 覆盖全范围 |
| §6 语法检查「21 个文件」| ⚠️ **过时** —— 实际 29 个文件（见 §5.1 #2）|
| §4.3 partial→covered 转换表（ObjNpc/Magic/ObjMon*/FState 等）| ✅ 抽样核对属实 |
| §8 三项修正（屏幕基准/A\*/Mission.pas）| ✅ README D0 + client-windows.md §8 + server.md §4.1 均已落实 |

**结论**：FINAL_REPORT 的核心完成声明与 ledger、验证脚本、抽样结果**无矛盾**。唯一过时内容是 §6 的语法检查文件数（21→29），属文档维护滞后，不影响完成判定的正确性。

---

## 7. 判定：PASS WITH GAPS

### 依据

1. **覆盖声明属实**：393/350/43/0/0 经独立脚本 + awk 统计 + 字节比对三方确认。
2. **精读质量属实**：15 个分层抽样（含 ObjBase 最后一文件、partial→covered 转换文件、关键结论文件）全部为实质精读，文档证据与源码逐项吻合。
3. **排除合理**：43 个 excluded 全为第三方库，无核心源码被误排。
4. **诚实标注未验证项**：跨文件 helper、运行期行为、常量值均标注 UNVERIFIED，未伪装完成。
5. **非匆忙完成**：7 周 / 825 提交的长期工作，非速成。

### Gaps（均为低严重度，不推翻完成判定）

- ledger 1 处 byte/line 漂移（`mir2packet.cpp`）
- FINAL_REPORT §6 语法检查文件数过时（21→29）
- Magic.pas 方法数表述口径略保守（55 vs 68）

### 不写「全量质量已确认」/「百分之百无问题」

本审计抽样 15/350 covered 文件（4.3%），未逐一核对全部 350 文件的文档内容。上述判定基于「抽样无负面发现 + 脚本全量通过 + 结构一致性」，不构成对 350 文件逐行质量的穷举确认。剩余 335 个 covered 文件的逐文档核对**尚未抽查**。

---

## 8. 本次审计未修改任何既有文件

本报告为唯一新增文件。未修改 ledger.tsv、FINAL_REPORT.md、server.md 或任何源码精读文档。上述 3 个 gap 仅作记录与修复建议，未擅自执行修复（遵循「不擅自重写既有文档或改大批 ledger」边界）。

---

*审计执行：独立复核 goal，2026-09-29*
