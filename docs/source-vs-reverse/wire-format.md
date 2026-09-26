# Preview 源码线格式与防外挂校验（EDCode.pas 精读）

> 证据源：`reference/mir3-source/Source/Common/EDCode.pas`（539 行）、
> `Source/Common/Grobal2.pas`（包头结构）。
> 参考实现：[`Tools/source-read/edcode.py`](../../Tools/source-read/edcode.py)（带 10 项自测，`selftest` 全绿）。
> 证据等级 `secondary-source`。

---

## 1. 三层结构总览

```
┌─ TMsgHeader (16B) ────────── 网关↔服务端 内部头（不发给客户端）
│    Code / SNumber / UserGateIndex / Ident / UserListIndex / temp / length
├─ TDefaultMessage (16B) ───── 客户端↔服务端 消息头（6bit 编码后发出）
│    Recog(4) Ident(2) Param(2) Tag(2) Series(2) Etc(2) Etc2(2)
└─ body ────────────────────── 可选二进制/字符串体（同样 6bit 编码）
```

**`TMsgHeader`**（`Grobal2.pas:9-17`）只在服务进程之间用（注释原文
「게이트와 서버 통신에 사용」= 网关与服务器通信用）。`Code` 注释写着 `$aa55aa55`
但实际未赋值 —— 是设计意图残留。

**`TDefaultMessage`**（`Grobal2.pas:20-28`）是真正的对外协议头，**固定 16 字节**。
源码注释里逐字段标了字节数（`//4` `//2` `//2` …），累计 16，与参考实现一致。

---

## 2. 6bit 编码 `Encode6BitBuf` / `Decode6BitBuf`

### 2.1 算法（`EDCode.pas:154-211` 编码 / `:213-274` 解码）

每字节经两次 XOR，再按 6bit 分组、加 `0x3C` 变成可打印字符：

```
ch = byte
ch ^= (((i + 5) * 2) + 3)        // i = 字节下标（编码用 i，解码用 bufpos）
ch ^= (HIBYTE(key) + LOBYTE(key))  // 注意是加法
然后每 6bit 一组 + 0x3C
```

三个必须记住的细节：

1. **`HIBYTE + LOBYTE` 是加法不是 XOR**（`EDCode.pas:177`/`:247`）。
   默认 `g_EndeKey = $6501`（`:117`）→ `0x65 + 0x01 = 0x66`。
   如果误当 XOR 会算成 `0x64`，编解码仍然自洽（因为 XOR 自反），
   **但与真实客户端/服务端完全不通** —— 这是最容易埋进去的隐蔽 bug。
2. **编码用输入下标 `i`，解码用输出下标 `bufpos`**。两者在正常数据上等价，
   但在 `destlen` 截断或非法字符提前退出时会分叉。
3. **非法字符导致整包作废**：`EDCode.pas:231-236`，字符不在
   `[0x3C, 0x3C+64]` 范围内时 `bufpos := 0; break` —— 返回空。
   这是天然的完整性检查。

### 2.2 编码结果形态

可打印字符集 = `chr(0x3C + v)`，`v ∈ [0, 64]` → 字符落在 `'<'`..`'|'`。
实测 `"hello"`（key=0x6501）→ `URey[sd`；`"Mir3 protocol test..."` → 可打印串。
**6 字节输入 → 8 字符输出**（6bit 打包的 3:4 膨胀）。

### 2.3 被禁用的置换表

`EDCode.pas:39-111` 定义了 256 字节的 `cTable_src` / `dTable_src` 置换表，
配合 `cXorValue = $14`、`g_HideTable = $97`、`g_HideBackTable = $34`（`:116-121`），
但**相关代码全部被注释掉了**（`:172`、`:252-253`，标注 `// added by sonmg`）：

```pascal
// ch := ( cTable_src[ Integer(ch) ] xor g_HideTable ) xor cXorValue;   // added by sonmg
```

→ **当前版本只做两次 XOR + 6bit 打包，没有置换**。三张表是历史遗留。
这是重要结论：如果按「有置换表 = 有置换」推断，会做出错误实现。

---

## 3. 防外挂校验字段 `Etc`

`Etc` 有**两套机制**，容易混淆：

### 3.1 `MakeDefaultMsg` 的掩码编码（`Grobal2.pas:2840-2851`）

```pascal
Etc  := ((HIWORD(hid) and $A3) or $58) xor $8A;
Etc2 := ((LOWORD(hid) and $EC) or $28) xor $A9;
```

`hid` 默认 200。实测 `hid=200`（0xC8）→ `Etc=0xD2`、`Etc2=0x41`。

