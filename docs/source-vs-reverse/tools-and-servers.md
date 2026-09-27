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
| `Birthday` | `string[10]` | 生日（样例 `1972/11/09`） |
| `MobilePhone` | `string[13]` | 手机（样例 `017-6227-1234`） |
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
| `Wil/WIL.pas` | **WIL 读写**（与客户端 `WIL.pas` 同源，是 `.map` 工具链的图库层） |
| `glight.pas` | **光照**（与 `Client/Light/Light0a-d.pas` 配套，8.1 MB `.inc` 查表被排除） |
| `Tile.pas` / `SmTile.pas` | 瓦片 |
| `o_WIL.pas` / `wmM3Def.pas` / `wmM3Zip.pas` / `wmMyImage.pas` / `wmUtil.pas` | **图库解析（与客户端同源）** |
| `ObjEdit.pas` / `ObjSet.pas` / `FObj.pas` | 地图对象编辑 |
| `DoorDlg.pas` | 门编辑（对应 `Envir.pas` 的 `PTDoorInfo`） |
| `MapSize.pas` | 地图尺寸 |
| `mpalett.pas` | 调色板 |
| `segunit.pas` | 段 |
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
| `Common/EDCode.pas` | 线格式（`wire-format.md` §4 已 diff） |
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
