# TEST_RESULTS — WebSocket→TCP 网关 Spike（关卡3）

日期：2026-08-14（服务器日志时间 00:55–00:59）

## 1. 环境/启动

- 网关：`hub start` name=`wsgateway`，`wsgateway.py` 监听 `0.0.0.0:7001`（websockets 15.0.1）
- 服务器：`hub start` name=`zircon-spike-server`，cwd=`/home/tetsuya/development/zircon/Debug/ServerCore`，`dotnet ServerCore.dll`
  （相对路径依赖 `Server.ini`/`Database/`/`Map/` 等，必须以该目录为 cwd）
- 服务器监听证据（日志原文）：
  ```
  [2026年8月14日星期五 00:55:08]: Network Started. Listen: 127.0.0.1:7000
  ```
- 测试账号：test@test.com / test123（Users.db 已有，已激活，1 个角色 TestHero）

## 2. 登录包字节构造依据

`login_client.py` 输出的 C.Login（49B）：

```
31000000 b600 0d 7465737440746573742e636f6d 07 74657374313233 14 3566306538613162396333643766326134653662
└─ 总长49 └id182 └len13 └"test@test.com"    └len7 └"test123" └len20 └"5f0e8a1b9c3d7f2a4e6b"(CheckSum)
```

构造依据（全部为实际读取的源码）：

| 字节 | 依据 |
|---|---|
| int32 LE 总长（含自身4B） | `LibraryCore/Network/Packet.cs:182`（`writer.Write(packet.Length + 4)`） |
| int16 LE packet id = 182 | `Packet.cs:172` + `packet_id_dump/` 对 `Debug/ServerCore/LibraryCore.dll` 反射导出（表由 Packet.cs:23-48 排序，勿手算） |
| 字段序 EMail/Password/CheckSum | `LibraryCore/Network/ClientPackets.cs:55-60` 声明序 + `Packet.cs:191-193`（GetProperties 声明序） |
| string = 7-bit 变长长度+UTF-8 | `Packet.cs:81`（`BinaryWriter.Write(string)`） |
| CheckSum 内容 = 20 位随机指纹 | `GodotClient/Network/ServerConnection.cs:23-31`（Guid N 格式前 20 位，存 user://checksum.bin），服务器不校验只记录（SEnvir.cs:3414-3415） |
| 无首包加密/版本握手 | `BaseConnection.cs:69-127` 裸 socket；`Server.ini` CheckVersion=False → `SConnection.cs:270-283` 直接 GoodVersion |

## 3. 服务器日志证据（原文行）

Python 客户端经 WS 网关（Security=5f0e8a1b9c3d7f2a4e6b，与发送字节逐字一致）：

```
[2026年8月14日星期五 00:55:17]: [Connection] IP Address:127.0.0.1
[2026年8月14日星期五 00:55:19]: [Account Logon] Admin: False, Account: test@test.com, IP Address: 127.0.0.1, Security: 5f0e8a1b9c3d7f2a4e6b
```

真实 Chromium（无头）经 WS 网关（Security=browser-spike-fingerprint）：

```
[2026年8月14日星期五 00:58:19]: [Account in Use] Account: test@test.com, Current IP: 127.0.0.1, New IP: 127.0.0.1, Security: browser-spike-fingerprint
[2026年8月14日星期五 00:58:34]: [Account Logon] Admin: False, Account: test@test.com, IP Address: 127.0.0.1, Security: browser-spike-fingerprint
```

> 00:57–00:59 间日志里另有 Security=46ea770111184c7da6ff 的登录/StartGame 行，来自并行的兄弟会话（非本 Spike）；
> 00:58:19 首次浏览器登录得 AlreadyLoggedIn 正是因为该会话占用账号，2s 后重试即 Success。

## 4. 回包解析

Python 客户端（经 WS 网关，`S.Login` rtt=1.436ms）：

```
result=Success (code 10)   message='' duration=0.0s   rest=120B
rest hex[0:64]=0101000000010100000008546573744865726f00ff000000000201000000ef14eb7990f9de480100000000010000000045687474703a2f2f3134352e3233392e
   解读: 01 Characters非空 | 01000000 count=1 | 01 元素非空 | (SelectInfo.Index=0x01000000?) 08 546573744865726f="TestHero" ...
```

字段序依据 `ServerPackets.cs:25-43` + `Packet.cs` 写序：`byte Result`（LoginResult:byte，Enum.cs:2302）→
`string Message`（空）→ `int64 Duration ticks`（0）→ 其余（Characters/Items/BlockList/Address/TestServer/IsGM）不展开。

浏览器客户端（Chromium 150 无头，页面 origin=http://127.0.0.1:7002）：

```
ws OPEN → got G.Connected → got G.GoodVersion
C.Login 54B: 36000000b6000d7465737440746573742e636f6d07746573743132331962726f777365722d7370696b652d66696e6765727072696e74
S.Login: result=Success rtt=60.600ms payloadLen=130 hex[0:16]=0a000000000000000000010100000001
   解读: 0a=10 Success | len0 Message | 0×8B Duration | 01 Characters非空 | 01000000 count=1 …
```

**登录包被服务器完整接受：两种客户端（Python/浏览器）均得到 Success，且服务器日志解析出的账号与指纹和发送字节完全一致。**

浏览器环境注意：从 `about:blank`（opaque origin）连 `ws://127.0.0.1:7001` 被 Chrome 拒绝
（readyState=3，Local Network Access 限制）；页面改由 `http://127.0.0.1:7002` 提供后立即成功。
→ Web 版部署时游戏页面与网关同源（或 localhost/https+策略放行）即可，Godot4 Web 导出同理。

