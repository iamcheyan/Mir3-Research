# Preview 源码协议精读（Grobal2.pas + 四段链路）

> 证据源：`reference/mir3-source/Source/`（Mir3 Preview Version，社区源码，
> 证据等级 `secondary-source`）。
> 机器可读常量表：[`protocol-constants.tsv`](protocol-constants.tsv)（474 行）。
> 生成器：`Tools/source-read/extract_protocol_constants.py`。
>
> **读取注意**：`Source/**` 注释以 CP949 韩文为主，但**混有 GB18030 中文注释**
> （见 §1.3）。直接用 `open()`/`rg` 会乱码或失效；用
> `Tools/source-read/read_src.py show|grep`。

---

## 1. 协议总表 `Common/Grobal2.pas`

### 1.1 常量规模（实测）

| 前缀 | 含义 | 条数 |
|---|---|---:|
| `SM_` | server → client | 271 |
| `CM_` | client → server | 120 |
| `ISM_` | inter-server（服间） | 57 |
| `DBR_` | DB 回复 | 26 |
| **合计** | | **474** |

数值范围：`CM_` 0x50–0xBDC，`SM_` 0x1–0xBDA。
`Tools/ImageEditor/Common/Grobal2.pas` 是第三份副本（473 条），
`Common/Grobal2 - 副本.pas` 是旧版备份（473 条）。

> ⚠️ 此前多处文档（含 `reference/mir3-source/README.md`）写「392 个常量」。
> 实测为 **474**。差异原因未查（可能是只数了 `CM_`+`SM_` 的一部分，或数了去重后的
> 名称）。**以本表为准**，因为它是脚本从文件重新解析的。

### 1.2 三份表的版本演进（脚本自动 diff）

| 对比 | 差异 |
|---|---|
| primary vs backup | primary 独有 `ISM_GUILDWAR`、`SM_POWERUP`；backup 独有 `ISM_STANDARDTICKREQ` |
| primary vs imageeditor | primary 独有 `SM_POWERUP`；imageeditor 无独有项 |

即：**primary 比两份副本都新**，演进量极小（1–2 个常量）。这本身是有价值的信息：
说明三份表来自同一分支的相邻时点，而非不同产品线。

### 1.3 混合编码坑（实测）

`Common/Grobal2.pas:419`：

```
    LoAC: Word;      //防御上限 ok
```

原始字节 `b7c0 d3f9 c9cf cfde` 是 **GB18030 中文**，但整文件其余注释是 CP949 韩文。
`c9cf` 恰好是**合法**的 CP949 双字节，所以：

- 严格 CP949 解码会在**文件偏移 16998** 处抛异常（该字节 `0xc9` 后跟 `0xcf`，
  但在另一处上下文里 `c9` 是尾字节）；
- 一旦容错解码，这一行会变成 `렝徒龜龜`（乱码）；
- 若按「整体编码判定」选 GB18030，则**整个文件 7000+ 韩文字符全变乱码**。

**结论**：`Source/**` 不是纯 CP949，是 **CP949 为主 + 零星 GB18030 中文注释**。
读文件必须逐行判定，不能整文件一刀切。`read_src.py` 已实现（逐行 CJK/谚文计分 + 重解）。

---

## 2. 服务进程拓扑与协议分区（重要）

四段链路对应四个不同的 opcode 子集，**不能混着看**：

```
客户端
 ├─ 7000 ─→ LoginGate   ──5500→ LoginServer     ← CM_IDPASSWORD / CM_SELECTSERVER / CM_PROTOCOL
 ├─ 7100 ─→ SelChrGate  ──5100→ DataBaseServer  ← 建号/选角/改密
 └─ 7200 ─→ RunGate     ──5000→ GameServer      ← 全部 CM_ 游戏消息
                                    └─6000→ DataBaseServer（GS_BPORT）
```

**LoginGate 分派表**（`LoginServer/LoginServer/netlogingate.cpp:25-27`）只有 3 条：

```cpp
CM_IDPASSWORD,    CLoginGate::OnIdPassword,
CM_SELECTSERVER,  CLoginGate::OnSelectServer,
CM_PROTOCOL,      CLoginGate::OnProtocol,
```

**客户端发出但 GameServer 无 `case` 的 10 条**（脚本实测差集）：

```
CM_ADDNEWUSER  CM_CHANGEPASSWORD  CM_DELCHR  CM_IDPASSWORD  CM_NEWCHR
CM_PROTOCOL    CM_QUERYCHR         CM_SELCHR  CM_SELECTSERVER  CM_UPDATEUSER
```

→ 这 10 条全部属于**登录/选角链路**（LoginGate + SelChrGate + DataBaseServer），
**不是遗漏**。做「客户端发送 vs 服务端处理」差集时**必须先按端口分段**，否则会得到
「服务端不处理登录」这种荒谬结论。

