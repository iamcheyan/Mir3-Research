#!/usr/bin/env python3
"""mapedit.data — 数据装载层（地图扫描/catalog/连接/workspace/atlas/Envir）。"""
from __future__ import annotations
import json
import os
import time

from mapnames import resolve as map_cn

from mapedit.constants import LAYOUT_RECT, MAP_CN
from mapedit.geom import map_ladder, world_bounds
from mapedit.mapio import parse_map_header

_API_MAPS_CACHE: dict = {}   # (maps_dir, layout) -> 编码后 JSON; /api/maps 免重复扫描

def map_category(fid: str) -> str:
    """Classify a map stem into town / cave / room."""
    f = (fid or "").strip()
    if not f:
        return "other"
    # sub-areas / buildings / small rooms: contains '_' (e.g. 0_000, 1_001, D404_002)
    if "_" in f:
        return "room"
    up = f.upper()
    # caves / dungeons / mines: D / ID prefixes
    if up.startswith("D") or up.startswith("ID"):
        return "cave"
    # towns / overland: plain numbers, E roads, GM
    if f.isdigit() or up.startswith("E") or up.startswith("GM"):
        return "town"
    return "other"


def api_maps_payload(maps_dir: str, layout: str) -> bytes:
    """构建并缓存 /api/maps 响应 (地图集服务期内静态; 首扫 627 头约 3~25s)。"""
    ck = (maps_dir, layout)
    body = _API_MAPS_CACHE.get(ck)
    if body is None:
        maps = scan_maps(maps_dir, layout)
        for m in maps:
            fid = m["name"][:-4] if m["name"].endswith(".map") else m["name"]
            cn = MAP_CN.get(fid)
            if not cn or cn.startswith("EI ") or cn == fid:
                cn = map_cn(fid)
            m["cn"] = cn
            m["cat"] = map_category(fid)
        body = json.dumps(maps).encode("utf-8")
        _API_MAPS_CACHE[ck] = body
    return body


def scan_maps(maps_dir: str, layout: str = LAYOUT_RECT) -> list[dict]:
    out = []
    for fn in os.listdir(maps_dir):
        if not fn.lower().endswith(".map"):
            continue
        try:
            w, h = parse_map_header(os.path.join(maps_dir, fn))
            ww, wh = world_bounds(w, h, layout)
            out.append({
                "name": fn,
                "w": w,
                "h": h,
                "world_w": ww,
                "world_h": wh,
                "ladder": map_ladder(w, h, layout),
            })
        except Exception:
            continue
    out.sort(key=lambda m: m["name"])
    return out


def load_catalog(catalog_dir: str) -> dict:
    """Load map-catalog.json (from build_map_catalog.py) into
    {map_name: doc}.  Returns {} when the dir/file is absent or invalid."""
    if not catalog_dir:
        return {}
    p = os.path.join(catalog_dir, "map-catalog.json")
    if not os.path.exists(p):
        return {}
    try:
        with open(p, encoding="utf-8") as f:
            data = json.load(f)
        return {d.get("name"): d for d in data.get("maps", []) if d.get("name")}
    except Exception:
        return {}


def load_connections(path: str) -> list[dict]:
    """Load exported System.db movements, keeping only renderable endpoints."""
    if not path or not os.path.exists(path):
        return []
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return [x for x in data.get("links", [])
                if x.get("source", {}).get("map") and x.get("destination", {}).get("map")]
    except (OSError, ValueError, TypeError):
        return []




# ------------------------------------------------ dbeditor workspace 直读
# NPC 位置与地图连接的第一数据源：Tools/dbeditor/workspace/*.json 是
# System.db 的全表 JSON 导出（dbeditor 保存即更新 / NpcMover 坐标修正同样
# 落在这里）。坐标取 MapRegion.PointRegion 质心（CenterX/CenterY，游戏格）。

def _ws_rows(workspace: str, table: str) -> list[dict]:
    p = os.path.join(workspace, table + ".json")
    try:
        with open(p, encoding="utf-8") as f:
            data = json.load(f)
        rows = data.get("rows") if isinstance(data, dict) else data
        return rows or []
    except (OSError, ValueError, TypeError):
        return []


