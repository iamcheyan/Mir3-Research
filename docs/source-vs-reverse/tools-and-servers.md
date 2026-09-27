# Preview 工具链、登录/DB 服与协议缺口（E24–E28）

> 证据源：`Source/Tools/`、`Source/LoginServer/`、`Source/DataBaseServer/`。
> 证据等级 `secondary-source`。

---

## 1. 【E28 定案】3 个 opcode 的接收端**确实不在本源码包**（已穷举验证）

### 1.1 问题回顾

`protocol.md` §2 与 `dispatch-coverage.json` 记录：
`CM_ADDNEWUSER`(2002) / `CM_CHANGEPASSWORD`(2003) / `CM_UPDATEUSER`(2004)
**在 GameServer 与登录链路都找不到接收端 `case`**。

### 1.2 **本轮穷举验证**（不是抽样，且已写成可复现工具）

验证工具：`Tools/source-read/verify_missing_opcodes.py`（独立实现，
枚举全部 C++ 分派表 + 全部 `case` 标签后判定）。

**运行结果**：

```
C++ 分派表数: 5
分派表项唯一常量: 39
case 标签唯一常量: 1

目标 opcode 检查:
  CM_ADDNEWUSER          分派表=False  case=False   ✅ 无接收端
  CM_CHANGEPASSWORD      分派表=False  case=False   ✅ 无接收端
  CM_UPDATEUSER          分派表=False  case=False   ✅ 无接收端

对照组（应有接收端的常量）:
  CM_IDPASSWORD          分派表=True  case=True
  CM_NEWCHR              分派表=True  case=False
  CM_QUERYCHR            分派表=True  case=False
  CM_WANTMINIMAP         分派表=False  case=False   ← 见下方说明

VERIFY PASS（接收端确实缺失）
```

⚠️ **工具的一个已知局限（如实记录）**：`CM_WANTMINIMAP` 在对照组显示
「分派表=False case=False」，但**它确实有接收端**（`ObjBase.pas:25170`
`CM_WANTMINIMAP: ServerGetWantMiniMap;`）—— 因为 GameServer 的 Pascal
分派是 `case ... of` 里用 **`常量:` 标签形式**（无 `case` 关键字重复），
本工具的 `case\s+CONST:` 正则匹配不到。
→ **该局限不影响目标 opcode 的结论**（那三个连定义外的任何出现都没有），
但说明**工具的「case 标签」列不完整**，判据应以「分派表 + 全文出现位置」为主。

**全仓 5 个 `g_cmdList[]` 分派表**（已全部列出）：

| 文件 | 表项 |
|---|---|
| `LoginServer/netlogingate.cpp:23` | `CM_IDPASSWORD` / `CM_SELECTSERVER` / `CM_PROTOCOL`（**仅 3 条**） |
| `LoginServer/netgameserver.cpp:16` | `ISM_USERCLOSED` / `ISM_USERCOUNT` / `ISM_GAMETIMEOFTIMECARDUSER` / `ISM_CHECKTIMEACCOUNT` / `ISM_REQUEST_PUBLICKEY` / `ISM_PREMIUMCHECK` / `ISM_EVENTCHECK` |
| `DataBaseServer/DBSvr/netrungate.cpp:17` | `CM_QUERYCHR` / `CM_NEWCHR` / `CM_DELCHR` / `CM_SELCHR`（**仅 4 条**） |
| `DataBaseServer/DBSvr/netloginserver.cpp:16` | `ISM_PASSWDSUCCESS` / `ISM_CANCELADMISSION` / `ISM_TOTALUSERCOUNT` / `ISM_SEND_PUBLICKEY` |
| `DataBaseServer/DBSvr/netgameserver.cpp:19` | `DB_LOADHUMANRCD` / `DB_SAVEHUMANRCD` / `DB_SAVEANDCHANGE` / `DB_FRIEND_*` … |

**LoginServer 里的 `case CM_` 只有 1 处**（`netlogingate.cpp:913` `case CM_IDPASSWORD:`）。

**结论**：`2002`/`2003`/`2004` 在 **5 个分派表 + 全部 `case` 语句中均不出现**。

### 1.3 全仓出现位置（**仅定义 + 客户端发送，无接收**）

| 类别 | 位置 |
|---|---|
| **定义**（5 处） | `Common/Grobal2.pas:1663-1665`、`Common/Grobal2 - 副本.pas:1404-1406`、`Tools/ImageEditor/Common/Grobal2.pas:1468-1470`、`LoginServer/protocol.h:27-29`、`DataBaseServer/Def/Protocol.h:18-20` |
| **客户端发送**（3 处） | `ClMain.pas:4211`（`SendNewAccount`）、`:4220`（`SendUpdateAccount`）、`:4236`（`SendChgPw`） |
| **接收端** | **零命中** |

→ **判定：源码包缺失接收端**（不是我们没找到）。按 Goal 要求
「源码包里找不到就明确记录『源码包缺失』，不要猜接收端」——
**本文不推测接收端逻辑**。

### 1.4 但**发送端的 payload 格式已完全解出**（可留档）

**`SendNewAccount` / `SendUpdateAccount`**（`ClMain.pas:4206-4222`）：

```pascal
msg := MakeDefaultMsg(CM_ADDNEWUSER, 0, 0, 0, 0);   // 或 CM_UPDATEUSER
SendSocket(EncodeMessage(msg)
         + EncodeBuffer(@ue, sizeof(TUserEntryInfo))
         + EncodeBuffer(@ua, sizeof(TUserEntryAddInfo)));
```

即 **6bit 编码的头 + 两个 `EncodeBuffer` 二进制块**（不是字符串）。

**`TUserEntryInfo`**（`Grobal2.pas:712-721`，注释「사용자 등록정보, logon시에 필요」
= 用户注册信息，登录时需要）：

| 字段 | 类型 | 备注 |
|---|---|---|
| `LoginId` | `string[10]` | 登录 ID |
| `Password` | `string[10]` | 密码 |
| `UserName` | `string[20]` | 用户名（`//*` 标记为必填） |
| `SSNo` | `string[14]` | **身份证号**（注释给了样例 `721109-1476110`） |
| `Phone` | `string[14]` | 电话（注释「전화 번호」） |
| `Quiz` | `string[20]` | 密保问题（`//*`） |
| `Answer` | `string[12]` | 密保答案（`//*`） |
| `EMail` | `string[40]` | 邮箱（注释显示曾是 `25`） |

**`TUserEntryAddInfo`**（`Grobal2.pas:722-`）：

| 字段 | 类型 | 备注 |
|---|---|---|
| `Quiz2` | `string[20]` | 第二个密保问题（`//*`） |
| `Answer2` | `string[12]` | 第二个答案（`//*`） |
| `Birthday` | `string[10]` | 生日（样例 `YYYY/MM/DD`） |
| `MobilePhone` | `string[13]` | 手机（样例 `<redacted-phone>`） |
| `Memo1` | `string[20]` | 备注（`//*`） |

**`SendChgPw`**（`ClMain.pas:4232-4238`）：**字符串形式**，`\t` 分隔
`id + #9 + passwd + #9 + newpasswd`。

> ⚠️ **两个 `//*` 标记的含义**：`TUserEntryInfo` 里 `UserName`/`SSNo`/`Quiz`/
> `Answer` 有 `//*`，`LoginId`/`Password`/`Phone`/`EMail` 没有 ——
> 疑似标记「**必填项**」。**未验证**（无接收端代码可对照）。

---

## 2. 【E24/E25】工具链

### 2.1 `Source/Tools/MapEdit/`（16,298 行）

| 文件 | 说明 |
|---|---|
| `MapEdit.dpr` | 地图编辑器主程序 |
| `Wil/WIL.pas` | DPR-selected `TWMBaseImages` factory for MyImage/M3Def; EdMain initializes 70 relative `WilArr` library paths as `ltLoadBmp`, with `.wil` fallback; bitmap/draw/write APIs require `WORKFILE`, whose project build setting is unverified |
| `glight.pas` | MapEdit's modal per-cell light-value dialog; `EdMain` routes light-brush clicks to the map `Light` field |
| `Tile.pas` / `SmTile.pas` | 瓦片 |
| `o_WIL.pas` | Legacy duplicate `unit WIL`/`TWMImages` component; not selected by `MapEdit.dpr` (which binds `Wil/WIL.pas`), and no `o_WIL` caller found |
| `wmM3Def.pas` | M3Def reader selected by EdMain's failed-MyImage `.Lib` → sibling `.wil` fallback; decodes WIX-indexed image rows to bitmaps and has an ARGB texture-conversion override with no MapEdit caller found |
| `wmM3Zip.pas` | MapEdit-unreferenced `TWMM3ZipImages` source; contains a sibling `.Idx` loader and compressed cached-texture path, but no WIL factory branch or caller was found; header/decompressed-length checks are missing and texture writes ignore pitch |
| `wmMyImage.pas` | Selected `.Lib` reader; `WORKFILE` gates bitmap, texture-copy, and image/index edit APIs, but the project build define is unverified |
| `wmUtil.pas` | Not imported by DPR-selected `Wil/WIL.pas`; within MapEdit, only legacy, unselected `o_WIL.pas` imports it. Its table converters, palette helpers, and zlib wrappers have no verified caller in the selected MapEdit path |
| `ObjEdit.pas` / `ObjSet.pas` / `FObj.pas` | 地图对象编辑 |
| `DoorDlg.pas` | 门编辑（对应 `Envir.pas` 的 `PTDoorInfo`） |
| `MapSize.pas` | 地图尺寸 |
| `mpalett.pas` | Legacy background-tile-group palette/attribute marks; DPR creates it, but observed EdMain populate/show calls are commented |
| `segunit.pas` / `segunit.dfm` | Legacy 3×3 segment-project selector; saves project metadata only because EdMain's `.sem` data load/save methods are commented; DPR auto-creates it, but no active form `Show` caller was located; mixed DFM parser cannot resolve the grid type |
| `HUtil32.pas` | 工具库（与 `Common/HUtil32.pas` 同源） |
| `ImgMan.pas` / `FScrlXY.pas` / `MoveObj.pas` / `About.pas` | 辅助 |

**价值**：`MapEdit/Wil/wm*.pas` 是 **`.map`/图库读写的参考实现**，
与本仓库 `Tools/maps/` 对照可验证 `.map` 解析（`server.md` §13.2 已用
`Envir.pas` 的结构定义验证过；MapEdit 侧是**写入端**视角）。

### 2.2 `Source/Tools/ImageEditor/`（26,733 行 + 62,337 行第三方）

| 部分 | 说明 |
|---|---|
| `ImageEditor.dpr` | 图库编辑器主程序 |
| 顶层 `.pas` | **非第三方部分**（图库读写、调色板、Alpha 处理等） |
| `Common/Grobal2.pas`（2,663 行） | 协议表第三份副本（`protocol.md` §1.1 已 diff） |
| `Common/EDCode.pas` | This ImageEditor copy declares unit `EDcode` and its 6-bit message/string/buffer APIs, but no ImageEditor DPR or `uses` caller was found. The GameServer project explicitly maps `EDcode` to the separate `Source/Common/EDCode.pas`; `Source/GameServer/EDCode.pas` is another same-named copy. Keep these paths distinct |
| `Common/HUtil32.pas` | 2,216-line helper copy for parsing, numeric/date/file/pointer utilities, bitmap/GDI operations and legacy high-byte text transforms. It declares the same `HUtil32` unit name as the ImageEditor root copy but has a different interface. Common `EDCode`/`MfdbDef`/`mudutil` import it; ImageEditor forms use unqualified `HUtil32`, and the DPR contains no explicit Common path binding; build/search-path resolution is unverified |
| `Common/MfdbDef.pas` | 1,192-line raw-file `TFileDB` utility with a `.db` record file and sibling `.idx`, case-insensitive in-memory key index and blank-record list; `THuman` and bag/magic/save record declarations branch on `MIR2EI`. Not selected by `ImageEditor.dpr`, and no ImageEditor `TFileDB` call was found. `Server_JOB_ItemGen.dpr` binds the separate `Source/Common/MfdbDef.pas`; no copy equivalence or mapping to current `System.db`/`Users.db` is asserted |
| `Common/DES.pas` | 独立的 `DES` 单元，含置换/S 盒表、16 轮核心及字符串/十六进制/缓冲区包装。ImageEditor 源码未找到对此路径的显式引用；`wmMyImage.pas` 使用未限定的 `DES`，而根目录 `DES.pas` 也声明同名单元。编译器单位解析未验证；与 MapEdit.dpr 显式选择的 `Source/Common/DES.pas` 保持区分 |
| **`Plug/`（62,337 行）** | ⚠️ **第三方组件，明确排除** |

**`Plug/` 排除清单**（`coverage-ledger.tsv` 已标 `excluded`）：
GraphicEx（图像格式库）· MyDirect9（DX9 封装）· pngimage · DelphiZlib。
**排除原因**：非本项目原创代码，占 Tools 的一半以上，与游戏逻辑无关。

---

## 3. 【E26】登录服 / DB 服主要实现链

### 3.1 进程拓扑（`config.md` §D4 已记录，此处补类名）

| 服务 | 入口 | 监听类 | 出向类 |
|---|---|---|---|
| **LoginServer** | `mir2wnd.cpp:420` `WinMain` | `netloginsvr.cpp` `CLoginSvr` | `netlogingate.cpp` `CLoginGate`、`netgameserver.cpp` `CGameServer`、`netcheckserver.cpp` `CCheckServer`、`netUdpsender.cpp` `CUdpsender` |
| **DataBaseServer** | `mir2wnd.cpp:411` `WinMain` | `netdbserver.cpp` `CDBServer` | `netgameserver.cpp` `CGameServer`、`netloginserver.cpp` `CLoginServer`、`netrungate.cpp` `CRunGate` |

### 3.2 网络框架：`_Oranze Library/`

| 文件 | 说明 |
|---|---|
| `netiocp.cpp` | **IOCP 网络**（Windows 完成端口） |
| `netbase.cpp` | 网络基类（`WSAStartup` 等） |
| `astar.h` | **A\* 寻路 —— 死代码**（`monsters.md` §4 已证：无任何 `#include`，仅工程文件列出） |
| `database.cpp` / `sqlhandler.cpp` | 数据库 |
| `base64.cpp` / `http.cpp` / `pop3.cpp` | 协议工具 |
| `vtimage.cpp` / `syncobj.cpp` / `bstree.h` | 图像/同步/树 |

### 3.3 协议编解码（C++ 侧）

| 文件 | 说明 |
|---|---|
| `Common/mir2packet.cpp` | 包编解码 |
| `Common/endecode.cpp` / `endecode.h` | **与 Delphi 侧 `EDCode.pas` 对应的 C++ 实现** |
| `Def/Protocol.h` | DB 服协议（`CM_ADDNEWUSER` 等定义在此） |

**`endecode.h:38` 有 `void SetPublicKey(WORD pubkey);`** ——
与 `EDCode.pas` 的 `SetPublicKey` 同签名，**印证公钥协商机制在 C++ 侧同样存在**
（`wire-format.md` §5 的链路）。

### 3.4 数据库层

| 文件 | 说明 |
|---|---|
| `DataBaseServer/Common/sqlhandler.cpp` | SQL statement generation from `MIRDB_FIELDS` descriptors; raw string-based SQL construction |
| `DataBaseServer/DBSvr/tablesdefine.cpp` + `tablesdefine.h` | legacy SQL Server player-record field metadata and packed `FDBRecord` wire model |
| `DataBaseServer/DBSvr/DBSvr.vcproj` | DB server links `_Oranze Library.lib`; standalone `Def/database.cpp` is not listed in this app project |

**Player-record SQL path**（`README.md` §3.7）：
`GameServer → DataBaseServer(GS_BPORT=6000) → ODBC → SQL Server 2000`。
These source tables do not establish a direct mapping to the repository's binary MirDB `System.db` or `Users.db`.

---

## 4. 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 账号注册协议 | 未闭合 | **定义+发送端有，接收端缺失** | — |
| 登录分派表 | 未闭合 | LoginGate 3 条 / RunGate 4 条 | — |
| 网络框架 | 未闭合 | IOCP（`netiocp.cpp`） | .NET async |
| 表定义 | 未闭合 | `tablesdefine.cpp`：legacy SQL Server player-record fields; not binary `.db` schema | Zircon MirDB persistence models; field-level mapping not established |
| `.map` 写入端 | 未闭合 | `Tools/MapEdit/` | `mapedit`（本仓库） |