> 注意 `MakeDefaultMsg` 还带**默认参数** `hid: integer = 200`（`:2798` 声明）。
> Delphi 的默认参数意味着大量调用点根本不传 `hid`，所以线上绝大多数包
> `Etc2` 恒为 `0x41`（当 hid 低 16 位为 0xC8 时）。

### 3.2 `EncodeMessage` 的**覆写**（`EDCode.pas:417-435`）—— 真正的防外挂

```pascal
RandKey := Random(256);
smsg.Etc := MAKEWORD(
  BYTE(RandKey xor $08),
  BYTE(((smsg.Recog and $57CD) + (smsg.Ident or $48) + (smsg.Param or $30)
        + (smsg.Tag and $2D) + smsg.Series) xor (GetPublicKey xor RandKey))
);
```

即 `Etc` 被**整体覆写**（3.1 生成的值在这里被丢掉）：

| Etc 部分 | 值 |
|---|---|
| 低字节 | `RandKey ^ 0x08`（每包随机） |
| 高字节 | `(校验和 ^ key ^ RandKey) & 0xFF` |

其中

```
校验和 = ((Recog and 0x57CD) + (Ident or 0x48) + (Param or 0x30)
          + (Tag and 0x2D) + Series) ^ GetPublicKey
```

**注意 `Ident or 0x48`**：这意味着 `Ident` 的低 3 位在参与校验时被强制置位，
`0x48` 之外的位保持原值。这是原版作者给校验和埋的「盐」。

实测（key=0x6501，RandKey=0x5A，Recog=12345，Ident=1033，Param=1，Tag=2，Series=3）：
校验和 `0x7187` → 高字节 `(0x7187 ^ 0x6501 ^ 0x5A) & 0xFF = 0xDC`；
低字节 `0x5A ^ 0x08 = 0x52` → `Etc = 0xDC52`。与参考实现输出一致。

### 3.3 old version（`EDCode.pas:425` 注释）

```pascal
// smsg.Etc := WORD(((smsg.Recog and $57CD) + (smsg.Ident or $48) + (smsg.Param or $30)
//                   + (smsg.Tag and $2D) + smsg.Series) xor GetPublicKey);
```

**没有 `RandKey`**：整 16 位 `Etc` 直接就是校验和。

**实用价值**：这条注释解释了早期抓包中「`Etc` 高字节与当前版本一致、
低字节恒为 0」的现象 —— 那是 old version 的产物。做老客户端抓包比对时
必须先判断对端用的是哪一版，否则会误判「校验和算错了」。

### 3.4 服务端侧的验证（`UsrEngn.pas:3530` 附近）

服务端拿到包后重算：

```pascal
RandKey := LOBYTE(pmsg.Etc) xor $08;
if BYTE(((pmsg.Recog and $57CD) + (pmsg.Ident or $48) + (pmsg.Param or $30)
         + (pmsg.Tag and $2D) + pmsg.Series) xor (GetPublicKey xor RandKey)) <> HIBYTE(pmsg.Etc)
then begin
   hum.SysMsg('Recorded as user of hacking program(2).', 0);
   hum.EmergencyClose := TRUE;
   MainOutMessage('MacroProgram(2) : ' + hum.UserName);
end;
```

→ 从 `Etc` 低字节**反解出 RandKey**，再用它验高字节。失败即标记外挂并**强制断线**
（`EmergencyClose := TRUE`）。

> ⚠️ 这套校验是**明文密钥 + 纯算法**，不含任何签名/挑战响应。
> `RandKey` 每包随机但随包明文传输（`Etc` 低字节），
> 所以**任何知道算法的人都能伪造合法包** —— 它的实际作用是拦「改包工具误用」
> 和「非本客户端」，不是密码学防护。做协议工具时不要高估它的强度。

---

## 4. 三份 EDCode 副本的关系（实测）

| 文件 | MD5 | 说明 |
|---|---|---|
| `Source/Common/EDCode.pas` | `1915f199…` | **与另两份不同** |
| `Source/GameServer/EDCode.pas` | `1d550769…` | |
| `Source/Tools/ImageEditor/Common/EDCode.pas` | `1d550769…` | 与 GameServer 完全相同 |

`Common/` 那份是**客户端**编译时用的（`Client/CMsg.pas:30`、`ClFunc.pas:7`、
`clEvent.pas:7`、`IntroScn.pas:8`、`MaketSystem.pas:7` 均 `uses EdCode`）。
GameServer 与 ImageEditor 共用另一份。

