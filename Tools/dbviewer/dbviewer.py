#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dbviewer.py — Mir3 / Zircon System.db Web 数据库查看器。

读取 SystemDbProbe --json 导出的 JSON 数据目录（见 export.sh），提供：
  - 集合浏览（分类树 + 分页表格 + 排序 + 搜索）
  - 记录详情 + 关联跳转（正向引用 / 反向引用，如 怪物->掉落->物品->商店）
  - 地图联动：位置类数据（刷怪/NPC/传送/守卫/安全区）跳转 mapviewer 定位
  - 统计概览

用法:
  python3 dbviewer.py --data /tmp/dbviewer_data --port 8800

数据目录结构（由 SystemDbProbe --json 生成）:
  <Type>.json   {"count": N, "rows": [{Index, _Identity, ...}]}
  meta.json     {集合名: {zh, identity, fields: {字段: {zh, type, to}}}}

依赖: 纯 Python 标准库（http.server）。地图中文名表 /tmp/map_cn_full.json 可选。
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
TEMPLATE = os.path.join(ROOT, "template.html")
DEFAULT_DATA = "/tmp/dbviewer_data"
MAP_CN_FILE = "/tmp/map_cn_full.json"

# 每页默认行数 / 上限
DEFAULT_PER = 50
MAX_PER = 500


def load_map_cn():
    """地图文件名 -> 中文名（与 mapviewer 共用 /tmp/map_cn_full.json）。

    优先读共享表；缺失时用 MapInfo.json（FileName + Description）配合
    mapnames 规则生成并缓存，供 dbviewer 与 mapviewer 共用。
    """
    for path in (MAP_CN_FILE,):
        try:
            with open(path, encoding="utf-8") as f:
                data = json.load(f)
            if data:
                return data
        except (OSError, ValueError):
            pass
    # 生成：Tools/maps/mapnames.py 的文件名->中文映射 + 描述族规则
    try:
        maps_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "maps")
        sys.path.insert(0, maps_dir)
        from mapnames import resolve as map_cn  # type: ignore
        src = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs")
        data_dir = os.environ.get("DBVIEWER_DATA", "/tmp/dbviewer_data")
        mapinfo = os.path.join(data_dir, "MapInfo.json")
        if os.path.exists(mapinfo):
            with open(mapinfo, encoding="utf-8") as f:
                payload = json.load(f)
            out = {}
            for r in payload.get("rows", []):
                fn = r.get("FileName")
                if not fn:
                    continue
                en = r.get("Description") or ""
                cn = map_cn(fn, en)
                if cn and cn != fn:
                    out[fn] = cn
            try:
                with open(MAP_CN_FILE, "w", encoding="utf-8") as f:
                    json.dump(out, f, ensure_ascii=False)
            except OSError:
                pass
            return out
    except ImportError:
        pass
    return {}