def load_db_names(path: str) -> dict:
    """db_names.json -> {npcs/maps/monsters/items: {en: zh}} (zh 优先, en 兜底)."""
    out: dict[str, dict] = {k: {} for k in ("npcs", "maps", "monsters", "items")}
    if not path or not os.path.exists(path):
        return out
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for section in ("npcs", "maps", "monsters", "items"):
            sec = data.get(section) or {}
            for en, entry in sec.items():
                zh = entry.get("zh") if isinstance(entry, dict) else None
                out[section][en] = zh if zh else en
    except (OSError, ValueError, TypeError, AttributeError):
        pass
    return out


def load_workspace_entities(workspace: str, db_names: dict | None = None) -> list[dict]:
    """NPCInfo x MapRegion -> [{map,x,y,kind:'npc',name,name_en}].

    name 为中文名（db_names.npcs 命中时），name_en 保留 DB 原名；坐标为
    Region.PointRegion 质心（EI 坐标系，NpcMover 修正后的最新值）。"""
    npc_names = (db_names or {}).get("npcs", {})
    regions = {r.get("Index"): r for r in _ws_rows(workspace, "MapRegion")}
    out: list[dict] = []
    for n in _ws_rows(workspace, "NPCInfo"):
        reg = regions.get((n.get("Region") or {}).get("Index"))
        if not reg:
            continue
        pr = reg.get("PointRegion") or {}
        x, y = pr.get("CenterX"), pr.get("CenterY")
        if x is None or y is None:
            continue
        en = n.get("NPCName") or ""
        if not en:
            # 装饰性 NPC（水井/火盆等）NPCName 为空，兜底 EntryPage 名
            en = str((n.get("EntryPage") or {}).get("Name") or "") or "未命名"
        out.append({
            "map": str((reg.get("Map") or {}).get("Name", "")),
            "x": x, "y": y, "kind": "npc",
            "name": npc_names.get(en, en) or en,
            "name_en": en,
            # NPC 形象：NPCInfo.Image = BodyShape，站立帧 = Image*100
            # （原版 NPCObject.BodyFrame = DrawFrame + Image*BodyOffSet(100)，
            #   库 = LibraryFile.NPC：ZL 客户端 NPC.Zl / EI 客户端 NPC.wil）
            "img": n.get("Image") or 0,
        })
    return out


# 城镇卫士（GuardInfo）：MonsterInfo.Image(MonsterImage 枚举名) -> (库 stem, BodyShape)。
# 客户端规则（MonsterObject.cs）：BodyFrame = DrawFrame + (BodyShape%10)*1000，
# DefaultMonster Standing = Frame(0,4,10) -> DrawFrame = 10 * (int)Direction。
GUARD_MONSTER_LIBS = {
    "Guard": ("Mon-3", 6),
}
MIR_DIRECTION_INDEX = {"Up": 0, "UpRight": 1, "Right": 2, "DownRight": 3,
                       "Down": 4, "DownLeft": 5, "Left": 6, "UpLeft": 7}


def load_workspace_guards(workspace: str, db_names: dict | None = None) -> list[dict]:
    """GuardInfo x MonsterInfo -> [{map,x,y,kind:'guard',name,name_en,lib,frame}].

    坐标为 GuardInfo.X/Y（服务端摆放的精确格），帧按朝向算好：
    frame = shape*1000 + 10*dirIndex（见 GUARD_MONSTER_LIBS 注释）。"""
    mon_names = (db_names or {}).get("monsters", {})
    monsters = {m.get("MonsterName"): m for m in _ws_rows(workspace, "MonsterInfo")}
    out: list[dict] = []
    for g in _ws_rows(workspace, "GuardInfo"):
        m = monsters.get((g.get("Monster") or {}).get("Name"))
        if not m:
            continue
        image = str(m.get("Image") or "")
        lib, shape = GUARD_MONSTER_LIBS.get(image, (None, 0))
        en = str((g.get("Monster") or {}).get("Name") or "") or "Guard"
        d = MIR_DIRECTION_INDEX.get(str(g.get("Direction") or "Down"), 4)
        out.append({
            "map": str((g.get("Map") or {}).get("Name", "")),
            "x": g.get("X"), "y": g.get("Y"), "kind": "guard",
            "name": mon_names.get(en, en) or en,
            "name_en": en,
            "lib": lib,
            "frame": (shape * 1000 + 10 * d) if lib else None,
        })
    return out


