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
| `LoginServer`/`DataBaseServer` 各 `net*.cpp` 的业务实现 | 只读了分派表与类名 |
| `sqlhandler.cpp` / `tablesdefine.cpp`（表结构） | 未读 —— **对 `System.db` 理解有价值** |
| `mir2packet.cpp` / `endecode.cpp`（C++ 线格式） | 未读 —— 可与 `EDCode.pas` 交叉验证 |
| `tablesdefine.cpp` 的表定义 | 未读 |
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