class DataStore:
    """全量数据 + 倒排索引（启动时一次性载入内存）。"""

    def __init__(self, data_dir: str):
        self.data_dir = data_dir
        self.meta = {"collections": {}}
        self.data: dict[str, dict] = {}          # type -> {count, rows, byIndex}
        self.inverted: dict[tuple, list] = {}    # (to_type, to_index) -> [(from_type, from_index, field)]
        self.map_cn = load_map_cn()
        self._load_meta()
        self._load_all()
        self._build_inverted()

    # ---------- 加载 ----------
    def _load_meta(self):
        meta_path = os.path.join(self.data_dir, "meta.json")
        if not os.path.exists(meta_path):
            raise SystemExit(
                f"缺少 {meta_path}。\n请先导出数据：bash Tools/dbviewer/export.sh "
                f"（或 dotnet run --project Tools/SystemDbProbe -- --json {self.data_dir}）")
        with open(meta_path, encoding="utf-8") as f:
            meta = json.load(f)
        collections = {}
        for name, m in meta.items():
            collections[name] = {
                "zh": m.get("zh", name),
                "identity": m.get("identity", []),
                "fields": m.get("fields", {}),
                "count": 0,
            }
        self.meta = {"collections": collections}

    def _load_all(self):
        for fname in sorted(os.listdir(self.data_dir)):
            if not fname.endswith(".json") or fname == "meta.json":
                continue
            t = fname[:-5]
            with open(os.path.join(self.data_dir, fname), encoding="utf-8") as f:
                payload = json.load(f)
            rows = payload.get("rows", [])
            by_index = {}
            for r in rows:
                idx = r.get("Index")
                if idx is not None:
                    by_index[idx] = r
            self.data[t] = {"count": payload.get("count", len(rows)), "rows": rows, "byIndex": by_index}
            if t in self.meta["collections"]:
                self.meta["collections"][t]["count"] = len(rows)

    # ---------- 倒排索引 ----------
    def _build_inverted(self):
        for from_type, coll in self.data.items():
            fields = self.meta["collections"].get(from_type, {}).get("fields", {})
            for row in coll["rows"]:
                fi = row.get("Index")
                if fi is None:
                    continue
                for fname, fmeta in fields.items():
                    if fmeta.get("type") not in ("ref", "reflist"):
                        continue
                    to_type = fmeta.get("to")
                    if not to_type or to_type not in self.data:
                        continue
                    v = row.get(fname)
                    if v is None:
                        continue
                    if fmeta["type"] == "ref":
                        if isinstance(v, dict) and v.get("Index") is not None:
                            key = (to_type, v["Index"])
                            self.inverted.setdefault(key, []).append((from_type, fi, fname))
                    else:  # reflist
                        for item in v:
                            if isinstance(item, dict) and item.get("Index") is not None:
                                key = (to_type, item["Index"])
                                self.inverted.setdefault(key, []).append((from_type, fi, fname))
        # 排序稳定化（来源类型、索引、字段）
        for k in self.inverted:
            self.inverted[k].sort()

    # ---------- 查询 ----------
    def list_rows(self, t: str, page: int, per: int, sort: str, dirn: int, q: str):
        coll = self.data.get(t)
        if not coll:
            return {"total": 0, "rows": []}
        rows = coll["rows"]
        fields = self.meta["collections"].get(t, {}).get("fields", {})

        # 搜索：_Identity / Index / 所有 string 字段（大小写不敏感，中英文均可）
        if q:
            ql = q.lower()
            match = []
            for r in rows:
                if ql in str(r.get("Index", "")):
                    match.append(r); continue
                ident = r.get("_Identity")
                if ident and ql in str(ident).lower():
                    match.append(r); continue
                if any(
                    fmeta.get("type") == "string" and isinstance(r.get(f), str) and ql in r[f].lower()
                    for f, fmeta in fields.items()
                ):
                    match.append(r)
            rows = match

        total = len(rows)
        if sort:
            fmeta = fields.get(sort, {})
            stype = fmeta.get("type", "other")

            def keyfn(r):
                v = r.get(sort)
                if v is None:
                    return (1, "")
                if stype == "ref" and isinstance(v, dict):
                    return (0, v.get("Name") or ("#" + str(v.get("Index"))))
                if isinstance(v, (int, float)):
                    return (0, v)
                return (0, str(v))

            rows = sorted(rows, key=keyfn, reverse=(dirn < 0))

        start = (page - 1) * per
        return {"total": total, "rows": rows[start:start + per]}

    def get_row(self, t: str, index: int):
        coll = self.data.get(t)
        if not coll:
            return None
        return coll["byIndex"].get(index)

    # ---------- 关联 ----------
    def related(self, t: str, index: int):
        row = self.get_row(t, index)
        if row is None:
            return None
        result = {"type": t, "index": index, "forward": [], "backward": {}}

        # 正向：本行 ref/reflist 字段展开（直接内联 value，前端渲染链接）
        fields = self.meta["collections"].get(t, {}).get("fields", {})
        for fname, fmeta in fields.items():
            if fmeta.get("type") not in ("ref", "reflist"):
                continue
            v = row.get(fname)
            if v is None:
                continue
            result["forward"].append({"field": fname, "value": v})

        # 反向：谁引用了本行
        hits = self.inverted.get((t, index), [])
        for from_type, from_idx, field in hits:
            result["backward"].setdefault(from_type, []).append({"index": from_idx, "field": field})

        # 地图特化：该地图的刷怪/NPC/传送/守卫/安全区/矿点（经 MapRegion 中转）
        if t == "MapInfo":
            result["mapLayers"] = self._map_layers(index)

        # NPC 特化：入口页面 -> 页面内的商品/按钮/检查/动作（经 EntryPage 中转）
        if t == "NPCInfo":
            ep = row.get("EntryPage")
            if isinstance(ep, dict) and ep.get("Index") is not None:
                result["entryPage"] = ep

        return result

    def _map_layers(self, map_index: int):
        """按地图聚合位置类数据。MapRegion.Map -> 地图，其余实体经 Region 关联。"""
        layers = {"respawns": [], "npcs": [], "movements": [], "guards": [], "safezones": [], "mines": []}
        map_meta = self.meta["collections"].get("MapRegion", {}).get("fields", {})
        region_rows = []
        for r in self.data.get("MapRegion", {}).get("rows", []):
            m = r.get("Map")
            if isinstance(m, dict) and m.get("Index") == map_index:
                region_rows.append(r)
        region_ids = {r["Index"] for r in region_rows if "Index" in r}

        # 守卫/矿点直接引用 MapInfo
        for r in self.data.get("GuardInfo", {}).get("rows", []):
            m = r.get("Map")
            if isinstance(m, dict) and m.get("Index") == map_index:
                layers["guards"].append(r)
        for r in self.data.get("MineInfo", {}).get("rows", []):
            m = r.get("Map")
            if isinstance(m, dict) and m.get("Index") == map_index:
                layers["mines"].append(r)

        # 刷怪/NPC/传送/安全区引用 MapRegion
        def by_region(coll_name, field):
            out = []
            fmeta = self.meta["collections"].get(coll_name, {}).get("fields", {})
            for r in self.data.get(coll_name, {}).get("rows", []):
                reg = r.get(field)
                if isinstance(reg, dict) and reg.get("Index") in region_ids:
                    out.append(r)
            return out

        layers["respawns"] = by_region("RespawnInfo", "Region")
        layers["npcs"] = by_region("NPCInfo", "Region")
        layers["movements"] = by_region("MovementInfo", "SourceRegion")
        layers["safezones"] = by_region("SafeZoneInfo", "Region")
        return layers

    def search(self, q: str, limit: int = 200):
        """全局搜索：所有集合的 _Identity / 名称字段。"""
        ql = q.lower()
        out = []
        for t, coll in self.data.items():
            fields = self.meta["collections"].get(t, {}).get("fields", {})
            name_fields = ["MonsterName", "ItemName", "NPCName", "QuestName", "Name", "Description",
                           "SetName", "FileName", "Abbreviation", "MobDescription", "Monster",
                           "Item", "NPC", "Quest", "Map", "Region"]
            for r in coll["rows"]:
                ident = r.get("_Identity") or ""
                hit = ql in str(ident).lower()
                if not hit:
                    for f in name_fields:
                        v = r.get(f)
                        if isinstance(v, str) and ql in v.lower():
                            hit = True
                            break
                        if isinstance(v, dict) and isinstance(v.get("Name"), str) and ql in v["Name"].lower():
                            hit = True
                            break
                if hit:
                    out.append({"type": t, "row": r})
                    if len(out) >= limit:
                        return out
        return out

    def stats(self):
        out = []
        for t, m in self.meta["collections"].items():
            out.append({"type": t, "zh": m["zh"], "count": m["count"]})
        out.sort(key=lambda x: (-x["count"], x["type"]))
        return out

    # ---------- 地图实体（供 mapviewer 合并展示） ----------
    def map_entities(self, map_file: str):
        """返回 mapviewer 格式的实体列表：{map, x, y, kind, name, count?}。

        kind 用 mapviewer 已有样式：monster（红方块）/ npc（圆点）。
        """
        stem = map_file[:-4] if map_file.lower().endswith(".map") else map_file
        out = []

        # 找地图 Index（MapInfo.FileName == stem）
        map_index = None
        for r in self.data.get("MapInfo", {}).get("rows", []):
            if r.get("FileName") == stem:
                map_index = r.get("Index")
                break
        if map_index is None:
            return out

        layers = self._map_layers(map_index)

        def ent(map_name, x, y, kind, name, count=None):
            e = {"map": map_name, "x": x, "y": y, "kind": kind, "name": name}
            if count is not None:
                e["count"] = count
            return e

        for r in layers["respawns"]:
            reg = r.get("Region")
            if not isinstance(reg, dict) or reg.get("CenterX") is None:
                continue
            mon = r.get("Monster")
            name = mon.get("Name") if isinstance(mon, dict) else ""
            out.append(ent(stem, reg["CenterX"], reg["CenterY"], "monster",
                           name or ("#" + str(r.get("Index"))), r.get("Count")))
        for r in layers["npcs"]:
            reg = r.get("Region")
            if not isinstance(reg, dict) or reg.get("CenterX") is None:
                continue
            out.append(ent(stem, reg["CenterX"], reg["CenterY"], "npc",
                           r.get("NPCName") or ("#" + str(r.get("Index")))))
        for r in layers["guards"]:
            mon = r.get("Monster")
            name = mon.get("Name") if isinstance(mon, dict) else "守卫"
            out.append(ent(stem, r.get("X"), r.get("Y"), "monster", name))
        for r in layers["movements"]:
            reg = r.get("SourceRegion")
            if not isinstance(reg, dict) or reg.get("CenterX") is None:
                continue
            out.append(ent(stem, reg["CenterX"], reg["CenterY"], "npc", "传送点"))
        for r in layers["safezones"]:
            reg = r.get("Region")
            if not isinstance(reg, dict) or reg.get("CenterX") is None:
                continue
            out.append(ent(stem, reg["CenterX"], reg["CenterY"], "npc", "安全区"))
        return out