**分级**：源码结论均 `secondary-source`。

---

## 5. 未验证项

| 项 | 原因 |
|---|---|
| `Tools/MapEdit/` 各文件实现主体 | 只读了文件清单与职责 |
| `Tools/ImageEditor/` 顶层非第三方实现 | 只读了文件清单 |
| DataBaseServer `DBSvr/` app and SQL path | ✅ Round 837 full-read listener, LoginServer/RunGate/GameServer handlers, save/load/create/select/delete, table mapper, SQL generator, config/UI; residual standalone `Def/` support files remain pending |
| DataBaseServer `_Oranze Library` copy | ✅ Round 837: all 64 ledgered files matched against LoginServer copies by SHA-256; 63 byte-identical to Round 836 full reads, `prime.cpp` read separately (explicit `double` cast difference) |
| DataBaseServer/Common C++ wire helpers | ✅ `endecode.cpp/.h` hash-identical to Round 835 LoginServer copies; `mir2packet.h` identical; DB `mir2packet.cpp` full-read and size guards absent |
| DataBaseServer `Common/sqlhandler.cpp/.h`, `DBSvr/tablesdefine.h` | ✅ Round 837 full read; corrected 11-table extraction has 175 active field descriptors; `fIsKey` is a generator flag, not verified SQL constraint |
| `//*` 标记的语义（必填？） | 无接收端可对照 |

---

## 6. SQL field metadata (`tablesdefine.cpp`) — legacy player-record schema (Round 828 / corrected Round 837)

> `Source/DataBaseServer/DBSvr/tablesdefine.cpp`（595 行）。
> 机器可读：[`sql-tables.tsv`](sql-tables.tsv)（11 arrays / 175 active descriptors; `//` comments excluded）。
> 提取器：`Tools/source-read/extract_sql_tables.py`；Round 837 fix preserves the first field on an array-declaration line.

### 6.1 定义格式

```cpp
MIRDB_FIELDS __ABILITYFIELDS[] = {
   { "FLD_CHARACTER", TABLETYPE_STR, true,  20 },   // name / type / fIsKey / byte width
   { "FLD_LEVEL",     TABLETYPE_INT, false,  4 },
   ...
};

MIRDB_TABLE __ABILITYTABLE = { "TBL_ABILITY",
      sizeof(__ABILITYFIELDS)/sizeof(MIRDB_FIELDS), __ABILITYFIELDS };
```

**四元组**：字段名 / 类型（`TABLETYPE_STR`/`INT`/`DAT`/`DBL`）/ `fIsKey` 生成器标志 / 字段宽度。
`fIsKey` 控制生成 SQL 的键谓词；不证明 SQL Server 实际索引/约束。表名在 `MIRDB_TABLE` 绑定。

### 6.2 **11 张表数组 / 175 字段描述**（完整源码顺序见 `sql-tables.tsv`）

| 数组 | SQL 表名 | 字段数 | `fIsKey` 字段 |
|---|---|---:|---|
| `__CHAR_INFOFIELDS` | `TBL_CHAR_INFO` | 5 | `FLD_LOGINID`, `FLD_CHARACTER` |
| `__ABILITYFIELDS` | `TBL_ABILITY` | 33 | `FLD_CHARACTER` |
| `__BONUSABILITYFIELDS` | `TBL_BONUSABILITY` | 11 | `FLD_CHARACTER` |
| `__CHARACTERFIELDS` | `TBL_CHARACTER` | **42** | `FLD_CHARACTER`, `FLD_USERID` |
| `__CURRENTABILITYFIELDS` | `TBL_CURRENTABILITY` | 11 | `FLD_CHARACTER` |
| `__ITEMFIELDS` | `TBL_ITEM` | **25** | `FLD_CHARACTER`, `FLD_TYPE` |
| `__MAGICFIELDS` | `TBL_MAGIC` | 6 | `FLD_CHARACTER` |
| `__QUESTFIELDS` | `TBL_QUEST` | 4 | `FLD_CHARACTER` |
| `__SAVEDITEMFIELDS` | `TBL_SAVEDITEM` | 24 | `FLD_CHARACTER` |
| `__SKILLFIELDS` | `TBL_SKILL` | 4 | `FLD_CHARACTER` |
| `__ITEMGIVEFIELDS` | `TBL_ITEMGIVE` | 10 | `FLD_GAMETYPE`, `FLD_SERVER`, `FLD_CHARACTER`, `FLD_DONE` |

### 6.3 关键字段组

**`TBL_ABILITY`（33 字段）** —— **角色能力值全集**：
基础（`FLD_LEVEL`/`AC`/`MAC`/`DC`/`MC`/`SC`/`HP`/`MP`/`MAXHP`/`MAXMP`/`EXP`/`MAXEXP`）
+ **重量三组**（`WEIGHT`/`MAXWEIGHT`、`WEARWEIGHT`/`MAXWEARWEIGHT`、
`HANDWEIGHT`/`MAXHANDWEIGHT`）
+ **七元素抗性 ×2 套**（`ATOMFIRE/ICE/LIGHT/WIND/HOLY/DARK/PHANTOM` 各 `_MC` 与 `_MAC`）。

> **七元素**（火/冰/雷/风/圣/暗/幻）是 Mir3 的属性体系 ——
> **`ATOM` 前缀即「元素」**，`_MC` 与 `_MAC` 是两套（魔攻/魔防？）。

**`TBL_CHARACTER`（42 descriptors）** —— 角色主记录字段；builder marks both `FLD_CHARACTER` and `FLD_USERID` as keys. Contains `FLD_DELETED` soft-delete flag, update date, DB version, map/coordinates, stats and state fields.

**`TBL_ITEM`（25 descriptors）** builder keys are `FLD_CHARACTER` + `FLD_TYPE`; source does not justify interpreting type as a standalone unique key or template table.

**`TBL_ITEMGIVE`（10 descriptors）** marks four keys: `FLD_GAMETYPE` + `FLD_SERVER` + `FLD_CHARACTER` + `FLD_DONE`.

`FLD_RESERVED1` in `__ABILITYFIELDS` is commented out; `FLD_RESERVED` in `__BONUSABILITYFIELDS` is active.

### 6.4 与仓库 MirDB `.db` 文件的边界

`README.md` §3.7 与 `CDBServer` source show the legacy network/ODBC chain:

```
GameServer → DataBaseServer(GS_BPORT=6000) → ODBC → SQL Server 2000
```

`tablesdefine.cpp` describes SQL Server record fields used by this C++ server family. It does **not** prove that these SQL tables are the repository's binary MirDB `System.db` or `Users.db` files. `System.db` contains static world data; the binary `.db` files are separate storage formats. Any mapping to `Users.db` requires independent evidence.

### 6.5 未验证项

| 项 | 原因 |
|---|---|
| `TBL_QUEST` four-field SQL record and runtime `QuestInfo` relation | table/packing code read; end-to-end SQL data mapping not established |
| `ATOM*_MC` vs `ATOM*_MAC` semantics | field names and conversion code read; meaning not established |
| `fIsKey` versus actual SQL Server primary keys/indexes | source flag only; no SQL Server schema/runtime inspection |
| legacy SQL records versus repository `Users.db` | no verified migration or one-to-one mapping |
| EI primary-static / Zircon persistence correspondence | not established by this source read |

## 7. LoginServer 业务实现（Round 835–836）

Round 835 全读 LoginServer 应用层与本目录 C++ 编码/包辅助文件；Round 836 再全读 `_Oranze Library/` 66 个文件。本轮清空了此前 90 个 pending LoginServer 条目；完整逐文件范围见 `coverage-ledger.tsv`。

### 7.1 进程入口、配置和连接

- `LoginSvr.sln` / `LoginSvr.vcproj` 标记 VS 7.10 Win32 Debug/Release 项目配置；应用层及头文件范围见台账。本轮源码读取 26 个文件：`LoginServer/LoginServer/` 的业务单元、UI/配置/结构体，以及 `LoginServer/Common/` 的线格式和 packet builder。
- `CMir2Wnd::Init` 创建窗口/工具栏/日志列表/状态栏，派生 `CLoginSvrWnd::OnInit` 从 `./LoginSvr.ini` 读取两个 ODBC DSN/账号/口令和三端口；缺配置时弹配置对话框，成功时自动发起服务启动。默认端口值在 UI 为 CS 3000、GS 5600、LG 5500。
- `CLoginSvr::Startup` 依次建日志、检查主 DSN/三端口、初始化证书哈希表、启动两个 ODBC 池、从 SQL 装载 `TBL_PUBIPS`/`TBL_SERVERINFO`/`TBL_SELECTGATEIPS`、初始化 IOCP 并监听三端口；定时器分别为计数日志 30 分钟、检查服状态 5 秒、清关闭证书 1 秒。`TID_CHECKEXPIRE` 的启动行被注释，故活动定时器不调用 `CheckAccountExpire`/`CheckDupIPs`。
- `OnAccept` 对 GameServer 与 LoginGate 用远端 IP 查询 `TBL_PUBIPS`；CheckServer 独立端口直接建立 `CCheckServer`。`OnReload` 直接再次调用 `LoadDBTables`，没有先清空三份列表；重复重载可能追加条目（源码路径事实，运行后果未实测）。已注释的 `TBL_SERVERIPS` 查询意味着 `m_listServerIP` 装载主体未活动。
- `CDBSvrOdbcPool` 默认连接数为 CPU 核数×4；`Alloc` 在锁内线性找首个空闲连接，池满则返回空。LoginServer 维护主账号池与 PC 房间池，分别用于账号与 PC 房间数据路径。

### 7.2 LoginGate：认证、计费和选服

- `CLoginGate` 的用户表以 Gate 内 `szUserHandle` 为键；Gate 协议帧以 `%...$` 分隔，数据包另含 `/#`、6bit 默认消息与解码正文。`OnUserOpen` 分配 `sGateUser` 后先发 `SM_SEND_PUBLICKEY`；`OnUserData` 只派发 `CM_IDPASSWORD`、`CM_SELECTSERVER`、`CM_PROTOCOL` 三项。协议版本需 `msg.nRecog >= 20050501`。
- `CM_IDPASSWORD` 从主账号池取 `TBL_ACCOUNT`，加载停权、失败次数、订阅/秒数、免费量与 MIR2/MIR3 分栏字段；累计失败达到 3 次或锁定时间未过返回错误。重复登录会向原 GameServer 取消准入并标记旧证书关闭。SSN 校验结果只影响已注释的响应；活动拒绝条件包括 `FLD_SECEDE`、失败/停权及 `FLD_PCHECK=3`。
- PC 房间信息从第二 ODBC 池查 `MR3_IPTable/MR3_PCRoomStatusTable`；活动代码读取房间订阅和并发数，TBL_DUPIP/TBL_USINGIP 的详细增删处理块在此方法内被注释。成功认证回 `SM_PASSOK_SELECTSERVER`（天数/小时分字段），创建 `sCertUser`，写连接日志；未订阅的路径仍回相同 opcode、零计数。
- `CM_SELECTSERVER` 按配置的服务器名找 `TBL_SELECTGATEIPS` 中的 Gate，选择 Gate 索引先递增再取项；容量判断仅在 `nMaxUserCount < currentCount` 时失败，等于上限的状态不会由该条件拒绝。选服后将认证信息发给所有同名 GameServer，再把 Gate IP/port 和认证号回给客户端。
- `sCertUser` 是服务端准入记录，含 login/IP/server、认证号、计费态、开始 tick 与关闭态。关闭记录 5 秒后由 1 秒 timer 清理。`CheckAccountExpire` 主体存在但其 timer 未启用。

### 7.3 LoginServer ↔ GameServer 与 CheckServer

- GameServer 字节帧以 `(… )` 分隔，分派表有 7 个 `ISM_*`：用户关闭/在线数/时间卡、时间账号检查、公钥请求、Premium 与 Event 检查。`ISM_USERCOUNT` 更新当前/峰值在线数并广播总人数；30 分钟计数任务写用户数日志。
- `ISM_CHECKTIMEACCOUNT` 读账号四类剩余秒数，归零则发送 `ISM_ACCOUNTEXPIRED`；成功关闭由 `ISM_USERCLOSED` 按 login ID 删除证书并通知取消准入。两个处理器虽解析 certification 字段，但实现按 login ID 查找，不比较该字段。
- `ISM_PREMIUMCHECK` 查询 `TBL_M2PREMIUMUSER` 的旗标/结束日/强制日期并组回传；`ISM_EVENTCHECK` 查询 `EVENT_COMEBACK2005`，首访写首次日期，30 天内可通过，强制 Y/N 覆盖日期判定。`ISM_REQUEST_PUBLICKEY` 回当前公钥；`ISM_GAMETIMEOFTIMECARDUSER` 处理函数为空。
- CheckServer 每 5 秒收到一个状态包，内容含 GameServer 数量、服务器名/ID/在线数及 30 秒心跳与全局 DB 错误标志推导的状态；`CCheckServer.OnRecv` 不接受应用消息。
- `CUdpsender.SendMessages` 对三个 `sockaddr` 都调用 `sendto`，返回字符串长度而不检查每次发送结果；LoginServer 构造路径当前只显式设置前两个接收地址，第三个初始化/使用结果未运行验证。

### 7.4 C++ 线格式与 UI/安全边界

- C++ `TDEFAULTMESSAGE` 含 `nRecog` 与六个 `WORD` 字段；`_DEFBLOCKSIZE=22` 是编码后消息块长度。活动 `fnEncode6BitBuf` 按位置与当前公钥字节和做 XOR 后 6bit 打包；旧版编码/解码保留但不是当前 `AttachWithEncoding` 路径。公钥、saved key、工作 key 是全局变量；`OnUserOpen` 在默认键/保存键之间切换。
- `CMir2Packet` 从 256 字节堆缓冲增长至 IOCP 上限；数值 `Attach` 用十进制字符串，`AttachWithEncoding` 用 6bit encoder。Encoder 对传入缓冲区原地改写；`fnMakeDefMessage` 只填 5 个字段而不初始化 `wEtc/wEtc2`，Gate `SendResponse` 的栈消息再编码整个 struct。两点均为源码可见边界，不代表本轮做过运行/安全测试。
- `OnInitDB` 的 UI 命令会写 PC ODBC：删除 `TBL_USINGIP`、更新 `TBL_DUPIP` 处理标志，并将 `MR3_PCRoomStatusTable` 的使用 IP 计数清零。本轮未调用该命令，也未连接或修改任何数据库。
- 本轮没有用 EI primary-static 证据推出账号校验/计费服务端语义，也没有读取 Zircon 完整账号认证处理器；只确认 C++ 服务源码路径。`CM_ADDNEWUSER/CM_CHANGEPASSWORD/CM_UPDATEUSER` 的接收端缺失仍按 §1 的穷举结果记录，不能从三个 LoginGate opcode 推定注册接收端。

### 7.5 本轮文件覆盖范围

`LoginServer/Common/`：`endecode.cpp/.h`、`mir2packet.cpp/.h` 全读；`LoginServer/LoginServer/`：`LoginSvr.sln/.vcproj`、`dbtable.h`、`dlgcfg.cpp/.h`、`loginsvrwnd.cpp/.h`、`mir2dbhandler.cpp/.h`、`mir2wnd.cpp/.h`、`netUdpsender.cpp/.h`、`netcheckserver.cpp/.h`、`netgameserver.cpp/.h`、`netlogingate.cpp/.h`、`netloginsvr.cpp/.h`、`Res/resource.h` 全读。前两份 `.cpp` 原已 covered；Round 835 扩为完整实现阅读。Round 836 全读 `_Oranze Library/` 66 个文件，见台账第 302–367 行；C++ 层没有以此替代 DataBaseServer 副本核验。

### 7.6 `_Oranze Library` 共享实现（Round 836）