**`0x418`/`0x419` 的正确定位**：`CM_FRIEND_EDIT`/`CM_FRIEND_LIST` 属于 GameServer 的
好友系统，但 GameServer 主分派（`ObjBase.pas`）**没有它们的 `case`**，命中 `else` 兜底回环；
`UsrEngn.pas:3546-3547` 把它们列在同一 begin 块里转发给 `FriendSystem`，
**保留 `pmsg.Ident` 原值**（没有重映射成 `ISM_*`）。这是本源码里唯一的
「好友系统走透传而非消息号重映射」路径，值得记住。

---

## 3. EI 3.0 反编译证据 ↔ 源码常量 全量对照

方法：扫描 `docs/research/ei-ui-layout/**`（排除 artifacts/sources）里所有
`msg 0x…` / `类型 0x…` / `opcode 0x…` 写法，得到 **28 个 opcode** 落在
客户端出站范围 0x3E9–0x419；再与 `protocol-constants.tsv` 按值连接。

**结果：28 个全部在源码里有同值的 `CM_` 常量（100% 命中）。**

| opcode | EI 反编译证据里的叫法 | 源码常量 | 源码注释 | 判定 |
|---|---|---|---|---|
| `0x3E9` | 商店操作族 | `CM_PICKUP` | | **修正** |
| `0x3EA` | 商店操作族 | `CM_OPENDOOR` | | **修正** |
| `0x3EB` | 装备槽 | `CM_TAKEONITEM` | 복장을 착용 | ✅ 吻合 |
| `0x3EC` | 装备槽 | `CM_TAKEOFFITEM` | 복장을 벗는다 | ✅ 吻合 |
| `0x3EE` | 聊天/商店 | `CM_EAT` | 먹다, 마시다 | **修正** |
| `0x3F1` | 金币交易 | `CM_SOFTCLOSE` | | **修正** |
| `0x3F2` | 商店控件/NPC | `CM_CLICKNPC` | | ✅ 吻合 |
| `0x3F3` | 商店控件 | `CM_MERCHANTDLGSELECT` | | ✅ 吻合 |
| `0x3F7` | 商店状态机 | `CM_USERGETDETAILITEM` | | ✅ 吻合 |
| `0x3F8` | 聊天提交 | `CM_DROPGOLD` | | **修正** |
| `0x400` | 坐标 | `CM_MERCHANTQUERYREPAIRCOST` | | **修正** |
| `0x401` | 交易请求 | `CM_DEALTRY` | | ✅ 吻合 |
| `0x402` | 交易 | `CM_DEALADDITEM` | | ✅ 吻合 |
| `0x403` | 交易 | `CM_DEALDELITEM` | | ✅ 吻合 |
| `0x405` | 金币 | `CM_DEALCHGGOLD` | 교환하는 돈이 변경됨 | ✅ 吻合 |
| `0x406` | 金币 | `CM_DEALEND` | | ✅ 吻合 |
| `0x408` | 重置 | `CM_USERTAKEBACKSTORAGEITEM` | | **修正** |
| `0x409` | 地图查询 | `CM_WANTMINIMAP` | | ✅ 吻合（Round 802） |
| `0x40A` | NPC | `CM_USERMAKEDRUGITEM` | | **修正** |
| `0x40C` | 行会请求 | `CM_GUILDHOME` | | ✅ 吻合 |
| `0x40F` | 未定 | `CM_GUILDDELMEMBER` | | **补名** |
| `0x410` | NPC 对话回复 | `CM_GUILDUPDATENOTICE` | | **修正** |
| `0x411` | NPC 对话回复 | `CM_GUILDUPDATERANKINFO` | | **修正** |
| `0x414` | 未定 | `CM_GUILDMAKEALLY` | | **补名** |
| `0x415` | 未定 | `CM_GUILDBREAKALLY` | | **补名** |
| `0x416` | NPC | `CM_FRIEND_ADD` | 친구추가 | **修正** |
| `0x418` | 任务窗（旧称） | `CM_FRIEND_EDIT` | 친구설명 변경 | **修正**（Round 802） |
| `0x419` | 任务窗（旧称） | `CM_FRIEND_LIST` | 친구 리스트 요청 | **修正**（Round 802） |

### 3.1 需要修正的三组（重点）

**(a) `0x410` / `0x411` = 行会公告 / 行会等级成员，不是「NPC 对话回复」**

- 原版证据（F256）：「非空时 `[this+0x1D0]==0` → `0x4524D0`（msg 0x411，行会等级/成员
  修改模式）/ `!=0` → `0x4524A0`（msg 0x410，公告模式）」，且 GBK 原串为
  「行会公告，请自行修改公告内容.」「行会修改 请自行修改行会等级、成员排行信息」。
- 源码：`CM_GUILDUPDATENOTICE = 0x410`、`CM_GUILDUPDATERANKINFO = 0x411`，
  服务端 `ServerGetGuildUpdateNotice` / `ServerGetGuildUpdateRanks`。