## 5. RTT 对比（发送 C.Login → 收到回包首字节；每次样本全新连接+握手，样本间隔 150ms）

| 路径 | n | min | avg | max |
|---|---|---|---|---|
| 直连 TCP 127.0.0.1:7000 | 12 | 0.154 ms | **3.582 ms** | 11.800 ms |
| 经 WS 网关 :7001 | 12 | 0.153 ms | **2.318 ms** | 7.663 ms |

明细（WS）：1.874 2.153 2.928 4.500 0.170 0.263 0.168 0.153 0.288 0.979 6.682 7.663
明细（TCP）：0.423 3.251 6.846 6.691 0.257 0.737 5.945 0.154 0.182 4.416 2.276 11.800

- **WS 路径 avg 反而更低：网关本身的转发出埋在同机噪声之下**。RTT 主导项是 ServerCore 主循环
  tick 的处理时机（样本 0.15ms~11ms 的抖动在两条路径上同分布），网关每包额外开销 <0.2ms。
- 样本交替出现 AlreadyLoggedIn：150ms 间隔偶发赶不上服务器清理上一条连接（SEnvir CleanUp 竞态），
  属预期行为，不影响计时（回包仍在服务器主循环内生成）。
- 附测（连接建立开销，connect→收到 G.Connected，各 10 次）：
  TCP avg 15.6ms / WS avg 52.2ms（其中一次 361ms 冷启动离群）——WS 多一次 HTTP Upgrade 握手 + 网关二次连接，
  一次性成本 ~5-40ms，仅登录时发生一次。

## 6. 断开传播（合同项：任一侧断开则两侧都关）

- 客户端先断：网关日志 30+ 次 `WS connected` ↔ `relay closed` 成对，TCP 侧由 writer.close() 关闭。
- 服务器先断（踢号场景）：A 连接登录成功后保持，B 连接用同 IP+同指纹再登录 →
  服务器对 A 执行 TrySendDisconnect。A 实际收到：
  ```
  0a000000 0500 05000000        → G.PingResponse{Ping=5ms}
  06000000 0400                 → G.Ping
  07000000 0200 04              → G.Disconnect{Reason=4=AnotherUser}（Enum.cs:2356）
  ConnectionClosedOK: received 1000 (OK)   ← 网关在服务器关 TCP 后关闭了 A 的 WS
  ```
  两个方向均验证通过。

## 7. 评估：透传网关 vs 内嵌 ServerCore（Web 移植路线取舍）

**开发量**：透传网关 ~150 行 Python、零协议知识、零服务器改动（本次实测一天内跑通含字节复刻）；
内嵌需给 ServerCore 加 WebSocket 端点（ASP.NET Core / System.Net.WebSockets）、把 SConnection 的
TcpClient 换成 Stream 抽象、处理宿主生命周期——侵入 ServerLibrary，回归面大。

**延迟**：同机透传每包开销 <0.2ms，被服务器主循环抖动（同分布 0.15–11ms）完全淹没；
对游戏手感无感知差异。跨机部署时网关到 ServerCore 走内网，仍优于浏览器直连绕公网。

**连接生命周期**：透传把 1 个玩家变成 2 条连接（浏览器↔网关、网关↔ServerCore），fd 翻倍、
级联关闭需网关保证（已验证两个方向）；断线检测多一跳（WS close frame 15s+ 才可能到达，需依赖
服务器 G.Ping 20s 超时兜底，透传下天然工作）。内嵌是单连接，无此问题。

**心跳/超时风险**：
- ServerCore 20s 无数据即踢（`Server.ini` TimeOut），保活靠 2s G.Ping 往返——透传字节流不动，语义完整。
- 风险点在**网关自身重启/热更新**：所有玩家 TCP 同时断，触发全服重连风暴；内嵌方案同样存在进程重启问题但无中间层。
- **最大风险：IP 语义坍缩**。SConnection 看到的 RemoteEndPoint 永远是网关 IP（127.0.0.1/网关内网 IP）：
  - `SEnvir.IPCount` 按 IP 限流失效/误伤（全体玩家共享一个计数桶）；
  - Account-in-use 的 `LastIP != con.IPAddress` 判定（SEnvir.cs:3366）退化为只看 CheckSum，
    本次实测同 IP+同指纹登录会直接踢旧连接（见 §6）；
  - 封禁/审计按 IP 记录全部指向网关。
  纯透传无法解决——要么网关升级为带会话层（PROXY protocol / 自定义首包传真实 IP，ServerCore 需小改），
  要么走内嵌 WebSocket。

**建议**：开发期与单机 Spike 用透传网关（零侵入、够快、已验证）；正式 Web 服不建议长期停在纯透传——
先透传上线，随后在网关↔ServerCore 之间引入真实 IP 透传（最小改动），或直接给 ServerCore 内嵌
WebSocket 监听作为最终形态。若浏览器端最终用 Godot4 Web 导出，协议层（帧/id/序列化）已由本 Spike
证明可在 JS/TS 中完整复刻（packet_id_dump 表 + §2 规则即为移植规格）。

## 8. 运行状态（收尾时）

```
$ hub ps   （2026-08-14 09:01 收尾快照，仅列相关行）
- wsgateway: ready pid=1594289 uptime=5m39s restarts=0
- zircon-spike-server: ready pid=1594682 uptime=5m36s restarts=0
```

两进程按要求保持运行（hub name：`wsgateway` / `zircon-spike-server`）。
收尾复测：`login_client.py --transport ws` 仍返回 Success（rtt=0.381ms）。