- `_Oranze Library.vcproj` 是 VS 7.10 Win32 静态库项目，Release/Debug 分别输出 `_Oranze Library.lib` / `_Oranze Library_Debug.lib`；LoginSvr 项目对它作库链接。本节涉及 66 个 ledgered 文件，含库项目、网络/数据库基础设施、容器、邮件/HTTP、文件与图像封装。
- `CIocpHandler` 以 IOCP 处理 overlapped TCP send/recv，接入和主动连接各由一个 Winsock event thread 管理；默认 worker 数为处理器数×2，另可选独立 dispatcher。每连接收发缓冲上限 `IOCP_MAXBUF=32768`；接收包边界由派生 `OnExtractPacket` 决定。`CIocpObject::Send` 可合并排队 packet，未启 dispatcher 时收包在 worker 内直接拆包/调 `OnRecv`。
- `CNetBase` 初始化 Winsock 2.2；`CSockAddr` 接受点分 IP 或 `gethostbyname` 主机名。`CIntLock` 是进程内 critical section，`CInpLock` 是命名 mutex。库另含 40ms select-loop TCP/UDP handler：TCP 的默认接收是原始流切片；UDP 用包序号、ACK 窗口、RTO/重传与 Poll 连续交付，不等同 LoginServer 实际使用的 IOCP 协议实现。
- ODBC `CDatabase` 管 ODBC3 环境，`CConnection` 管连接/事务，`CRecordset` 将每列绑定到 `SQL_C_CHAR` 缓冲并按列名/序号访问；无 result column 的执行返回 row count。`EndTran` 即使 `SQLEndTran` 失败也继续重置 autocommit，最终布尔值取重置操作结果，事务失败可仅留诊断记录。另一个 `CCodeBase` 是 Sequiter CodeBase DBF wrapper，含 Insert/Delete/Pack/Compress，和 ODBC 类是两条独立路径；本轮没有调用或连接任一路径。
- 容器以指针所有权 API 为主：`CList` 双向链表，`CQueue/CStack` 派生其尾/头操作，`CIndexMap` 并行维护 hash 与遍历 list；`CMap` 各桶再用 BST。静态检查发现 `IHT_UNTOUCH` 分支把 `m_nRealSize` 设成 flag 值 1 而非 `nDemandSize`；`CFixedSizeAllocator::Init` 分配数组后未设置 `m_nCapacity`，`ConstructFreeList(0,m_nCapacity)` 得到空区间。两者属于源码缺陷，不是运行实测。
- HTTP/URL、Base64、quoted-printable、UUDecode、MIME/POP3、脚本/注册表/日期日志是同一库的工具表面；本轮并未证明它们都从登录主流程调用。`CMimeDecoder` 对传入响应按 C 字符串查找边界；非 NUL 缓冲的完整性依赖调用方。`CVtImage` 包装 Victor 库的 BIF/BMP/GIF/JPG/PCX/PNG/TGA 打开/保存和编辑；`RealizePalette` 方法体调用同名方法，源码上形成自递归；选区 `Rotate` 分支若底层旋转失败仍落到 `return true`。这些路径均未在 Windows 上运行。
- 本轮不构建 Win32 库、不启动登录服、不连接 ODBC、不调用 CodeBase，也不执行任一数据库变更 UI；保留 EI primary-static 与 Zircon 认证行为的对照边界。

## 8. DataBaseServer 实现（Round 837）

- `DBSvr.vcproj` 是 VS 7.10 Win32 应用：编译 `DBSvr/` 处理器及 `Common/endecode.cpp`、`mir2packet.cpp`、`sqlhandler.cpp`，并编译 `_Oranze Library/netiocp.cpp`；通过 `_Oranze Library.lib` 链接。`Def/database.cpp` 和 `Def/EnDecode.cpp` 不在该项目文件列表中：实际服务 ODBC 路径来自链接库中的 ODBC wrapper，线格式实现来自 `Common/endecode.cpp`，不能把同名 `Def/` API 当作当前服务实现。
- `CDBServer::Startup` 读取配置、`badid.txt`、`!serverinfo.txt` 和 `MapInfo.txt`，建 ODBC pools，连接 LoginServer，并分别接受 GameServer 与 RunGate。timer 首次请求 LoginServer 公钥并每 10 秒报在线数；LoginServer 重连后 `bRequestPublicKey` 未复位，源码不保证会再次请求公钥。
- LoginServer 成功认证时向 DataBaseServer 添加 `{ID, cert, paymode}` admission；RunGate 只接受 admission 中 ID 与 cert 均匹配的用户，随后可查询角色、创建、软删除或选择角色。字符查询按 account ID 过滤未删除记录；创建会校验名字长度/字符、禁用词、发型/职业/性别并查重。角色表插入与 quest 行插入的结果处理不一致：quest 成功可将响应置成功，即便角色插入未返回行；反之角色行成功、quest 行失败时，响应仍可保留成功值。
- 角色软删除的 SQL 条件只有 `FLD_CHARACTER`，不含 account ID；处理器检查 admission，但源码路径没有显式校验该角色属于当前 account。此为静态边界，不据此声称存在可利用漏洞。选角查询同时按角色名和 account ID 过滤；多 endpoint 时地址与端口由两个独立随机选择调用取得，存在组合不一致的源码可能。
- GameServer 收包按 `#...!` 拆帧，解出命令和正文，并以 certification 派生的六个编码字节校验 trailer；分派包括角色加载/保存和 friend/tag/relationship 操作。加载从 `TBL_CHARACTER` 取记录，再访问 magic、quest、bag、saved-item 等数据；账号库 `TBL_ITEMGIVE` 的离线金币补发路径会标记记录完成后加金币，路径未检查账号 ODBC pool 指针。能力表加载仍为注释代码。
- 保存路径要求解码记录正文为硬编码 9324 字节，开启事务并更新 character、magic、items、quest；但 `fCommit` 与 `EndTran(true)` 的结果没有共同控制最终成功响应，且部分 helper 忽略查询返回值并直接报告成功。好友/标签/关系处理器还构造 stored-procedure SQL 字符串；多个更新分支的成功响应被注释而 `returnvalue` 留为 false，`OnTagNotReadCount` 在无行时可能读取未初始化计数。均为源代码读数，未对 SQL Server 运行或写库。
- `sqlhandler.cpp` 的 `_makesql` UPDATE 生成器把 DAT 赋值写到 where 缓冲、用错误计数器生成赋值分隔符，DBL where 格式用 `%d` 接收 double；`_makesqlparam` 的 UPDATE 逗号计数和 DAT 缓冲也有相似缺陷。这里构造的是原始 SQL 字符串，不是绑定参数。`tablesdefine.cpp` 的 `fIsKey` 是 SQL 生成器内部查询条件标志，不能据此断言 SQL Server 物理主键。
- `tablesdefine.h` 是 `#pragma pack(1)` 玩家记录模型；表数组上限包括 46 个 bag item、25 个 magic、100 个 saved item。`_setrecordTBagItem` 遇到未知类型时顺序分配 bag slot 而无可见上限检查；Prefix 字段在 load/save 中显式清零而不持久化。SQL 表字段抽取器在 Round 837 修复：数组声明同一行的首个字段现在计入，`//` 后注释字段不再计入；回归测试覆盖首字段与注释字段。修正结果为 11 组、175 个活动字段描述符，不是旧报告记录的 165。
- DataBaseServer `_Oranze Library/` 64 个文件中，63 个与 Round 836 已全读的 LoginServer 副本 SHA-256 完全一致；`prime.cpp` 全读后仅见 `sqrt` 实参显式 `double` 转换差异。`Common/endecode.cpp/.h` 与 LoginServer 版本字节一致；DataBaseServer `Common/mir2packet.cpp` 的三处 `Attach` 路径缺少 LoginServer 版本的 `MIR2PACKET_MAXSIZE` 防护。细目见 coverage ledger 与 `sql-tables.tsv`。
- `CMsgFilter` 将 `%s` 读入固定 12 字节 token，且目标为 1024 项数组；源码未见逐 token 长度或项目数上限检查。配置对话框把 ODBC 用户/密码明文写入 `DBSvr.ini`，默认值含 `sa`。`CDBSvrOdbcPool` 默认按 CPU 数×8 建连接，分配在线性临界区内轮询；耗尽返回 null，重建失败会留下不可用 slot。
- 以上是 C++ 服务源码和项目文件证据，不是 EI `System.db` / `Users.db` 的生成链证据，也不推出 Zircon 运行语义。本轮未执行 Win32 构建、服务启动、ODBC/SQL 查询或数据库写入；不把源码可见缺陷描述为已运行验证的故障。

### 8.1 `Def/` 兼容与辅助源码（Round 838）

- 本轮全读剩余 14 个 pending `Def/` 文件，并将此前只记录三个注册 opcode 的 `Def/Protocol.h` 扩展为全文件覆盖。`Def/Protocol.h` 含旧版 login/game/DB opcode 和 packed records；它不同于 app 使用的 `DBSvr/protocol.h`，常量定义不等于活动接收端，`CM_ADDNEWUSER`、`CM_CHANGEPASSWORD`、`CM_UPDATEUSER` 无接收端结论不变。
- `Def/DynamicArray.cpp` 是非模板旧版 slot allocator，其两个扫描循环检查固定初始 `nIndex`；相邻 `DynamicArray.h` 则是 5000 槽模板实现，`GetData`/`DettachData` 的 `<= _MAX_USER_ARRAY` 边界允许索引越界，满表的 `AttachData` 没有返回值。两份都是源码路径，不从名称推断同一实现。
- `Def/IocpHelper` 与 `Def/ServerSockHandler` 不在 `DBSvr.vcproj` 编译列表。前者通过 `TerminateThread` 停止 accept 线程，accept 失败后仍调用 `OnAccept`；后者的 `ConnectToServer` 在 `connect` 立即成功时仍返回 `FALSE`，且头文件/实现的 `CreateIOCPWorkerThread` 签名不一致。均未在 Windows 构建或执行。
- `CStaticArray` 返回空槽时单调增加 cursor，回绕扫描使用未经 size clamp 的 cursor 上界；`CList::InsertAt` 未更新 count，`Remove`/`Search` 未保护空 comparator，析构为空而不会清理节点。`CQueue` 只是该链表的 head/tail wrapper。registry、日期/字符串和 `CCriticalSection` 文件为独立支持函数。所有问题均是静态阅读发现；除 `DBSvr/` app 和已证实链接库来源外，不把这些文件宣称为服务运行时路径。

## 9. GameServer ADO 数据子系统（Round 839）

- `Server_JOB_ItemGen.dpr` 是 GameServer 项目入口并包含 `SQLLocalDB`、`DBSQL`、`SqlEngn`。`svMain.pas` 创建 `g_DBSQL`/`SqlEngine`、启动时调用 `g_DBSQL.Connect()`；`RunTimerTimer` 在服务 ready 时调用 `SqlEngine.ExecuteRun()`。这是源码调用链，不代表本轮启动过服务。
- `SQLLocalDB.pas` 定义四类 ADO 数据 loader：StdItems、Monster、MonsterItem、Magic。`LocalDB.pas` 对这些列表调用 `Load(..., ltSQL, ...)`；连接信息文件为 `.\Setup\!DBSETUP.TXT`。虽然 API 保留 `ltFILE`，`LoadFromFile` 方法体恒返回 false。`TMonsterItemMgr` 把比较字符串拼入 `WHERE MOBNAME='...'`；`TMagicMgr` 将 `NEEDL3` 同时写入 NeedLevel[2]/[3]，训练等级固定为 3 且第 4 阶 training 值复制第 3 阶。
- `DBSQL.pas` 的 `TDBSql` 另用 ADO `SQLOLEDB.1`，连接串由 `SqlDBPassword/SqlDBID/SqlDBDSN/SqlDBLocal` globals 组成。功能集中于物品市场（`TBL_ITEMMARKET`、`UM_*` procedures）和行会据点公告板（`TBL_GABOARD`、`GABOARD_*`），不是 C++ `tablesdefine.cpp` 的玩家角色表 mapper。它与 §8 DataBaseServer 的 C++ ODBC/character path 是两个独立源码路径。
- `TSQLEngine` 用请求/响应 `TList` 队列在 SQL 工作循环与游戏 timer 间传递 market/board 操作；`ExecuteSaveCommand` 为空。`DBSQL` 通过字符串拼接执行 SQL，不用绑定参数；`AddSellUserMarket` 构造的 INSERT 列表和值列表各有尾逗号，`ReadyToSell` 对 `RecordCount >= 0` 即返回 success。公告板 insert/update 也拼接字符串；这些仅是源码检查，未连接执行或修改 SQL Server。
- 资源 ADO、market/board ADO 与 DataBaseServer ODBC 均不能证明 EI `System.db`/`Users.db` 的 upstream 或一一映射；`SQLLocalDB` 的 “Local” 名称也不证明它使用本地文件数据库。

## 10. GameServer character-record DB socket and RunGate transport（Round 840）

- `RunDB.pas` 是 GameServer 与 DB server 通信的层：`FDBLoadHuman`/`FDBMakeHumRcd` 在 `FDBRecord` 的 `DBHuman`、`DBBagItem`、`DBUseMagic`、`DBSaveItem` blocks 与运行时 `TUserHuman` 之间逐项搬运人物属性、装备/背包、技能和仓库物品。`FrnEngn.OpenUserCharactor` 调 `LoadHumanCharacter`；保存队列在 `FrnEngn.ProcessReadyPlayers` 调 `SaveHumanCharacter`；`UsrEngn` 使用转换函数准备保存记录、读入普通登录记录或 server-shift 记录。
- GameServer 以 `DB_LOADHUMANRCD`/`DB_SAVEHUMANRCD` 请求经 `FrmMain.DBSocket` 发送，`RunDBWaitMsg` 从共享接收缓存取到 `!` 完整帧后检查 certification 衍生校验尾及长度，再按 opcode/recog 解释结果；加载成功还检查返回角色名并解码 `FDBRecord`。`DataBaseServer/DBSvr/netgameserver.cpp` 将这两个 opcode 注册到 `CGameServer::OnLoadHumanRcd`/`OnSaveHumanRcd`，因此源码可闭合 GameServer↔DataBaseServer 的角色记录协议链。请求组包是字符串拼接与编码 buffer，并非 MirDB 序列化格式。
- `RunSock.pas` 是独立的 GameServer↔RunGate 客户端数据路径：`TMsgHeader` magic 为 `$aa55aa55`，接收端增量缓存并按 header length 拆帧；`GM_OPEN` 分配用户槽，首个 `GM_DATA` 在用户对象尚未建立时解析认证字段、调用 `FrmIDSoc.GetAdmission`，准入后 `FrontEngine.LoadPlayer`；加载完成后才把 `GM_DATA` 内 `TDefaultMessage` 送给 `UserEngine`。`svMain.pas` 的 timer 调 `RunSocket.Run`，其发送队列进行小包合并和基于 receive-check 的 gate 节流。
- 静态注意：`RunSock.Connect` 中 `IsValidGateAddr` 调用处被注释，因此该接入函数本身没有执行地址表 allowlist 校验；发送路径按请求字节数更新计数并释放缓冲，没有检查 `SendBuf` 返回字节数。本轮未对这些静态观察作运行验证。`RunDB` 的同步等待也未在 Windows/DB server 环境执行。
- 这条玩家记录通路与 Round 839 的资源/market/board ADO 子系统不同于同一个 socket：`RunDB`/DataBaseServer ODBC 即使映射角色记录表，也没有证明 EI `System.db`/`Users.db` 的来源或相同 schema；RunGate 传输更不涉及该映射。

## 11. GameServer interserver hub and cross-server character handoff（Round 841）

- `svMain` 按 `ServerIndex` 选拓扑：0 号服启动 `FrmSrvMsg` listener；非零服初始化 `FrmMsgClient` 指向配置的 `MsgServerAddress:MsgServerPort`。`InterMsgClient.Run` 在未连接且距 `start` 超过 20 秒时触发 `Active := TRUE`。服务端最多维护 10 个 peer socket；`SendInterMsg` 在 0 号服广播、其它服发给 master。timer 分支分别调用 `FrmSrvMsg.Run`/`FrmMsgClient.Run`。
- 线路以 `(...)` 包住 `ident/encoded-server-index/encoded-body`。双方接收端累积流片段并保留未闭合尾帧；master 收到完整帧后先转发到除来源 socket 外的其它 peer，再在本服按 opcode dispatch。处理面包括跨服登录/登出、whisper、guild/castle/recall/lover、friend/tag 到 `UserMgrEngine` 的委派、资源 reload 与 market open/close；它是 RunDB 角色数据库 socket 和 RunSock 客户端 RunGate 的第三条独立通路。
- 服务器切换的数据面另走共享文件：`TServerShiftUserInfo` 包含 `FDBRecord` 与 group/whisper/slave/status/extra-ability 等运行态字段。`UsrEngn.WriteShiftUserData` 写原始 struct 和 4-byte checksum，文件名 `$_<ServerIndex>_$_<counter>.shr`，目录根取 `Share/BaseDir`；`UserServerChange` 把目标服索引与编码文件名通过 `ISM_USERSERVERCHANGE` 送 master。目标服匹配自己的 `ServerIndex` 后读取并删除文件，按逐字节加和校验；通过后入 `WaitServerList` 并发 `ISM_CHANGESERVERRECIEVEOK`，源服据文件名置对应 `ClosePlayers` 的 `BoChangeServerOK`。等待记录超过 30 秒才清理。
- 静态风险边界：文件 writer/reader 均未检查 `FileWrite`/`FileRead` 实际字节数；reader 的 `FileOpen` 未成功时仍沿后续 checksum loop 解引用 `psui`。逐字节加和可检出部分损坏但不是强完整性校验。均未在 Windows/多服环境运行；共享 handoff `.shr` 不是 MirDB `.db`，也不证明 `System.db`/`Users.db` 映射。