**服务端 `EncodeMessage` 也带 RandKey**（`GameServer/EDCode.pas:401/408/409`），
与客户端一致 —— 即双向都做校验。

**已做逐行 diff（`diff -w -B`，忽略空白）**：非空白差异 106 行，**唯一实质差异**是
`Common/` 那份多出 `TCrypToSeed` 记录类型 + `Decrypt(FName)` 函数
（`:9-13`、`:465-539`），即 **`.dat`/`.Mir3Res.dat` 文件加解密**
（魔数 `CrypByte = F0 39 AB 8E`、`CrypLong = 0x9FDE1A93`）。
其余差异全部是缩进/`begin...end` 折行风格。

→ **线格式相关代码（`Encode6BitBuf`/`Decode6BitBuf`/`EncodeMessage`/`DecodeMessage`/
`EncodeString`/`DecodeString`）在三份副本里完全一致**。可以放心把
`Tools/source-read/edcode.py` 当作三者的共同参考实现。

> 附带发现：`Decrypt` 的种子常量与 `docs/notes/31-DAT解码任务交接文档.md`
> 里 `WemadeCryptLib.dll` 的结论可能相关（同一族固定 S-box 分组算法），
> 值得在阶段 4「配置与数据」时交叉核对。

---

## 5. 公钥协商（**重要修正**）

先前版本的本文件写「公钥来自 `enckey.txt` 配置文件」。**这是错的** ——
逐链追踪后确认公钥是**登录期动态协商**的：

### 5.1 完整链路

```
LoginServer ──ISM_SEND_PUBLICKEY(118)──→ DataBaseServer  (netloginserver.cpp:21 → OnRecvPublicKey)
                                             │
                                             └─ SetPublicKey(WORD(atoi(szPubKey)))   :131
                                                    │
DataBaseServer ──ISM_SEND_PUBLICKEY──→ GameServer  (IdSrvClient.pas:263 → GetRecvPublicKey)
                                                    │
                                                    ├─ SetPublicKey(WORD(pubkey))     :484
                                                    └─ RunSocket.SendPublicKeyToAllGate(GetPublicKey)  :486
                                                           │
GameServer/RunGate ──SM_SEND_PUBLICKEY(536)──→ 客户端  (ClMain.pas:5413)
                                                           │
                                                           └─ SetPublicKey(msg.Param xor msg.Tag)  :5415
```

**关键点**：

- 客户端收到的不是明文 key，而是 `msg.Param xor msg.Tag`（`ClMain.pas:5415`）——
  又一次简单混淆，不是加密。
- `GameServer/IdSrvClient.pas:487` 的日志
  `'GetRecvPublicKey : ' + IntToStr(GetPublicKey)` 会在服务端启动时**打印公钥明文**。
- `GameServer/IdSrvClient.pas:485` 注释原文：「로그인서버로부터 public키를 받았을 때
  다시 모든 런게이트에 보내준다.」（从登录服收到 public key 后，再转发给所有 RunGate）

### 5.2 与硬编码默认值的关系

`EDCode.pas:117` 仍有 `g_EndeKey: WORD = ($6501)` 作为**编译期默认值**，
但运行时会被上述协商覆盖。`LoadPublicKey(fname)`（`:125-140`，读文本首行）
是**离线工具**（ImageEditor 等）用的旁路，不是线上流程。

### 5.3 对逆向研究的价值

1. **不必去原 rar 里找 `enckey.txt`** —— 线上 key 由协商决定，配置里没有。
2. 取 key 有三条路：
   - 服务端启动日志 `GetRecvPublicKey : <数字>`（最直接）；
   - 抓登录包解 `SM_SEND_PUBLICKEY` 的 `Param xor Tag`；
   - 已知明文包暴力枚举（`key_xor = HIBYTE + LOBYTE` 只有 8 位熵）。
3. 反过来说明：**key 不是安全边界**。它在登录期明文协商，且服务端会打印。
   防外挂校验的作用是拦改包工具误用，不是防有心的攻击者。

---

## 6. 与本仓库既有结论的对照

| 本仓库 | 本轮源码结论 |
|---|---|
| `Tools/wsgateway` 的 packet id 从部署 dll 反射导出 | 反射得到的 id 应与 `protocol-constants.tsv` 的 474 条**按前缀**对齐；本表可作为独立交叉源 |
| 本仓库记录「客户端发包目录 0x3E9-0x419」 | 源码 `CM_` 范围 0x50–0xBDC，**远大于** 0x419 —— 原版证据只覆盖了 UI 相关子集，不是全量 |
| Zircon `LibraryCore/Network/ClientPackets.cs` | Zircon 是**重写的现代协议**，与这套 6bit 编码**无关**（Zircon 用自己的包格式）。两套不可混用 |

