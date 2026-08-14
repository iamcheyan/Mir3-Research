# wsgateway — Zircon WebSocket→TCP 网关 Spike（阶段0 关卡3）

验证浏览器侧 WebSocket 客户端能通过网关与 ServerCore（TCP :7000）完成登录包交互。
**结论：通过**（Python 客户端 + 真实 Chromium 无头浏览器均登录成功），实测数据见 `TEST_RESULTS.md`。

## 文件

| 文件 | 说明 |
|---|---|
| `wsgateway.py` | 透传网关：监听 `ws://0.0.0.0:7001`，每条 WS 连接对应一条到 `127.0.0.1:7000` 的 TCP（`asyncio.open_connection`），二进制帧双向透传，任一侧断开两侧同关，无协议解析 |
| `login_client.py` | Python 测试客户端：按 C# 源码复刻 C.Login 字节，`--transport ws/tcp`，`--bench N` RTT 基准，解析 S.Login |
| `packet_id_dump/` | C# 反射小工具，从服务器实际使用的 `Debug/ServerCore/LibraryCore.dll` 导出 packet id 表 |
| `TEST_RESULTS.md` | 实测记录 |

## 用法

```bash
# 1. 启动网关（hub: name=wsgateway）
/home/tetsuya/mir3-venv/bin/python wsgateway.py

# 2. 启动服务器（hub: name=zircon-spike-server, cwd=Debug/ServerCore）
dotnet ServerCore.dll   # 日志出现 "Network Started. Listen: 127.0.0.1:7000"

# 3. 经网关登录
/home/tetsuya/mir3-venv/bin/python login_client.py --transport ws

# 4. 对照：直连 TCP
/home/tetsuya/mir3-venv/bin/python login_client.py --transport tcp

# 5. RTT 基准（每条路径 N 次全新连接+握手）
/home/tetsuya/mir3-venv/bin/python login_client.py --transport ws --bench 12
/home/tetsuya/mir3-venv/bin/python login_client.py --transport tcp --bench 12
```

## 线路协议（从 C# 源码复刻的依据）

### 帧格式 — `LibraryCore/Network/Packet.cs`

- `GetPacketBytes()`（Packet.cs:165-187）：`[int32 LE 总长][int16 LE packet id][payload]`，
  **总长 = 4 + 2 + payload 长度**（长度前缀包含自身，Packet.cs:182）。
- `ReceivePacket()`（Packet.cs:121-164）：同样规则；最小合法包 6 字节，最大 64MB（Packet.cs:133-135）。
- 字段写序 = 属性声明序（`GetProperties()` 元数据序，Packet.cs:191-193）。
- 字符串 = C# `BinaryWriter.Write(string)`：**7-bit 变长长度前缀 + UTF-8**（Packet.cs:81）。
- 数值全部小端（BinaryWriter 默认）。
- 枚举按底层类型写（Packet.cs:208-209）；引用类型属性先写 1 字节非空标志（Packet.cs:201-205）；
  `List<T>` 先写 bool 非空 + int32 数量（Packet.cs:212-216）。
- **无加密**：`BaseConnection` 直接读写原始 socket（BaseConnection.cs:69-127），TCP 流不套加密层
  （`Encryption.cs` 的 `GetWriter` 只用于 DB 存盘，Session.cs:281/320）。
- **无 checksum 算法**：`C.Login.CheckSum` 只是客户端生成的机器指纹字符串
  （`ServerConnection.cs:23-31`：`user://checksum.bin` 里存 Guid 前 20 位），服务器仅记录/用于异地登录判定。

### Packet id — 静态排序表（Packet.cs:23-48）

id = 类型在 `Packets` 表中的索引。排序规则：GeneralPackets 命名空间置顶、组内按类名 Ordinal 排序，
比较器跨命名空间时不满足全序，**手算不可靠**，必须从实际 DLL 导出。
`packet_id_dump/Program.cs` 用反射读取私有静态字段 `Packets`，对本服务器 DLL 实测：

| id | 包 | id | 包 |
|---|---|---|---|
| 0 | G.CheckVersion | 4 | G.Ping |
| 1 | G.Connected | 5 | G.PingResponse |
| 2 | G.Disconnect | 6 | G.Version |
| 3 | G.GoodVersion | **182 / 183** | **C.Login / S.Login** |
| 343 | C.SelectLanguage | 184 / 344 | C.Logout / S.SelectLogout |

> 注意：重建 LibraryCore 增删包类会使 id 漂移；`wsgateway.py` 是纯透传不受影响，只有 `login_client.py` 依赖此表。

### 握手与登录流程（无首包加密/版本握手，因 `Server.ini` CheckVersion=False）

```
TCP 连接 ──> 服务器主动发 G.Connected        (SConnection.cs:63，accept 即发)
客户端 ──> G.Connected                       (ServerConnection.cs:364-368)
服务器 ──> G.GoodVersion{DatabaseKey,Ver}    (SConnection.cs:270-283；EncryptionEnabled=False → key 为空)
客户端 ──> C.SelectLanguage{Chinese}         (ServerConnection.cs:371)
客户端 ──> C.Login{EMail,Password,CheckSum}  (ServerConnection.cs:893-896)
服务器 ──> S.Login{Result:byte, Message:string, Duration:i64, Characters…}  (SEnvir.cs:3396-3408)
```

- 保活：服务器空闲 2s 发 G.Ping（`Server.ini` PingDelay），客户端必须回 G.Ping
  （ServerConnection.cs:379），否则 20s 超时踢线（`Server.ini` TimeOut）。
- `LoginResult : byte`（Enum.cs:2302-2315，Success=10）；`DisconnectReason : byte`（Enum.cs:2350-2362，AnotherUser=4）。

### 关键源码位置（zircon 仓库，只读）

| 主题 | 位置 |
|---|---|
| SendLogin | `GodotClient/Network/ServerConnection.cs:893-896` |
| CheckSum 生成 | `GodotClient/Network/ServerConnection.cs:18-32` |
| 客户端握手（Connected/GoodVersion/Ping） | `GodotClient/Network/ServerConnection.cs:364-380` |
| C.Login 定义 | `LibraryCore/Network/ClientPackets.cs:55-60` |
| S.Login 定义 | `LibraryCore/Network/ServerPackets.cs:25-43` |
| 帧格式/序列化 | `LibraryCore/Network/Packet.cs:121-299` |
| 原始 TCP 收发（无加密） | `LibraryCore/Network/BaseConnection.cs:69-198` |
| 服务器 accept 即发 G.Connected | `ServerLibrary/Envir/SConnection.cs:43-64` |
| 版本握手分支 | `ServerLibrary/Envir/SConnection.cs:270-301` |
| 登录分发 | `ServerLibrary/Envir/SConnection.cs:350-355` |
| 登录逻辑/日志行 | `ServerLibrary/Envir/SEnvir.cs:3262-3419` |
| LoginResult 枚举 | `LibraryCore/Enum.cs:2302-2315` |