- **判定**：原版证据**本来就说对了**（行会公告），是 F514 的「NPC 对话回复」标注错了。
  本轮把 F514 的标注修正为 `CM_GUILDUPDATENOTICE` / `CM_GUILDUPDATERANKINFO`。

**(b) `0x416` = `CM_FRIEND_ADD`，不是「帧内容请求 / NPC」**

- 原版证据（F251 系列）把 `0x4519E0` 的 4 个调用点解释为「帧内容请求」。
- 源码：`CM_FRIEND_ADD = 0x416`（친구추가 = 好友添加）。
- **判定**：业务名改为「好友添加请求」；原版「未装载 → 发 0x416」的**静态事实不变**
  （那是原版任务窗的发送行为），只改名字。

**(c) `0x3E9`/`0x3EA`/`0x3EE`/`0x3F1`/`0x3F8`/`0x400`/`0x408`/`0x40A` = 非「商店/聊天/金币/坐标/重置」**

| opcode | 旧标注 | 源码真名 |
|---|---|---|
| `0x3E9` | 商店操作族 | `CM_PICKUP`（拾取） |
| `0x3EA` | 商店操作族 | `CM_OPENDOOR`（开门） |
| `0x3EE` | 聊天/商店 | `CM_EAT`（吃喝） |
| `0x3F1` | 金币交易 | `CM_SOFTCLOSE`（软关闭） |
| `0x3F8` | 聊天提交 | `CM_DROPGOLD`（丢金币） |
| `0x400` | 坐标 | `CM_MERCHANTQUERYREPAIRCOST`（查询修理费） |
| `0x408` | 重置 | `CM_USERTAKEBACKSTORAGEITEM`（取回仓库物品） |
| `0x40A` | NPC | `CM_USERMAKEDRUGITEM`（制药） |

> **注意**：`0x400` 的旧标注「坐标」有原版字节证据（`0x4517A0` = 0x3F5 打包坐标是另一条），
> 需在差异文档里逐条复核原版证据原文再改，**不要一次性批量改**。

### 3.2 已吻合的（无需改动）

`0x401-0x403` 交易族、`0x405`/`0x406` 金币族、`0x409` 小地图、`0x40C` 行会主页、
`0x3EB`/`0x3EC` 穿脱装备、`0x3F2`/`0x3F3` NPC 点击/对话选择、`0x3F7` 商品详情。

---

## 4. 数值命名空间冲突（做对照时必须知道）

474 个常量里有 **31 组重复值**，全部是**跨前缀**（`CM_` vs `SM_` vs `ISM_` vs `DBR_`），
即不同方向/不同链路的独立命名空间。**不是错误**，但会让「按值反查名字」歧义。

高频冲突示例：

| 值 | 冲突常量 |
|---|---|
| `0x50` | `SM_DRAGON_LIGHTING` / `CM_QUERYUSERNAME` |
| `0x64` | `SM_SYSMESSAGE` / `CM_QUERYCHR` / `ISM_PASSWDSUCCESS` |
| `0xC8` | `SM_ADDITEM` / `ISM_USERSERVERCHANGE` |
| `0x3E8` | `SM_ACTION2_MIN` / `CM_DROPITEM` |
| `0x44C` | `SM_OPENHEALTH` / `CM_CLIENT_CHECKTIME` / `DBR_LOADHUMANRCD` |
| `0x7D0` | `CM_PROTOCOL` / `DBR_FAIL` / `DBR_NONE` |

**规则**：任何「按值查名」的脚本**必须同时限定前缀**。`protocol-constants.tsv`
已带 `prefix` 列，用它做 key 是 `(prefix, value)` 而不是 `value`。

---

## 5. 待办（本阶段未做完的）

| 项 | 说明 |
|---|---|
| `TDefaultMessage` 结构与线格式 | ✅ **已读**（`wire-format.md`，含 `edcode.py` 参考实现 10 项自测） |
| 校验和/防外挂链 | ✅ **已读**（`wire-format.md` §3，含实测值 `Etc=0xDC52`） |
| 392 vs 474 的口径 | 需确认 `reference/mir3-source/README.md` 的 392 从哪来 |
| 服务端分派表完整性 | ✅ **已完成**（`coverage.py` 分层统计；`tools-and-servers.md` 定案 3 个缺失 opcode） |
| `0x400`/`0x408` 等修正的逐条原版复核 | §3.1(c) 的批量结论需逐条回到原版证据原文确认后再落盘 |
| 韩文注释翻译 | 474 条里带注释的尚未系统翻译（本文件只译了涉及的） |

---

## 6. 复核方式

```bash
# 常量表重生成 + 统计（含三表 diff 与重值检测）
python3 Tools/source-read/extract_protocol_constants.py --check

# 独立校验（不得复用生成器解析逻辑）
python3 Tools/source-read/verify_protocol_constants.py

# 读带韩文/中文注释的源码行
python3 Tools/source-read/read_src.py show Source/Common/Grobal2.pas --start 1746 --end 1752
python3 Tools/source-read/read_src.py grep '行会公告' --scope Source/GameServer
```