## 12. GameServer `UserMgrEngine` queue bridge（Round 842）

- `svMain` 创建 suspended `TUserMgrEngine`，在 `UserEngine.Initialize` 后 `Resume`。`Execute` 循环调用 `FUserMgr.RunMsg`，捕获异常后只写通用错误文本，再 sleep 1 ms 并检查 `Terminated`。
- `InterSendMsg(stClient, ...)` 在入队前以 `GetUserInfo` 检查目标是否在线；缺失时记录错误并返回。通过后以 `SendMsgQueue1` 入队。`ExternSendMsg` 则以 `SendMsgQueue` 入队；`AddUser`/`DeleteUser` 生成 `ISM_FUNC_USEROPEN`/`ISM_FUNC_USERCLOSE` 并发往 interserver target 0。
- `OnExternInterMsg(snum, Ident, UserName, Data)` 把外部 interserver 事件包装为目标 `snum` 的 `stInterServer` 队列消息。调用点包括 `InterServerMsg` dispatch；`UserMgr` 的 friend-notify 使用 `stOtherServer`，test-server 的 DB friend-list 请求使用 `stDBServer`，`FriendSystem`/`TagSystem`/`UserSystem` 调用 `InterSendMsg`，`ObjBase`/`UsrEngn` 调用 `ExternSendMsg`。
- `svMain` 的 DB-read callback 转交给 `UserMgrEngine.OnDBRead`；该 wrapper 中 `umLock` 代码被注释。`InterSendMsg` 对 `stClient` 的 `GetUserInfo` 检查也发生在其 queue lock 之前（某些调用方可能已持锁）。这是静态锁边界，不据此断言存在 race；未作多线程运行验证。
- 队列 selector 和 DB-server message 不等同于 EI MirDB `.db`；该 wrapper 未建立 `System.db`/`Users.db` schema 或来源映射。
- `TUserMgr` 把 `ISM_FRIEND_OPEN`/`ISM_FRIEND_CLOSE`/`ISM_USER_INFO` dispatch 到目标 `Func.FInfo.OnCmdChange`。`UserSystem.TUserInfo` 的 friend-open/close handler bodies 在该 unit 内为空；`OnCmdISMUserInfo` 解析 `UserName/ConnState/MapInfo/`，重组 `UserName/MapInfo` client body，并以 `ConnState` 作为 `SM_USER_INFO.Param`（非 test-server 强制为 `0`），随后调用 `InterSendMsg(stClient, ...)`。`TUserMgr.OnSendInfoToOthers` 构造该斜线分隔正文并以 `stOtherServer` 发送 `ISM_USER_INFO`。这是静态路由，不是运行实测。

## 13. GameServer legacy hash-list, CRC, and MD5 helper（Round 844–845）

- `crc_32.pas` builds a 256-entry reflected table using `$EDB88320`; `CrcStr` starts with `c = 0`, folds each `byte(Str[i])` through `crc32`, and has no final XOR. A Python translation of that exact recurrence maps ASCII `123456789` to `2DFD2D88`, versus standard zlib CRC-32 `CBF43926`; this checks the formula only, not Pascal/Windows runtime behavior.
- `CryptMd5.pas` provides `TCrMD5` for file, byte-array, or Pascal-string inputs; `ElHashList` uses only `SourceString`. Strings are copied via `StrPCopy` with `Length(FInputString)` and no explicit encoding conversion. The byte-array worker uses a fixed 4,160-byte scratch buffer without checking input length before copy/padding; sufficiently long strings/arrays exceed that capacity. File input is read in 4,096-byte blocks. The implementation uses Intel `ROL` assembly and documents a little-endian requirement.
- `ElHashList` exposes MD5, quick-hash, and CRC32 modes. CRC/quick modes compare only the 32-bit hash value; original keys are not retained, so distinct strings with a colliding hash are indistinguishable to lookup/duplicate handling. `NoCase` uppercases before hash calculation.
- `THashInsertDupesMode` declares `himMove`, but the duplicate switch handles only ignore/raise/replace; `himInsert` and `himMove` fall through to insert a new record at `Index`. Ignore/raise paths return or raise after `New(P)` without disposing the allocation. `Delete` shifts the pointer list but does not dispose the removed hash record (nor a separately allocated MD5 digest).
- Source-reader search finds `CrcStr` only inside `ElHashList`; no non-comment `TElHashList.Create` callsite outside its constructor. FriendSystem/TagSystem/UserMgr mention that class only in comments and construct `TList`/`TStringList` instead. Other repository matches in Client/DrawHint and ImageEditor/DelphiZlib use separate CRC APIs; no equivalent runtime use is inferred.
- This legacy helper does not establish a MirDB checksum, any EI `.db` mapping, or active GameServer behavior; no Delphi build or runtime exercise was available.

## 14. GameServer `TFrontEngine` load/save queues（Round 846）

- `svMain` 创建 suspended `TFrontEngine`，完成初始化后 `Resume`；close timer 在 `UserEngine.GetRealUserCount = 0` 且 `FrontEngine.IsFinished` 时退出。`Execute` 每轮跑 `ProcessReadyPlayers` 与 `ProcessEtc`，异常只输出固定文本，sleep 1 ms 后检查 `Terminated`。
- `LoadPlayer`、`ChangeUserInfos`、`AddDBData` 分别入 ready、gold-change、DB-message lists；`ProcessReadyPlayers` 在 `fuLock` 下复制待处理列表并清空 ready/change/data lists，锁外执行工作，保存队列则保留到成功或超时删除。加载经 `LoadHumanCharacter` 得 `FDBRecord` 后交 `UserEngine.AddNewUser`；失败路径调用 forced-close，外层还调用 `RunSocket.CloseUser`。
- `UsrEngn.SavePlayer` 先以 `FDBMakeHumRcd` 组 `PTSaveRcd`，再 `AddSavePlayer`；FrontEngine 每隔超过 500 ms 重试 `SaveHumanCharacter`。若 `savefail > 20`，即使本轮保存仍失败也走删除分支、设 `hum.BoSaveOk := TRUE` 并记超时警告；这是源码中的失败放弃路径，不代表实际运行中已触发。
- `ChangeUserInfos` 经队列加载记录（传 `"1"` 作 uid/address、certify=1），仅在 `0 < Gold + ChangeGold < MAXGOLD` 时改金币并保存；成功才通知 `UserEngine.ChangeAndSaveOk`。`ObjBase` 的金币增减命令在目标不属于当前/其它服时走此路径。
- `CmdMgr` 把编码后的用户消息入 `fDBDatas`；处理端通过 `RunDB.SendNonBlockDatas` → `SendRDBSocket(0, data)` 送 DB socket。`CmdMgr` 中旧的直接发送/等待循环是注释代码。`HasServerHeavyLoad` 仅检查保存队列数量达到 1000，影响 `UsrEngn` 的角色上线与周期保存；`IsFinished` 仅检查保存队列为空，并被关服 timer 使用。
- 静态读数；未在 Windows GameServer/DB server 中运行。此队列和 RunDB character-record socket 不证明 EI MirDB `.db` 的格式或来源。

## 15. GameServer `M2Share` shared records and rule helpers（Round 847）

- Shared records include `TSaveRcd` (`FDBRecord` plus user/save bookkeeping), bounded `TReadyUserInfo` and `TChangeUserInfo`, and `TUserOpenInfo`; these are GameServer memory/queue contracts, not EI persistence declarations.
- `MAXLEVEL=101`, `MAXKINGLEVEL=61`, `ADJ_LEVEL=20`; `NEEDEXPS[1..101]` ends at 2,140,000,000. `GetBonusPoint` returns 0 through level 20, then uses per-job step formulas; `ObjBase`/`UsrEngn` consume the progression values.
- `SpitMap` and `CrossMap` are 8-direction × 5 × 5 byte masks; `ObjMon`/`ObjMon3` index `SpitMap` around creature center, while `ObjBase` uses `CrossMap` for target range. `GetNextPosition` computes a bounded endpoint only (no walkability test) and returns false only when the endpoint did not move.
- Static coordinate defect: `GetFrontPosition` and `GetBackPosition` return true unconditionally. Their diagonal up-right/down-left branches use edge predicates inconsistent with the signed coordinate updates; the front helper can step beyond the x bound, while the back helper has mismatched x/y edge tests. No map/runtime reproduction was performed. `GetNextDirectionNew` changes one old `>` comparison to `>=`; callsites include `Magic` (new) and `ObjBase` (old).
- Item helpers map wear slots to `StdMode` values (`IsTakeOnAvailable` in `ObjBase`; upgrade/cheap-item predicates and make-item lookup in `ObjNpc`). `GetMakeItemCondition` returns the stored `TStringList` from `MakeItemList`; source search found no callsites for `GetHpMpRate`, `IsDCItem`, or `GetStrGoldStr`.
- These are Preview server-source constants and helpers only; no EI primary-static or Zircon behavior was compared, and nothing here establishes an EI database schema.

## 16. GameServer `FSrvValue` runtime settings dialog（Round 848）

- `FSrvValue.pas` (1–93) exposes six timeout fields, `SENDBLOCK`/`SENDCHECKBLOCK`/`SENDAVAILABLEBLOCK`, `GATELOAD`, and two diagnostic flags. `svMain.Panel1DblClick` is the observed caller. Supporting `FSrvValue.dfm` is textual (215 lines); `dfm_parse.py tree` rejected its first bytes (`object FrmServer...`, expected `TPF0`), so the form was read with the source-reader instead.
- On OK, timeout values are capped with `_MIN(150, value)`; the three send settings use `_MAX(10, value)`; `GATELOAD` is copied directly. The DFM serializes `MinValue=0`/`MaxValue=0`; no further spin-range behavior is inferred from those stored values here.
- `svMain` reads `AvailableBlock` from `.\Setup\!Setup.txt` at startup, but the dialog save handler writes `SendBlock`, `CheckBlock`, and `GateLoad` only. An `AvailableBlock` edit changes the global in memory but is lost on restart.
- Active `RunSock` use: `SENDBLOCK` coalesces adjacent queued packets when their combined size is below the threshold; its older chunk-splitting block is commented. When `GateSyncMode=0` and `sendlen + SendDataCount >= SENDCHECKBLOCK`, a lone packet that itself reaches the threshold with no buffered bytes is deleted/freed; otherwise the gate sends `GM_RECEIVE_OK` and enters sync mode. `SENDAVAILABLEBLOCK` appears only in a commented threshold branch. `GATELOAD` schedules `GATELOAD` `GM_TEST` packets per eligible gate every 100 ms. `SendGateLoadTest` sets header length 80 and copies a local `TDefaultMessage` without visible initialization; possible indeterminate payload bytes are a static concern, not a runtime observation.
- `BoViewHackCode` has active `ObjBase` readers. `BoViewAdmissionFail` has only a commented runtime reference in the searched GameServer source; `DecLimitTime` is loaded, shown, and saved but has no active consumer found. No Preview server execution or EI primary-static/Zircon UI comparison was performed; these settings do not establish a database mapping.

## 17. Preview ImageEditor WIL/Lib authoring UI（Round 849）

- `ImageEditor.dpr` creates `TFormMain`, then the add/delete/export/conversion dialogs. Main form `FrmMain.dfm` is textual (1–1752); `dfm_parse.py tree` rejected its `object FormMain:` prefix because the parser expects `TPF0`, so geometry and controls were read with the source-reader. The form client area is 1102×789; toolbar/status/grid surround a scrollable render panel. DFM `MyDevice` and runtime `PanelDraw` use 1920×1080, windowed rendering.
- Main dispatch: the Mir3 menu opens `.wil` as `t_wmM3Def`; the custom-library menu opens `.Lib` as `t_wmMyImage`; `CreateWMImages` maps these to `TWMM3DefImages`/`TWMMyImageImages`. The 16-column grid selects and renders entries through the DX9 device. `Tool_Middle`/`Tool_Random` set layout and mouse-drag positions.
- Add/delete dialogs require an initialized, writable `TWMMyImageImages`; add supports BMP/PNG/TGA conversion plus append/insert/replace and coordinate-offset paths, while delete removes data bytes and adjusts the index list. `FrmAdd`/`FrmDel` refresh row count with `ImageCount div 6 + 1` although `FrmMain` uses 16 columns; this can over-allocate blank rows. In explicit-file import, `File_AddClick` reduces the selected path to a basename before constructing the offset sidecar path, unlike directory import; sidecar lookup may therefore resolve against the working directory.
- `FrmOut` exports indexed images as BMP, or uses D3DX BMP/PNG/TGA/DDS when its texture-export option is selected; optional `.txt` sidecars contain x/y, shadow offsets/flag, and format. If `Out_Clear` is selected, it recursively deletes the entered output directory before validating the image-index range; this destructive path was not run.
- The active WIL→Lib menu handler opens `TfrmConvertDlg`; `FrmAlpha` decodes `TWMM3DefImages` and writes `TWMMyImageImages`. The old inline converter body in `FrmMain` is commented, and the main-unit `FormatBitmap` has no active callsite in the source-reader search. `FSaveDir` is initialized to empty, with no assignment found in the ImageEditor source search; the timer's `SaveRenderToBmp` branch appears dormant.
- **Primary:** no EI primary-static editor/UI comparison was performed. **Source:** this Preview Windows authoring tool reads/writes WIL and custom `.Lib` libraries. **Difference:** no direct game-client UI/rendering correspondence is established. **Conclusion:** secondary tool-source evidence only; no EI client, Zircon, or resource-rendering equivalence is inferred.

## 18. ImageEditor DES helper and encrypted `.Lib` path（Round 850）

- `Source/Tools/ImageEditor/DES.pas` (CP949, 1–563) contains the DES IP/FP, expansion, S-box, P, PC-1/PC-2 tables and 16-round Feistel/key schedule. Keys are zero-padded to eight bytes when short; only the first eight bytes are consumed when longer. This records source behavior, not cryptographic suitability.
- `EncryStr`/`EncryStrHex` reject input ending in NUL and zero-pad to an 8-byte boundary; `DecryStr` removes all trailing NULs. `EncryStrHex` emits lowercase hex; `DecryStrHex` accepts either case, raises on invalid hex characters, and ignores a final unmatched nibble. String decrypt processes complete 8-byte blocks only; an incomplete ciphertext tail is ignored.
- `EncryBuffer` zero-fills its temporary input and allocates `nSourceLen + (8 - nSourceLen mod 8)` bytes, including an extra block for already aligned input; it writes only up to `nDestLen`, with no returned byte count/error if the destination truncates output. `DecryBuffer` processes `nSourceLen div 8` blocks, emits at most `nDestLen`, does not remove padding, and leaves any unwritten destination tail untouched. The high-level string and buffer padding/length contracts differ.
- `ImageEditor.dproj` defines `WORKFILE` in Debug and Release. `WIL.TWMBaseImages` initializes `FPassword` to empty and exposes it as a writable property; no active password assignment was found in the ImageEditor source search. `TWMMyImageImages.Initialize` sets `FCanEncry` only for version 1 with a nonempty password, then checks an 8-byte marker through `DecryBuffer`.
- `FormatImageInfo` stores width/height with a shifted value plus a random low nibble and shifts them back on read. Its DES gate checks `FCanEncry and (FPassword = '')`, opposite the nonempty-password initialization condition; under an unchanged initialized password that predicate is false. `FormatDataBuffer` instead gates on `FCanEncry`, `BufferLen >= 128`, and a nonempty password, then processes exactly the first 128 bytes. No claim is made about externally changing the public password property.
- In `FrmAdd`, append uses `AddDataToFile(ImageInfo, ...)`, which calls both format helpers. Insert/replace stage already formatted metadata and later use the offset-only writer; the searched `FrmAdd` path has no `FormatDataBuffer` call. These are source-level branch differences; no `.Lib` was opened or written.
- ImageEditor-scoped search found no external use of the string/hex APIs; buffer calls are in `wmMyImage`. Separate `ImageEditor/Common/DES.pas` and `Source/Common/DES.pas` files exist; the latter declares `PAnsiChar` buffer parameters versus local `PChar`. `MapEdit/Wil/wmMyImage.pas` and `Client/wmMyImage.pas` contain similarly named buffer calls, but their resolved DES copies/implementations were not compared. No EI primary-static, protocol, MirDB, or cryptographic-equivalence conclusion follows.