def load_workspace_connections(workspace: str) -> list[dict]:
    """MovementInfo x MapRegion -> links（与 map-connections.json 同 schema）.

    Region 质心坐标直接从 workspace MapRegion 取（0 缺失），比 8月11 的
    Markdown 导出（155 端点 x=null）完整；MovementInfo 1039 行含 D 系地下城
    连接。"""
    regions = {r.get("Index"): r for r in _ws_rows(workspace, "MapRegion")}

    def endpoint(ref) -> dict:
        reg = regions.get((ref or {}).get("Index")) or {}
        pr = reg.get("PointRegion") or {}
        x, y = pr.get("CenterX"), pr.get("CenterY")
        return {
            "map": str((reg.get("Map") or {}).get("Name", "")),
            "region": (ref or {}).get("Index"),
            "description": reg.get("Description", ""),
            "x": x if x is not None else None,
            "y": y if y is not None else None,
        }

    links = []
    for m in _ws_rows(workspace, "MovementInfo"):
        src = endpoint(m.get("SourceRegion"))
        dst = endpoint(m.get("DestinationRegion"))
        if not src["map"] or not dst["map"]:
            continue
        links.append({"index": m.get("Index"), "icon": str(m.get("Icon") or "None"),
                      "source": src, "destination": dst})
    return links


# ------------------------------------------------------ 地图工坊 atlas
# 启动时对 workspace/*.json（System.db 全表导出）做一次全量 JOIN，构建内存
# 索引：地图号 -> [regions/respawns/npcs]，怪物 -> 刷新点，任务 -> 覆盖层，
# MovementInfo -> 连通图谱 + map_links_v2.json。所有端点 O(1) 查询，无每请求
# 全表扫描。MapRegion 无显式矩形（只有 PointRegion 质心 + Size 格数），色块
# 以质心为中心、边长 = sqrt(Size) 格的方块近似。

# 出生点地图（连通图谱孤岛判定排除项）
SPAWN_STEMS = {"0"}
# 守卫类怪物等级（Guard/Archer = 250）不参与地图等级均值 —— 否则每张城图
# 都被守卫拉成 51+ 红区，总览分层失去意义。
GUARD_LEVEL_CAP = 200

# NPC 功能覆盖审计规则：先按 EntryPage 匹配，再按中/英文名关键词兜底。
NPC_FUNC_RULES = [
    ("药店", ("Basic Potion",), ("药", "Potion", "Pharmacy")),
    ("仓库", ("Storage",), ("仓", "Storage", "Warehouse")),
    ("修理", ("Weapon Refiner", "Repair"), ("修理", "铁匠", "Repair", "Refin", "Smith")),
    ("传送", ("Teleport",), ("传送", "Teleport")),
]


def _region_block(reg: dict) -> tuple[int, int, int] | None:
    """MapRegion -> (CenterX, CenterY, half_side_cells) 或 None（无质心）。"""
    pr = reg.get("PointRegion") or {}
    x, y = pr.get("CenterX"), pr.get("CenterY")
    if x is None or y is None:
        return None
    size = reg.get("Size") or pr.get("PointCount") or 1
    half = max(1, round((size ** 0.5) / 2))
    return int(x), int(y), half


def level_tier(avg: float | None) -> str:
    """总览染色分层：1-15 灰绿 / 16-30 黄 / 31-50 橙 / 51+ 红 / 无怪 灰。"""
    if avg is None:
        return "none"
    if avg <= 15:
        return "low"
    if avg <= 30:
        return "mid"
    if avg <= 50:
        return "high"
    return "max"


def respawn_tier(count: int) -> str:
    """刷怪热力分级：绿<10 黄<50 橙<150 红>=150。"""
    if count < 10:
        return "t1"
    if count < 50:
        return "t2"
    if count < 150:
        return "t3"
    return "t4"


