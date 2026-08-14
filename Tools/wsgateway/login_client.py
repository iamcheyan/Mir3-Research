#!/usr/bin/env python3
"""Zircon 登录协议 Python 测试客户端（WS 网关 Spike）。

字节构造 1:1 复刻 C# 源码（LibraryCore/Network/Packet.cs 的
GetPacketBytes/WriteObject + GodotClient/Network/ServerConnection.cs 的
SendLogin 流程），详见 README.md。

线路格式（无加密、无额外握手）:
    [int32 LE 总长(含自身4字节)][int16 LE packet id][payload...]

握手流程:
    TCP 连上 -> 服务器主动发 G.Connected (id=1)
    客户端回 G.Connected -> 服务器回 G.GoodVersion (id=3)（CheckVersion=False）
    客户端发 C.SelectLanguage (id=343, 模拟真实客户端)
    客户端发 C.Login (id=182): string EMail + string Password + string CheckSum
    服务器回 S.Login (id=183): byte Result + string Message + int64 Duration + ...

用法:
    # 经 WS 网关 (ws://127.0.0.1:7001) 单次登录
    /home/tetsuya/mir3-venv/bin/python login_client.py

    # 直连 TCP :7000
    /home/tetsuya/mir3-venv/bin/python login_client.py --transport tcp

    # RTT 基准: 每条路径各 N 次（每次全新连接+握手），报告 avg/max
    /home/tetsuya/mir3-venv/bin/python login_client.py --transport ws --bench 12
"""

import argparse
import asyncio
import statistics
import struct
import time

# ---------------------------------------------------------------------------
# Packet id 表 —— 由 packet_id_dump/ 对服务器实际使用的 LibraryCore.dll
# 反射导出（LibraryCore/Network/Packet.cs 静态排序表），勿手改。
# ---------------------------------------------------------------------------
ID_G_DISCONNECT = 2
ID_G_CONNECTED = 1
ID_G_GOODVERSION = 3
ID_G_PING = 4
ID_C_LOGIN = 182
ID_S_LOGIN = 183
ID_C_SELECTLANGUAGE = 343

LOGIN_RESULT = {
    0: "Disabled", 1: "BadEMail", 2: "BadPassword", 3: "AccountNotExists",
    4: "AccountNotActivated", 5: "WrongPassword", 6: "Banned",
    7: "AlreadyLoggedIn", 8: "AlreadyLoggedInPassword",
    9: "AlreadyLoggedInAdmin", 10: "Success",
}


# --------------------------- C# BinaryWriter 兼容编码 ---------------------------

def write_u7(value: int) -> bytes:
    """BinaryWriter 7-bit 编码长度（LEB128，用于 string 前缀）。"""
    out = bytearray()
    while value >= 0x80:
        out.append((value & 0x7F) | 0x80)
        value >>= 7
    out.append(value)
    return bytes(out)


def write_string(s: str) -> bytes:
    data = s.encode("utf-8")
    return write_u7(len(data)) + data


def build_packet(packet_id: int, payload: bytes = b"") -> bytes:
    """复刻 Packet.GetPacketBytes(): 长度前缀 = 4 + 2 + len(payload)。"""
    total = 4 + 2 + len(payload)
    return struct.pack("<i", total) + struct.pack("<h", packet_id) + payload


def build_login(email: str, password: str, checksum: str) -> bytes:
    """复刻 C.Login 序列化：属性按声明序 EMailAddress/Password/CheckSum。"""
    return build_packet(
        ID_C_LOGIN,
        write_string(email) + write_string(password) + write_string(checksum),
    )


# ------------------------------- 流式解码 ---------------------------------------

class PacketStream:
    """把字节流切成 (id, payload)；与 Packet.ReceivePacket 相同的帧规则。"""

    def __init__(self):
        self.buf = bytearray()

    def feed(self, data: bytes):
        self.buf += data

    def next_packet(self):
        if len(self.buf) < 4:
            return None
        total = int.from_bytes(self.buf[0:4], "little")
        if total < 6:
            raise ValueError(f"invalid packet length {total}")
        if len(self.buf) < total:
            return None
        pid = int.from_bytes(self.buf[4:6], "little")
        payload = bytes(self.buf[6:total])
        del self.buf[:total]
        return pid, payload