## 19. ImageEditor embedded BASS payload and loader reachability（Round 851）

- `DLLFile.pas` (CP949, 1–4977) is almost entirely `BassData: array[1..98872] of BYTE`; its leading bytes form an MZ/PE image with machine `0x014C` (I386). The embedded version resource strings identify BASS 2.4.3. Pascal code declares `BassDLL`, writes the array to a `TMemoryStream`, calls `BassDLL.Load`, then frees the stream; finalization frees the loader.
- Supporting `DLLLoader.pas` code manually maps 32-bit PE headers/sections with `VirtualAlloc`, handles selected base relocations, resolves imports via `LoadLibrary`/`GetProcAddress`, applies section protections, calls the image entrypoint with `DLL_PROCESS_ATTACH`, and builds an export lookup. `Unload` calls process detach, releases mapped sections and external imports, and frees the image.
- `DLLFile` ignores the Boolean returned by `BassDLL.Load`. `TDLLLoader.Destroy` and `Unload` test `@DLLProc <> nil` rather than whether the function pointer is assigned; if loading fails before setting the entrypoint, finalization can attempt to call a nil procedure pointer. Static control-flow finding; not executed.
- Reachability is not established: source-reader search across `Source` found `DLLFile`/`BassDLL` references only in `DLLFile.pas`; `ImageEditor.dproj` does not list `DLLFile.pas`, `DLLLoader.pas`, or `Common/bass.pas` in its DCC references. `Common/bass.pas` declares `external bass.dll` BASS functions, but ImageEditor-scoped search found declarations and no BASS callsites; these declarations are not wired to the in-memory `BassDLL` object.
- Full `DLLLoader.pas` (CP949, 1–1134) defines packed PE32 records and checks MZ, PE signature, and machine `$14C`; it does not validate that the file-declared optional-header size fits the fixed record. Image/header/section `VirtualAlloc` results are not checked. `ReadSections` can exit on a short read before freeing its temporary section-header buffer.
- `ProcessRelocations` applies ABSOLUTE/HIGH/LOW/HIGHLOW; HIGHADJ and MIPS branches are empty, and other types are not rejected. `ProcessImports` does not validate `LoadLibrary` handles or `GetProcAddress` results; `ProtectSections` ignores `VirtualProtect` results. `InitializeLibrary` invokes the converted entrypoint without checking it is assigned. `Load` returns success only after the staged pipeline, but does not unwind partial state when a stage returns false.
- `ProcessExports` builds the name trie. Named forwarders call `GetProcAddress`; the ordinal-forwarder branch converts the parsed ordinal as an image RVA and does not assign the export function pointer. `FindExport`, `FindExportPerIndex`, and `GetExportList` have declarations/definitions only in `DLLLoader.pas`; source search found no consumer outside this unit.
- `Unload` initializes its Boolean result to false and never changes it; it does not clear `DLLProc` or `ImageBase`, so repeated unload is not guarded. The `@DLLProc` address test in `Destroy`/`Unload` is not an assigned-procedure check and can call a nil entrypoint after a failed load. These are static source findings; the loader was not executed.
- **Primary:** no EI audio/resource comparison. **Source:** embedded Preview BASS image and manual loader unit. **Difference:** the observed ImageEditor project/source references do not connect the payload or BASS declarations to an application callsite. **Conclusion:** record as unlinked source payload, not evidence of active ImageEditor audio or EI behavior; no runtime or security assessment.

## 20. ImageEditor file-drop group component（Round 853）