def _articulation_points(nodes: set, adj: dict) -> set:
    """无向图割点（Tarjan）。adj 为双向邻接表。"""
    seen, disc, low = set(), {}, {}
    cut = set()
    timer = [0]

    def dfs(u: int, parent: int):
        seen.add(u)
        disc[u] = low[u] = timer[0]
        timer[0] += 1
        children = 0
        for v in adj.get(u, ()):
            if v == parent:
                continue
            if v in seen:
                low[u] = min(low[u], disc[v])
            else:
                dfs(v, u)
                low[u] = min(low[u], low[v])
                children += 1
                if parent != -1 and low[v] >= disc[u]:
                    cut.add(u)
        if parent == -1 and children > 1:
            cut.add(u)

    order = sorted(nodes)   # 确定性遍历顺序
    for n in order:
        if n not in seen:
            dfs(n, -1)
    return cut


def build_atlas(workspace: str, db_names: dict, maps_dir: str) -> dict:
    """workspace 全表 JOIN -> 地图工坊六大功能的内存索引（见模块注释）。"""
    regions = {r.get("Index"): r for r in _ws_rows(workspace, "MapRegion")}
    monsters = {m.get("Index"): m for m in _ws_rows(workspace, "MonsterInfo")}
    m_cn = db_names.get("monsters", {})
    i_cn = db_names.get("items", {})
    n_cn = db_names.get("npcs", {})
    npc_stems = db_names.get("maps", {})

    def cn_of_map(stem: str, desc: str = "") -> str:
        return MAP_CN.get(stem) or npc_stems.get(desc) or desc or stem

    atlas: dict = {
        "respawns_by_map": {}, "regions_by_map": {}, "respawns_by_monster": {},
        "quests": [], "overview": [], "npc_audit": [], "links_v2": {},
        "graph": {}, "item_droppers": {},
    }

    # ---- MapRegion：地图号 -> 区域块（质心 + Size 方块近似） ----
    for reg in regions.values():
        blk = _region_block(reg)
        if blk is None:
            continue
        stem = str((reg.get("Map") or {}).get("Name", ""))
        if not stem:
            continue
        x, y, half = blk
        atlas["regions_by_map"].setdefault(stem, []).append({
            "idx": reg.get("Index"), "desc": reg.get("Description", ""),
            "x": x, "y": y, "half": half,
        })

    # ---- RespawnInfo × MapRegion × MonsterInfo -> 刷怪热力 ----
    for r in _ws_rows(workspace, "RespawnInfo"):
        reg = regions.get((r.get("Region") or {}).get("Index")) or {}
        blk = _region_block(reg)
        if blk is None:
            continue
        stem = str((reg.get("Map") or {}).get("Name", ""))
        if not stem:
            continue
        x, y, half = blk
        men = (r.get("Monster") or {}).get("Name") or ""
        minfo = monsters.get((r.get("Monster") or {}).get("Index")) or {}
        count = int(r.get("Count") or 0)
        entry = {
            "m": men, "mc": m_cn.get(men, men), "x": x, "y": y, "half": half,
            "count": count, "delay": r.get("Delay"), "dropset": r.get("DropSet"),
            "tier": respawn_tier(count),
            "level": minfo.get("Level"), "boss": bool(minfo.get("IsBoss")),
        }
        atlas["respawns_by_map"].setdefault(stem, []).append(entry)
        atlas["respawns_by_monster"].setdefault(men, []).append(
            {"map": stem, "x": x, "y": y, "count": count})

    # ---- DropInfo 反查：物品 -> 掉落怪物（GainItem 任务兜底） ----
    for d in _ws_rows(workspace, "DropInfo"):
        item = (d.get("Item") or {}).get("Name") or ""
        mon = (d.get("Monster") or {}).get("Name") or ""
        if item and mon:
            s = atlas["item_droppers"].setdefault(item, set())
            s.add(mon)

    # ---- QuestInfo × QuestTask × QuestTaskMonsterDetails -> 任务叠加 ----
    qtasks = {t.get("Index"): t for t in _ws_rows(workspace, "QuestTask")}
    qdetails = {t.get("Index"): t for t in _ws_rows(workspace, "QuestTaskMonsterDetails")}
    for q in _ws_rows(workspace, "QuestInfo"):
        tasks = []
        for tref in q.get("Tasks") or []:
            t = qtasks.get(tref.get("Index"))
            if not t:
                continue
            monsters = []
            for dref in t.get("MonsterDetails") or []:
                det = qdetails.get(dref.get("Index")) or {}
                m = (det.get("Monster") or {}).get("Name")
                if m:
                    monsters.append(m)
            item = (t.get("ItemParameter") or {}).get("Name") or None
            # GainItem 无 MonsterDetails 时用 DropInfo 反查兜底
            if item and t.get("Task") == "GainItem" and not monsters:
                monsters = sorted(atlas["item_droppers"].get(item, ()))
            reg_param = t.get("RegionParameter") or {}
            reg = regions.get(reg_param.get("Index")) or {}
            rblk = _region_block(reg)
            tasks.append({
                "type": t.get("Task"), "amount": t.get("Amount") or 0,
                "item": item, "item_cn": i_cn.get(item, item) if item else None,
                "monsters": monsters,
                "region": {
                    "map": str((reg.get("Map") or {}).get("Name", "")),
                    "x": rblk[0], "y": rblk[1], "half": rblk[2], "idx": reg.get("Index"),
                    "desc": reg.get("Description", ""),
                } if rblk else None,
            })
        start = (q.get("StartNPC") or {}).get("Name") or ""
        atlas["quests"].append({
            "id": q.get("Index"), "name": q.get("QuestName") or f"Quest {q.get('Index')}",
            "type": q.get("QuestType"), "start": start, "tasks": tasks,
        })

    # ---- NPCInfo -> NPC 审计（功能覆盖检查按地图聚合） ----
    audit: dict[str, dict] = {}
    for n in _ws_rows(workspace, "NPCInfo"):
        reg = regions.get((n.get("Region") or {}).get("Index")) or {}
        stem = str((reg.get("Map") or {}).get("Name", ""))
        if not stem:
            continue
        en = n.get("NPCName") or ""
        page = (n.get("EntryPage") or {}).get("Name") or ""
        zh = n_cn.get(en, en)
        row = audit.setdefault(stem, {"map": stem, "npcs": [], "funcs": {k: [] for k, _, _ in NPC_FUNC_RULES}})
        row["npcs"].append({"en": en, "cn": zh, "page": page})
        for func, page_pats, name_pats in NPC_FUNC_RULES:
            if any(p in page for p in page_pats) or any(p in zh for p in name_pats) or any(p in en for p in name_pats):
                row["funcs"][func].append(zh or en)
    map_files = set()
    if maps_dir and os.path.isdir(maps_dir):
        map_files = {f[:-4] for f in os.listdir(maps_dir) if f.lower().endswith(".map")}
    npc_counts = {s: len(r["npcs"]) for s, r in audit.items()}
    for stem in sorted(audit):
        row = audit[stem]
        row["cn"] = cn_of_map(stem)
        row["total"] = len(row["npcs"])
        row["missing"] = [f for f, _, _ in NPC_FUNC_RULES if not row["funcs"][f]]
        row["file"] = stem in map_files
        atlas["npc_audit"].append(row)
    atlas["npc_audit"].sort(key=lambda r: -r["total"])

    # ---- MapInfo + 刷怪等级 -> 总览（627 张图） ----
    for mi in _ws_rows(workspace, "MapInfo"):
        stem = str(mi.get("FileName") or "")
        if not stem:
            continue
        desc = mi.get("Description") or ""
        respawns = atlas["respawns_by_map"].get(stem) or []
        lv_sum = lv_n = 0
        boss = False
        seen_m = set()
        for e in respawns:
            boss = boss or e["boss"]
            if e["m"] in seen_m or e["level"] is None:
                continue
            seen_m.add(e["m"])
            if e["level"] < GUARD_LEVEL_CAP:
                lv_sum += e["level"]
                lv_n += 1
        avg = round(lv_sum / lv_n, 1) if lv_n else None
        atlas["overview"].append({
            "id": stem, "cn": cn_of_map(stem, desc), "desc": desc,
            "file": stem in map_files, "lvl": avg, "tier": level_tier(avg),
            "boss": boss, "resp": len(respawns), "npcs": npc_counts.get(stem, 0),
            "cat": map_category(stem),
        })

    # ---- MovementInfo -> 连通图谱 + map_links_v2 ----
    edges: set[tuple[str, str]] = set()
    for m in _ws_rows(workspace, "MovementInfo"):
        s = str((regions.get((m.get("SourceRegion") or {}).get("Index")) or {}).get("Map", {}).get("Name", ""))
        d = str((regions.get((m.get("DestinationRegion") or {}).get("Index")) or {}).get("Map", {}).get("Name", ""))
        if s and d:
            edges.add((s, d))
    names = {row["id"]: row["cn"] for row in atlas["overview"]}
    d_edges = sorted([list(e) for e in edges if e[0].startswith("D") or e[1].startswith("D") or e[0].startswith("d") or e[1].startswith("d")])
    atlas["links_v2"] = {
        "names": names,
        "links": sorted([list(e) for e in edges]),
        "_meta": {
            "generated": time.strftime("%Y-%m-%d %H:%M:%S"),
            "source": "System.db MovementInfo (Tools/dbeditor/workspace/MovementInfo.json)",
            "movement_rows": len(_ws_rows(workspace, "MovementInfo")),
            "unique_links": len(edges),
            "d_series_links": len(d_edges),
            "note": "地图号对齐 MapInfo.FileName；names 覆盖全部 MapInfo 地图",
        },
    }
    # 图谱统计：孤岛（入度0且非出生点）/ 割点（无向割点=必经之路）
    indeg = {s: 0 for s in names}
    outdeg = {s: 0 for s in names}
    undirected: set[frozenset] = set()
    for a, b in edges:
        if a == b:
            continue
        outdeg[a] = outdeg.get(a, 0) + 1
        indeg[b] = indeg.get(b, 0) + 1
        undirected.add(frozenset((a, b)))
    adj: dict[str, set] = {}
    for e in undirected:
        a, b = tuple(e)
        adj.setdefault(a, set()).add(b)
        adj.setdefault(b, set()).add(a)
    cut = _articulation_points(set(names), adj)
    graph_nodes = []
    for stem in names:
        island = indeg.get(stem, 0) == 0 and stem not in SPAWN_STEMS
        graph_nodes.append({
            "id": stem, "cn": names[stem],
            "indeg": indeg.get(stem, 0), "outdeg": outdeg.get(stem, 0),
            "island": island, "isolated": stem not in adj,
            "cut": stem in cut,
            "file": stem in map_files, "npcs": npc_counts.get(stem, 0),
        })
    atlas["graph"] = {
        "nodes": graph_nodes, "edges": sorted([list(e) for e in edges]),
        "spawn_stems": sorted(SPAWN_STEMS),
    }
    return atlas