def read_bs7(buf: memoryview, pos: int):
    val, shift = 0, 0
    while True:
        b = buf[pos]
        pos += 1
        val |= (b & 0x7F) << shift
        if not b & 0x80:
            return val, pos
        shift += 7


def read_string(buf: memoryview, pos: int):
    n, pos = read_bs7(buf, pos)
    s = bytes(buf[pos:pos + n]).decode("utf-8", "replace")
    return s, pos + n


def parse_s_login(payload: bytes) -> dict:
    """S.Login: byte Result, string Message, int64 Duration, 其余(角色列表等)不展开。"""
    mv = memoryview(payload)
    result = mv[0]
    pos = 1
    message, pos = read_string(mv, pos)
    duration_ticks = int.from_bytes(mv[pos:pos + 8], "little", signed=True)
    rest = bytes(mv[pos + 8:])
    return {
        "result_code": result,
        "result": LOGIN_RESULT.get(result, f"?{result}"),
        "message": message,
        "duration_s": duration_ticks / 10_000_000,
        "rest_len": len(rest),
        "rest_hex_head": rest[:64].hex(),
    }


# ------------------------------- 传输抽象 ---------------------------------------

class TcpTransport:
    def __init__(self, host, port):
        self.host, self.port = host, port
        self.reader = self.writer = None

    async def connect(self):
        self.reader, self.writer = await asyncio.open_connection(self.host, self.port)

    async def send(self, data: bytes):
        self.writer.write(data)
        await self.writer.drain()

    async def recv(self) -> bytes:
        data = await self.reader.read(65536)
        if not data:
            raise ConnectionError("TCP EOF")
        return data

    async def close(self):
        if self.writer:
            self.writer.close()
            try:
                await self.writer.wait_closed()
            except Exception:
                pass


class WsTransport:
    def __init__(self, url):
        self.url = url
        self.ws = None

    async def connect(self):
        from websockets.asyncio.client import connect
        self.ws = await connect(self.url, max_size=8 * 1024 * 1024)

    async def send(self, data: bytes):
        await self.ws.send(data)

    async def recv(self) -> bytes:
        msg = await self.ws.recv()
        if isinstance(msg, str):
            return msg.encode()
        return msg

    async def close(self):
        if self.ws:
            await self.ws.close()


# ------------------------------- 登录流程 ---------------------------------------

async def read_packet(tr, stream, respond_ping=True, timeout=10.0):
    """收下一个完整包；路上遇到 G.Ping 就回 G.Ping（保活，与真实客户端一致）。"""
    while True:
        pkt = stream.next_packet()
        if pkt is None:
            data = await asyncio.wait_for(tr.recv(), timeout)
            stream.feed(data)
            continue
        pid, payload = pkt
        if pid == ID_G_PING and respond_ping:
            # 服务器空闲 2s 发 G.Ping，必须回否则 20s 超时踢线
            # （ServerConnection.cs:379 / SConnection.cs:302）。
            await tr.send(build_packet(ID_G_PING))
            continue
        return pkt


