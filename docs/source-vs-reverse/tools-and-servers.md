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
| `DataBaseServer/Common/sqlhandler.cpp` | SQL/ODBC 层 |
| `DataBaseServer/Def/database.cpp` | 数据库定义 |
| `DBSvr/tablesdefine.cpp` | **表定义**（`System.db` 的上游） |

**`System.db` 上游链**（`README.md` §3.7 已记录）：
`GameServer → DataBaseServer(GS_BPORT=6000) → ODBC → SQL Server 2000`。

---

## 4. 与 EI 证据 / Zircon 的对照

| 项 | 原版反编译 | 源码 | Zircon |
|---|---|---|---|
| 账号注册协议 | 未闭合 | **定义+发送端有，接收端缺失** | — |
| 登录分派表 | 未闭合 | LoginGate 3 条 / RunGate 4 条 | — |
| 网络框架 | 未闭合 | IOCP（`netiocp.cpp`） | .NET async |
| 表定义 | 未闭合 | `tablesdefine.cpp` | `System.db` 模型类 |
| `.map` 写入端 | 未闭合 | `Tools/MapEdit/` | `mapedit`（本仓库） |

**分级**：源码结论均 `secondary-source`。

---

## 5. 未验证项

| 项 | 原因 |
|---|---|
| `Tools/MapEdit/` 各文件实现主体 | 只读了文件清单与职责 |
| `Tools/ImageEditor/` 顶层非第三方实现 | 只读了文件清单 |
| LoginServer 登录服务业务链 | ✅ Round 835 全读 `netloginsvr`、`netlogingate`、`netgameserver` 与辅助通道；其 `_Oranze Library` 依赖仍逐文件待读 |
| DataBaseServer 服务实现 | pending；仅已有 `netloginserver/netrungate` 分派与 `tablesdefine.cpp` 表字段证据，业务主体及 DB 侧便条语义仍待读 |
| LoginServer/Common C++ 线格式 | ✅ Round 835 全读 `endecode.cpp/.h` 与 `mir2packet.cpp/.h`；DataBaseServer 副本待读核对 |
| `DataBaseServer/Common/sqlhandler.cpp/.h`、`tablesdefine.h` | 未读；`tablesdefine.cpp` 已于 Round 828 提取并覆盖，见 §6 |
| `//*` 标记的语义（必填？） | 无接收端可对照 |

---

## 6. SQL 表定义（`tablesdefine.cpp`）—— **`System.db` 的上游**（Round 828）

> `Source/DataBaseServer/DBSvr/tablesdefine.cpp`（595 行）。
> 机器可读：[`sql-tables.tsv`](sql-tables.tsv)（165 字段）。
> 提取器：`Tools/source-read/extract_sql_tables.py`。

### 6.1 定义格式

```cpp
MIRDB_FIELDS __ABILITYFIELDS[] = {
   { "FLD_CHARACTER", TABLETYPE_STR, true,  20 },   // 名 / 类型 / 是否主键 / 大小
   { "FLD_LEVEL",     TABLETYPE_INT, false,  4 },
   ...
};

MIRDB_TABLE __ABILITYTABLE = { "TBL_ABILITY",
      sizeof(__ABILITYFIELDS)/sizeof(MIRDB_FIELDS), __ABILITYFIELDS };
```

**四元组**：字段名 / 类型（`TABLETYPE_STR`/`INT`/`DAT`）/ **是否主键** / 大小。
表名在 `MIRDB_TABLE` 里绑定到字段数组。

### 6.2 **11 张表 / 165 字段**（完整表见 `sql-tables.tsv`）

| 数组 | SQL 表名 | 字段数 | 主键 |
|---|---|---:|---|
| `__CHARACTERFIELDS` | `TBL_CHARACTER` | **41** | `FLD_USERID` |
| `__ABILITYFIELDS` | `TBL_ABILITY` | **33** | — |
| `__ITEMFIELDS` | `TBL_ITEM` | 24 | `FLD_TYPE` |
| `__SAVEDITEMFIELDS` | `TBL_SAVEDITEM` | 23 | — |
| `__BONUSABILITYFIELDS` | `TBL_BONUSABILITY` | 10 | — |
| `__CURRENTABILITYFIELDS` | `TBL_CURRENTABILITY` | 10 | — |
| `__ITEMGIVEFIELDS` | `TBL_ITEMGIVE` | 9 | **三主键**：`FLD_SERVER`+`FLD_CHARACTER`+`FLD_DONE` |
| `__MAGICFIELDS` | `TBL_MAGIC` | 5 | — |
| `__CHAR_INFOFIELDS` | `TBL_CHAR_INFO` | 4 | `FLD_CHARACTER` |
| `__QUESTFIELDS` | `TBL_QUEST` | 3 | — |
| `__SKILLFIELDS` | `TBL_SKILL` | 3 | — |