class Handler(BaseHTTPRequestHandler):
    store: DataStore

    def log_message(self, fmt, *args):
        sys.stderr.write("[dbviewer] %s\n" % (fmt % args))

    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        if isinstance(body, str):
            body = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def _json(self, obj, code=200):
        self._send(code, json.dumps(obj, ensure_ascii=False))

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        qs = parse_qs(parsed.query)
        try:
            if path in ("/", "/index.html"):
                self._serve_index()
            elif path == "/api/meta":
                self._json(self.store.meta)
            elif path == "/api/rows":
                self._api_rows(qs)
            elif path == "/api/row":
                self._api_row(qs)
            elif path == "/api/related":
                self._api_related(qs)
            elif path == "/api/search":
                self._api_search(qs)
            elif path == "/api/map-entities":
                map_file = qs.get("map", [""])[0]
                ents = self.store.map_entities(map_file)
                self._json({"ok": True, "count": len(ents), "entities": ents})
            elif path == "/api/stats":
                self._json(self.store.stats())
            elif path == "/api/map-cn":
                self._json(self.store.map_cn)
            else:
                self._json({"error": "not found"}, 404)
        except BrokenPipeError:
            pass
        except Exception as e:  # noqa: BLE001
            import traceback
            traceback.print_exc()
            self._json({"error": str(e)}, 500)

    def _serve_index(self):
        try:
            with open(TEMPLATE, encoding="utf-8") as f:
                html = f.read()
        except OSError:
            self._send(500, "template.html 缺失", "text/plain; charset=utf-8")
            return
        html = html.replace("window.__MAP_CN__ || {}", json.dumps(self.store.map_cn, ensure_ascii=False))
        self._send(200, html, "text/html; charset=utf-8")

    def _api_rows(self, qs):
        t = qs.get("type", [""])[0]
        if t not in self.store.data:
            self._json({"error": "unknown type: " + t}, 400)
            return
        try:
            page = max(1, int(qs.get("page", ["1"])[0]))
        except ValueError:
            page = 1
        try:
            per = min(MAX_PER, max(1, int(qs.get("per", [str(DEFAULT_PER)])[0])))
        except ValueError:
            per = DEFAULT_PER
        sort = qs.get("sort", [""])[0]
        dirn = 1 if qs.get("dir", ["1"])[0] != "-1" else -1
        q = qs.get("q", [""])[0]
        self._json(self.store.list_rows(t, page, per, sort, dirn, q))

    def _api_row(self, qs):
        t = qs.get("type", [""])[0]
        try:
            index = int(qs.get("index", ["0"])[0])
        except ValueError:
            self._json({"error": "bad index"}, 400)
            return
        row = self.store.get_row(t, index)
        if row is None:
            self._json({"error": "not found"}, 404)
            return
        self._json({"__type": t, "row": row})

    def _api_related(self, qs):
        t = qs.get("type", [""])[0]
        try:
            index = int(qs.get("index", ["0"])[0])
        except ValueError:
            self._json({"error": "bad index"}, 400)
            return
        rel = self.store.related(t, index)
        if rel is None:
            self._json({"error": "not found"}, 404)
            return
        self._json(rel)

    def _api_search(self, qs):
        q = qs.get("q", [""])[0]
        limit = 200
        try:
            limit = int(qs.get("limit", ["200"])[0])
        except ValueError:
            pass
        self._json({"results": self.store.search(q, limit)})