async def login_once(tr, email, password, checksum, verbose=True):
    """完整登录流程，返回 (rtt_seconds, s_login_dict)。"""
    # （计时点：login 包发送 -> S.Login 到达）

    await tr.connect()
    stream = PacketStream()

    # 1) 服务器 accept 后立刻发 G.Connected（SConnection.cs:63）
    pid, payload = await read_packet(tr, stream)
    if pid != ID_G_CONNECTED:
        raise RuntimeError(f"expected G.Connected, got packet id {pid}")

    # 2) 客户端回 G.Connected（ServerConnection.cs:367）
    await tr.send(build_packet(ID_G_CONNECTED))

    # 3) 服务器回 G.GoodVersion（CheckVersion=False, SConnection.cs:270-283）
    pid, payload = await read_packet(tr, stream)
    if pid != ID_G_GOODVERSION:
        raise RuntimeError(f"expected G.GoodVersion, got packet id {pid}")
    mv = memoryview(payload)
    keylen = int.from_bytes(mv[0:4], "little")
    db_version, _ = read_string(mv, 4 + keylen)
    if verbose:
        print(f"  handshake: GoodVersion dbVersion={db_version!r} databaseKeyLen={keylen}")

    # 4) 模拟真实客户端发 SelectLanguage（ServerConnection.cs:371）
    await tr.send(build_packet(ID_C_SELECTLANGUAGE, write_string("Chinese")))

    # 5) 发送 C.Login，RTT = send -> 回包首字节（首次 recv 返回时刻）
    pkt = build_login(email, password, checksum)
    if verbose:
        print(f"  -> C.Login ({len(pkt)}B): {pkt.hex()}")
    send_t = time.perf_counter()
    await tr.send(pkt)
    first_byte_t = None
    while True:
        got = stream.next_packet()
        if got is None:
            data = await asyncio.wait_for(tr.recv(), 10.0)
            if first_byte_t is None:
                first_byte_t = time.perf_counter()  # 收到回包首块，停表
            stream.feed(data)
            continue
        pid, payload = got
        if pid == ID_S_LOGIN:
            rtt = (first_byte_t or time.perf_counter()) - send_t
            return rtt, parse_s_login(payload)
        if pid == ID_G_PING:
            await tr.send(build_packet(ID_G_PING))
            continue
        if pid == ID_G_DISCONNECT:
            raise RuntimeError("server sent G.Disconnect before S.Login")
        # 其它包忽略，继续等（SelectLanguage 无回包）


async def bench(args, make_transport, n):
    rtts, results = [], []
    for i in range(n):
        tr = make_transport()
        try:
            rtt, info = await login_once(tr, args.email, args.password, args.checksum, verbose=False)
        except Exception as e:
            print(f"  sample {i + 1}: FAILED {e!r}")
            await asyncio.sleep(0.15)
            continue
        rtts.append(rtt * 1000)
        results.append(info["result"])
        print(f"  sample {i + 1:2d}: rtt={rtt * 1000:7.3f} ms  result={info['result']}")
        await tr.close()
        await asyncio.sleep(0.15)  # 让服务器清理上一条连接（Account in Use 竞态）
    if not rtts:
        raise RuntimeError("no successful samples")
    return {
        "n": len(rtts),
        "min": min(rtts), "avg": statistics.fmean(rtts), "max": max(rtts),
        "results": results,
    }


async def run(args):
    if args.transport == "ws":
        make = lambda: WsTransport(args.ws)
    else:
        make = lambda: TcpTransport(*args.tcp.rsplit(":", 1))

    if args.bench:
        stats = await bench(args, make, args.bench)
        print(f"BENCH[{args.transport}] n={stats['n']} "
              f"min={stats['min']:.3f}ms avg={stats['avg']:.3f}ms max={stats['max']:.3f}ms "
              f"results={sorted(set(stats['results']))}")
        return

    tr = make()
    try:
        rtt, info = await login_once(tr, args.email, args.password, args.checksum)
        print(f"  <- S.Login rtt={rtt * 1000:.3f} ms")
        print(f"  result={info['result']} (code {info['result_code']})")
        print(f"  message={info['message']!r} duration={info['duration_s']:.1f}s")
        print(f"  rest={info['rest_len']}B hex[0:64]={info['rest_hex_head']}")
    finally:
        await tr.close()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--transport", choices=["ws", "tcp"], default="ws")
    p.add_argument("--ws", default="ws://127.0.0.1:7001")
    p.add_argument("--tcp", default="127.0.0.1:7000")
    p.add_argument("--email", default="test@test.com")
    p.add_argument("--password", default="test123")
    p.add_argument("--checksum", default="5f0e8a1b9c3d7f2a4e6b",
                   help="客户端随机生成的机器指纹（ServerConnection.cs:23-31），服务器仅记录")
    p.add_argument("--bench", type=int, default=0, help="N 次 RTT 基准")
    args = p.parse_args()
    asyncio.run(run(args))


if __name__ == "__main__":
    main()