def write_map_links_v2(atlas: dict, path: str) -> bool:
    """把 links_v2 落盘到 Tools/maps/map_links_v2.json（git 跟踪的产出物）。"""
    try:
        with open(path, "w", encoding="utf-8") as f:
            json.dump(atlas["links_v2"], f, ensure_ascii=False, indent=1)
        return True
    except OSError:
        return False




_DROPS_CACHE: dict[str, list[dict]] = {}


def load_drops(envir_dir: str, monster_name: str) -> list[dict]:
    """Parse Envir/MonItems/<monster>.txt into a drop list.

    Lines are '<num>/<den> <item> [count]' (GBK item names).  Returns up to
    12 entries sorted by chance descending: [{item, chance (num/den), count}].
    Falls back to the trailing-digit-stripped name (e.g. '巨象兽8' -> '巨象兽'),
    then to None.  Cached per envir_dir+name.
    """
    key = (envir_dir, monster_name)
    cached = _DROPS_CACHE.get(key)
    if cached is not None:
        return cached
    import re as _re
    candidates = [monster_name]
    stripped = _re.sub(r"\d+$", "", monster_name)
    if stripped != monster_name:
        candidates.append(stripped)
    result: list[dict] = []
    for cand in candidates:
        p = os.path.join(envir_dir, "MonItems", cand + ".txt")
        try:
            raw = open(p, "rb").read()
        except OSError:
            continue
        text = raw.decode("gbk", errors="replace")
        for ln in text.splitlines():
            ln = ln.strip()
            if not ln or ln.startswith(";"):
                continue
            m = _re.match(r"^(\d+)/(\d+)\s+(.+)$", ln)
            if not m:
                continue
            num, den = int(m.group(1)), int(m.group(2))
            rest = m.group(3).split()
            item = rest[0]
            count = int(rest[1]) if len(rest) > 1 and rest[1].isdigit() else 1
            result.append({"item": item, "chance": num / den, "count": count})
        if result:
            break
    result.sort(key=lambda d: (-d["chance"], d["item"]))
    result = result[:12]
    _DROPS_CACHE[key] = result
    return result


