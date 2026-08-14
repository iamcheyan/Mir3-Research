"""uieditor — Zircon Godot 客户端 UI 所见即所得 Web 编辑器（:8820）。

数据流：
  GodotClient --ui-export → UI/ui_tree.json（46 窗口控件树，1024x768 逻辑坐标）
  → 本服务渲染（贴图 /zl/{lib}/{frame}.png 实时解码，dbeditor 同款 zlsdk）
  → 编辑 diff 保存为 UI/ui_overlay.json（原子写 + 备份）
  → 游戏内 F12 热重载生效（零重启迭代）。

红线：overlay 只改视觉属性（location/size/text/fontSize/visible/颜色），
永不动逻辑/事件绑定 —— 属性面板与 UiOverlay.cs 开放同一集合。
"""
from __future__ import annotations

import json
import os
import re
import sys
import threading
import time
from pathlib import Path
from typing import Any
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

UIEDITOR = Path(__file__).resolve().parent
REPO = UIEDITOR.parent.parent                       # Mir3-Research 仓库根
ZIRCON = Path(os.environ.get("ZIRCON_ROOT", "/home/tetsuya/development/zircon"))
UI_TREE_PATH = ZIRCON / "GodotClient" / "UI" / "ui_tree.json"
OVERLAY_PATH = ZIRCON / "GodotClient" / "UI" / "ui_overlay.json"
SHOTS_DIR = UIEDITOR / "shots"
ZL_DATA = ZIRCON / "Debug" / "Client" / "Data"
STATIC = UIEDITOR / "static"
FRAME_CACHE = UIEDITOR / "frame-cache"
FRAME_CACHE.mkdir(exist_ok=True)

APP = FastAPI(title="uieditor", docs_url=None, redoc_url=None)

APP.mount("/static", StaticFiles(directory=str(STATIC)), name="static")
# 共享移动端壳（Tools/common/webui/），见 TOOLS_MOBILE_ENHANCE_GOAL §3.1
APP.mount("/_webui", StaticFiles(directory=str(REPO / "Tools" / "common" / "webui")), name="webui")

# ---------------------------------------------------------------- zl 实时解码
_zl_lock = threading.Lock()
_zl_libs: dict[str, Any] = {}


def _get_zl_lib(lib_file: str):
    if str(REPO / "Tools" / "common") not in sys.path:
        sys.path.insert(0, str(REPO / "Tools" / "common"))
    with _zl_lock:
        if lib_file not in _zl_libs:
            import zlsdk
            path = ZL_DATA / lib_file
            _zl_libs[lib_file] = zlsdk.ZlLibrary(str(path))
        return _zl_libs[lib_file]


# ---------------------------------------------------------------- 数据加载
_ui_tree_lock = threading.Lock()
_ui_tree: dict[str, Any] | None = None
_ui_tree_mtime: float = 0.0


def _load_ui_tree(force: bool = False) -> dict[str, Any]:
    """ui_tree.json 带缓存读取；文件更新（重新 --ui-export）自动重载。"""
    global _ui_tree, _ui_tree_mtime
    with _ui_tree_lock:
        mtime = UI_TREE_PATH.stat().st_mtime if UI_TREE_PATH.exists() else 0.0
        if _ui_tree is not None and not force and mtime == _ui_tree_mtime:
            return _ui_tree
        if not UI_TREE_PATH.exists():
            raise HTTPException(500, f"ui_tree.json 不存在，请先运行: "
                                     f"godot-mono --path GodotClient res://Scenes/UITestScene.tscn -- --ui-export")
        _ui_tree = json.loads(UI_TREE_PATH.read_text(encoding="utf-8"))
        _ui_tree_mtime = mtime
        return _ui_tree


# ---------------------------------------------------------------- overlay
def _read_overlay() -> dict[str, Any]:
    if not OVERLAY_PATH.exists():
        return {}
    try:
        return json.loads(OVERLAY_PATH.read_text(encoding="utf-8"))
    except Exception as exc:
        raise HTTPException(500, f"ui_overlay.json 解析失败: {exc}") from exc