def main():
    parser = argparse.ArgumentParser(description="Mir3 / Zircon System.db Web 数据库查看器")
    parser.add_argument("--data", default=DEFAULT_DATA,
                        help="SystemDbProbe --json 导出的数据目录（默认 %(default)s）")
    parser.add_argument("--port", type=int, default=8800, help="HTTP 端口（默认 8800）")
    parser.add_argument("--host", default="0.0.0.0", help="监听地址（默认 0.0.0.0，局域网+tailscale 可达）")
    args = parser.parse_args()

    data_dir = os.path.abspath(args.data)
    if not os.path.isdir(data_dir):
        print(f"数据目录不存在: {data_dir}")
        print("请先导出数据：bash Tools/dbviewer/export.sh")
        sys.exit(1)

    store = DataStore(data_dir)
    Handler.store = store
    n_collections = len(store.data)
    n_rows = sum(c["count"] for c in store.data.values())
    print(f"[*] 数据目录: {data_dir}")
    print(f"[*] 集合: {n_collections} 个，记录: {n_rows} 条，内存索引已就绪")
    print(f"[*] 地图中文名: {len(store.map_cn)} 个")

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"[*] 数据库查看器运行于 http://127.0.0.1:{args.port}/")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[*] 已停止。")


if __name__ == "__main__":
    main()