---

## 7. 待办

| 项 | 说明 |
|---|---|
| `enckey.txt` | **已确认线上不走这条路**（见 §5）；`LoadPublicKey` 只服务离线工具。配置清单里的 `enckey.txt` 待查是否为冗余项 |
| `TMsgHeader` 的实际填充点 | ⚠️ 仍 pending（只读了结构） |
| `EncodeBuffer` 的 `BUFFERSIZE` 常量值 | `Common/EDCode.pas` 里未直接 grep 到定义，疑似在 `Hutil32.pas`；影响单包 body 上限 |
| old version 的启用时点 | 需比对老客户端二进制判断 |
| `Decrypt` 与 `.dat` 解码研究的交叉 | 种子 `F0 39 AB 8E` / `0x9FDE1A93` 是否与 `WemadeCryptLib.dll` 同族 |
| `CM_ADDNEWUSER`/`CM_CHANGEPASSWORD`/`CM_UPDATEUSER` 的处理点 | ✅ **已定案**：接收端**确实缺失**（`tools-and-servers.md` §1，`verify_missing_opcodes.py` 穷举验证 PASS） |

---

## 9. 登录链路的 opcode 命名空间（**已实测：与游戏协议完全一致**）

`LoginServer/LoginServer/protocol.h` 与 `DataBaseServer/DBSvr/protocol.h`
定义了一套登录/选角 opcode。实测与 `Grobal2.pas` 逐条对照，**10 个全部数值相同**：

| 常量 | `Grobal2.pas`（游戏协议） | `protocol.h`（登录链路） | 一致 |
|---|---:|---:|:--:|
| `CM_QUERYCHR` | 100 (0x64) | 100 | ✅ |
| `CM_NEWCHR` | 101 (0x65) | 101 | ✅ |
| `CM_DELCHR` | 102 (0x66) | 102 | ✅ |
| `CM_SELCHR` | 103 (0x67) | 103 | ✅ |
| `CM_SELECTSERVER` | 104 (0x68) | 104 | ✅ |
| `CM_PROTOCOL` | 2000 (0x7D0) | 2000 | ✅ |
| `CM_IDPASSWORD` | 2001 (0x7D1) | 2001 | ✅ |
| `CM_ADDNEWUSER` | 2002 (0x7D2) | 2002 | ✅ |
| `CM_CHANGEPASSWORD` | 2003 (0x7D3) | 2003 | ✅ |
| `CM_UPDATEUSER` | 2004 (0x7D4) | 2004 | ✅ |

→ **不是两套命名空间，是一套**。`Grobal2.pas` 的 `CM_` 表是**全链路总表**，
登录/选角段（100-104、2000-2004）只是其中一段。

**这解释了那 3 个「客户端发但两层都无 case」的 opcode**：
`CM_ADDNEWUSER`(2002) / `CM_CHANGEPASSWORD`(2003) / `CM_UPDATEUSER`(2004)
属于账号段，由 LoginGate 之后的 LoginServer 处理，而 LoginServer 侧
只收录了 3 条表项（`netlogingate.cpp:25-27` 的
`CM_IDPASSWORD`/`CM_SELECTSERVER`/`CM_PROTOCOL`）。
账号段（2002-2004）的接收端 `case` **在本源码包里确实缺失** ——
要么是 LoginGate 直接转发给 LoginServer 后由其内部处理（未在收录文件中体现），
要么这段代码在未收录的源文件里。**标注为待查，不猜**。

> ✅ 之前版本的本文件曾错误声称「账号族数值完全不同（1101/1103/1105/1106）」，
> 那是把 `SM_` 段的值误当成 `CM_` 段。已实测修正。

**仍然成立的规则**：`CM_*` 常量名在**游戏链路**内唯一，但**同一数值可被
多个前缀（CM/SM/ISM/DBR）复用**（见 `protocol.md` §4 的 31 组跨前缀重值）。
按值查名必须带前缀维度。

---

## 8. 复核方式

```bash
# 参考实现自测（10 项，含真实默认 key 0x6501）
python3 Tools/source-read/edcode.py selftest

# 实测编解码
python3 Tools/source-read/edcode.py encode-string "hello"
python3 Tools/source-read/edcode.py make-msg --ident 1033 --recog 12345 --rand 90

# 读源码原文
python3 Tools/source-read/read_src.py show Source/Common/EDCode.pas --start 154 --end 211
python3 Tools/source-read/read_src.py show Source/Common/Grobal2.pas --start 2840 --end 2851
```