- `DropGroupPas.pas` (CP949, 1–114) defines `TDropFileGroupBox`, with a `TStringList` allocated in its constructor and freed in its destructor. `AutoActive` defaults true; `CreateWindowHandle` calls `DragAcceptFiles(Handle, TRUE)`. `WMDropFiles` gets the count from `Msg.Drop`, clears and refills `Files` using a fixed `MAX_PATH` buffer, and invokes `OnDropFile(Self)` only when at least one name was collected. `Files` exposes the mutable list through a read-only property.
- Win32 contracts: [`WM_DROPFILES`](https://learn.microsoft.com/en-us/windows/win32/shell/wm-dropfiles) supplies an `HDROP`; [`DragFinish`](https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-dragfinish) releases that drop data; [`DragAcceptFiles`](https://learn.microsoft.com/en-us/windows/win32/api/shellapi/nf-shellapi-dragacceptfiles) controls whether a window accepts drops. The source's `ChangeActive(FALSE)` calls `DragFinish(Handle)` (a window handle, not the `HDROP`) instead of disabling with `DragAcceptFiles(Handle, FALSE)`. `WMDropFiles` queries `Msg.Drop` but never calls `DragFinish(Msg.Drop)`, leaving the message's drop data unreleased. These are source/API-contract findings; not runtime-tested.
- Reachability: `FrmAlpha.pas` imports `DropGroupPas`, but ImageEditor-wide search finds no `TDropFileGroupBox` or `OnDropFile` use outside this unit. The full `FrmAlpha.dfm` (1–232) contains no drop-group instance/event, and `FrmAlpha.pas` has no drop handler. **Primary:** no EI file-drop comparison. **Conclusion:** a helper implementation exists, but no active ImageEditor dialog drop path is established.

## 21. ImageEditor HUtil32 utility behavior and call boundaries（Round 854）

- `HUtil32.pas` (CP949, 1–2682) exports string, file, numeric, geometry, bitmap, and bitfield helpers. Non-comment source callsites in root-level ImageEditor units include `FrmAdd`, `FrmMain`, `FrmAlpha`, `WIL`, `wmM3Def`, `wmMyImage`, and `FrmOut`; the matching unit resolution was not verified by a Delphi build, and no application run was performed.
- `GetValidStr3` (1065–1143) scans a delimited token into a fixed local `Buf[0..$7FFF]`, returns the remaining suffix, and resets both outputs to empty for input length ≥ `$7FFF-1` or a caught exception. `FrmAdd` splits five X/Y/shadow-offset values from UI text and the first sidecar line (397–401, 420–424, 576–580). `FrmMain` splits a menu hint and passes the bracketed file-type text through `ArrestStringEx` (879–882).
- `ExtractFileNameOnly` (674–688) calls `ExtractFileName` to isolate the basename, then removes the extension using the first `Pos(ext, fn)`. Callers build `.txt` sidecar names in `FrmAdd`, conversion output names in `FrmAlpha`, and `.WIX` paths in `wmM3Def`. `SafeFillChar` (190–209) is a three-overload `FillChar` wrapper; callers clear zlib state, texture surfaces/pixels, and a `TWMImageInfo`. `SpliteBitmap` (2303–2359) builds monochrome masks and combines them with `BitBlt`; `WIL` calls it with transparent color `$0`.
- Static edge cases in helpers with no external ImageEditor caller found: `FileSize` returns `FindFirst`'s size or `-1` but does not `FindClose` its search record (741–749); `GetMonDay` overwrites the accumulated year/month string when month or day is at least 10 (2533–2548); `ReplaceChar` and `IsUniformStr` iterate string indexes from `0` through `Length-1` (1755–1784); `BoolToCStr` has an empty body (349–352). Top-level `FileCopy`/`FileCopyEx` and `GetFileDate` likewise have no caller found in the inspected ImageEditor paths. The `Common/HUtil32.pas` copy is kept separate; `Common/MfdbDef.pas` references that copy, not evidence of calls to this top-level unit.
- **Primary:** no EI helper or bitmap implementation comparison. **Source:** Preview ImageEditor utility unit and the callsites above. **Difference:** static utility code does not establish a live application path for uncalled helpers. **Conclusion:** source-only behavior; no EI equivalence, runtime, or Delphi compiler behavior inferred.

## 22. ImageEditor MyCommon version and Windows-system helpers（Round 855）

- `MyCommon.pas` (CP949, 1–526) defines packed version records, file-time/date conversion, Windows version-resource access/update, process-window lookup, CPUID and IDE-drive serial helpers. Source-reader finds `MyCommon` imported by `FrmMain.pas` and `ZShare.pas`; only `GetFileVersion` has an external helper callsite. `ZShare` declares `g_FileVersionInfo: TFileVersionInfo`; `FrmMain.FormCreate` calls `GetFileVersion(ParamStr(0), @g_FileVersionInfo)` and appends `sVersion` to `MAINFORMCAPTION` (FrmMain.pas:357–364). `FrmMain.dfm:16` binds `OnCreate = FormCreate`. The Boolean result is ignored; this remains static evidence, not an application run.
- `GetFileVersion` (304–331) zeroes the output record, gets the executable version resource, queries the fixed-file-info root, and extracts four MS/LS version words into `wMajor/wMinor/wRelease/wBuild` and `sVersion`. It returns false for a nil output pointer, missing resource, failed resource/query call; `FormCreate` does not branch on that result.
- `GetFileVersionInfomation` (333–394) reads localized string fields and optional custom fields; it does not check most `VerQueryValue` results, size `Info.UserDefineValues`, or protect `VersionInfo` with `try/finally`. `GetFileVerSionInfoByNameW` also uses translation/string query outputs without checking both query results. `SetFileVerSionInfoByNameW` edits a queried wide-string buffer with `Move((Length(sValue)+1)*2)` without checking that replacement length fits the queried value span (`dwSize2`, lines 71–98). No callsite for these version-resource helpers was found.
- `FileTime` (122–133) converts a search record's last-write FILETIME through local time and DOS date/time, but performs conversion even if `FindFirst` failed, leaving `LocalFileTime` uninitialized on that branch. `CovFileDate` converts FILETIME to local `TDateTime` (285–293); `DateTimeToGMT` subtracts eight hours, replaces localized date abbreviations, and appends `GMT` (251–274). No callers for these date helpers were found.
- `GetHandleByFileName` enumerates processes, opens each with `PROCESS_ALL_ACCESS`, compares the executable path, and returns the first visible/enabled window; snapshot/API results are not consistently checked (185–246). `GetCpuID` passes the sum of CPUID leaf-1 slots 1, 3, and 4 to `IntToHex(..., 8)`; its no-CPUID branch initializes slots 1 and 4 but still includes slot 3 in the sum (137–183). `GetIdeSerialNumber` requests `\\.\PhysicalDrive0` or `\\.\SMARTVSD`, issues an IDE identify control request, byte-swaps the sector serial field, and swallows exceptions as an empty result (396–523). These helpers have no external ImageEditor caller found and were not executed.
- `dfm_parse.py tree` rejects `FrmMain.dfm` because it is text (`object FormMain:` rather than a `TPF0` binary marker); source-reader confirms the `OnCreate = FormCreate` binding at line 16. **Primary:** no EI version/resource/helper comparison. **Source:** Preview `MyCommon` implementation, the form callsite, and DFM binding. **Difference:** a static binding and method-body call do not prove runtime; other helpers remain unreferenced. **Conclusion:** no hardware identifier, process scan, resource update, Delphi build, or EI behavior was exercised.

## 23. ImageEditor MyD3DX9 Direct3DX declarations and export caller（Round 856）

- `MyD3DX9.pas` (CP949, full 1–11277) is a Pascal D3DX9 binding adapted from the listed D3DX9 header family; its header identifies `D3DX9.par` v1.32 dated 2006-10-29. `interface` spans lines 53–10415, and the Pascal `implementation` starts at 10416. It imports `Windows`, `ActiveX`, `SysUtils`, `MyDirect3D9`, and `MyDXTypes`, plus `include\DirectX.inc`; the project `.dproj` selects `DCC32` and lists both the project-root and `Plug\MyDirect9` unit/include search paths.
- External D3DX APIs use `stdcall`; COM declarations derive from `IUnknown` and declare `stdcall` methods. The unit maps math/core/shader/effect/mesh/shapes/texture/animation API groups through DLL aliases; `d3dx9MicrosoftDLL` and the debug alias both name `d3dx9_31.dll`, `D3DX_SDK_VERSION` is 31, and `D3DX_VERSION` is `$0902`. Separate-DLL aliases are present in text, but the enabling define is commented out and `D3DX_SEPARATE` is undefined before the aliases, so the checked source configuration selects the monolithic DLL. The implementation section supplies Pascal-side math/value helpers and the DDS-mip/TX-version macros; it is not an implementation of the external D3DX API.
- Source-reader search finds root-unit imports in `FrmAdd.pas` and `FrmOut.pas`. `FrmAdd`'s `D3DXCreateTextureFromFile` sample is commented. `FrmOut.SaveTextureToFile` calls `D3DXSaveTextureToFile` with a nil palette for BMP, PNG, TGA, or DDS (299–322); the routine is reached from the alpha-export path both after successful `CopyDataToTexture` and after constructing an empty texture on failure (183–202). The returned `HRESULT` is ignored. The default `PChar` binding names the ANSI `...A` export.
- The separate `Plug/MyDirect9/include/MyD3DX9.pas` path is ledgered as excluded third-party package content; this round covers only the root ImageEditor unit. The project lists both root and package search paths, but no Delphi build was run to establish unit resolution or ABI compatibility, and DLL deployment/presence was not checked. **Primary:** no EI D3DX binding or rendering comparison. **Source:** declarations, helper implementations, project settings, and the above textual callsites. **Difference:** imports and declarations do not prove successful linking or runtime rendering. **Conclusion:** source-level D3DX9 binding/export path only; no runtime, Delphi compiler, or EI behavior inferred.

## 24. ImageEditor WIL base/cache, texture readers and zlib paths（Round 857）

- **Scope:** source-reader read `Source/Tools/ImageEditor/WIL.pas` in full (1–523, CP949+mixed), then searched `Source` for the factory/class names and searched ImageEditor for cache, texture, compression, and edit callsites. Supporting excerpts came from `wmM3Def.pas`, `wmMyImage.pas`, `FrmMain.pas`, `FrmOut.pas`, `FrmAdd.pas`, `FrmDel.pas`, `FrmAlpha.pas`, and `ImageEditor.dproj`; the subclass files remain separately pending in the ledger. Debug and Release both define `WORKFILE`; no Delphi build, ImageEditor run, EI primary comparison, or archive write was performed.
- **Factory and lifecycle:** `ImageEditor.dpr` includes the root `WIL.pas`; `CreateWMImages` dispatches `t_wmM3Def` to `TWMM3DefImages` and `t_wmMyImage` to `TWMMyImageImages`. `TWMBaseImages` defaults to `ltUseCache` and read-only; under `WORKFILE`, `Initialize` opens read/write only when `FReadOnly=False`. `TWMMyImageImages.Create` clears read-only, while `TWMM3DefImages.Create` keeps it true. The observed main and conversion opens explicitly set `LibType=ltLoadBmp`; `InitializeTexture` only allocates an array for `ltUseCache`.
- **Cache reachability:** `Images[index]` routes through `GetImageSurface` to `GetCachedImage`, which rejects non-cache mode, invalid indices and uninitialized objects, lazily calls `LoadDxImage`, and catches decoder exceptions by clearing the surface and marking `boNotRead`. `TWMMyImageImages` overrides `LoadDxImage`; `TWMM3DefImages` inherits the base implementation, which only clears the surface and marks it unreadable. `FreeTextureByTime` evicts entries older than the configured surface age when automatic cleanup runs. ImageEditor-scoped searches found no external `Images[]`, `GetCachedImage`, `DrawZoom`, or `DrawZoomEx` caller; observed open paths use `ltLoadBmp`, so this cache route is not the active grid/export path, and the M3Def subclass has no cache decoder override.
- **Format readers and texture path:** `TWMM3DefImages.Initialize` reads the WIL header and initially sets `FNewFmt` from `VerFlag=5000`; `LoadIndex` then derives the final flag from the WIX signature (`$B13A0000`) and chooses a 24- or 28-byte offset-table start. It loads a sibling `.WIX` and initializes the optional cache; its bitmap and direct-texture paths use the M3Def run decoder. `TWMMyImageImages.Initialize` reads its library header and index list; its bitmap, cache and direct-texture readers decompress image data and convert among the declared 16-bit formats and `A8R8G8B8`. Compressed index data is accepted only at `ImageCount*4+40` bytes, with offsets copied after ten 32-bit prefix words; `OffsetSize=0` selects the raw offset-list path. Both format readers reject dimensions outside 2–4095; the MyImage readers also reject nonpositive image-data lengths. `MakeDXImageTexture` sets size, pattern size and mapped WIL format, activates the DX9 texture, and frees it if activation fails.
- **Observed editor callers:** `FrmMain.OpenWMFile` constructs the selected subclass, sets `ltLoadBmp`, and initializes it. Grid cells request `Bitmap[index]`; selecting a cell calls `CopyDataToTexture`. WIL→Lib conversion in `FrmMain` and `FrmAlpha` reads M3Def bitmaps and writes the MyImage library; add/delete dialogs require a writable `TWMMyImageImages` and update/save its index list. `FrmOut` uses `Bitmap[index]` for ordinary export and `CopyDataToTexture` for the alpha/D3DX path. No runtime writes were exercised.
- **zlib contract:** `ZIPCompress`/`ZIPDecompress` grow output buffers, shrink successful output to `strm.total_out`, and return that byte count. Negative zlib results raise an internal exception, but each wrapper catches failures, frees the output, sets it to nil, and suppresses the exception; the returned integer is not reset on that failure path. `ZIPCompress` is called by the FrmAdd/FrmAlpha/FrmMain data encoders and MyImage index writer; ImageEditor `ZIPDecompress` callsites are in `wmMyImage.pas` image and offset-index readers. `SaveIndexList` explicitly falls back to an uncompressed offset list when compression returns nil.
- **Static edge conditions:** MyImage bitmap/cache/direct-texture paths do not check `outBuffer` after `ZIPDecompress` before reading or copying it; a decompression failure can therefore reach a nil-buffer access in those paths (the cache wrapper catches exceptions, but direct bitmap/texture calls do not add that guard). In `TWMM3DefImages.LoadIndex`, a `FileOpen` handle is opened before a second `CreateFile` mapping handle and no `FileClose(fhandle)` appears; local `POffsetIndex` is allocated only inside the mapped-file-size condition but is consumed by the following loop and `FreeMem` outside that condition. These are source-level failure-path risks, not reproduced faults. `MAXIMAGECOUNT` occurs only as a declaration in this ImageEditor scope; no enforcement was found. `AddIndex` permits `nIndex=Count` but does not reject values below `-1` before passing them to `TList.Insert`.
- **Identity and limits:** source-wide search found separate same-named WIL units under `Source/Tools/MapEdit/Wil/`, legacy `Source/Tools/MapEdit/o_WIL.pas`, and `Source/Client/`; this round did not compare those implementations. Only the ImageEditor root `WIL.pas` is covered here; supporting subclass excerpts do not complete their pending full reads. **Primary:** no EI cache/decoder comparison. **Conclusion:** Preview ImageEditor source behavior only; no Delphi compiler, runtime, `.wil`/`.Lib` mutation, EI equivalence, or Zircon behavior is established.

## 25. ImageEditor ZShare shared state, shell helpers and mapped-file edits（Round 858）

- **Scope:** source-reader read `Source/Tools/ImageEditor/ZShare.pas` in full (1–442, CP949). `ImageEditor.dpr` includes the unit; source-reader finds imports in `FrmAdd`, `FrmAlpha`, `FrmDel`, `FrmMain`, `FrmOut`, `wmM3Def`, and `wmMyImage`. Supporting excerpts came from those callers and `ImageEditor.dpr`; no sibling file was thereby marked fully read. No Delphi build, ImageEditor run, primary comparison, or library write was performed.
- **Shared state:** `g_WMImages` is the active library reference; `g_OldWMImages`/`g_NewWMImages` are used by the WIL→Lib conversion path. `g_SelectImageIndex` starts at `-1`; selection updates it and refreshes `g_TextureInfo`/`g_WILColorFormat`. `g_Texture[0..1]` are shared by main drawing/export paths. `FrmMain.FormCreate` reads the `256RGB` palette resource into `g_DefMainPalette`, gets `g_FileVersionInfo` and appends its version to `MAINFORMCAPTION`, and records the custom blend-item index. Main-form open dispatch reads/sets `g_WILType`. Shared color defaults feed drawing and conversion; `IMAGEOFFSETDIR='Placements\'` is used for per-image sidecars. Add-folder handlers set mutually exclusive `sBrowseForFolder`/`sBrowseForAllFolder` modes, and `g_boWalking` guards conversion while its `try/finally` restores the flag. Initialization zeroes `g_TextureInfo` and sets all 16 private custom colors to white; the unit's finalization section is empty.
- **Helper reachability:** `RGB2TColor` packs R/G/B into low-to-high bytes; `TColor2RGB` extracts those channels, and `RGB16` packs 5:6:5 components. The latter two are used in M3Def/MyImage conversion routines. `DisplaceRB` swaps the low/high color bytes and has `FrmAlpha`/`FrmMain` callsites; `MyDXBase.pas` contains a distinct same-named `stdcall` routine, and unqualified symbol binding was not compiler-verified. ImageEditor search found no external caller for `RGB2TColor`, `GetSysColor`, or ZShare's `CountDiffPixels`/`CountSamePixels`; `GetSysColor` actually opens `ChooseColor`. `Plug/GraphicEx/GraphicCompression.pas` defines and calls its own pixel-count routines, not ZShare's exports.
- **PNG and folder selection:** `LoadPNGtoBMP` catches `LoadFromStream` exceptions and returns `False`; on success it assigns the PNG to the destination and copies explicit alpha rows for RGBA/grayscale-alpha formats. Exceptions during `AssignTo` or alpha-row copying bypass its trailing `Image.Free`. `FrmAdd.LoadFileToBmp` selects this helper by PNG signature, ignores its Boolean result, and continues with the already-created bitmap. `BrowseForFolder` is used by the add-folder and output-folder dialogs; it does not initialize its path buffer, check the shell return values, or visibly free the returned PIDL. `SelectDirectory` is used by both `FrmAlpha` directory pickers with an empty `Root`; it frees the selected PIDL and its buffer, but ignores shell path/root parse statuses and does not free a non-nil root PIDL on the optional non-empty-Root path.
- **Search and file mutation:** `DoSearchFile` is called by `FrmAlpha.GetSourceList` for `.Wil`; it enumerates only `Path + '*.*'` (its nested `IsDir` is unused), pumps `Application.ProcessMessages`, and sets `Result := True` even when `FindFirst` fails or no files match; `FindClose` is unconditional. `RemoveData`/`AppendData` are called by add insert/replace and delete paths, whose callers ignore the Boolean. Both helpers set `Result := True` without checking `FileOpen`, mapping, or copy results; offsets/sizes are not fully validated, and pointer arithmetic casts the mapped address through `LongInt`. `RemoveData` also ignores seek/truncation results, shifts the tail left, and truncates; `AppendData` maps a larger extent and shifts the tail right. These are static failure-path observations, not exercised corruptions.
- **Primary/source boundary:** this unit describes Preview ImageEditor shared state and helper paths only. No EI primary-static counterpart, Delphi compile-time unit resolution, UI execution, or `.wil`/`.Lib` mutation was verified; do not infer original EI helper or client behavior.

## 26. ImageEditor M3Def WIL index and run decoder（Round 859）

- **Scope and identity:** source-reader read `Source/Tools/ImageEditor/wmM3Def.pas` in full (1–460, CP949). `ImageEditor.dpr` and `.dproj` explicitly include/reference this root unit; `.dproj` selects `DCC32` and defines `WORKFILE` in Debug and Release. Supporting excerpts came from the root `WIL.pas`, `FrmMain.pas`, `FrmAlpha.pas`, and `FrmOut.pas`. Source-wide search also found `Source/Tools/MapEdit/Wil/wmM3Def.pas` and `Source/Client/wmM3Def.pas`; neither copy was compared or treated as the ImageEditor implementation. No Delphi build, runtime, primary comparison, or archive write was performed.
- **Format selection and index:** `TWMM3DefImages` keeps the WIL input read-only. `Initialize` calls the base opener, reads the WIL header without checking its read count, gets `ImageCount`, and initially sets `FNewFmt` from `VerFlag=5000`; active `LoadIndex` then reads the sibling `.WIX` count at byte 20 and signature at byte 24, re-derives `FNewFmt` from high word `$B13A`, and selects a 24-byte old or 28-byte new offset-table start. A passing table-size check copies offsets into `FIndexList` and replaces `FImageCount` with the WIX count; the WIL and WIX counts are not cross-checked. Image records read all but their trailing 32-bit `VerFlag` for old format and the full record for new format.
- **Active decode paths:** `Decode` is a word-run decoder: each row starts with a 16-bit encoded-length word; `$C0` advances over a transparent run in the pre-zeroed output, while `$C1`–`$C3` copy the following word run. Unknown tags return `False`. The active implementation does not branch on `FNewFmt` or enforce source bounds, decoded row width, or run count against the destination. The commented-out older `Decode` contains the `FNewFmt`-dependent two-row adjustment and clipping logic; a separate commented `LoadIndex` is also inactive. The active bitmap reader decodes to `pf16bit` and substitutes `g_OutBackColor` for zero words. Direct texture output sets `D3DFMT_A8R8G8B8`; zero words become alpha 0 and nonzero words alpha 255.
- **Lifecycle and callers:** `Finalize` clears the offset list and delegates to the base finalizer, which resets initialization, frees cache surfaces, and closes the WIL stream; the subclass destructor adds no cleanup before inherited destruction. The main grid invokes virtual `CopyDataToTexture`; `FrmOut` uses that path for alpha/texture export and `Bitmap[index]` for ordinary export. `FrmMain`/`FrmAlpha` WIL→Lib conversion retrieves `Bitmap[index]`; those conversion excerpts catch retrieval exceptions and represent nil as a missing output index. The base `GetImageBitmap` directly dispatches to `GetImageBitmapEx` without an exception guard; the inspected grid/ordinary-export callers add none. `NewFmt` also drives the main status-bar old/new-format label.
- **Static failure boundaries:** active `LoadIndex` opens a `FileOpen` handle that is not closed. It reads fixed WIX offsets 20/24 before validating that the mapped file is large enough, and the offset pointer is allocated only inside a later size condition but read and freed outside it; `FImageCount` may still be the WIL-header count. Once `fhandle>0`, it sets `Result := True` even if `CreateFile`, mapping, view, or the table-size check failed, so `Initialize` can proceed with an unusable list. `CopyDataToTexture` checks the seek position, but both decode paths ignore image-header read counts and derive `ReadSize` from unbounded `dwImageLength * 2`; `GetImageBitmapEx` also ignores the seek result. The texture copier addresses rows by `Texture.Width` rather than `Access.Pitch` and does not validate decoded run totals. These are static source risks, not reproduced corruptions.
- **Primary/source boundary:** only the Preview ImageEditor root unit and its textual callers are covered. No EI WIL decoder comparison, Delphi build, runtime render, or `.wil`/`.wix` read/write validation was performed; no behavior is inferred for the separate MapEdit/Client copies or EI client.

## 27. ImageEditor MyImage `.Lib` reader, texture conversion and index editing（Round 860）

- **Scope and identity:** source-reader read `Source/Tools/ImageEditor/wmMyImage.pas` in full (1–745, GB18030). Root `WIL.pas` dispatches `t_wmMyImage` to this class; `ImageEditor.dproj` selects `DCC32` and defines `WORKFILE` in Debug and Release. Source-wide search also found `Source/Tools/MapEdit/Wil/wmMyImage.pas` and `Source/Client/wmMyImage.pas`; neither copy was reconciled. No Delphi build, UI/runtime, EI primary comparison, or `.Lib` read/write was performed.
- **Header and optional encryption:** `Initialize` reads `TWMImageHeader` without checking the read count, treats `nVer=1` as the encryption-capable version, and enables `FCanEncry` only when a nonempty `Password` decrypts the 8-byte marker to `lom2com`; a marker mismatch disables that flag but does not itself fail initialization. `FormatHeader` rebuilds `IndexOffset` from the high words of `IndexOffset1/2`; WORKFILE writes split the offset across those fields with randomized low words. `FormatImageInfo` stores dimensions as `(dimension shl 4) | random-low-nibble` and shifts them right on read. `FormatDataBuffer` decrypts/encrypts only the first 128 payload bytes when `FCanEncry`, a nonempty password, and payload length ≥128. The separate metadata `EncryBuffer`/`DecryBuffer` guard requires an empty password, while the observed initialization path requires a nonempty password to set `FCanEncry`; no caller configures `Password` in the normal open path (the only main-form assignment is commented).
- **Index layout and writes:** `LoadIndex` resets the list/count, sets a nonpositive header offset to `SizeOf(FHeader)` and returns with zero images, caps positive `OffsetSize` at 50 MiB, and chooses `ImageCount2` only for `FCanEncry`. `OffsetSize>0` decompresses an index and accepts exactly `ImageCount*4+40` bytes, copying offsets after ten 32-bit prefix words; zero/negative `OffsetSize` takes a raw `ImageCount*4` read. The index seek result is ignored; table reads require an exact byte count, but count multiplication and file extents are not bounded. `SaveIndexList` writes the table after the last positive record; the compressed form allocates ten prefix words but does not initialize them before filling the following offsets, and the raw fallback writes the offset list. Stream write/seek results are ignored; it returns true for a nonempty list regardless of write counts and does not serialize an empty index. `AddDataToFile` updates list/count/append position after a successful seek but does not check write counts; its offset overload has the same unchecked write, and the editor callers ignore both return values.
- **Image conversion paths:** `LoadDxImage` is the optional base cache route; the observed main open sets `LibType=ltLoadBmp`, so that cache path is not selected there. It reads metadata and compressed payload, applies `FormatDataBuffer`, then calls `ZIPDecompress` and `CopyImageDataToTexture`; it does not set `FLastColorFormat` before that helper, although the helper selects its RGB565 branch by reading that field. WORKFILE bitmap retrieval supports A4R4G4B4, A1R5G5B5, R5G6B5 and A8R8G8B8; RGB565 magenta word 63519 becomes the configured background color. Direct-texture R5G6B5 instead maps word 63519 to transparent alpha and converts other words to ARGB; texture mode initializes dimensions/format from the image metadata. Both routes pass decompressed output onward without checking `outBuffer` for nil. Header reads, payload-size upper bounds and several seek/read counts are also unchecked. `CopyImageDataToTexture` addresses RGB565 rows by `Texture.Width` rather than `Access.Pitch`; its equal-size non-RGB565 path copies the whole buffer contiguously, while only its mismatched-size non-RGB565 path uses per-row pitch.
- **Reachable editor callers:** `FrmMain.OpenWMFile` selects the class for `.Lib`, sets `ltLoadBmp`, and initializes it; the grid selection calls `CopyDataToTexture`. `FrmOut` uses `Bitmap[index]` for ordinary bitmap export and `CopyDataToTexture` for alpha/texture export; optional offset sidecars include `LastColorFormat`. `FrmMain` and `FrmAlpha` convert WIL records by retrieving old-library bitmaps, compressing RGB565 data, appending MyImage records, then saving the index; their bitmap retrieval catches exceptions and turns failures into missing entries, but append/index-save results are ignored. `FrmAdd` edits coordinate metadata, appends or replaces records, inserts empty offsets, and saves the table; `FrmDel` shifts/removes offsets and calls `SaveIndexList`. Insert/replace/delete paths also call the shared mapped-file `AppendData`/`RemoveData` helpers without checking their Boolean results. `GetImageXY` checks its metadata read length; `UpdateImageXY` and `GetDataImageInfo` do not check theirs, and metadata writes are unchecked.
- **Static boundary:** these are Preview ImageEditor `.Lib` reader/editor paths only. No archive or UI behavior was exercised, no EI `.Lib` counterpart was inspected, and the MapEdit/Client units were not compared; do not infer client compatibility or runtime corruption from static failure surfaces.

## 28. MapEdit About form and active menu path（Round 861）

- **Scope:** source-reader read `Source/Tools/MapEdit/About.pas` in full (1–33, CP949), then read `About.dfm` (1–39), `MapEdit.dpr` (1–43), and the relevant `EdMain.dfm`/`EdMain.pas` menu code. The DPR includes `about.pas` and calls `Application.CreateForm(TForm1, Form1)`; no Delphi build or UI run was performed.
- **Form contract:** the resource caption is “关于”, its first label says “地图编辑器”, its second label has no caption, and the OK button is bound to `Button1Click`; the handler only calls `Close`.
- **Reachability:** the main menu DFM binds an item to `N10Click`; that handler calls Windows `ShellAbout`. Its `form1.ShowModal` statement is commented, and MapEdit-scoped source-reader search found no active `Form1.Show`/`ShowModal` caller. Thus the project auto-creates the custom form, but this observed menu route invokes the shell dialog instead.
- **Primary/source boundary:** this is Preview MapEdit source and resource evidence only. No EI About counterpart, runtime display, Delphi compilation, or behavior of an externally shown `Form1` was verified.

## 29. MapEdit door marker dialog and map-click path（Round 862）

- **Scope:** source-reader read `Source/Tools/MapEdit/DoorDlg.pas` in full (1–52, CP949), then traced `DoorDlg.dfm`, `MapEdit.dpr`, and the caller/menu path in `EdMain.pas`/`.dfm`. The DPR includes `DoorDlg` and calls `Application.CreateForm(TFrmDoorDlg, FrmDoorDlg)`. No Delphi build or UI run was performed.
- **Dialog contract:** `UpdateEx` initializes its checkbox from `nDoorIndex and $80`, displays the lower seven bits in `EdIndex` and the offset in `EdOffset`, then calls `ShowModal`. On `mrOk`, both texts use `StrToIntDef(..., 0)`; the checkbox re-adds `$80` to the parsed index, and the parsed offset is returned unchanged. The function returns true only for `mrOk`; otherwise the `var` values are not assigned. It imposes no explicit numeric bounds or post-parse index mask.
- **Reachability and mutation:** the main-form menu DFM binds `UpdateDoor1` to `DrawObject1Click`, whose handler selects `mdDoor`. `MapPaintMouseDown` routes that mode through `UpdateDoor`; it seeds dialog values from the cell's byte `DoorIndex`/`DoorOffset` fields and calls `SetMapDataEx` for those two fields only when `UpdateEx` returns true. The click branch sets `Edited := TRUE` after the call regardless of modal acceptance, so cancellation leaves these cell fields unchanged but still marks the editor dirty in this path. `SetMapDataEx` records prior field values for undo and assigns the supplied integers into the byte fields without a local input-range guard.
- **Static limits:** the DFM reader view exposes `CkDoor`, `EdIndex`, `EdOffset`, and an OK-kind bit button, but the resource is reported as mixed binary/text; `dfm_parse.py tree` (full and shallow) and `list` raised `IndexError` while reading past input. Captions and geometry are therefore not claimed. The lack of explicit bounds checks is a source observation; overflow/range behavior at byte assignment depends on compiler/runtime settings and was not exercised.
- **Primary/source boundary:** this records the Preview MapEdit dialog and its observed map-click caller only. No EI dialog comparison, Delphi compilation, or runtime edit/cancel behavior was tested.

## 30. MapEdit main form, map editing and persistence boundaries（Round 863）

- **Scope and entry:** source-reader read `Source/Tools/MapEdit/EdMain.pas` in full (1–3283, CP949), then read `MapEdit.dpr`, the 126-line mixed `EdMain.dfm` view and relevant segment-manager source/resource. The DPR creates `TFrmMain` first and auto-creates the listed palette, object, tile, size, segment, light, door, scroll, move and About forms. The main DFM binds form lifecycle/key/timer events and `MapPaint` mouse/paint events; its menu and speed buttons bind the file, drawing-mode, visibility, zoom and brush handlers.
- **State, drawing and undo:** `FormCreate` loads the `256RGB` palette resource, initializes 70 relative `Data\...Lib` paths as `ltLoadBmp` images (falling back to a `.wil` path when a MyImage `.Lib` initialization fails), starts at 200×200 with `Zoom = 0.4`, and calls `NewMap`. The editor separates draw modes (tile, middle tile, object, set, light, door) from brushes (auto, normal, fill, attribute, eraser); the canvas handlers dispatch these operations, and `MapPaintPaint` draws background/middle/object layers plus attribute, light and door overlays. `SetMapData` and `SetMapDataEx` capture full-cell or selected-field snapshots in a temporary undo record; `CopyTempEnd` retains at most 30 operations, and Ctrl+Z calls `Undo`. The source also shows uneven dirty tracking: the door mode marks `Edited` after the dialog even on cancel, while mouse-down eraser/attribute branches and `MapScroll1Click` mutate map data without setting it.
- **Keyboard path:** the main DFM binds `FormKeyDown`; F5 repaints, Ctrl+Z invokes undo, and Ctrl+C/V copies/pastes only `nInteger1`, `nInteger2`, `nInteger3`, and `nWord4` as slash-separated text at the current mouse cell. Paste records field-level undo, sets `Edited`, and repaints.
- **Brush behavior:** background `mbFill` scans every even/even map cell for matching `FillIndex`/tile classes rather than flooding only a connected region; `mbFillAttrib` prompts for a square radius. The attribute brush sets or clears background/foreground high bits, extending to a 5×5 square with Shift. The eraser clears foreground (or middle layer with Alt), animation and door fields; Ctrl uses radius 1 and Shift radius 10 (Shift overwrites Ctrl), with Ctrl also clearing the background attribute. Auto tile brushes rewrite neighboring tiles to repair their edge patterns. These are code-path descriptions, not visual/UI results.
- **Main-map file path:** `LoadFromFile` initializes `Result := False`; its file decoding body is commented out. `SaveToFile` likewise initializes false and leaves header/write logic commented. `Open1Click`, `OpenOldFormatFile1Click`, and batch conversion call the loader; `SaveAs1Click` calls the saver, and `Save1Click` delegates to Save As (the in-place save is commented). Thus these source paths do not implement active main-map file read/write. `VerifyWork` returns true after a “yes” response even if Save As is cancelled or the false-returning save fails, so its callers can proceed without a successful save. The separate bitmap exporter is active in source: the two DFM menu items bind `SaveToBitmap1Click`, which renders to fixed `map.bmp` using the sender's `Tag` as a scale divisor.
- **Segment path and reachability:** `LoadSegment`/`SaveSegment` bodies are commented out; `DoEditSegment` calls the loader for a 3×3 grid of 40×40 `.sem` regions and `DoSaveSegments` calls the saver then clears `Edited`. The segment form has separate `.mp` project metadata handlers, but `NewSegmentMap1Click` contains only a commented `FrmSegment.Show`, and MapEdit-scoped search found no active `FrmSegment.Show`/`ShowModal` caller; the DPR merely auto-creates the form. Therefore the segment-map editing path is not shown reachable from the observed UI entrypoints, and its `.sem` data persistence is inactive in this source.
- **Static source inconsistencies and limits:** `TFrmMain.MArr` is declared as an array of `TTileInfo` (whose record fields are `bFileIdx`/`wTileIdx`), but the `TMapInfo` getter/setter and editor code use it as map records with fields such as `BkImg` and `DoorIndex`. This is an unresolved declaration/use mismatch; no Delphi build was run, so no compiler outcome is asserted. `dfm_parse.py tree` raises `IndexError` at EOF for `EdMain.dfm`; the source-reader mixed-text view still exposes event bindings, but captions/geometry are not claimed. No EI editor/map-format comparison or runtime editing/save test was performed.
- **Primary/source boundary:** all findings are Preview MapEdit source/resource observations only. They do not establish EI map compatibility, successful Delphi compilation, or behavior of any code path with a runtime compiler configuration.

## 31. MapEdit object-image palette and library-index routing（Round 864）

- **Scope and resource:** source-reader read `Source/Tools/MapEdit/FObj.pas` in full (1–114, CP949), then read its 30-line mixed `FObj.dfm`, `MapEdit.dpr`, and the relevant `EdMain` menu, renderer and object-placement code. The DPR includes `FObj` and creates `TFrmObj` after `TFrmMain`; the main form initializes `WilArr` before the palette form's `FormCreate`. The DFM view exposes `FormCreate`/`FormResize`/`FormShow`, grid click/draw-cell events, and a drop-down-list change event; `dfm_parse.py tree` fails with `IndexError` at EOF, so grid geometry and `RowCount` are not claimed.
- **Palette behavior and caller:** `FormCreate` starts in half-size mode, adds the basenames of all 70 `WilArr` paths, and selects index 0. `FormShow` sets grid cell width to 24 or 48, obtains the current library's image count capped at 65,535, and sets at least one column. A valid combo index 0–69 updates `WilIndex` and reruns `FormShow`. `ObjGridDrawCell` flattens the cell as `Col + Row * ColCount`, checks the resolved image count and draws at 0.5× or 1×. `GetCurrentIndex`, however, checks/returns only `ObjGrid.Col` plus `WilIndex * 65535`; it does not include the selected row. The DFM's row-count value was not recovered, so no claim is made about multi-row selection behavior. `EdMain.Object1Click` shows `FrmObj`; the grid click selects `mdObj`; the only observed `GetCurrentIndex` caller is `EdMain.DrawObject`, where Alt passes -1 to `DrawObjDr` and Ctrl XORs `$8000` into the selected index.
- **Library routing discrepancy:** the combo accepts all `WilArr` indices 0–69, but `EdMain.ObjWil` initializes its result to `WilArr[0]` and selects an indexed entry only for `idx div 65535` in 0–39. Thus indices 40–69 resolve to the default library in the palette preview and downstream object rendering, while `GetCurrentIndex` still prefixes the selected index by `WilIndex * 65535`. This is a static routing difference; no displayed palette or map was tested.
- **Primary/source boundary:** Preview MapEdit code/resource behavior only. No EI object palette comparison, Delphi build, DFM geometry recovery or runtime image-selection test was performed.

## 32. MapEdit scroll-offset dialog and menu caller（Round 865）

- **Scope and resource:** source-reader read all 47 lines of `Source/Tools/MapEdit/FScrlXY.pas` (CP949), then read the 25-line mixed DFM, `MapEdit.dpr`, the `EdMain` menu binding and complete `MapScroll1Click` caller plus its temporary-snapshot helpers. The DPR includes and auto-creates `TFrmScrollMap`; the DFM view exposes the two edits and `Button1Click`, but `dfm_parse.py tree` raises `IndexError` at EOF and the captions/geometry were not recovered.
- **Dialog contract:** `Execute` clears `EdX`/`EdY`, calls `ShowModal`, then unconditionally assigns each field through `StrToIntDef(..., 0)`; `Button1Click` calls `Close`. The unit has no modal-result branch or numeric bounds check, so blank or unparsable input becomes zero.
- **Caller behavior:** the main DFM binds the MapScroll menu item to `MapScroll1Click`. That handler calls `CopyTempBegin`, opens the dialog, zero-initializes `nilmap`, processes both axes, calls `CopyTempEnd` and refreshes; it does not test a modal result or set `Edited`. For either axis, only an offset strictly between zero and its maximum uses the positive-direction branch; zero uses the alternate loop, which writes `nilmap` to the final column (`MapData[MAXX-1, k]`) or final row (`MapData[k, MAXY-1]`). Thus blank/default-zero fields are not a no-op in the observed caller. This is a static source-path consequence, not a runtime reproduction.
- **Primary/source boundary:** Preview MapEdit source/resource evidence only. No Delphi build, dialog interaction, map mutation or undo test, or EI equivalence comparison was performed.

## 33. MapEdit HUtil32 helper surface and unit-resolution boundary（Round 866）

- **Scope and project resolution:** source-reader read all 2,682 lines of `Source/Tools/MapEdit/HUtil32.pas` (CP949). Its interface exposes fixed character arrays, color/list/alignment tables and string, numeric/date, bit/feature/color, file/directory, pointer/memory and GDI helpers. A MapEdit-scoped reader search found 17 `uses` clauses naming `HUtil32`; the only explicit `HUtil32.pas` project-path reference found under `Source/Tools` is `MapEdit.dpr`, which maps the unit name to `..\..\Common\HUtil32.pas`. The local copy is therefore not established as the MapEdit build's implementation; no Delphi build was run.
- **Local implementation boundaries:** `BoolToCStr` and the implementation-only `Str_Catch` have empty bodies. `GetValidStrEx`/`GetValidStr3`/`GetValidStr4`/`GetValidStrVal` are separate token parsers with `$7FFF` fixed buffers and differing input-length and exception handling; `GetFirstWord` writes a token into `Str4096` without a length check. `FileCopy`/`FileCopyEx` set `Result := True` after the copy loop without checking `FileRead`/`FileWrite` results. These are local source observations, not claims about the Common copy.
- **Observed MapEdit references:** `EdMain` uses `GetValidStr3` for slash-delimited clipboard fields and `ObjSet` uses it for space-delimited object-set fields; `FObj` and `ObjEdit` cap displayed image columns with `_MIN(65535, ImageCount)`. `o_WIL`/`Wil/WIL` call `SpliteBitmap` in bitmap drawing, and `o_WIL`, `wmM3Def` and `wmM3Zip` use `ExtractFileNameOnly` to form `.WIX`/`.Idx` sidecar paths. WIL-family sources also call `SafeFillChar` for stream/record initialization. These references establish source-level unit-name/API use, not linkage to this local copy.
- **Primary/source boundary:** Preview MapEdit source only. The Common HUtil32 implementation was not compared; compiler unit resolution, Delphi runtime behavior and EI equivalence remain unverified.

## 34. MapEdit ImgMan image managers and cache boundaries（Round 867）

- **Scope and reachability:** source-reader reports `Source/Tools/MapEdit/ImgMan.pas` as 557 lines (CP949), seven more than the 550-line pending ledger entry, which is corrected in this round. Exact-name reader searches across `Source/Tools` and all `Source` found no external `ImgMan` import or manager API caller; no form/resource binding surfaced in those text searches. This does not establish project inclusion or runtime reachability.
- **Declared image managers:** `TScreenImages` validates a screen and five filenames, then loads body, hair, weapon, magic-effect and screen-image lists. The loader reads one library header and each image header/pixel block, creates a surface and stores its x/y offsets. Body/hair/weapon lookup uses `224 * type * 2 + sex + frame`; magic effects use `24 * type + frame`. These getters test only `idx < Count`, not a nonnegative lower bound. `TLoginImages.Initialize` only validates its screen/file fields; loading and freeing are separate methods. Its `GetImage` implementation has a standalone `end;` before the result statements and indexes `ILLogin` with `i` rather than its `index` parameter.
- **Visible source inconsistencies:** `TScreenImages.LoadLibrary` is implemented but absent from the class declaration. `TBufferingImages` declares `FileName` and `MemorySize: inteter`, while its implementation refers to `ImageFile`/`MaxMemorySize`, an `ImgHeader` field, and `LoadImages`/`FreeOldMemorys` members not declared there. Its `LoadMonImages` declaration belongs to `TMonsterImage`, but the implementation is qualified as `TBufferingImages.LoadMonImages`. These are source-level declaration/implementation mismatches; no Delphi compiler outcome is asserted.
- **Lazy-cache and ownership path:** `TBufferingImages.Initialize` allocates `ImageArr` without zeroing its pointer slots, records `stream.Seek(pixelBytes, 1)` results after reading each image header, and `LoadImages` later seeks to the recorded value before reading an image header. `GetSurface` tests a slot as a pointer and may invoke eviction; `FreeOldMemorys` traverses all slots without a nil guard. `TBufferingImages.Destroy` frees only `IndexList`, while `TScreenImages.Destroy` frees its lists but not their stored surfaces/records. The source exposes these paths but no external caller that establishes safe initialization/cleanup.
- **Monster cache and primary/source boundary:** the declared cache has 300 race slots and a `MAXMONMEMORY` threshold; `LoadMonster` returns nil on a repeated-load early exit, and a new over-budget load frees at most one oldest list. `FreeMonster` has no visible race-range check; `TMonsterImage.Destroy` only calls its inherited destructor and `Initialize` is empty. Findings are Preview source text only: no project build, runtime/cache test, image-format validation or EI equivalence comparison was performed.

## 35. MapEdit DPR project graph and startup order（Round 868）

- **Project unit list:** source-reader read all 43 lines of `Source/Tools/MapEdit/MapEdit.dpr` (CP949). The `uses` list names `EdMain`, `mpalett`, `FObj`, `ObjEdit`, `ObjSet`, `Tile`, `MapSize`, `segunit`, `SmTile`, `glight`, `DoorDlg`, `FScrlXY`, `MoveObj`, `about`, `HUtil32`, `DES` and `WIL` plus VCL `Forms`. `HUtil32` and `DES` have explicit `..\..\Common\...` paths; `WIL` explicitly resolves to `Wil\WIL.pas`. `ImgMan` is not in this project list, consistent with the source-wide exact-name searches finding no external import/caller; its inclusion in this project is not established.
- **Startup path:** after `Application.Initialize` and assigning `Application.Title`, the DPR calls `Application.CreateForm` for `TFrmMain` first, followed in order by `TFrmMainPal`, `TFrmObj`, `TFrmObjEdit`, `TFrmObjSet`, `TFrmTile`, `TFrmMapSize`, `TFrmSegment`, `TFrmSmTile`, `TFrmGetLight`, `TFrmDoorDlg`, `TFrmScrollMap`, `TFrmMoveObj` and `TForm1`; it then calls `Application.Run`. Source-reader searches located matching form-class declarations/resources for the named forms. This records source call order only, not runtime visibility or successful compilation.
- **Project/source boundary:** `{$R *.RES}` is present, but its resource was not inspected here. No Delphi build, startup runtime, EI project/unit-resolution comparison or MapEdit binary inspection was performed.

## 36. MapEdit map-size dialog and New/Resize callers（Round 869）

- **Scope and resource:** source-reader read all 52 lines of `Source/Tools/MapEdit/MapSize.pas` (CP949), searched MapEdit callers, and read its 25-line mixed `MapSize.dfm`. The DFM reader view exposes `bkOK`/`bkCancel`, both `MinValue`/`MaxValue` property names, and `FormShow`; `dfm_parse.py tree/list` returns only three parsed entries (form root, `BorderStyle`, `EdHeight`). Numeric spin limits and a complete control tree were not recovered.
- **Dialog contract:** every `Execute` call resets `MapX`/`MapY` to 20 and fills `EdWidth`/`EdHeight` with those defaults. Only `mrOk` returns true; accepted text is parsed with `StrToIntDef(..., 1)`, while cancel returns false. `FormShow` focuses `EdWidth`. The actual spin-edit numeric bounds remain unknown from this mixed resource.
- **New-map path:** the main DFM binds the New and Resize menu items to `New1Click` and `Resize1Click`. New first gates on `VerifyWork` and `SegmentMode`, then on dialog acceptance assigns the dimensions, calls `NewMap` and refreshes. `NewMap` clamps negative dimensions to 1, zeroes `MArr`, clears undo and resets canvas dimensions/cursor; zero is not changed by its negative-only clamp.
- **Resize path and boundary:** `Resize1Click` has no `VerifyWork`/segment-mode gate; on acceptance it assigns the dimensions, clamps only negative values to 1, updates canvas size/cursor and refreshes. It does not call `NewMap`, snapshot map data, or set `Edited` in the observed handler. Thus its source path changes dimension/canvas state without an observed map-array resize/clear or undo entry. No claim is made that zero is user-enterable, because DFM spin limits were not recovered. Static Preview source/resource only; no Delphi build, UI operation, undo test or EI comparison was performed.

## 37. MapEdit object-move dialog and partial undo path（Round 870）

- **Scope and entry:** source-reader read all 96 lines of `Source/Tools/MapEdit/MoveObj.pas` (CP949), searched exact MapEdit callers, and read the 32-line mixed DFM. `MapEdit.dpr` includes and auto-creates `TFrmMoveObj`; `EdMain.dfm` binds the CellMove menu item to `CellMove1Click`, which calls `FrmMoveObj.Execute`. `Execute` clears `Edit1`, `Edit3` and `Edit4`, then calls `Show` (modeless), not `ShowModal`. The DFM view exposes Button1/2 event bindings; `dfm_parse.py tree` fails with `IndexError` at EOF, so full control geometry/captions were not recovered.
- **Button1 move path:** `Edit1` parses an object id with fallback -1, `Edit3` parses row offset `y` with fallback 0, and the guard is only `obj >= 0 and y < 10`; negative offsets pass. It scans `i=0..MAXX-10`, `k=MAXY-10..0` descending, matches `(FrImg and $7FFF) = obj+1`, directly clears each source cell while preserving `$8000`, then reads the destination's `$8000` bit and calls `SetMapDataEx` to place `obj+1`. The direct source clear bypasses `SetMapDataEx`; the helper's visible bounds exclude `y >= MAXY-1`, so an offset reaching the final row can clear the source while rejecting the destination write. A negative offset reaches a direct `MapData[i,k+y]` read before the helper's bounds guard. These are source-level path consequences, not runtime reproductions.
- **Button2 remove path and undo:** `Edit4` parses an object id with fallback -1; for nonnegative ids the handler scans the full grid and directly clears matching low-15-bit `FrImg` values while preserving `$8000`. Both handlers bracket edits with `CopyTempBegin/CopyTempEnd`, but these direct assignments do not populate undo entries. Button1 records only destination fields that reach `SetMapDataEx`; Button2 performs no `SetMapData`/`SetMapDataEx`, so `CopyTempEnd` disposes its empty temporary record. Neither handler sets `Edited`, calls `MapPaint.Refresh` or closes the shown form in the observed body.
- **Primary/source boundary:** Preview MapEdit source/resource text only. No Delphi build, object movement/removal, rendering, undo test or EI comparison was performed.

## 38. MapEdit object-piece editor and set callers（Round 871）

- **Scope and resource:** source-reader read all 1,018 lines of `Source/Tools/MapEdit/ObjEdit.pas` (`cp949+mixed`) and all 127 mixed lines of `ObjEdit.dfm`; exact-name searches across `Source/Tools` found only MapEdit callers. The project includes and auto-creates `TFrmObjEdit`. The resource exposes paint-box/grid/form events, modal-button properties, tile/object/mark/door/light controls and eleven checkboxes. `dfm_parse.py tree/list` yield only 15 entries with binary-property artifacts and bad nesting, so the full layout and many captions are not reliable.
- **Data and modal contract:** `TPieceInfo` holds relative `rx/ry`, background/middle/front image IDs and library indices, animation/tick/blend, light, door index/offset, and mark bits. `SetPieceList` clears the editor's owned records/undo then clones the caller list; `DuplicatePieceList` appends fresh record copies to the output list. `Execute` is modal; it returns true only for `mrOk`, then applies the animation controls to every piece. It reparents `FrmTile`/`FrmSmTile` into the editor while shown and clears their parents on return.
- **Editing and undo:** `PboxMouseDown` maps clicks to relative cells; it edits marks, background or middle tiles, object IDs, light and door metadata. Background-tile placement requires even `x` and `y`; selecting a small tile sets `CanDrawSmTitle` and writes the middle-image fields. `PboxPaint` conditionally previews background/middle/front layers and overlays marks/light/door labels. `CopyPiece` retains at most 20 per-piece undo snapshots and Ctrl+Z restores/removes the last touched record. `ShiftPieces` changes every piece coordinate directly without creating snapshots; the arrow handlers therefore bypass this undo path. `BtnClearClick` clears pieces and snapshots. The DFM binds a visible `Button1` to `Button1Click`, whose entire implementation body is commented out.
- **Callers and row-count coupling:** `ObjSet.SetGridDblClick` copies the selected set list when non-nil and updates it only after `Execute` returns true; cancellation leaves that caller's external list unchanged. `FrmObjSet.Execute` calls `Show` (modeless). `EdMain.MapPaintMouseUp` then requests `SetGrid.RowCount-1`; the usual `RowCount := SetList.Count+1` makes this the nil append row, so it builds the selected-map rectangle in a temporary list and adds a new set only on `mrOk`. `PasteSet` is the exception: it inserts a copied list without updating `RowCount`, and its key handler only refreshes the grid. After that stale count, `RowCount-1` can be the last real set; region selection then clears/replaces that list before opening ObjEdit, so cancellation leaves the rectangle snapshot in that slot. The standalone `RunObjEditer1Click` path calls `Execute` without importing or exporting a caller list.
- **Ownership and boundary:** when the region-selection path creates a new-set temporary list, it frees the `TList` container without disposing the allocated `TPieceInfo` entries; `FormDestroy` likewise frees the editor's list containers without calling `ClearPiece` on remaining records. These are static ownership-path observations. No Delphi compile, runtime, UI, cancel/undo, or EI comparison was performed.

## 39. MapEdit object-set manager, persistence and placement（Round 872）

- **Scope/resource and startup:** source-reader read all 484 lines of `ObjSet.pas` (CP949), the 35-line mixed DFM and relevant EdMain/Tile callers. `MapEdit.dpr` includes and auto-creates `TFrmObjSet`; `TFrmMain.FormShow` invokes `InitializeObjSet`, which loads `mir.set`. `FrmObjSet.Execute` only calls `Show`, so this manager is modeless. DFM exposes a stay-on-top DrawGrid with click/double-click/draw/key handlers plus Save/Load dialogs; `dfm_parse.py tree` raises `IndexError` at EOF, so resource geometry/captions remain partial.
- **Collection, row and edit contracts:** `SetList` owns lists of `TPieceInfo` records and `Buffers` owns copied records. `GetSet` returns a list only for indices `0..Count-1`; `RowCount` is reset to `SetList.Count+1` by load/update/insert/delete, reserving an append row. `UpdateSet` replaces an existing list (disposing its records) or appends when passed the count index. Grid double-click copies the selected list into ObjEdit and installs a copied replacement only on `mrOk`; the editor's cancel path leaves this source list unchanged.
- **Keyboard operations and row-count defect:** Ctrl+Insert copies the selected list to `Buffers`; Shift+Insert clones the buffer into `SetList`; bare Insert inserts a nil slot. Ctrl+Delete removes a set, while bare Delete only removes an already-nil slot; Enter reuses the double-click editor. `PasteSet` does not update `SetGrid.RowCount`, unlike `InsertSet`/`UpdateSet`/`DelSet`, and its key handler only calls `Refresh`. After paste, the append-row invariant is stale; `EdMain.MapPaintMouseUp` can then treat the last real set as the target during region capture, mutate it before the ObjEdit modal result, and leave the captured rectangle there if the editor is cancelled.
- **Persistence format:** `SaveToFile` always writes a `NEW` marker, `[index]` section headers and 14 space-delimited piece fields. `LoadFromFile` treats headers only as section boundaries and ignores the numeric index; it uses `NEW` to choose direct `StrToIntDef` parsing, otherwise `Str_ToInt1` applies `i*65535+j` after `div/mod 10000` to each numeric field. Nil list slots are skipped by save and numeric header indices are ignored on load, so gaps are not preserved. Loading clears the current set only when the selected file exists; the default `mir.set` load still sets `RowCount` from the resulting list count.
- **Map use and static edge cases:** clicking a grid row sets `mdObjSet` and builds the cursor; map mouse-up calls `DrawObjectSet` inside the main-form undo bracket and marks the map edited. Placement checks foreground collisions, then applies background/middle/front images, marks, animation, light and door fields through the main-form setters. `ClearSet` dereferences every slot as a `TList`, so a nil slot created by bare Insert is unsafe for its clear/reload path. `SetGridDrawCell` marks animation if any piece animates but writes the tick label from the final piece, not necessarily the animated one. `FormCreate` allocates `SetList` and `Buffers`, but no ObjSet destroy handler frees these containers or remaining record pointers. No Delphi build, runtime, persistence round-trip, map placement or EI comparison was performed.

## 40. MapEdit small-tile palette and automatic middle-tile placement（Round 873）

- **Scope and resource:** source-reader read all 155 lines of `SmTile.pas` (CP949), the 31-line mixed `SmTile.dfm`, `MapEdit.dpr`, and relevant `EdMain`/`ObjEdit` callers. The DPR auto-creates `TFrmSmTile`; the DFM reader view exposes stay-on-top, `FormCreate`/`FormShow`, grid draw/click, and combo-change bindings. `dfm_parse.py list/tree` recovers only the form root and `BorderStyle`; combo contents and full control geometry remain unavailable.
- **Palette modes:** `CanDrawSmTile` selects automatic mode only when `FrmObjEdit` is not visible and `SpeedButton1.Down` is true. That mode uses three columns, groups image indices in `MIDDLEBLOCK=60` units, and draws preview frames at offsets +33, +0 and +17 from each group base. `UnitMax` is `ceil(ImageCount/60)`, but `RowCount` is `UnitMax+1`; clicks accept only rows below `UnitMax`, while drawing checks the row against total `ImageCount`, so the extra row can request frames beyond the selectable group range. Other contexts use five columns and `max(1, ImageCount div 5)` rows, which omits a partial final row when the count is not divisible by five.
- **Selection callers:** in automatic mode a click sets `mdMiddle`, the group number and combo index; `EdMain.MapPaintMouseUp` routes `mbAuto` middle painting to `DrawAutoMiddleTile`, whose indices are derived from 60-frame groups. In the individual view, click stores the flattened frame index/library index; `ObjEdit` reparents the palette and its piece-paint handler obtains the range-checked `GetCurrentImageIndex` plus `GetCurrentFileIndex` for the middle layer. `GetCurrentImageIndex` returns -1 when the flattened index is outside `ImageCount`; no active MapEdit caller for `SetImageUnitCount` was found (the `EdMain.FormShow` call is commented out).
- **Unresolved selector setup:** `SmTile.FormCreate` has its `CBSmTitle.Items.Add` loop and `ItemIndex := 0` commented out, and no other active `CBSmTitle` population was found in the inspected `Source/Tools`. `EdMain.InitWMImagesLib` initializes the 70-entry `WilArr`, including `smtilesc.Lib` at indices 3, 17, 31, 45 and 59, but the visible `EdMain.WilSmTile` function body names `WilSmTileArr`; the exact-name source-wide search found no declaration for that identifier. Do not infer the combo-to-library map or successful compilation from these references.
- **Primary/source boundary:** static Preview MapEdit code and mixed DFM only. No Delphi build, palette rendering, tile placement/partial-row runtime test or EI comparison was performed.

## 41. MapEdit tile palette, auto brushes and fill-group behavior（Round 874）

- **Scope and resource:** source-reader read all 163 lines of `Tile.pas` (CP949), the 33-line mixed `Tile.dfm`, and the MapEdit DPR/`EdMain`/`ObjEdit` paths. The DPR auto-creates `TFrmTile`; `EdMain.Tile1Click` shows it, and ObjEdit reparents it beside its piece editor. DFM reader view exposes stay-on-top, form/grid lifecycle and draw/click/combo-change handlers; `dfm_parse.py list` recovers only the form root and `BorderStyle`, not the full control tree or combo values.
- **Grouped palette modes:** `CanDrawTile` is true when ObjEdit is hidden and either `SpeedButton1` (auto) or `SpeedButton3` (fill) is down. It uses three columns, `UNITBLOCK=50`, `UnitMax=ceil(ImageCount/50)` and `RowCount=UnitMax+1`. Clicks accept only rows `<UnitMax`; the extra row is not drawn because `TileGridDrawCell` uses the same `UnitMax` bound. Each selectable group draws samples at offsets +22, +0 and +21, without checking those individual indices against `ImageCount`, so a partial final group can request an out-of-range sample. In other contexts the grid has five columns and `max(1, ImageCount div 5)` rows; `TileGridDrawCell` checks each flattened image index, but a non-multiple-of-five remainder has no row.
- **Main-map operations:** grouped clicks set `mdTile`, the group in `ImageIndex`, the selected library and `TileAttrib := 0`. The `mbAuto` map-paint path calls `DrawAutoTile`; `DrawOne` converts the group and pattern frame to `group*50 + frame + 1`. Under `mbFill`, the caller derives `FillIndex` from the seed cell's current background group; `DrawFill` replaces eligible cells in that group with a random frame from the selected `ImageIndex` group. Individual-view clicks store a flattened image index; `DrawTileDetail` aligns map coordinates to even cells and writes only when `GetCurrentImageIndex` returns a valid index. In ObjEdit, background tile pieces likewise require even relative x/y and store the returned frame/library indices.
- **Unresolved selector setup:** `Tile.FormCreate`'s `WilTileArr` item loop and initial combo index are commented out; no active `CBTitle` population was found in the inspected `Source/Tools`. `EdMain.InitWMImagesLib` initializes `WilArr` with base tile paths at indices 0–2, but the visible `EdMain.WilTile` function body refers to `WilTileArr`; source-wide exact-name search found only the commented palette code and this function use, with no declaration. Do not infer the combo-to-library map or successful compilation from those references.
- **Primary/source boundary:** static Preview MapEdit code and mixed DFM only. No Delphi build, grid rendering, auto/fill painting, partial-row test or EI comparison was performed.
