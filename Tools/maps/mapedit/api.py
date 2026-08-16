#!/usr/bin/env python3
"""mapedit.api — HTTP 服务（ViewerHandler 全端点 + 进度状态）。"""
from __future__ import annotations
import argparse
import io
import json
import os
import sys
import threading
import time
import traceback
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from PIL import Image

from zlsdk import ZlLibrary

from mapedit.constants import (_TOOLS_MAPS_DIR, CACHE_TILES_MAX, CACHE_VERSION,
                               DEFAULT_CACHE_MOUNT, DEFAULT_CACHE_ROOT,
                               DEFAULT_CLIENT_ROOT, DEFAULT_CONNECTIONS,
                               DEFAULT_DBWORKSPACE, DEFAULT_DB_NAMES,
                               KR_ORDER, LAYOUT_ISO, LAYOUT_RECT, OFFSET_ALL,
                               OFFSET_MIDFRONT, OFFSET_MODES, OFFSET_NONE,
                               THUMBS_DIR, _nas_cache_available,
                               default_tile_cache_dir)

# [E6 P0-2] /sprite 编辑器逻辑名 → KR_ORDER 物理库名（MapControl 语义）。
# 大小写不敏感（查询侧 lower）。 KR_ORDER 真名（tilesc 等）与带扩展名
# 请求不经此表，由 _find_library_path 直接解析。
_SPRITE_LIB_ALIASES = {
    "tile": "tilesc", "tiles": "tilesc", "tile30": "tiles30c",
    "tiles30": "tiles30c", "tiles30c": "tiles30c", "tiles5": "tiles5c",
    "smtiles": "smtilesc", "smobjects": "smobjectsc",
    "objects": "object1c", "objects1": "object1c", "objects2": "object2c",
    "houses": "housesc", "walls": "wallsc",
    "cliff": "cliffsc", "cliffs": "cliffsc",
    "dungeon": "dungeonsc", "dungeons": "dungeonsc",
    "inner": "innersc", "inners": "innersc",
    "furniture": "furnituresc", "furnitures": "furnituresc",
    "animation": "animationsc", "animations": "animationsc",
    "sabak": "sabak",
}
from mapedit.data import (MAP_CN, NPC_FUNC_RULES, api_maps_payload,
                          build_atlas, load_catalog, load_connections,
                          load_db_names, load_entities, load_workspace_connections,
                          load_workspace_entities, load_workspace_guards,
                          scan_maps, write_map_links_v2)
from mapedit.frames import FramePool
from mapedit.geom import map_ladder
from mapedit.mapio import MapCache
from mapedit.minimap import MiniMapSource
from mapedit.render import (_POOL_WORKERS, _TILE_SUBMIT_TIMEOUT,
                            _get_fast_pool, _render_tile_worker, prewarm_pools,
                            render_full_map, render_offset_strip, render_tile,
                            tile_cache_path)
from mapedit.templates import HTML_TEMPLATE, SIM_TEMPLATE

BATCH_PROGRESS = {
    "running": False,
    "total": 0,
    "current": 0,
    "current_map": "",
    "done": 0,
    "failed": 0,
    "percent": 0
}

# 瓦片预渲染进度 (合并进 /api/progress; 字段与 BATCH_PROGRESS 同构,
# 前端进度条直接复用; batch (整图重建) 优先显示)
TILE_PREWARM = {
    "running": False,
    "total": 0,
    "current": 0,
    "current_map": "",
    "done": 0,
    "failed": 0,
    "percent": 0,
    "phase": "tiles",   # tiles = 瓦片预生成 (z0 全量 -> z1 全量)
    "focus": "",        # 用户正在浏览的地图 -> 预渲染插队跟进
}

_TILE_INTERACTIVE = [0]                       # 在途交互瓦片渲染数
_INTERACTIVE_LOCK = threading.Lock()          # 预渲染让路依据




KNOWN_CANDIDATE_ROOTS = [
    "/home/tetsuya/development/Zircon/Debug/Client",
    "/home/tetsuya/NAS/TMP/EI传奇3.0客户端",
    "/home/tetsuya/NAS/TMP/mir3ei"
]

def get_client_roots() -> list[dict]:
    roots = []
    for path in KNOWN_CANDIDATE_ROOTS:
        if os.path.exists(path):
            name = os.path.basename(path.rstrip("/"))
            m_dir = os.path.join(path, "Map") if os.path.exists(os.path.join(path, "Map")) else path
            d_dir = os.path.join(path, "Data") if os.path.exists(os.path.join(path, "Data")) else path
            roots.append({
                "name": name,
                "path": path,
                "map_dir": m_dir,
                "data_dir": d_dir
            })
    return roots


class ViewerHTTPServer(ThreadingHTTPServer):
    """静默客户端断连噪音; 死连接不过度堆积。"""
    daemon_threads = True
    request_queue_size = 128

    def handle_error(self, request, client_address):
        exc = sys.exc_info()[1]
        if isinstance(exc, (ConnectionError, TimeoutError)):
            return   # 浏览器中止轮询/关标签页: 正常噪音, 不刷栈
        super().handle_error(request, client_address)