### 6.3 关键字段组

**`TBL_ABILITY`（33 字段）** —— **角色能力值全集**：
基础（`FLD_LEVEL`/`AC`/`MAC`/`DC`/`MC`/`SC`/`HP`/`MP`/`MAXHP`/`MAXMP`/`EXP`/`MAXEXP`）
+ **重量三组**（`WEIGHT`/`MAXWEIGHT`、`WEARWEIGHT`/`MAXWEARWEIGHT`、
`HANDWEIGHT`/`MAXHANDWEIGHT`）
+ **七元素抗性 ×2 套**（`ATOMFIRE/ICE/LIGHT/WIND/HOLY/DARK/PHANTOM` 各 `_MC` 与 `_MAC`）。

> **七元素**（火/冰/雷/风/圣/暗/幻）是 Mir3 的属性体系 ——
> **`ATOM` 前缀即「元素」**，`_MC` 与 `_MAC` 是两套（魔攻/魔防？）。

**`TBL_CHARACTER`（41 字段，最多）** —— 角色主表，主键 `FLD_USERID`。
含 `FLD_DELETED`（软删除标记）/`FLD_UPDATEDATETIME`/`FLD_DBVERSION`
（对应 `TCreature.DBVersion`，`server.md` §2.1）/`FLD_MAPNAME`/`CX`/`CY`/`DIR`。

**`TBL_ITEM`（24 字段）** 主键 **`FLD_TYPE`** —— 注意主键是**类型**而非唯一 ID，
说明是**按类型索引的物品表**（可能是模板表而非实例表）。

**`TBL_ITEMGIVE`（9 字段）三主键** `FLD_SERVER`+`FLD_CHARACTER`+`FLD_DONE`
—— **跨服发奖表**（`SERVER` 字段说明是分服共享的）。

**`FLD_RESERVED`/`FLD_RESERVED1` 被注释掉**（`:15`）—— 版本演进痕迹。

### 6.4 与 `System.db` 的关系

`reference/mir3-source/README.md` §3.7 记录的链路：

```
GameServer → DataBaseServer(GS_BPORT=6000) → ODBC → SQL Server 2000
                                                      ↓
                                            System.db 的上游
```

**本节给出的是这条链路的表结构** —— 即 `System.db` 里**玩家相关数据**
（角色/能力/物品/技能/任务）的**上游 SQL 定义**。

> ⚠️ **注意边界**：`System.db` 是**世界静态数据**（`ItemInfo`/`MonsterInfo`/
> `MagicInfo`/`MapInfo`/`NPCInfo`），而 `tablesdefine.cpp` 定义的是
> **玩家存档表**（`TBL_CHARACTER`/`TBL_ABILITY`/`TBL_SAVEDITEM`…）。
> **两者不是同一批数据** —— 玩家数据在 `Users.db` 一侧。
> 本节的表结构对**理解 `Users.db`** 更有价值，对 `System.db` 是间接参考。

### 6.5 未验证项

| 项 | 原因 |
|---|---|
| `tablesdefine.h`（声明） | 未读 |
| `TABLETYPE_*` 的完整枚举 | 只见到 `STR`/`INT`/`DAT` |
| 各表的**完整字段清单与顺序** | 见 `sql-tables.tsv`（已提取） |
| `TBL_QUEST`（3 字段）与 `QuestInfo` 的关系 | 未核 |
| `ATOM*_MC` vs `ATOM*_MAC` 的语义差别 | 未追（疑魔攻/魔防） |
| 这些表与 `Users.db` 的实际对应 | 需读 `Users.db` 侧（超出本 Goal） |

## 7. LoginServer 业务实现（Round 835）

本节仅闭合 LoginServer 的应用层与本目录 C++ 编码/包辅助文件，不代表 90 个 LoginServer 台账条目全部完成；`_Oranze Library/` 的其余通用依赖仍按台账逐文件推进。完整读档清单见 `coverage-ledger.tsv` Round 835 条目。

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

`LoginServer/Common/`：`endecode.cpp/.h`、`mir2packet.cpp/.h` 全读；`LoginServer/LoginServer/`：`LoginSvr.sln/.vcproj`、`dbtable.h`、`dlgcfg.cpp/.h`、`loginsvrwnd.cpp/.h`、`mir2dbhandler.cpp/.h`、`mir2wnd.cpp/.h`、`netUdpsender.cpp/.h`、`netcheckserver.cpp/.h`、`netgameserver.cpp/.h`、`netlogingate.cpp/.h`、`netloginsvr.cpp/.h`、`Res/resource.h` 全读。前两份 `.cpp` 原已 `covered`；Round 835 扩为完整实现阅读。未读的 `_Oranze Library/` 依赖不在本轮标 covered。