def _atomic_write_backup(path: Path, content: str) -> None:
    """原子写 + 备份上一版：tmp 写入 → fsync → rename；旧内容存 .bak。"""
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        bak = path.with_suffix(path.suffix + ".bak")
        bak.write_bytes(path.read_bytes())
    tmp = path.with_suffix(path.suffix + ".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(content)
        f.flush()
        os.fsync(f.fileno())
    os.replace(tmp, path)


class OverlayPayload(BaseModel):
    overlay: dict[str, dict[str, dict[str, Any]]]


# ---------------------------------------------------------------- API
@APP.get("/api/tree")
def api_tree() -> dict:
    tree = _load_ui_tree()
    windows = [
        {
            "className": w["className"],
            "title": w.get("title", ""),
            "size": w["size"],
            "controlCount": w["controlCount"],
            "maxDepth": w["maxDepth"],
        }
        for w in tree["windows"]
    ]
    return {
        "logicalCanvas": tree.get("logicalCanvas", [1024, 768]),
        "windowCount": len(windows),
        "windows": windows,
        "libManifest": tree.get("libManifest", {}),
    }


@APP.get("/api/window/{class_name}")
def api_window(class_name: str) -> dict:
    tree = _load_ui_tree()
    for w in tree["windows"]:
        if w["className"] == class_name:
            return w
    raise HTTPException(404, "window not found")


@APP.get("/api/overlay")
def api_overlay() -> dict:
    return _read_overlay()


@APP.post("/api/overlay")
def api_save_overlay(payload: OverlayPayload) -> dict:
    """同步：把编辑器 diff 原子写入 GodotClient/UI/ui_overlay.json（含 .bak 备份）。"""
    overlay = payload.overlay
    # 清理空壳（属性全被撤销的 path / 空窗口）
    cleaned: dict[str, dict[str, dict[str, Any]]] = {}
    for win, paths in overlay.items():
        valid = {p: props for p, props in paths.items() if props}
        if valid:
            cleaned[win] = valid
    content = json.dumps(cleaned, ensure_ascii=False, indent=1) + "\n"
    _atomic_write_backup(OVERLAY_PATH, content)
    total = sum(len(v) for v in cleaned.values())
    print(f"[uieditor] 同步 overlay → {OVERLAY_PATH}（{len(cleaned)} 窗口 / {total} 条）")
    return {"ok": True, "windows": len(cleaned), "controls": total}


@APP.get("/api/shots")
def api_shots() -> dict:
    """可用截图 underlay 清单（D 阶段产出 shots/*.png）。"""
    if not SHOTS_DIR.exists():
        return {"shots": []}
    return {"shots": sorted(p.stem for p in SHOTS_DIR.glob("*.png"))}


@APP.get("/zl/{lib}/{frame:int}.png")
def zl_frame(lib: str, frame: int):
    """实时解码 ZL 库指定帧（zlsdk 已处理 BGRA→RGBA）。仅允许 Data 下的库名。"""
    if not re.fullmatch(r"[A-Za-z0-9_\-]+", lib):
        raise HTTPException(404, "bad lib")
    cache = FRAME_CACHE / f"{lib}_{frame}.png"
    if cache.exists():
        return FileResponse(cache, media_type="image/png")
    try:
        lib_obj = _get_zl_lib(lib if lib.endswith(".Zl") else lib + ".Zl")
        img = lib_obj.decode(frame)
    except Exception as exc:
        raise HTTPException(404, f"decode failed: {exc}") from exc
    if img is None:
        raise HTTPException(404, "no frame")
    img.save(cache, format="PNG")
    return FileResponse(cache, media_type="image/png")


@APP.get("/shot/{name}.png")
def shot_png(name: str):
    if not re.fullmatch(r"[A-Za-z0-9_\-]+", name):
        raise HTTPException(404, "bad name")
    p = SHOTS_DIR / f"{name}.png"
    if not p.exists():
        raise HTTPException(404, "no shot")
    return FileResponse(p, media_type="image/png")


@APP.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC / "index.html")


def main() -> None:
    import uvicorn
    tree = _load_ui_tree(force=True)
    print(f"[uieditor] ui_tree: {tree['windowCount']} 窗口 / {tree.get('controlCount', '?')} 控件")
    print(f"[uieditor] overlay: {OVERLAY_PATH}（{'已存在' if OVERLAY_PATH.exists() else '尚无，保存后创建'}）")
    print("[uieditor] http://127.0.0.1:8820/")
    uvicorn.run(APP, host="0.0.0.0", port=8820, log_level="warning")


if __name__ == "__main__":
    main()