class ViewerHandler(BaseHTTPRequestHandler):
    map_cache: MapCache
    pool: FramePool
    tile_cache: dict[tuple, bytes] = {}
    tile_cache_lock = threading.Lock()
    protocol_version = "HTTP/1.1"
    cache_dir: str = ""   # disk cache root; empty disables persistence
    cache_dir_override: str | None = None
    thumbs_dir: str = THUMBS_DIR  # full-map thumbnail dir (shared with WikiServer)
    render_locks: dict = {}       # per-fullmap-key render locks (dedupe work)
    render_locks_mu = threading.Lock()
    current_root_path: str = ""
    layout: str = LAYOUT_RECT   # axis-aligned (original Mir3.exe projection); "iso" legacy
    catalog: dict = {}          # map_name -> catalog doc (build_map_catalog.py)
    entities: list = []         # Mud3 Envir entity data (load_entities)
    connections: list = []      # exported System.db movement records
    db_names: dict = {}         # db_names.json: npcs/maps en->zh 显示名
    atlas: dict = {}            # 地图工坊索引（build_atlas：热力/任务/总览/连通/NPC审计）
    db_workspace_path: str = ""   # [E2] dbeditor workspace（NPC 摆放写目标）
    base_entities: list = []      # [E2] 非 workspace 实体（Envir），刷新时保留

    @classmethod
    def _render_lock(cls, key: tuple):
        with cls.render_locks_mu:
            lk = cls.render_locks.get(key)
            if lk is None:
                lk = cls.render_locks[key] = threading.Lock()
            return lk


    def _json_200(self, body: bytes):
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    @classmethod
    def _thumb_mc(cls):
        """缩略图专用 MapCache：MapCache13 支持 13 字节旧格式地图回退。"""
        mc = cls._thumb_map_cache
        if mc is None:
            try:
                from thumb_gen import MapCache13
                mc = MapCache13(cls.map_cache.maps_dir, max_keep=4)
            except Exception:
                mc = cls.map_cache
            cls._thumb_map_cache = mc
        return mc

    def do_POST(self):
        from urllib.parse import parse_qs, urlparse
        if self.path.startswith("/api/switch_root"):
            qs = parse_qs(urlparse(self.path).query)
            target_path = qs.get("path", [""])[0]
            roots = get_client_roots()
            found = next((r for r in roots if r["path"] == target_path), None)
            if found:
                ViewerHandler.map_cache = MapCache(found["map_dir"])
                ViewerHandler.pool = FramePool(found["data_dir"])
                ViewerHandler.current_root_path = found["path"]
                ViewerHandler.cache_dir = (ViewerHandler.cache_dir_override
                                           if ViewerHandler.cache_dir_override is not None
                                           else default_tile_cache_dir(found["map_dir"]))
                body = json.dumps({"ok": True, "current": found}).encode("utf-8")
            else:
                body = json.dumps({"ok": False, "error": "not_found"}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/rebuild":
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            if map_name:
                safe = map_name.replace("/", "_").replace("\\", "_")
                cdir = os.path.join(self.cache_dir, safe)
                if os.path.exists(cdir):
                    import shutil
                    shutil.rmtree(cdir, ignore_errors=True)
            body = b'{"ok": true}'
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/rebuild_all":
            if BATCH_PROGRESS["running"]:
                body = json.dumps({"ok": True, "msg": "already_running"}).encode("utf-8")
            else:
                def batch_worker():
                    BATCH_PROGRESS["running"] = True
                    maps = scan_maps(self.map_cache.maps_dir)
                    BATCH_PROGRESS["total"] = len(maps)
                    BATCH_PROGRESS["current"] = 0
                    BATCH_PROGRESS["done"] = 0
                    BATCH_PROGRESS["failed"] = 0
                    BATCH_PROGRESS["percent"] = 0
                    # clear stale cache so every map re-renders from scratch
                    if self.cache_dir and os.path.isdir(self.cache_dir):
                        try:
                            for name in os.listdir(self.cache_dir):
                                p = os.path.join(self.cache_dir, name)
                                if os.path.isdir(p):
                                    import shutil
                                    shutil.rmtree(p, ignore_errors=True)
                                else:
                                    os.remove(p)
                            print(f"[*] Cache cleared: {self.cache_dir}")
                        except Exception as ex:
                            print(f"[!] Cache clear failed: {ex}")
                    print(f"[*] Starting background pre-render for {len(maps)} maps...")
                    from concurrent.futures import ThreadPoolExecutor, as_completed

                    def render_one(m):
                        mname = m["name"]
                        w, h, _ = self.map_cache.get(mname)
                        ladder = map_ladder(w, h, self.layout)
                        if ladder:
                            z = ladder[-1]
                            data = render_full_map(self.map_cache, self.pool, mname, z, True, True, True,
                                                   layout=self.layout,
                                                   offset_mode=OFFSET_NONE)
                            key = (mname, z, True, True, True, OFFSET_NONE)
                            dp = self._fullmap_path(key)
                            os.makedirs(os.path.dirname(dp), exist_ok=True)
                            with open(dp, "wb") as f:
                                f.write(data)
                        return mname, None

                    done_i = [0]
                    with ThreadPoolExecutor(max_workers=4) as ex:
                        futs = {ex.submit(render_one, m): m for m in maps}
                        for fut in as_completed(futs):
                            mname = futs[fut].get("name")
                            BATCH_PROGRESS["current"] += 1
                            BATCH_PROGRESS["current_map"] = mname
                            BATCH_PROGRESS["percent"] = int((BATCH_PROGRESS["current"] / len(maps)) * 100)
                            try:
                                fut.result()
                                BATCH_PROGRESS["done"] += 1
                            except Exception as ex:
                                BATCH_PROGRESS["failed"] += 1
                                print(f"[!] Pre-render map {mname} failed: {ex}")

                    BATCH_PROGRESS["running"] = False
                    BATCH_PROGRESS["current_map"] = "完成"
                    print("[*] Background pre-render completed!")

                threading.Thread(target=batch_worker, daemon=True).start()
                body = json.dumps({"ok": True, "msg": "started"}).encode("utf-8")

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/npc/"):
            self._handle_npc()

        elif self.path.startswith("/edit/"):
            self._handle_edit()
        else:
            self.send_error(404)

    def _handle_edit(self):
        """编辑模式端点（JSON POST，body: {map, ...}）。

        /edit/open /edit/set /edit/brush /edit/undo /edit/redo
        /edit/save /edit/discard
        """
        from mapedit import editstate as es
        try:
            length = int(self.headers.get("Content-Length") or "0")
        except ValueError:
            length = 0
        try:
            payload = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            self._json_200(json.dumps({"ok": False, "error": "bad_json"}).encode())
            return
        map_name = os.path.basename(str(payload.get("map", "")))
        if not map_name.lower().endswith(".map"):
            self._json_200(json.dumps({"ok": False, "error": "map_required"}).encode())
            return
        maps_dir = self.map_cache.maps_dir
        op = self.path.split("?")[0].split("/", 2)[2]
        try:
            if op == "open":
                s = es.get_session(maps_dir, map_name)
                body = {"ok": True, "w": s.w, "h": s.h, "dirty": s.dirty,
                        "undo": len(s.undo), "redo": len(s.redo)}
            elif op == "set":
                s = es.get_session(maps_dir, map_name)
                plan = s.apply(payload.get("edits") or [])
                body = {"ok": True, "applied": len(plan), "dirty": s.dirty,
                        "undo": len(s.undo), "redo": len(s.redo)}
            elif op == "brush":
                s = es.get_session(maps_dir, map_name)
                src = payload.get("src")
                n = s.brush(int(payload.get("x0", 0)), int(payload.get("y0", 0)),
                            int(payload.get("x1", 0)), int(payload.get("y1", 0)),
                            payload.get("fields") or {},
                            (int(src["x"]), int(src["y"])) if src else None)
                body = {"ok": bool(n), "applied": n,
                        "error": None if n else "no_match",
                        "dirty": s.dirty, "undo": len(s.undo), "redo": len(s.redo)}
            elif op == "undo":
                s = es.get_session(maps_dir, map_name)
                n = s.step_undo()
                body = {"ok": True, "reverted": n, "dirty": s.dirty,
                        "undo": len(s.undo), "redo": len(s.redo)}
            elif op == "redo":
                s = es.get_session(maps_dir, map_name)
                n = s.step_redo()
                body = {"ok": True, "reapplied": n, "dirty": s.dirty,
                        "undo": len(s.undo), "redo": len(s.redo)}
            elif op == "discard":
                es.drop_session(maps_dir, map_name)
                body = {"ok": True}
            elif op == "save":
                s = es.get_session(maps_dir, map_name)
                if s.dirty == 0:
                    body = {"ok": False, "error": "nothing_to_save"}
                else:
                    rep = es.save_session(s, confirm=bool(payload.get("confirm")))
                    self.map_cache.invalidate(map_name)
                    es.invalidate_caches(self.cache_dir, map_name)
                    with self.tile_cache_lock:
                        for k in [k for k in self.tile_cache if k[0] == map_name]:
                            self.tile_cache.pop(k, None)
                    body = {"ok": True, **rep}
            else:
                body = {"ok": False, "error": "unknown_op"}
        except es.EditError as ex:
            body = {"ok": False, "error": str(ex)}
        except FileNotFoundError:
            body = {"ok": False, "error": "map_not_found"}
        self._json_200(json.dumps(body, ensure_ascii=False).encode("utf-8"))

    # ------------------------------------------------ E2 NPC 摆放编辑

    def _npc_editor(self):
        """WorkspaceEditor 工厂：maps_dir 供越界校验。"""
        from mapedit import npcedit
        return npcedit.WorkspaceEditor(self.db_workspace_path,
                                       maps_dir=self.map_cache.maps_dir)

    def _handle_npc(self):
        """E2 NPC/Region 摆放端点（JSON POST，body 见 npcedit.WorkspaceEditor）。

        /npc/move /npc/create /npc/delete /npc/guard_move
        /npc/safezone_move /npc/region_size /npc/rollback
        写 workspace JSON（不碰 .db），成功后刷新实体索引并通知 dbeditor reload。
        """
        from mapedit import npcedit
        try:
            length = int(self.headers.get("Content-Length") or "0")
            payload = json.loads(self.rfile.read(length) or b"{}")
        except ValueError:
            self._json_200(json.dumps({"ok": False, "error": "bad_json"}).encode())
            return
        op = self.path.split("?")[0].split("/", 2)[2]
        map_stem = None
        try:
            ed = self._npc_editor()
            if op == "move":
                body = {"ok": True, "result": ed.move_npc(
                    int(payload["npc"]), int(payload["x"]), int(payload["y"]),
                    payload.get("map"), force=bool(payload.get("force")))}
                map_stem = body["result"]["to"]["map"]
            elif op == "create":
                body = {"ok": True, "result": ed.create_npc(
                    str(payload["map"]), int(payload["x"]), int(payload["y"]),
                    str(payload.get("name") or ""), image=int(payload.get("image") or 0),
                    entry_page=(int(payload["entry_page"])
                                if payload.get("entry_page") is not None else None),
                    force=bool(payload.get("force")))}
                map_stem = payload["map"]
            elif op == "delete":
                body = {"ok": True, "result": ed.delete_npc(int(payload["npc"]))}
            elif op == "guard_move":
                body = {"ok": True, "result": ed.move_guard(
                    int(payload["guard"]), int(payload["x"]), int(payload["y"]),
                    payload.get("map"), force=bool(payload.get("force")))}
                map_stem = body["result"]["to"]["map"]
            elif op == "safezone_move":
                body = {"ok": True, "result": ed.move_safezone(
                    int(payload["safezone"]), int(payload["x"]), int(payload["y"]),
                    force=bool(payload.get("force")))}
            elif op == "region_size":
                body = {"ok": True, "result": ed.set_region_size(
                    int(payload["region"]), int(payload["size"]))}
            elif op == "rollback":
                body = {"ok": True, "result": npcedit.workspace_rollback(
                    self.db_workspace_path, payload.get("table"))}
            else:
                body = {"ok": False, "error": "unknown_op"}
            if body.get("ok"):
                ed.commit(f"NPC摆放 {op}")
                self.refresh_workspace_entities()
                body["diff"] = npcedit.workspace_diff(
                    self.db_workspace_path)["summary"]
        except npcedit.NpcEditError as ex:
            body = {"ok": False, "error": str(ex)}
        except (KeyError, TypeError, ValueError) as ex:
            body = {"ok": False, "error": f"参数错误: {ex}"}
        self._json_200(json.dumps(body, ensure_ascii=False).encode("utf-8"))

    @classmethod
    def refresh_workspace_entities(cls):
        """重载 workspace NPCs/guards 实体（编辑后 /api/entities 立即可见新坐标）。"""
        ws_ents = load_workspace_entities(cls.db_workspace_path, cls.db_names)
        ws_guards = load_workspace_guards(cls.db_workspace_path, cls.db_names)
        cls.entities = ws_guards + ws_ents + cls.base_entities


    def do_GET(self):
        if self.path.split("?")[0] in ("/", "/index.html"):
            from mapedit.templates import EDIT_UI_JS
            lib_json = json.dumps({**KR_ORDER, 255: "无"}, ensure_ascii=False)
            body = (HTML_TEMPLATE
                    .replace("/*__MAP_CN__*/",
                             json.dumps(MAP_CN, ensure_ascii=False))
                    .replace("/*__EDIT_UI__*/", EDIT_UI_JS)
                    .replace("__LIB_JSON__", lib_json)).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.split("?")[0].startswith("/_webui/"):
            # 共享移动端壳（Tools/common/webui/），见 TOOLS_MOBILE_ENHANCE_GOAL §3.1
            from pathlib import Path as _P
            name = self.path.split("?")[0][len("/_webui/"):]
            if not name or "/" in name or ".." in name:
                self.send_error(403)
                return
            # [E6 P1-1] 共享移动端壳在 Tools/common/webui/（api.py 位于
            # Tools/maps/mapedit/，需回溯三层；旧代码两层算到
            # Tools/maps/common/webui 导致移动端壳 CSS/JS 全 404）
            f = _P(__file__).resolve().parent.parent.parent / "common" / "webui" / name
            if not f.is_file():
                self.send_error(404)
                return
            ctype = {".css": "text/css; charset=utf-8",
                     ".js": "application/javascript; charset=utf-8"}.get(f.suffix, "application/octet-stream")
            body = f.read_bytes()
            self.send_response(200)
            self.send_header("Content-Type", ctype)
            self.send_header("Cache-Control", "no-cache")
            self.send_header("Content-Length", str(len(body)))

            self.end_headers()
            self.wfile.write(body)

        elif self.path.split("?")[0] in ("/sim", "/sim.html"):
            body = SIM_TEMPLATE.encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/maps":
            body = api_maps_payload(self.map_cache.maps_dir, self.layout)
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        elif self.path == "/api/progress":
            merged = dict(BATCH_PROGRESS)
            if TILE_PREWARM["running"]:
                merged["tiles"] = {k: TILE_PREWARM[k] for k in
                                   ("total", "current", "done", "failed", "percent")}
                if not merged["running"]:   # batch 优先展示
                    merged.update({k: TILE_PREWARM[k] for k in
                                   ("running", "total", "current", "current_map",
                                    "done", "failed", "percent")})
                    merged["current_map"] = "瓦片 " + str(merged["current_map"])
            body = json.dumps(merged).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path == "/api/roots":
            roots = get_client_roots()
            cur = self.current_root_path or (roots[0]["path"] if roots else "")
            body = json.dumps({"roots": roots, "current": cur}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/api/catalog?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            doc = self.catalog.get(map_name)
            if doc is None:
                body = json.dumps({"ok": False, "error": "not_in_catalog"}).encode("utf-8")
            else:
                body = json.dumps({"ok": True, "catalog": doc}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/api/connections?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.splitext(os.path.basename(qs.get("map", [""])[0]))[0]
            links = self.conn_index.get(map_name, [])
            body = json.dumps({"ok": True, "map": map_name, "links": links}, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/api/entities?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            map_stem = os.path.splitext(map_name)[0]
            # 兼容 "0.map"（Envir 实体）与 "0"（workspace 实体）两种命名
            ents = [e for e in self.entities
                    if e.get("map") == map_name or e.get("map") == map_stem]
            # 合并 System.db 位置实体（dbviewer 服务 8800 运行时启用）：
            # 刷怪点 / NPC / 守卫 / 传送点 / 安全区，格式与 Envir 实体一致。
            try:
                import urllib.request
                db_url = "http://127.0.0.1:8800/api/map-entities?map=" + urllib.parse.quote(map_name)
                with urllib.request.urlopen(db_url, timeout=3) as r:
                    db = json.loads(r.read().decode("utf-8"))
                for e in db.get("entities", []):
                    if not any(x.get("x") == e.get("x") and x.get("y") == e.get("y")
                               and x.get("kind") == e.get("kind") and x.get("name") == e.get("name")
                               for x in ents):
                        ents.append(e)
            except Exception:
                pass
            body = json.dumps({"ok": True, "count": len(ents), "entities": ents},
                              ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        # ------------------------------------------------ 地图工坊端点
        # 全部优雅降级：atlas 缺失（workspace 表不全）时返回 ok=False + 200，
        # 前端禁用对应图层并提示，不崩。
        elif self.path.startswith("/api/respawns?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            stem = os.path.splitext(os.path.basename(qs.get("map", [""])[0]))[0]
            respawns = (self.atlas or {}).get("respawns_by_map", {}).get(stem, [])
            body = json.dumps({"ok": True, "map": stem, "count": len(respawns),
                               "respawns": respawns}, ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/quests"):
            quests = (self.atlas or {}).get("quests") or []
            body = json.dumps({"ok": bool(quests), "count": len(quests),
                               "quests": [{"id": q["id"], "name": q["name"],
                                           "type": q["type"],
                                           "kinds": sorted({t["type"] for t in q["tasks"]})}
                                          for q in quests]},
                              ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/quest?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            atlas = self.atlas or {}
            try:
                qid = int(qs.get("id", ["0"])[0])
            except ValueError:
                qid = 0
            quest = next((q for q in atlas.get("quests", []) if q["id"] == qid), None)
            if quest is None:
                body = json.dumps({"ok": False, "error": "quest_not_found"},
                                  ensure_ascii=False).encode("utf-8")
            else:
                # 解析任务 -> 覆盖层：VisitRegion 金框 / KillMonster·GainItem
                # 怪物刷新点（跨地图）。点位取 respawns_by_monster 反查。
                rbm = atlas.get("respawns_by_monster", {})
                regions, monsters = [], []
                seen_m = set()
                for t in quest["tasks"]:
                    if t["type"] == "VisitRegion" and t.get("region"):
                        regions.append(t["region"])
                    for men in t["monsters"]:
                        if men in seen_m:
                            continue
                        seen_m.add(men)
                        monsters.append({
                            "m": men, "kind": t["type"],
                            "item": t.get("item_cn") or t.get("item"),
                            "amount": t["amount"],
                            "points": rbm.get(men, []),
                        })
                body = json.dumps({"ok": True, "quest": quest,
                                   "regions": regions, "monsters": monsters},
                                  ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/overview"):
            overview = (self.atlas or {}).get("overview") or []
            body = json.dumps({"ok": bool(overview), "count": len(overview),
                               "maps": overview}, ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.split("?")[0] == "/api/map_links_v2.json":
            path = os.path.join(_TOOLS_MAPS_DIR, "map_links_v2.json")
            try:
                with open(path, "rb") as f:
                    body = f.read()
            except OSError:
                body = json.dumps((self.atlas or {}).get("links_v2") or
                                  {"ok": False, "error": "links_v2_not_generated"},
                                  ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/graph"):
            graph = (self.atlas or {}).get("graph") or {}
            body = json.dumps({"ok": bool(graph), **graph},
                              ensure_ascii=False).encode("utf-8")
            self._json_200(body)

        elif self.path.startswith("/api/npc_audit"):
            rows = (self.atlas or {}).get("npc_audit") or []
            body = json.dumps({"ok": bool(rows), "count": len(rows), "rows": rows,
                               "funcs": [f for f, _, _ in NPC_FUNC_RULES]},
                              ensure_ascii=False).encode("utf-8")
            self._json_200(body)


        elif self.path.startswith("/edit/flags?"):
            # 编辑模式 flag 着色图：w*h 字节 base64（反映未保存编辑）
            from urllib.parse import parse_qs, urlparse
            from mapedit import editstate as _es
            import base64
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            s = _es.get_session(self.map_cache.maps_dir, map_name, create=False)
            if s is None:
                body = json.dumps({"ok": False, "error": "no_session"}).encode()
            else:
                flags = bytearray(s.w * s.h)
                i = 0
                for x in range(s.w):
                    col = s.cells[x]
                    for y in range(s.h):
                        flags[x * s.h + y] = col[y].flag
                body = json.dumps({"ok": True, "w": s.w, "h": s.h,
                                   "flags": base64.b64encode(bytes(flags)).decode()
                                   }).encode()
            self._json_200(body)

        elif self.path.startswith("/api/cell?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            try:
                x = int(qs.get("x", ["0"])[0])
                y = int(qs.get("y", ["0"])[0])
            except ValueError:
                self.send_error(400, "x/y must be ints")
                return
            # 编辑会话优先（含未保存编辑的格语义）
            from mapedit import editstate as _es
            sess = _es.get_session(self.map_cache.maps_dir, map_name, create=False)
            try:
                if sess is not None:
                    w, h, cells = sess.w, sess.h, sess.cells
                else:
                    w, h, cells = self.map_cache.get(map_name)
            except Exception as ex:
                self.send_error(404, f"map not readable: {ex}")
                return
            if not (0 <= x < w and 0 <= y < h):
                body = json.dumps({"ok": False, "error": "out_of_bounds",
                                   "w": w, "h": h}).encode("utf-8")
            else:
                c = cells[x][y]
                def lib_name(lid):
                    return KR_ORDER.get(lid, f"lib{lid}") if lid >= 0 else "none"
                body = json.dumps({
                    "ok": True, "x": x, "y": y, "w": w, "h": h,
                    "flag": c.flag, "anim": [c.anim_a, c.anim_b],
                    "back": {"file": c.back_file, "lib": lib_name(c.back_file),
                             "frame": c.back_img},
                    "mid": {"file": c.mid_file, "lib": lib_name(c.mid_file),
                            "frame": c.mid_img},
                    "front": {"file": c.front_file, "lib": lib_name(c.front_file),
                              "frame": c.front_img},
                }, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/strip?"):
            # Export the 3-mode offset comparison strip as PNG (sim "导出对比图").
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            if not map_name.lower().endswith(".map"):
                self.send_error(400, "map must be a .map file")
                return
            try:
                z = int(qs.get("z", ["2"])[0])
            except ValueError:
                z = 2
            g = qs.get("g", ["1"])[0] == "1"
            m = qs.get("m", ["1"])[0] == "1"
            f = qs.get("f", ["1"])[0] == "1"
            try:
                data = render_offset_strip(self.map_cache, self.pool, map_name, z,
                                           g, m, f, layout=self.layout)
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception as ex:
                self.send_error(500, str(ex))

        elif self.path.startswith("/sprite?"):
            # Decode a single frame from a named WIL library (character / NPC /
            # monster sprites for the simulator) as a transparent PNG.
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            lib_name = os.path.basename(qs.get("lib", [""])[0])
            low = lib_name.lower()
            try:
                frame = int(qs.get("frame", ["0"])[0])
                scale = int(qs.get("scale", ["1"])[0])
            except ValueError:
                self.send_error(400, "frame/scale must be ints")
                return
            # 库解析 [E6 P0-2]：与渲染层同一条路径表——_find_library_path
            # 覆盖 data_dir 根 + "Map Data" + wood/sand/snow/forest 子目录
            # （Tile 类库全在子目录里，旧实现只查根目录导致编辑面板三图层
            # 预览全裂）。另支持编辑器逻辑名（Tile/SmTiles/Objects…）→
            # KR_ORDER 物理名的别名表，杜绝 /sprite 与 render.py 两份映射。
            from mapedit.frames import _find_library_path
            lib_path = None
            is_zl = False
            if low.endswith(".wil") or low.endswith(".zl"):
                p = os.path.join(self.pool.data_dir, lib_name)
                if not os.path.exists(p):
                    p = _find_library_path(self.pool.data_dir, lib_name.rsplit(".", 1)[0])
                if p is None:
                    self.send_error(404, "lib not found in data dir")
                    return
                lib_path, is_zl = p, p.lower().endswith(".zl")
            else:
                probe = _SPRITE_LIB_ALIASES.get(low) or lib_name
                p = _find_library_path(self.pool.data_dir, probe)
                if p is None:
                    self.send_error(404, f"lib {lib_name} not found "
                                         f"(data_dir + Map Data, alias={probe})")
                    return
                lib_path, is_zl = p, p.lower().endswith(".zl")
            try:
                if is_zl:
                    lib = ZlLibrary(lib_path)
                    count = lib.count
                    def _decode(fr, _l=lib): return _l.decode(fr)
                else:
                    from wilsdk import open_library as _open_wil
                    lib = _open_wil(lib_path)
                    count = lib.count
                    def _decode(fr, _l=lib): return _l.decode(fr)
                img = _decode(frame) if frame < count else None
                if img is None:
                    self.send_error(404, f"frame {frame} blank or out of range")
                    return
                if scale > 1:
                    img = img.resize((max(1, img.width // scale), max(1, img.height // scale)),
                                     Image.NEAREST)
                buf = io.BytesIO()
                img.save(buf, format="PNG")
                data = buf.getvalue()
                self.send_response(200)
                self.send_header("Content-Type", "image/png")
                self.send_header("Cache-Control", "public, max-age=86400")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception as ex:
                self.send_error(500, str(ex))

        elif self.path.startswith("/thumb?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            thumb_path = os.path.join(self.thumbs_dir, map_name + ".png")
            if not os.path.exists(thumb_path):
                # On-demand render + disk cache (one-time, ~seconds to tens of
                # seconds for large maps; shared with WikiServer/thumb_gen).
                # 13B 旧格式地图经 MapCache13 回退解析；与后台预渲染共享 per-map
                # 锁，避免并发写坏 PNG。
                with self._render_lock(("thumb", map_name)):
                    if not os.path.exists(thumb_path):
                        try:
                            from thumb_gen import render_one
                            mc = self._thumb_mc()
                            w, h, _ = mc.get(map_name)
                            render_one(mc, self.pool, self.thumbs_dir, map_name, w, h)
                        except Exception as ex:
                            self.send_error(500, f"thumb render failed: {ex}")
                            return
            try:
                with open(thumb_path, "rb") as f:
                    body = f.read()
            except FileNotFoundError:
                self.send_error(404, "thumb not generated")
                return
            self.send_response(200)
            self.send_header("Content-Type", "image/png")
            self.send_header("Cache-Control", "public, max-age=3600")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        elif self.path.startswith("/minimap?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            stem = map_name[:-4] if map_name.lower().endswith(".map") else map_name
            img = None
            try:
                img = MiniMapSource._for(self.pool.data_dir).frame(stem)
            except Exception:
                img = None
            if img is None:
                self.send_error(404, "no minimap for %s" % map_name)
                return
            buf = io.BytesIO()
            if img.mode != "RGB":
                img = img.convert("RGB")
            img.save(buf, format="JPEG", quality=85)
            data = buf.getvalue()
            self.send_response(200)
            self.send_header("Content-Type", "image/jpeg")
            self.send_header("Cache-Control", "public, max-age=86400")
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        elif self.path.startswith("/fullmap?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = os.path.basename(qs.get("map", [""])[0])
            if not map_name.lower().endswith(".map"):
                self.send_error(400, "map must be a .map file")
                return
            z = int(qs.get("z", ["0"])[0])
            g = qs.get("g", ["1"])[0] == "1"
            m = qs.get("m", ["1"])[0] == "1"
            f = qs.get("f", ["1"])[0] == "1"
            om = qs.get("om", [OFFSET_NONE])[0]
            if om not in OFFSET_MODES:
                om = OFFSET_NONE
            try:
                from mapedit import editstate as _es
                _sess = _es.get_session(self.map_cache.maps_dir, map_name,
                                        create=False)
                _live = _sess is not None and _sess.dirty > 0
                w, h, _ = self.map_cache.get(map_name)
                ladder = map_ladder(w, h, self.layout)
                if ladder:
                    z = min(max(z, ladder[0]), ladder[-1])
                if _live:
                    # 编辑态：会话 cells 现场渲染，绕过一切缓存（读写都不）
                    data = render_full_map(_es.SessionMapCache(_sess),
                                           self.pool, map_name, z, g, m, f,
                                           layout=self.layout, offset_mode=om)
                    self.send_response(200)
                    self.send_header("Content-Type", "image/jpeg")
                    self.send_header("Cache-Control", "no-store")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
                key = (map_name, z, g, m, f, om)
                dp = self._fullmap_path(key)
                try:
                    with open(dp, "rb") as f:
                        data = f.read()
                except FileNotFoundError:
                    data = None
                if data is None:
                    with self._render_lock(key):
                        try:
                            with open(dp, "rb") as f:
                                data = f.read()
                        except FileNotFoundError:
                            data = None
                        if data is None:
                            # One full-map render per (map, zoom, layers);
                            # disk-cached, so the browser's next open is a
                            # static file read instead of a re-render.
                            data = render_full_map(self.map_cache, self.pool,
                                                   map_name, z, g, m, f,
                                                   layout=self.layout,
                                                   offset_mode=om)
                            os.makedirs(os.path.dirname(dp), exist_ok=True)
                            tmp = dp + ".tmp"
                            with open(tmp, "wb") as f:
                                f.write(data)
                            os.replace(tmp, dp)
                self.send_response(200)
                self.send_header("Content-Type", "image/jpeg")
                self.send_header("Cache-Control", "public, max-age=86400")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception as ex:
                self.send_error(500, str(ex))

        elif self.path.startswith("/tile?"):
            from urllib.parse import parse_qs, urlparse
            qs = parse_qs(urlparse(self.path).query)
            map_name = qs.get("map", [""])[0]
            tx = int(qs.get("tx", ["0"])[0])
            ty = int(qs.get("ty", ["0"])[0])
            z = int(qs.get("z", ["0"])[0])
            g = qs.get("g", ["1"])[0] == "1"
            m = qs.get("m", ["1"])[0] == "1"
            f = qs.get("f", ["1"])[0] == "1"
            om = qs.get("om", [OFFSET_NONE])[0]
            if om not in OFFSET_MODES:
                om = OFFSET_NONE

            try:
                from mapedit import editstate as _es
                _sess = _es.get_session(self.map_cache.maps_dir, map_name,
                                        create=False)
                if _sess is not None and _sess.dirty > 0:
                    # 编辑态：会话 cells 现场渲染（快池 worker 读盘会丢编辑，
                    # 故主进程直接渲），且不读写任何缓存
                    data = render_tile(_es.SessionMapCache(_sess), self.pool,
                                       map_name, tx, ty, z, g, m, f,
                                       layout=self.layout, offset_mode=om)
                    self.send_response(200)
                    self.send_header("Content-Type",
                                     "image/png" if z == 0 else "image/jpeg")
                    self.send_header("Cache-Control", "no-store")
                    self.send_header("Content-Length", str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                    return
                key = (map_name, tx, ty, z, g, m, f, om)
                TILE_PREWARM["focus"] = map_name   # 预渲染优先跟进用户正在看的地图
                with self.tile_cache_lock:
                    data = self.tile_cache.get(key)
                if data is None and self.cache_dir:
                    # L2: disk cache survives restarts; the expensive render
                    # (4.6k Python RLE decodes + 122k composites for a 350x350
                    # map) is paid once per tile EVER, not once per session.
                    dp = self._tile_path(key)
                    try:
                        with open(dp, "rb") as f:
                            data = f.read()
                    except FileNotFoundError:
                        data = None
                if data is None:
                    # 交互冷块: 默认图层组合整块下放快池渲染 (绕开主进程
                    # GIL 串行; 与预渲染共用 worker 代码, 输出一致已验证)
                    with _INTERACTIVE_LOCK:
                        _TILE_INTERACTIVE[0] += 1
                    try:
                        timed_out = False
                        if g and m and f:
                            fp = _get_fast_pool(self.pool.data_dir)
                            try:
                                res = fp.submit(_render_tile_worker, (
                                    os.path.join(self.map_cache.maps_dir, map_name),
                                    (map_name, tx, ty, z, self.layout, om))
                                    ).result(timeout=_TILE_SUBMIT_TIMEOUT)
                            except TimeoutError:
                                # [E6 P0-1] 瓦片渲染超预算：503 让前端占位，
                                # 绝不无限等待拖死请求线程
                                timed_out = True
                                res = None
                            if res:
                                data = res[1]
                        if timed_out:
                            # finally 统一递减 _TILE_INTERACTIVE，此处只回包
                            self.send_response(503)
                            self.send_header("Retry-After", "5")
                            self.send_header("Cache-Control", "no-store")
                            body = b'{"ok": false, "error": "tile_timeout"}'
                            self.send_header("Content-Length", str(len(body)))
                            self.end_headers()
                            self.wfile.write(body)
                            return
                        if data is None:
                            data = render_tile(self.map_cache, self.pool, map_name,
                                               tx, ty, z, g, m, f,
                                               layout=self.layout, offset_mode=om)
                    finally:
                        with _INTERACTIVE_LOCK:
                            _TILE_INTERACTIVE[0] -= 1
                    with self.tile_cache_lock:
                        self.tile_cache[key] = data
                        while len(self.tile_cache) > CACHE_TILES_MAX:
                            self.tile_cache.pop(next(iter(self.tile_cache)))
                    if self.cache_dir:
                        dp = self._tile_path(key)
                        os.makedirs(os.path.dirname(dp), exist_ok=True)
                        tmp = dp + ".tmp"
                        with open(tmp, "wb") as f:
                            f.write(data)
                        os.replace(tmp, dp)
                self.send_response(200)
                self.send_header("Content-Type", "image/png" if z == 0 else "image/jpeg")
                self.send_header("Cache-Control", "public, max-age=86400")
                self.send_header("Content-Length", str(len(data)))
                self.end_headers()
                self.wfile.write(data)
            except Exception as ex:
                self.send_error(500, str(ex))
        elif self.path.split("?")[0].startswith("/npc/"):
            from urllib.parse import parse_qs, urlparse
            from mapedit import npcedit
            qs = parse_qs(urlparse(self.path).query)
            op = self.path.split("?")[0][len("/npc/"):]
            try:
                ed = self._npc_editor()
                if op == "pages":
                    body = json.dumps({"ok": True, "pages": ed.npc_pages(
                        qs.get("q", [""])[0])}, ensure_ascii=False)
                elif op == "list":
                    # [E6 P1-2] 编辑 UI 的 NPC 列表数据源（审计实证浏览器
                    # 请求过 /npc/list 404）。map 省略 = 全库概览。
                    map_stem = os.path.splitext(
                        os.path.basename(qs.get("map", [""])[0]))[0]
                    npcs = ed.npc_overview(map_stem or None)
                    body = json.dumps({"ok": True, "map": map_stem or None,
                                       "count": len(npcs), "npcs": npcs},
                                      ensure_ascii=False)
                elif op == "diff":
                    body = json.dumps(npcedit.workspace_diff(
                        self.db_workspace_path), ensure_ascii=False)
                elif op == "region":
                    body = json.dumps({"ok": True, **ed.region_detail(
                        int(qs.get("index", ["0"])[0]))}, ensure_ascii=False)
                elif op == "overview":
                    map_stem = os.path.splitext(
                        os.path.basename(qs.get("map", [""])[0]))[0]
                    body = json.dumps({"ok": True, "npcs": ed.npc_overview(
                        map_stem or None)}, ensure_ascii=False)
                else:
                    self.send_error(404)
                    return
                self._json_200(body.encode("utf-8"))
            except (npcedit.NpcEditError, ValueError) as ex:
                self._json_200(json.dumps(
                    {"ok": False, "error": str(ex)}, ensure_ascii=False).encode())
        else:
            self.send_error(404)

    def _tile_path(self, key: tuple) -> str:
        map_name, tx, ty, z, g, m, f, om = key
        return tile_cache_path(self.cache_dir, self.layout, map_name,
                               tx, ty, z, g, m, f, om)

    def _fullmap_path(self, key: tuple) -> str:
        map_name, z, g, m, f, om = key
        safe = map_name.replace("/", "_").replace("\\", "_")
        tag = "r" if self.layout == LAYOUT_RECT else "i"
        omt = "n" if om == OFFSET_NONE else ("a" if om == OFFSET_ALL else "m")
        return os.path.join(self.cache_dir, safe, f"full_{tag}_{z}_{int(g)}{int(m)}{int(f)}{omt}.jpg")




def main():

    parser = argparse.ArgumentParser(description="Mir3 EI / Zircon Map Viewer")
    parser.add_argument("maps_dir", nargs="?", help="Folder containing .map files (default: current Zircon client)")
    parser.add_argument("--client-root", default=DEFAULT_CLIENT_ROOT,
                        help="Client root containing Map/ and Data/ (default: Zircon Debug/Client)")
    parser.add_argument("--data", help="Folder containing WIL / ZL libraries", default=None)
    parser.add_argument("--port", type=int, default=8766, help="HTTP Server Port")
    parser.add_argument("--cache-dir", default=None,
                        help=f"Disk tile cache dir (default: {DEFAULT_CACHE_ROOT}/tiles/{CACHE_VERSION}/<source>; empty disables)")
    parser.add_argument("--catalog", default=None,
                        help="map-catalog.json dir from build_map_catalog.py (enables /api/catalog)")
    parser.add_argument("--envir", default=None,
                        help="Mud3 server Envir dir (enables /api/entities: spawn/NPC/monster positions)")
    parser.add_argument("--db-workspace", default=DEFAULT_DBWORKSPACE,
                        help="dbeditor workspace dir (NPCInfo/MapRegion/MovementInfo JSON; default: %(default)s)")
    parser.add_argument("--db-names", default=DEFAULT_DB_NAMES,
                        help="db_names.json (NPC/地图中文名映射; default: %(default)s)")
    parser.add_argument("--thumbs-dir", default=THUMBS_DIR,
                        help="Full-map thumbnail dir (shared with WikiServer/thumb_gen)")
    parser.add_argument("--layout", choices=[LAYOUT_RECT, LAYOUT_ISO], default=LAYOUT_RECT,
                        help="Map projection: rect (axis-aligned, original Mir3.exe) or iso (legacy diamond)")
    parser.add_argument("--connections", default=DEFAULT_CONNECTIONS,
                        help="JSON exported by export_map_connections.py")
    parser.add_argument("--no-prewarm-tiles", action="store_true",
                        help="Disable background tile prewarm (z1+z0 for all maps)")
    parser.add_argument("--no-prewarm-thumbs", action="store_true",
                        help="Disable background thumbnail prewarm (regression/test runs)")
    args = parser.parse_args()

    if not args.maps_dir:
        args.maps_dir = os.path.join(args.client_root, "Map")
    if not os.path.isdir(args.maps_dir):
        parser.error(f"maps directory not found: {args.maps_dir}")
    if ((args.cache_dir is None or args.thumbs_dir == THUMBS_DIR)
            and not _nas_cache_available()):
        parser.error(f"NAS cache mount is not available: {DEFAULT_CACHE_MOUNT}")

    data_dir = args.data
    if not data_dir:
        candidates = [
            os.path.join(args.maps_dir, "..", "Data"),
            os.path.join(args.maps_dir, "..", "Data", "Map Data"),
            os.path.join(args.maps_dir, "Data"),
            os.path.join(args.maps_dir, "Data", "Map Data"),
            "/home/tetsuya/development/Zircon/Debug/Client/Data",
            "/home/tetsuya/development/Zircon/Debug/Client/Data/Map Data",
            args.maps_dir
        ]
        for c in candidates:
            if os.path.exists(c):
                data_dir = c
                break

    print(f"[*] Maps directory: {args.maps_dir}")
    ViewerHandler.map_cache = MapCache(args.maps_dir)
    ViewerHandler.pool = FramePool(data_dir)
    cache_dir = (args.cache_dir if args.cache_dir is not None
                 else default_tile_cache_dir(args.maps_dir))
    ViewerHandler.cache_dir_override = args.cache_dir
    ViewerHandler.cache_dir = cache_dir
    ViewerHandler.thumbs_dir = args.thumbs_dir
    ViewerHandler.layout = args.layout
    ViewerHandler.catalog = load_catalog(args.catalog)
    ViewerHandler.connections = load_connections(args.connections)
    ViewerHandler.db_names = load_db_names(args.db_names)
    # dbeditor workspace 直读：NPCInfo + MapRegion 质心坐标（NpcMover 修正后
    # 的 EI 坐标）+ MovementInfo 连接。workspace 数据比 8月11 的 Markdown 导出
    # 新（294 NPC / 1039 movement / 坐标 0 缺失），作为第一数据源。
    ws_ents = load_workspace_entities(args.db_workspace, ViewerHandler.db_names)
    if ws_ents:
        ViewerHandler.entities = ws_ents + ViewerHandler.entities
        print(f"[*] Workspace NPCs: {len(ws_ents)} loaded from {args.db_workspace}")
    ws_guards = load_workspace_guards(args.db_workspace, ViewerHandler.db_names)
    if ws_guards:
        ViewerHandler.entities = ws_guards + ViewerHandler.entities
        print(f"[*] Workspace guards: {len(ws_guards)} loaded from GuardInfo")
    ws_links = load_workspace_connections(args.db_workspace)
    if ws_links:
        ViewerHandler.connections = ws_links
        print(f"[*] Workspace movements: {len(ws_links)} (override Markdown export)")
    # 连接索引：map stem -> links（/api/connections O(1) 查询用）
    conn_index: dict[str, list] = {}
    for link in ViewerHandler.connections:
        for side in ("source", "destination"):
            stem = os.path.splitext(str((link.get(side) or {}).get("map", "")))[0]
            if stem:
                conn_index.setdefault(stem, []).append(link)
    ViewerHandler.conn_index = conn_index
    # 地图工坊 atlas：workspace 全表 JOIN（热力/任务/总览/连通/NPC 审计）
    try:
        t0 = time.time()
        ViewerHandler.atlas = build_atlas(args.db_workspace, ViewerHandler.db_names, args.maps_dir)
        lv2 = ViewerHandler.atlas.get("links_v2") or {}
        graph = ViewerHandler.atlas.get("graph") or {}
        islands = sum(1 for n in graph.get("nodes", []) if n.get("island"))
        cuts = sum(1 for n in graph.get("nodes", []) if n.get("cut"))
        print(f"[*] Atlas built in {time.time()-t0:.1f}s: "
              f"{len(ViewerHandler.atlas.get('overview', []))} maps / "
              f"{sum(len(v) for v in ViewerHandler.atlas.get('respawns_by_map', {}).values())} respawns / "
              f"{len(ViewerHandler.atlas.get('quests', []))} quests / "
              f"{len(lv2.get('links', []))} links (D系 {lv2.get('_meta', {}).get('d_series_links', 0)}) / "
              f"islands {islands} / cut {cuts}")
        if write_map_links_v2(ViewerHandler.atlas, os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "map_links_v2.json")):
            print("[*] map_links_v2.json written to Tools/maps/")
    except Exception as ex:
        ViewerHandler.atlas = {}
        print(f"[!] Atlas build failed (layers disabled): {ex}")
    if ViewerHandler.catalog:
        print(f"[*] Catalog: {len(ViewerHandler.catalog)} maps loaded")
    print(f"[*] Connections: {len(ViewerHandler.connections)} movements loaded ({len(conn_index)} maps indexed)")
    if args.envir:
        ViewerHandler.entities = load_entities(args.envir) + ViewerHandler.entities
        print(f"[*] Envir entities: {len(ViewerHandler.entities)} loaded")
    else:
        if not ws_ents:
            ViewerHandler.entities = []
    # [E2] 摆放编辑：workspace 路径 + 非 workspace 实体底座（刷新时保留）
    ViewerHandler.db_workspace_path = args.db_workspace
    ws_idx = len(load_workspace_guards(args.db_workspace, ViewerHandler.db_names)) \
        + len(ws_ents)
    ViewerHandler.base_entities = ViewerHandler.entities[ws_idx:]
    # [E6 P0-1] 进程池预建：此刻主进程尚无后台线程（fork 继承的锁快照是
    # 干净的），把快/慢池全部 worker fork+预热到位。此后请求/prewarm 线程
    # submit 不再触发 os.fork，import 锁死锁的入口被整体封死。
    n_warm = prewarm_pools(data_dir)
    print(f"[*] Render pools warmed: {n_warm} workers "
          f"({_POOL_WORKERS}x2 configured)")

    # [E6 P0-1/P2] 端口先于后台预热就绪：server 构造即绑定，prewarm 线程
    # 在其后启动，保证服务可达不因 NAS 慢 I/O 排队。
    print(f"[*] Tile cache: {cache_dir}")
    server = ViewerHTTPServer(("0.0.0.0", args.port), ViewerHandler)
    print(f"[*] Map Viewer running on http://127.0.0.1:{args.port}/")
    # 总览缩略图后台预渲染（守护线程，只补缺失项）
    if not args.no_prewarm_thumbs:
        from mapedit.prewarm import prewarm_thumbs
        prewarm_thumbs(args.maps_dir, data_dir, args.thumbs_dir)
    # 瓦片模式预生成（守护线程，只补缺失文件；拖拽冷区秒开的关键）
    if not args.no_prewarm_tiles:
        from mapedit.prewarm import prewarm_tiles
        prewarm_tiles(args.maps_dir, data_dir, cache_dir,
                      layout=args.layout)
    # /api/maps 首扫慢 (NAS 627 头), 启动即后台预热缓存
    threading.Thread(target=lambda: api_maps_payload(args.maps_dir, args.layout),
                     daemon=True, name="api-maps-warm").start()
    while True:
        try:
            server.serve_forever(poll_interval=0.5)
            break   # 干净关闭 (shutdown() 被调用)
        except KeyboardInterrupt:
            break
        except Exception:
            # 服务循环意外异常 (如客户端中断引发的处理链错误):
            # 记录并续命, 不让单次异常杀死整个查看器
            import traceback
            traceback.print_exc()
            try:
                with open(os.path.join(cache_dir, "server-crash.log"), "a") as fh:
                    fh.write(f"\n==== {time.strftime('%F %T')} ====\n")
                    traceback.print_exc(file=fh)
            except OSError:
                pass
            time.sleep(1)
    server.server_close()
    print("[*] Server stopped.")

