#!/usr/bin/env python3
"""WebSocket -> TCP 透传网关（Zircon Web 移植 Spike 关卡3）。

浏览器 WS 客户端连 ws://0.0.0.0:7001，网关为每条 WS 连接开一条到
127.0.0.1:7000 (ServerCore) 的 TCP 连接，二进制帧双向透传，不做任何
协议解析；任一侧断开则两侧同时关闭。

用法:
    /home/tetsuya/mir3-venv/bin/python wsgateway.py [--listen 0.0.0.0:7001] [--tcp 127.0.0.1:7000]
"""

import argparse
import asyncio
import logging

from websockets.asyncio.server import serve

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)
log = logging.getLogger("wsgateway")

TCP_HOST = "127.0.0.1"
TCP_PORT = 7000


async def pump_ws_to_tcp(ws, tcp_writer):
    """WS -> TCP: 每收到一个二进制帧就原样写入 TCP。"""
    try:
        async for message in ws:
            if isinstance(message, str):
                # 协议是纯二进制；文本帧按 UTF-8 编码后透传，保持字节流不变。
                message = message.encode("utf-8")
            tcp_writer.write(message)
            await tcp_writer.drain()
    except Exception as e:
        log.debug("ws->tcp pump ended: %r", e)


async def pump_tcp_to_ws(reader, ws):
    """TCP -> WS: 读到多少转发多少（不组包、不解析长度前缀）。"""
    try:
        while True:
            data = await reader.read(65536)
            if not data:
                break
            await ws.send(data)
    except Exception as e:
        log.debug("tcp->ws pump ended: %r", e)


async def handle(ws):
    peer = ws.remote_address
    log.info("WS connected: %s", peer)
    try:
        reader, writer = await asyncio.open_connection(TCP_HOST, TCP_PORT)
    except OSError as e:
        log.error("cannot reach ServerCore %s:%d: %r", TCP_HOST, TCP_PORT, e)
        await ws.close(1013, "upstream unavailable")
        return

    t1 = asyncio.create_task(pump_ws_to_tcp(ws, writer))
    t2 = asyncio.create_task(pump_tcp_to_ws(reader, ws))
    _, pending = await asyncio.wait({t1, t2}, return_when=asyncio.FIRST_COMPLETED)

    # 任一侧结束：关闭另一侧（写 EOF / 关 socket），并等待任务退出。
    if t1 in pending:
        t1.cancel()
    if t2 in pending:
        t2.cancel()
    try:
        writer.close()
        await writer.wait_closed()
    except Exception:
        pass
    try:
        await ws.close()
    except Exception:
        pass
    await asyncio.gather(t1, t2, return_exceptions=True)
    log.info("relay closed: %s", peer)


async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--listen", default="0.0.0.0:7001", help="WS 监听地址")
    parser.add_argument("--tcp", default="127.0.0.1:7000", help="ServerCore TCP 地址")
    args = parser.parse_args()

    global TCP_HOST, TCP_PORT
    host, _, port = args.tcp.rpartition(":")
    TCP_HOST, TCP_PORT = host or "127.0.0.1", int(port)

    lhost, _, lport = args.listen.rpartition(":")
    async with serve(handle, lhost or "0.0.0.0", int(lport), max_size=8 * 1024 * 1024):
        log.info(
            "wsgateway listening on ws://%s:%d -> tcp %s:%d",
            lhost, int(lport), TCP_HOST, TCP_PORT,
        )
        await asyncio.get_running_loop().create_future()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
