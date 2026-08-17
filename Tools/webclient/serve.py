#!/usr/bin/env python3
"""serve.py — 浏览器世界观测试台服务 (FastAPI :8822)。

路由:
    GET /                       → 静态站 Tools/webclient/index.html
    GET /static/*               → 前端资源 (js/css)
    GET /res/data/*             → WebData/data JSON 清单 + walk 位图
    GET /res/maps/{stem}/{x}_{y}.webp   → 地图瓦片 (缺失时按需渲染, 断点续跑产物优先)
    GET /res/sprites/{lib}/{n}.webp     → 精灵帧 (缺失时按需抽取)
    GET /res/sprites/{lib}/manifest.json → 帧元数据 (惰性生成)
    GET /api/disk               → WebData 用量 + 预算
磁盘守卫: WebData > 3G 时按需渲染返回 507, 不再写盘 (预渲染任务自行评估分级方案)。

启动: /home/tetsuya/mir3-venv/bin/python Tools/webclient/serve.py
"""
from __future__ import annotations

import os
import json
import sys
import threading
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles

_EMPTY_WEBP = None   # 1x1 透明 lossless (惰性生成, E5/C6 库内空帧 200 响应用)


def _empty_webp() -> bytes:
    global _EMPTY_WEBP
    if _EMPTY_WEBP is None:
        import io
        from PIL import Image
        buf = io.BytesIO()
        Image.new("RGBA", (1, 1), (0, 0, 0, 0)).save(buf, format="WEBP", lossless=True)
        _EMPTY_WEBP = buf.getvalue()
    return _EMPTY_WEBP

_MIR3 = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(_MIR3 / "Tools" / "webres"))
sys.path.insert(0, str(_MIR3 / "Tools" / "common"))
sys.path.insert(0, str(_MIR3 / "Tools" / "maps"))

import webres  # noqa: E402

ROOT = webres.WEB                     # Debug/Client/WebData
STATIC = Path(__file__).resolve().parent
DISK_BUDGET = webres.DISK_BUDGET      # 3G

app = FastAPI(title="webclient", docs_url=None, redoc_url=None)

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
    # 静态 JS/CSS 与 /lab 数据 (事实源会再生成) 不缓存; /res 资源 (瓦片/帧, 内容不可变) 长缓存
    p = request.url.path
    resp.headers["Cache-Control"] = "no-cache" if (p.startswith("/static") or p.startswith("/lab")) \
        else "public, max-age=86400"
    return resp


@app.get("/")
def index():
    return FileResponse(STATIC / "static" / "index.html")

@app.get("/lab")
def lab_index():
    return FileResponse(STATIC / "static" / "lab.html")


def _client_data() -> Path:
    """zircon/ClientData (E5 数据层 canonical, MIR3_ZIRCON_ROOT 解析)。"""
    zr = Path(os.environ.get("MIR3_ZIRCON_ROOT",
                             str(_MIR3.parent / "zircon"))).resolve()
    return zr / "ClientData"


@app.get("/lab/table")
def lab_table():
    """技能特效事实源 (E5: zircon/ClientData/magic-effects.json, 双端共读)。
    服务端投影回旧扁平结构 (start/release/castAnim/sound 摊平), lab.js 兼容。"""
    p = _client_data() / "magic-effects.json"
    if not p.exists():
        raise HTTPException(500, "ClientData/magic-effects.json 缺失 — "
                                 "运行 Tools/magiclab/merge_effects.py")
    doc = json.loads(p.read_text(encoding="utf-8"))
    flat = {}
    for name, sk in doc["skills"].items():
        o = sk.get("original") or {}
        flat[name] = {"castAnim": sk.get("castAnim"), "notes": sk.get("notes"),
                      "sound": sk.get("sound"), **o}
    return JSONResponse(flat)


@app.get("/lab/frame-formulas")
def lab_frame_formulas():
    """帧公式单一数据源 (E5: zircon/ClientData/frame-formulas.json, 双端共读)。"""
    p = _client_data() / "frame-formulas.json"
    if not p.exists():
        raise HTTPException(500, "ClientData/frame-formulas.json 缺失 — "
                                 "运行 Tools/resedit/frameformulas.py")
    return FileResponse(p, media_type="application/json")

_SAVE_TOP_KEYS = {"frame", "count", "delayMs", "lib", "colour", "kind", "segment", "target",
                  "ctx", "line", "origin", "particle", "startLight", "endLight",
                  "frameExpr", "directionFrames"}
_SAVE_EXTRA_KEYS = {"Blend", "BlendRate", "Opacity", "DrawType", "Skip", "StartDelayMs",
                    "DistanceDelayMs", "Direction", "DirectionSemantic",
                    "Has16Directions", "StartTime"}


