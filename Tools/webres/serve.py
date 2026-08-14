#!/usr/bin/env python3
"""serve.py — Web 移植资源按需加载原型服务 (FastAPI)。

监听 127.0.0.1:8821，serve WebData 目录 (decode_zl_webp.py 的输出):

    GET /res/interface/manifest.json   → 清单 (帧号/宽高/偏移/codec/字节数)
    GET /res/interface/{frame}.webp    → 单帧 WebP (image/webp)

启动:
    /home/tetsuya/mir3-venv/bin/python serve.py            # 默认根目录
    WEBRES_ROOT=/path/to/WebData python serve.py           # 自定义根目录
"""
from __future__ import annotations

import os
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse

# 资源根目录: 默认 zircon 客户端 WebData，可用 WEBRES_ROOT 覆盖
ROOT = Path(os.environ.get(
    "WEBRES_ROOT",
    "/home/tetsuya/development/zircon/Debug/Client/WebData",
))

app = FastAPI(title="webres", docs_url=None, redoc_url=None)


@app.middleware("http")
async def corp_header(request, call_next):
    """COOP/COEP 隔离页面 (如 Godot Web WASM 客户端) 跨源拉资源时,
    浏览器要求资源带 Cross-Origin-Resource-Policy, 否则直接拦截
    (阶段0 Spike 实测: 同源可加载, 跨源被 COEP require-corp 拦)。"""
    response = await call_next(request)
    response.headers["Cross-Origin-Resource-Policy"] = "cross-origin"
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response


@app.get("/")
def index() -> dict:
    return {
        "service": "webres",
        "routes": [
            "/res/interface/manifest.json",
            "/res/interface/{frame}.webp",
        ],
        "root": str(ROOT),
    }


@app.get("/res/{lib}/manifest.json")
def manifest(lib: str):
    path = ROOT / lib / "manifest.json"
    if not path.is_file():
        raise HTTPException(404, f"manifest not found: {lib}")
    return FileResponse(path, media_type="application/json")


@app.get("/res/{lib}/{frame:int}.webp")
def frame(lib: str, frame: int):
    path = ROOT / lib / f"{frame}.webp"
    if not path.is_file():
        raise HTTPException(404, f"frame not found: {lib}/{frame}")
    return FileResponse(path, media_type="image/webp")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8821, log_level="info")