def load_entities(envir_dir: str) -> list[dict]:
    """Parse Mud3 server entity data into a flat list of dicts.

    Sources (all GBK-encoded names):
      StartPoint.txt  -> one spawn point per map  (map x y)
      Merchant.txt    -> NPCs                      (name map x y face body)
      MonGen.txt      -> loadgen lines expanding to .gen files in Mon_Def/
                        (map x y name count level attack respawn)
    Returns [{map, x, y, kind, name, face?, body?, count?, level?}].
    Map names are normalised to '<name>.map'.  MonGen's loadgen refs that do
    not resolve to a file are skipped (pending note)."""
    out: list[dict] = []

    def norm(name: str) -> str:
        name = name.strip()
        return name if name.lower().endswith(".map") else name + ".map"

    def lines(path: str):
        try:
            with open(path, "rb") as f:
                raw = f.read()
        except OSError:
            return
        try:
            text = raw.decode("gbk", errors="replace")
        except Exception:
            text = raw.decode("utf-8", errors="replace")
        for ln in text.splitlines():
            ln = ln.strip()
            if not ln or ln.startswith(";"):
                continue
            yield ln

    # spawn points
    sp = os.path.join(envir_dir, "StartPoint.txt")
    for ln in lines(sp):
        parts = ln.split()
        if len(parts) >= 3 and parts[0].replace(".", "", 1).isdigit():
            try:
                out.append({"map": norm(parts[0]), "x": int(parts[1]),
                            "y": int(parts[2]), "kind": "spawn", "name": "出生点"})
            except ValueError:
                pass

    # merchants / NPCs
    mp = os.path.join(envir_dir, "Merchant.txt")
    for ln in lines(mp):
        parts = ln.split()
        if len(parts) < 6:
            continue
        fname, mapn, xs, ys = parts[0], parts[1], parts[2], parts[3]
        if not fname or mapn in ("Map", "map") or not xs.isdigit():
            continue
        try:
            out.append({"map": norm(mapn), "x": int(xs), "y": int(ys),
                        "kind": "npc", "name": parts[4],
                        "face": int(parts[5]) if parts[5].isdigit() else 0,
                        "body": int(parts[6]) if len(parts) > 6 and parts[6].isdigit() else 0})
        except (ValueError, IndexError):
            continue

    # monsters: MonGen.txt loadgen refs -> .gen files (Mon_Def/ and Envir/)
    mon_gen = os.path.join(envir_dir, "MonGen.txt")
    gen_files: list[str] = []
    for ln in lines(mon_gen):
        low = ln.lower()
        if low.startswith("loadgen"):
            ref = ln.split('"')[1] if '"' in ln else ln.split()[1]
            for base in (os.path.join(envir_dir, "Mon_Def"), envir_dir):
                p = os.path.join(base, ref)
                if os.path.exists(p):
                    gen_files.append(p)
                    break
    for gp in gen_files:
        for ln in lines(gp):
            parts = ln.split()
            if len(parts) < 4:
                continue
            try:
                mon = {"map": norm(parts[0]), "x": int(parts[1]), "y": int(parts[2]),
                       "kind": "monster", "name": parts[3],
                       "count": int(parts[4]) if len(parts) > 4 and parts[4].isdigit() else 1,
                       "level": int(parts[5]) if len(parts) > 5 and parts[5].isdigit() else 0}
            except (ValueError, IndexError):
                continue
            drops = load_drops(envir_dir, mon["name"])
            if drops:
                mon["drops"] = drops
            out.append(mon)
    return out