@app.post("/lab/save")
def lab_save(body: dict):
    """E5/C7 编辑闭环: 网页编辑 → 写回 ClientData/magic-effects.json original 段
    (帧三元组同步 godot 段) → .bak → 回显校验 → gen_cs_table --check 自检。
    自检失败自动回滚并返回失败详情。"""
    import copy
    import subprocess

    key, entry = body.get("key"), body.get("entry")
    if not key or not isinstance(entry, dict):
        raise HTTPException(400, "body: {key, entry}")
    p = _client_data() / "magic-effects.json"
    if not p.exists():
        raise HTTPException(500, "ClientData/magic-effects.json 缺失")
    doc = json.loads(p.read_text(encoding="utf-8"))
    sk = doc["skills"].get(key)
    if not sk or not sk.get("original"):
        raise HTTPException(404, f"技能 {key} 无 original 段")

    def clean_effects(effects):
        out = []
        for e in effects if isinstance(effects, list) else []:
            if not isinstance(e, dict):
                continue
            ne = {k: e[k] for k in e if k in _SAVE_TOP_KEYS}
            if isinstance(e.get("extra"), dict):
                ne["extra"] = {k: v for k, v in e["extra"].items() if k in _SAVE_EXTRA_KEYS}
            out.append(ne)
        return out

    new_start = clean_effects(entry.get("start", {}).get("effects", []))
    new_release = clean_effects(entry.get("release", {}).get("effects", []))
    if not new_start and not new_release:
        raise HTTPException(400, "空 effects, 拒绝保存")

    def triples(*effects_lists):
        t = []
        for effects in effects_lists:
            for e in effects:
                if isinstance(e.get("frame"), int):
                    t.append((e.get("lib"), e["frame"], e.get("count")))
        return sorted(t)

    orig = sk["original"]
    old_t = triples(orig.get("start", {}).get("effects", []),
                    orig.get("release", {}).get("effects", []))
    new_t = triples(new_start, new_release)
    if len(old_t) != len(new_t):
        raise HTTPException(422, "三元组数量变化 (增删特效不支持), 拒绝保存")

    if old_t != new_t and sk.get("godot"):
        mapping = dict(zip(old_t, new_t))   # 排序后按位对应; check_file 是最终守门
        def sync(x):
            if isinstance(x, dict):
                if isinstance(x.get("startIndex"), int):
                    k3 = (x.get("file"), x["startIndex"], x.get("frameCount"))
                    if k3 in mapping:
                        x["file"], x["startIndex"], x["frameCount"] = mapping[k3]
                for v in x.values():
                    sync(v)
            elif isinstance(x, list):
                for v in x:
                    sync(v)
        g2 = copy.deepcopy(sk["godot"])
        sync(g2)
        sk["godot"] = g2

    bak = p.with_suffix(".json.bak")
    bak.write_text(p.read_text(encoding="utf-8"), encoding="utf-8")
    orig.setdefault("start", {})["effects"] = new_start
    orig.setdefault("release", {})["effects"] = new_release
    text = json.dumps(doc, ensure_ascii=False, indent=1) + "\n"   # 与 merge_effects 同格式
    p.write_text(text, encoding="utf-8")
    try:
        if json.loads(p.read_text(encoding="utf-8")) != doc:
            raise RuntimeError("回显不一致")
        rc = subprocess.run(
            [sys.executable, str(_MIR3 / "Tools" / "magiclab" / "gen_cs_table.py"),
             "--check", "--skip-runtime"],
            capture_output=True, text=True, timeout=120)
        if rc.returncode != 0:
            raise RuntimeError(f"gen_cs_table --check 失败:\n{rc.stdout[-600:]}{rc.stderr[-300:]}")
    except Exception as ex:   # 自检失败 → 回滚
        p.write_text(bak.read_text(encoding="utf-8"), encoding="utf-8")
        return JSONResponse({"ok": False, "error": str(ex)[:900], "rolled_back": True})
    return {"ok": True, "check": "pass", "key": key, "triples": [list(t) for t in new_t]}


@app.get("/lab/magicinfo")
def lab_magicinfo():
    """MagicInfo 全字段 (dbeditor workspace 快照, 只读)。"""
    p = _MIR3 / "Tools" / "dbeditor" / "workspace" / "MagicInfo.json"
    return FileResponse(p, media_type="application/json")


@app.get("/api/disk")
def disk():
    used = webdata_size()
    return {"used_mb": round(used / 1048576, 1), "budget_mb": round(DISK_BUDGET / 1048576, 0),
            "ok": used <= DISK_BUDGET}


@app.get("/res/data/{name}")
def data_file(name: str):
    if "/" in name or ".." in name:
        raise HTTPException(400)
    p = ROOT / "data" / name
    if not p.is_file():
        raise HTTPException(404, f"{name}")
    return FileResponse(p, media_type="application/json" if name.endswith(".json") else "application/octet-stream")


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
                # E5/C6: 库内空帧 → 200 透明 (X-Empty-Frame 标记); 界外 → 404 (原版 Draw 同样静默)
                if webres.frame_state(lib, int(frame)) == "blank":
                    resp = Response(_empty_webp(), media_type="image/webp")
                    resp.headers["X-Empty-Frame"] = "1"
                    return resp
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


# 静态资源挂最后 (避免吞掉 /res /api)
app.mount("/static", StaticFiles(directory=STATIC / "static"), name="static")


if __name__ == "__main__":
    import uvicorn
    os.environ.setdefault("WEBRES_ROOT", str(ROOT))
    uvicorn.run(app, host="0.0.0.0", port=8822, log_level="warning")
