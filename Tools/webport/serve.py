#!/usr/bin/env python3
"""serve.py — 网页版传奇3客户端资源服务 (FastAPI :8823)。

从 Tools/webclient/serve.py 迁移（资源管线不变），新增:
    GET /ui/ui_tree.json    → GodotClient/UI/ui_tree.json (只读转发)
    GET /ui/ui_overlay.json → GodotClient/UI/ui_overlay.json (缺省 404)
其余路由与 webclient 一致 (WebData 共享同一份, 不重复占盘):
    GET /res/data/*, /res/walk/*, /res/maps/{stem}/{x}_{y}.webp,
    GET /res/sprites/{lib}/{n}.webp, /res/sprites/{lib}/manifest.json
磁盘守卫: WebData > 3G 时按需渲染返回 507。

启动: /home/tetsuya/mir3-venv/bin/python Tools/webport/serve.py
"""
from __future__ import annotations

import os
import sys
import threading
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

_MIR3 = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_MIR3 / "Tools" / "webres"))
sys.path.insert(0, str(_MIR3 / "Tools" / "common"))
sys.path.insert(0, str(_MIR3 / "Tools" / "maps"))

import webres  # noqa: E402

ROOT = webres.WEB                     # Debug/Client/WebData
STATIC = Path(__file__).resolve().parent
GODOT_UI = Path("/home/tetsuya/development/zircon/GodotClient/UI")
DISK_BUDGET = webres.DISK_BUDGET      # 3G

app = FastAPI(title="webport", docs_url=None, redoc_url=None)

_size_cache = {"bytes": -1, "ts": 0.0}
_size_lock = threading.Lock()


def webdata_size() -> int:
    """WebData 目录字节数 (30s 缓存)。"""
    import time as _t
    now = _t.time()
    if _size_cache["bytes"] >= 0 and now - _size_cache["ts"] < 30:
        return _size_cache["bytes"]
    total = 0
    for p in ROOT.rglob("*"):
        if p.is_file():
            try:
                total += p.stat().st_size
            except OSError:
                pass
    with _size_lock:
        _size_cache.update(bytes=total, ts=now)
    return total


@app.middleware("http")
async def headers(request, call_next):
    resp = await call_next(request)
    resp.headers["Cross-Origin-Resource-Policy"] = "cross-origin"
    resp.headers["Access-Control-Allow-Origin"] = "*"
    # 静态 JS/CSS 与 data JSON 开发期不缓存 (data 会被 webres 重建);
    # 瓦片/精灵帧内容寻址不变 → 长缓存
    path = request.url.path
    resp.headers["Cache-Control"] = "no-cache" if (path.startswith("/static") or path.startswith("/res/data")) \
        else "public, max-age=86400"
    return resp


@app.get("/")
def index():
    return FileResponse(STATIC / "static" / "index.html")


@app.get("/api/disk")
def disk():
    used = webdata_size()
    return {"used_mb": round(used / 1048576, 1), "budget_mb": round(DISK_BUDGET / 1048576, 0),
            "ok": used <= DISK_BUDGET}


@app.get("/ui/{name}")
def ui_file(name: str):
    if "/" in name or ".." in name or not name.endswith(".json"):
        raise HTTPException(400)
    p = GODOT_UI / name
    if not p.is_file():
        raise HTTPException(404, name)
    return FileResponse(p, media_type="application/json")


@app.get("/res/data/{name}")
def data_file(name: str):
    if "/" in name or ".." in name:
        raise HTTPException(400)
    p = ROOT / "data" / name
    if not p.is_file():
        raise HTTPException(404, f"{name}")
    return FileResponse(p, media_type="application/json" if name.endswith(".json") else "application/octet-stream",
                        headers={"Cache-Control": "no-cache"})


@app.get("/res/walk/{stem}.bin")
def walk_file(stem: str):
    p = ROOT / "data" / "walk" / f"{stem}.bin"
    if not p.is_file():
        raise HTTPException(404, stem)
    return FileResponse(p, media_type="application/octet-stream")


_tile_lock = threading.Lock()


@app.get("/res/maps/{stem}/{tile}")
def map_tile(stem: str, tile: str):
    if not tile.endswith(".webp") or not stem.replace("_", "").isalnum():
        raise HTTPException(400)
    try:
        tx, ty = (int(v) for v in tile[:-5].split("_"))
    except ValueError:
        raise HTTPException(400, "tile must be {tx}_{ty}.webp") from None
    p = ROOT / "maps" / stem / f"{tx}_{ty}.webp"
    if p.is_file():
        return FileResponse(p, media_type="image/webp")
    # 按需渲染 (磁盘守卫)
    if webdata_size() > DISK_BUDGET:
        return JSONResponse({"error": "disk budget exceeded", "hint": "预渲染分级方案见 WebData/maps/_estimate.json"}, 507)
    manifest = ROOT / "data" / "maps_manifest.json"
    if not manifest.is_file():
        raise HTTPException(404, "maps_manifest missing (先跑 webres.py data)")
    import json as _json
    m = _json.loads(manifest.read_text(encoding="utf-8"))["maps"].get(stem)
    if not m:
        raise HTTPException(404, f"unknown map {stem}")
    nx, ny = m["tiles"]
    if not (0 <= tx < nx and 0 <= ty < ny):
        raise HTTPException(404, "tile out of range")
    with _tile_lock:
        if not p.is_file():      # 双检: 并发下可能已被渲染
            try:
                webres.render_map_tiles(stem, {"maps": {stem: m}}, only=(tx, ty))
            except Exception as e:
                raise HTTPException(500, f"render failed: {e}") from e
        return FileResponse(p, media_type="image/webp")
    raise HTTPException(404, "tile render produced nothing")


_frame_lock = threading.Lock()


@app.get("/res/sprites/{lib}/{frame}.webp")
def sprite_frame(lib: str, frame: str):
    if frame == "manifest":
        return sprite_manifest(lib)
    if "/" in lib or ".." in lib or not frame.isdigit():
        raise HTTPException(400)
    p = ROOT / "sprites" / lib / f"{frame}.webp"
    if p.is_file():
        return FileResponse(p, media_type="image/webp")
    if webdata_size() > DISK_BUDGET:
        return JSONResponse({"error": "disk budget exceeded"}, 507)
    with _frame_lock:
        if not p.is_file():
            n = webres.extract_frame(lib, int(frame), ROOT / "sprites" / lib)
            if n < 0:
                raise HTTPException(404, f"{lib}/{frame}")
    return FileResponse(p, media_type="image/webp")


@app.get("/res/sprites/{lib}/manifest.json")
def sprite_manifest(lib: str):
    if "/" in lib or ".." in lib:
        raise HTTPException(400)
    p = ROOT / "sprites" / lib / "manifest.json"
    if not p.is_file():
        with _frame_lock:
            if not p.is_file():
                if webres.cmd_manifest(type("A", (), {"lib": lib})) != 0:
                    raise HTTPException(404, lib)
    return FileResponse(p, media_type="application/json")


# 静态资源挂最后 (避免吞掉 /res /api /ui)
app.mount("/static", StaticFiles(directory=STATIC / "static"), name="static")


if __name__ == "__main__":
    import uvicorn
    os.environ.setdefault("WEBRES_ROOT", str(ROOT))
    uvicorn.run(app, host="0.0.0.0", port=8823, log_level="warning")
