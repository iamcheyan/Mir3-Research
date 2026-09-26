"""mapedit.npcedit — E2 NPC/Region 摆放编辑引擎。

写路径纪律（EDITOR_GOALS_MASTER §6 / AGENTS.md §四）：
- 只写 dbeditor workspace JSON（Tools/dbeditor/workspace/*.json），**绝不直写 .db**；
- 写后通知 dbeditor POST /api/reload（在线时），防止其内存态 persist 覆写外部编辑；
- 入库统一走 dbeditor sync.sh → DBImporter（points 单点写回 / 多点拒改，2026-08-15 扩展）。

数据模型（workspace meta.json + Zircon LibraryCore/SystemModels 实证）：
- NPCInfo.Region -> MapRegion（Association "RegionNPCs"，MapRegion.NPCs 是派生回链，
  入库时由子行 Region setter 自动维护；工作区 JSON 需手动保持一致供 round-trip 对比）；
- MapRegion.PointRegion = System.Drawing.Point[]；工作区 JSON 是**质心摘要**
  {PointCount, CenterX, CenterY}（SystemDbProbe 导出有损）→ 单点区域可无损编辑，
  多点区域只读（移动/新建一律 PointCount=1）；
- NPC 摆放区约定：PointCount=1, Size=1（293/294 现状）= 定点 NPC；
- Index 分配 = 表内 max+1（与 dbeditor next_index 同规则；MirDB 计数器若更大，
  importer 自动 REMAP 并在 round-trip 对比时换算）；
- _Identity 按 meta.json identity 字段重算（ref 取 .Name）。

删除语义（importer 先删 → 改 → 增，del 按 Index 升序）：
- NPCInfo Index(1..294+) 恒小于新建 MapRegion Index(5010+)，先删 NPC 再删 Region，
  MirDB 级联不会撞「目标不存在」；Region 被运动/安全区/刷新/任务引用时保留 Region
  仅删 NPCInfo。
"""
from __future__ import annotations

import copy
import json
import os
import shutil
import subprocess
import threading
import urllib.request

_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

# ---------------------------------------------------------------- 基础载入


class NpcEditError(Exception):
    """摆放编辑业务错误（前端可展示）。"""


def _ws_path(workspace: str, table: str) -> str:
    return os.path.join(workspace, table + ".json")


def load_table(workspace: str, table: str) -> list[dict]:
    try:
        with open(_ws_path(workspace, table), encoding="utf-8") as f:
            return json.load(f).get("rows") or []
    except (OSError, ValueError):
        return []


def load_meta(workspace: str) -> dict:
    try:
        with open(os.path.join(workspace, "meta.json"), encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def recompute_identity(meta: dict, table: str, row: dict) -> None:
    """与 dbeditor Store.recompute_identity 同规则：identity 字段 join(' / ')。"""
    fields = (meta.get(table) or {}).get("identity") or []
    parts = []
    for f in fields:
        v = row.get(f)
        if isinstance(v, dict):
            v = v.get("Name")
        if v is None:
            continue
        parts.append(str(v))
    if parts:
        row["_Identity"] = " / ".join(parts)
    else:
        row.pop("_Identity", None)


# MapRegion 被这些行/列表引用时不可整行删除（MirDB Delete 级联会带走它们）。
# 键 = MapRegion 上的派生回链字段，值 = （展示用的）引用方表名。
REGION_BACKREF_FIELDS = {
    "SourceMovements": "MovementInfo",
    "DestinationMovements": "MovementInfo",
    "SafeZones": "SafeZoneInfo",
    "BindSafeZones": "SafeZoneInfo",
    "Respawns": "RespawnInfo",
    "QuestTasks": "QuestTask",
}


class WorkspaceEditor:
    """一次编辑 = load 全量 → 变更 → 校验 → 原子落盘 + git commit + reload 通知。

    不在内存里长期缓存：每次操作前重新读盘（表都是几十 KB 级，读得起；
    且与 dbeditor / 其它会话的外部写天然合并，杜绝覆写）。"""

    def __init__(self, workspace: str, maps_dir: str | None = None,
                 dbeditor_url: str = "http://127.0.0.1:8810"):
        self.workspace = workspace
        self.maps_dir = maps_dir
        self.dbeditor_url = dbeditor_url.rstrip("/")
        self.meta = load_meta(workspace)
        self.tables: dict[str, dict[int, dict]] = {}
        self._touched: set[str] = set()

    def load(self, *tables: str) -> "WorkspaceEditor":
        for t in tables:
            self.tables[t] = {r["Index"]: r for r in load_table(self.workspace, t)}
        return self

    def _require(self, table: str):
        if table not in self.tables:
            self.load(table)
        return self.tables[table]

    def _next_index(self, table: str) -> int:
        rows = self._require(table)
        return max(rows) + 1 if rows else 1

    def _persist(self, table: str) -> None:
        rows = sorted(self.tables[table].values(), key=lambda r: r["Index"])
        out = {"count": len(rows), "rows": rows}
        tmp = _ws_path(self.workspace, table) + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=2)
        os.replace(tmp, _ws_path(self.workspace, table))
        self._touched.add(table)

    def commit(self, msg: str) -> bool:
        """落盘后的收尾：git 提交 workspace 子树 + 通知 dbeditor reload。"""
        if not self._touched:
            return False
        try:
            subprocess.run(["git", "add", "Tools/dbeditor/workspace"],
                           cwd=_REPO, check=True, capture_output=True)
            r = subprocess.run(
                ["git", "diff", "--cached", "--quiet", "--", "Tools/dbeditor/workspace"],
                cwd=_REPO, capture_output=True)
            if r.returncode != 0:
                subprocess.run(["git", "commit", "-m", f"mapedit: {msg}"],
                               cwd=_REPO, check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError:
            pass    # 提交失败不阻塞编辑（工作区文件已是新值）
        self._notify_dbeditor()
        self._touched = set()
        return True

    def _notify_dbeditor(self) -> None:
        try:
            req = urllib.request.Request(self.dbeditor_url + "/api/reload",
                                         method="POST", data=b"{}",
                                         headers={"Content-Type": "application/json"})
            urllib.request.urlopen(req, timeout=2).read()
        except Exception:
            pass    # dbeditor 未运行：无事（下次启动自然读盘）

    # ---------- 校验

    def _map_row(self, map_stem: str) -> dict:
        for r in self._require("MapInfo").values():
            if str(r.get("FileName") or "") == map_stem:
                return r
        raise NpcEditError(f"地图 {map_stem!r} 不在 MapInfo 中")

    def _map_header(self, map_stem: str) -> tuple[int, int, str] | None:
        """(w, h, path)；maps_dir 未配置或文件缺失返回 None（跳过校验）。"""
        if not self.maps_dir:
            return None
        p = os.path.join(self.maps_dir, os.path.basename(map_stem) + ".map")
        try:
            with open(p, "rb") as f:
                head = f.read(26)
            if len(head) < 26:
                return None
            return (int.from_bytes(head[22:24], "little"),
                    int.from_bytes(head[24:26], "little"), p)
        except OSError:
            return None

    def _bounds(self, map_stem: str) -> tuple[int, int] | None:
        hdr = self._map_header(map_stem)
        return (hdr[0], hdr[1]) if hdr else None

    def _cell_blocked(self, map_stem: str, x: int, y: int) -> bool:
        """按 Segment2 布局取格 flag（与 E1 mapio.parse_map 同约定）：
        第 i 格 → x=i//h, y=i%h，每格 14B，flag@+0。flag&3!=3 即阻挡。
        服务器实证（2026-08-16）：NPC spawn 在阻挡格 = 游戏内不可见
        （对象存在但不广播），摆放编辑必须在写 workspace 前拒绝。"""
        hdr = self._map_header(map_stem)
        if not hdr:
            return False
        w, h, p = hdr
        try:
            with open(p, "rb") as f:
                f.seek(28 + (w // 2) * (h // 2) * 3 + (x * h + y) * 14)
                flag = f.read(1)[0]
            return (flag & 3) != 3
        except (OSError, IndexError):
            return False

    def _check_xy(self, map_stem: str, x: int, y: int,
                  require_passable: bool = False) -> None:
        if not isinstance(x, int) or not isinstance(y, int) or x < 0 or y < 0:
            raise NpcEditError(f"坐标必须是非负整数：({x},{y})")
        dims = self._bounds(map_stem)
        if dims:
            w, h = dims
            if x >= w or y >= h:
                raise NpcEditError(f"({x},{y}) 超出 {map_stem} 边界 {w}x{h}")
        if require_passable and self._cell_blocked(map_stem, x, y):
            raise NpcEditError(
                f"({x},{y}) 是阻挡格（flag&3!=3）——服务器 spawn 后游戏内不可见，"
                "请选通行格（可加 force=1 强制）")

    @staticmethod
    def _region_single(reg: dict) -> None:
        pr = reg.get("PointRegion") or {}
        if pr.get("PointCount") != 1:
            raise NpcEditError(
                f"Region#{reg['Index']} 是 {pr.get('PointCount')} 点区域，"
                "工作区 JSON 只有质心摘要，多点区域不可经此编辑")

    # ---------- 查询

    def npc_overview(self, map_stem: str | None = None) -> list[dict]:
        out = []
        regions = self._require("MapRegion")
        for n in sorted(self._require("NPCInfo").values(), key=lambda r: r["Index"]):
            reg = regions.get((n.get("Region") or {}).get("Index"))
            if reg is None:
                continue
            m = str((reg.get("Map") or {}).get("Name") or "")
            if map_stem and m != map_stem:
                continue
            pr = reg.get("PointRegion") or {}
            out.append({"npc_index": n["Index"], "name": n.get("NPCName"),
                        "map": m, "region": reg["Index"],
                        "x": pr.get("CenterX"), "y": pr.get("CenterY"),
                        "size": reg.get("Size"),
                        "point_count": pr.get("PointCount"),
                        "image": n.get("Image") or 0,
                        "entry_page": (n.get("EntryPage") or {}).get("Index")})
        return out

    def region_detail(self, region_index: int) -> dict:
        reg = self._require("MapRegion").get(region_index)
        if reg is None:
            raise NpcEditError(f"Region#{region_index} 不存在")
        refs = {f: [e.get("Index") for e in reg.get(f) or []]
                for f in REGION_BACKREF_FIELDS}
        return {"region": reg, "backrefs": refs,
                "deletable": not any(refs.values())}

    def npc_pages(self, q: str = "", limit: int = 60) -> list[dict]:
        q = (q or "").strip().lower()
        out = []
        for r in sorted(self._require("NPCPage").values(), key=lambda r: r["Index"]):
            hay = f"{r.get('Description') or ''}".lower()
            if q and q not in hay:
                continue
            out.append({"Index": r["Index"], "Name": r.get("Description")})
            if len(out) >= limit:
                break
        return out

    # ---------- 变更操作
    def _set_region_point(self, reg: dict, x: int, y: int,
                          allow_multi: bool = False) -> None:
        pr = reg.get("PointRegion") or {}
        if pr.get("PointCount") != 1:
            if not (allow_multi and pr.get("PointCount")):
                raise NpcEditError(
                    f"Region#{reg['Index']} 是 {pr.get('PointCount')} 点区域，"
                    "多点区域只支持整体平移（安全区），NPC 摆放须单点区域")
            # 多点区域：只更新质心，importer 按质心差整体平移全部点（形状保持）
            reg["PointRegion"] = {"PointCount": pr["PointCount"],
                                  "CenterX": x, "CenterY": y}
            return
        reg["PointRegion"] = {"PointCount": 1, "CenterX": x, "CenterY": y}

    def move_npc(self, npc_index: int, x: int, y: int,
                 map_stem: str | None = None, force: bool = False) -> dict:
        npc = self._require("NPCInfo").get(npc_index)
        if npc is None:
            raise NpcEditError(f"NPCInfo#{npc_index} 不存在")
        reg = self._require("MapRegion").get((npc.get("Region") or {}).get("Index"))
        if reg is None:
            raise NpcEditError(f"NPCInfo#{npc_index} 的 Region 缺失")
        cur_map = str((reg.get("Map") or {}).get("Name") or "")
        target_map = map_stem or cur_map
        self._check_xy(target_map, x, y, require_passable=not force)
        old = (reg.get("PointRegion") or {}).get("CenterX"), (reg.get("PointRegion") or {}).get("CenterY")
        self._set_region_point(reg, x, y)
        moved_map = False
        if target_map != cur_map:
            mi = self._map_row(target_map)
            reg["Map"] = {"Index": mi["Index"], "Name": mi.get("FileName")}
            npc["Region"]["Name"] = None    # 下面的重算会填
            moved_map = True
        recompute_identity(self.meta, "MapRegion", reg)
        npc["Region"]["Name"] = reg["_Identity"]
        recompute_identity(self.meta, "NPCInfo", npc)
        self._persist("MapRegion")
        if moved_map:
            # MapInfo.Regions 派生回链（导出顺序无关，round-trip 按集合比）也要挪
            self._sync_map_regions_reflist(cur_map, target_map, reg)
        self._persist("NPCInfo")
        return {"npc": npc_index, "region": reg["Index"],
                "from": {"map": cur_map, "x": old[0], "y": old[1]},
                "to": {"map": target_map, "x": x, "y": y}}

    def _sync_map_regions_reflist(self, old_map: str, new_map: str, reg: dict) -> None:
        """跨图移动时同步 MapInfo.Regions 派生回链（否则 round-trip 对比不过）。"""
        ref = {"Index": reg["Index"], "Name": reg.get("_Identity")}
        for stem in {old_map, new_map}:
            try:
                mi = self._map_row(stem)
            except NpcEditError:
                continue
            regions = mi.get("Regions") or []
            regions = [e for e in regions if e.get("Index") != reg["Index"]]
            if stem == new_map:
                regions.append(ref)
            mi["Regions"] = regions
        self._persist("MapInfo")

    def create_npc(self, map_stem: str, x: int, y: int, name: str,
                   image: int = 0, entry_page: int | None = None,
                   description: str | None = None, force: bool = False) -> dict:
        name = (name or "").strip()
        if not name:
            raise NpcEditError("NPCName 不能为空")
        self._map_row(map_stem)          # 地图存在性
        self._check_xy(map_stem, x, y, require_passable=not force)
        mi = self._map_row(map_stem)
        if entry_page is not None:
            if entry_page not in self._require("NPCPage"):
                raise NpcEditError(f"NPCPage#{entry_page} 不存在")

        reg_idx = self._next_index("MapRegion")
        npc_idx = self._next_index("NPCInfo")
        reg = {"Index": reg_idx,
               "Map": {"Index": mi["Index"], "Name": mi.get("FileName")},
               "Description": description or f"{mi.get('FileName')} / {name}",
               "PointRegion": {"PointCount": 1, "CenterX": x, "CenterY": y},
               "RegionType": "None", "Size": 1}
        recompute_identity(self.meta, "MapRegion", reg)
        npc = {"Index": npc_idx,
               "Region": {"Index": reg_idx, "Name": reg["_Identity"]},
               "NPCName": name, "Image": int(image or 0), "FaceImage": 0,
               "Category": "None", "GoodsIndex": 0, "MapIcon": "None",
               "StartQuests": [], "FinishQuests": [], "Requirements": []}
        if entry_page is not None:
            page = self._require("NPCPage")[entry_page]
            npc["EntryPage"] = {"Index": entry_page,
                                "Name": page.get("Description")}
        else:
            npc["EntryPage"] = None
        recompute_identity(self.meta, "NPCInfo", npc)
        reg["NPCs"] = [{"Index": npc_idx, "Name": npc["_Identity"]}]
        self.tables["MapRegion"][reg_idx] = reg
        self.tables["NPCInfo"][npc_idx] = npc
        mi.setdefault("Regions", []).append(
            {"Index": reg_idx, "Name": reg["_Identity"]})
        self._persist("MapRegion")
        self._persist("NPCInfo")
        self._persist("MapInfo")
        return {"npc": npc_idx, "region": reg_idx, "map": map_stem,
                "x": x, "y": y, "name": name,
                "entry_page": entry_page}

    def delete_npc(self, npc_index: int) -> dict:
        npcs = self._require("NPCInfo")
        npc = npcs.get(npc_index)
        if npc is None:
            raise NpcEditError(f"NPCInfo#{npc_index} 不存在")
        regions = self._require("MapRegion")
        reg = regions.get((npc.get("Region") or {}).get("Index"))
        del npcs[npc_index]
        drop_region = False
        if reg is not None:
            reg["NPCs"] = [e for e in reg.get("NPCs") or []
                           if e.get("Index") != npc_index]
            if not reg["NPCs"] and not any(
                    (reg.get(f) or []) for f in REGION_BACKREF_FIELDS):
                drop_region = True
        self._persist("NPCInfo")
        if drop_region:
            del regions[reg["Index"]]
            self._persist("MapRegion")
            mi = self._map_row(str((reg.get("Map") or {}).get("Name") or ""))
            mi["Regions"] = [e for e in mi.get("Regions") or []
                             if e.get("Index") != reg["Index"]]
            self._persist("MapInfo")
        return {"npc": npc_index, "region": reg["Index"] if reg else None,
                "region_deleted": drop_region}

    def move_guard(self, guard_index: int, x: int, y: int,
                   map_stem: str | None = None, force: bool = False) -> dict:
        guards = self._require("GuardInfo")
        g = guards.get(guard_index)
        if g is None:
            raise NpcEditError(f"GuardInfo#{guard_index} 不存在")
        cur_map = str((g.get("Map") or {}).get("Name") or "")
        target = map_stem or cur_map
        self._check_xy(target, x, y, require_passable=not force)
        old = (g.get("X"), g.get("Y"), cur_map)
        g["X"], g["Y"] = x, y
        if target != cur_map:
            mi = self._map_row(target)
            g["Map"] = {"Index": mi["Index"], "Name": mi.get("FileName")}
        recompute_identity(self.meta, "GuardInfo", g)
        self._persist("GuardInfo")
        return {"guard": guard_index,
                "from": {"map": old[2], "x": old[0], "y": old[1]},
                "to": {"map": target, "x": x, "y": y}}

    def move_safezone(self, safezone_index: int, x: int, y: int,
                       force: bool = False) -> dict:
        szs = self._require("SafeZoneInfo")
        sz = szs.get(safezone_index)
        if sz is None:
            raise NpcEditError(f"SafeZoneInfo#{safezone_index} 不存在")
        regions = self._require("MapRegion")
        reg = regions.get((sz.get("Region") or {}).get("Index"))
        if reg is None:
            raise NpcEditError(f"SafeZoneInfo#{safezone_index} 的 Region 缺失")
        map_stem = str((reg.get("Map") or {}).get("Name") or "")
        self._check_xy(map_stem, x, y, require_passable=not force)
        old = ((reg.get("PointRegion") or {}).get("CenterX"),
               (reg.get("PointRegion") or {}).get("CenterY"))
        self._set_region_point(reg, x, y, allow_multi=True)
        recompute_identity(self.meta, "MapRegion", reg)
        # Region._Identity 变化会传导到引用它的行（SafeZoneInfo identity=Region）
        sz["Region"]["Name"] = reg["_Identity"]
        recompute_identity(self.meta, "SafeZoneInfo", sz)
        self._persist("MapRegion")
        self._persist("SafeZoneInfo")
        return {"safezone": safezone_index, "region": reg["Index"],
                "from": {"x": old[0], "y": old[1]}, "to": {"x": x, "y": y}}

    def set_region_size(self, region_index: int, size: int) -> dict:
        reg = self._require("MapRegion").get(region_index)
        if reg is None:
            raise NpcEditError(f"Region#{region_index} 不存在")
        if not isinstance(size, int) or size < 1:
            raise NpcEditError("Size 需为 >=1 整数")
        old = reg.get("Size")
        reg["Size"] = size
        self._persist("MapRegion")
        return {"region": region_index, "from": old, "to": size}

    # ---------- diff / 回滚（工作区 vs _baseline，独立于 dbeditor 内存态）


#（diff/rollback 见模块级函数：不依赖编辑器实例）

_SKIP_FILES = {"baseline.json", "meta.json", "state.json", "sync_report.txt",
               "workspace.lock"}


def workspace_diff(workspace: str) -> dict:
    """工作区(盘上) vs _baseline：按表/行/字段。与 dbeditor Store.diff 同语义。"""
    ws, base = workspace, os.path.join(workspace, "_baseline")
    result: dict = {"tables": {}, "summary": {"added": 0, "modified": 0, "deleted": 0}}
    for fn in sorted(os.listdir(ws)):
        if not fn.endswith(".json") or fn in _SKIP_FILES:
            continue
        table = fn[:-5]
        cur = {r["Index"]: r for r in load_table(ws, table)}
        old = {r["Index"]: r for r in load_table(base, table)}
        entries = []
        for idx in sorted(set(cur) | set(old)):
            if idx not in old:
                entries.append({"op": "added", "index": idx, "fields": None})
                result["summary"]["added"] += 1
            elif idx not in cur:
                entries.append({"op": "deleted", "index": idx, "fields": None})
                result["summary"]["deleted"] += 1
            else:
                changed = {k: {"old": old[idx].get(k), "new": cur[idx].get(k)}
                           for k in sorted(set(old[idx]) | set(cur[idx]))
                           if old[idx].get(k) != cur[idx].get(k)}
                if changed:
                    entries.append({"op": "modified", "index": idx,
                                    "fields": changed})
                    result["summary"]["modified"] += 1
        if entries:
            result["tables"][table] = entries
    return result


def workspace_rollback(workspace: str, table: str | None = None) -> dict:
    """把工作区(盘上)恢复为 _baseline。table=None 恢复全部（除基线/元数据）。"""
    base = os.path.join(workspace, "_baseline")
    restored = []
    names = [table + ".json"] if table else sorted(os.listdir(base))
    for fn in names:
        if not fn.endswith(".json") or fn in _SKIP_FILES:
            continue
        src, dst = os.path.join(base, fn), _ws_path(workspace, fn[:-5])
        if os.path.exists(src):
            shutil.copyfile(src, dst)
            restored.append(fn[:-5])
    if restored:
        ed = WorkspaceEditor(workspace)
        ed._touched = set(restored)
        ed.commit(f"回滚工作区至基线：{','.join(restored)}")
    return {"restored": restored}


# ---------------------------------------------------------------------------
# 未知实体人工安置 manifest

_PLACEMENT_LOCK = threading.RLock()
_MAP_RE = __import__("re").compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")


def _placement_map(value) -> str:
    raw = str(value or "").strip()
    if "/" in raw or "\\" in raw:
        raise NpcEditError("非法地图名：不允许目录分隔符")
    value = raw
    if value.lower().endswith(".map"):
        value = value[:-4]
    if not _MAP_RE.fullmatch(value):
        raise NpcEditError("非法地图名")
    return value


def _json_int(value, name: str, minimum: int, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise NpcEditError(f"{name} 必须是整数")
    if value < minimum or value > maximum:
        raise NpcEditError(f"{name} 必须在 {minimum}..{maximum} 范围内")
    return value


class PlacementStore:
    """独立于 System.db 的未知实体候选存储。

    文件结构固定为 ``{version, placements}``；同一 monster/map/x/y 使用
    稳定 ID，重复保存只更新字段，不增加重复候选。所有落盘均为临时文件
    + os.replace，历史保留旧值，undo 只改变 manifest 状态。
    """

    def __init__(self, path: str):
        self.path = os.path.abspath(path)

    def load(self) -> dict:
        try:
            with open(self.path, encoding="utf-8") as f:
                doc = json.load(f)
        except (OSError, ValueError, TypeError):
            doc = {}
        rows = doc.get("placements") if isinstance(doc, dict) else []
        return {"version": int((doc or {}).get("version") or 1),
                "placements": [r for r in rows or [] if isinstance(r, dict)]}

    def _save(self, doc: dict) -> None:
        os.makedirs(os.path.dirname(self.path), exist_ok=True)
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2, sort_keys=True)
            f.write("\n")
        os.replace(tmp, self.path)

    @staticmethod
    def _now() -> str:
        import datetime
        return datetime.datetime.now(datetime.timezone.utc).isoformat()

    @staticmethod
    def _operator(value) -> str:
        value = str(value or "mapedit").strip()
        return value[:80] or "mapedit"

    def _upsert(self, row: dict) -> dict:
        with _PLACEMENT_LOCK:
            doc = self.load()
            rows = doc["placements"]
            old = next((r for r in rows if r.get("placement_id") == row["placement_id"]), None)
            if old:
                comparable = {k: v for k, v in row.items() if k not in {"history", "updated_at"}}
                previous = {k: v for k, v in old.items() if k not in {"history", "updated_at"}}
                if comparable != previous:
                    old_snapshot = copy.deepcopy({
                        k: v for k, v in old.items() if k != "history"})
                    old.setdefault("history", []).append({
                        "action": "update", "timestamp": self._now(),
                        "previous": old_snapshot, "operator": row["operator"]})
                    old.update(row)
                    old["history"] = old.get("history") or []
                    row = old
                else:
                    row = old
            else:
                rows.append(row)
            self._save(doc)
            return row

    def record_npc_move(self, npc_index: int, old: dict, new: dict,
                        previous_status: str = "pending-review",
                        operator: str = "mapedit", validation: dict | None = None) -> dict:
        idx = _json_int(npc_index, "npc_index", 1, 2_000_000_000)
        row = {
            "placement_id": f"npc:{idx}", "kind": "npc-placement",
            "npc_index": idx, "map": _placement_map(new["map"]),
            "x": _json_int(new["x"], "x", 0, 100_000),
            "y": _json_int(new["y"], "y", 0, 100_000),
            "status": "user-placed", "source": "website-alignment-manual-placement",
            "operator": self._operator(operator), "updated_at": self._now(),
            "validation": validation or {"in_bounds": True, "walkable": True},
        }
        with _PLACEMENT_LOCK:
            doc = self.load()
            existing = next((r for r in doc["placements"]
                             if r.get("placement_id") == row["placement_id"]), None)
            history = (existing or {}).get("history") or []
            history.append({"action": "place", "timestamp": self._now(),
                            "old": old, "new": dict(row), "source": row["source"],
                            "operator": row["operator"],
                            "validation": row["validation"],
                            "previous_status": previous_status})
            row["history"] = history
            if existing:
                doc["placements"] = [row if r is existing else r
                                     for r in doc["placements"]]
            else:
                doc["placements"].append(row)
            self._save(doc)
            return row

    def upsert_monster(self, monster_index: int, map_stem: str, x: int, y: int,
                       count: int = 1, spawn_range: int | None = None,
                       delay: int | None = None, drop_set: int | None = None,
                       announce: bool = False, source_note: str = "",
                       operator: str = "mapedit", validation: dict | None = None,
                       placement_id: str | None = None) -> dict:
        idx = _json_int(monster_index, "monster_index", 1, 2_000_000_000)
        stem = _placement_map(map_stem)
        x, y = _json_int(x, "x", 0, 100_000), _json_int(y, "y", 0, 100_000)
        count = _json_int(count, "count", 1, 10_000)
        for value, name, maximum in ((spawn_range, "range", 1000),
                                     (delay, "delay", 86_400),
                                     (drop_set, "drop_set", 2_000_000_000)):
            if value is not None:
                _json_int(value, name, 0, maximum)
        if not isinstance(announce, bool):
            raise NpcEditError("announce 必须是布尔值")
        stable = f"monster:{idx}:{stem}:{x}:{y}"
        if placement_id and placement_id != stable:
            raise NpcEditError("placement_id 与 monster/map/坐标不一致")
        row = {
            "placement_id": stable, "kind": "monster-placement",
            "monster_index": idx, "map": stem, "x": x, "y": y,
            "count": count, "range": spawn_range, "delay": delay,
            "drop_set": drop_set, "announce": announce,
            "status": "user-placed", "source": "website-alignment-manual-placement",
            "source_note": str(source_note or "")[:500],
            "operator": self._operator(operator), "updated_at": self._now(),
            "validation": validation or {"in_bounds": True, "walkable": True},
        }
        return self._upsert(row)

    def undo(self, placement_id: str, operator: str = "mapedit") -> dict:
        placement_id = str(placement_id or "")
        if not placement_id or len(placement_id) > 200:
            raise NpcEditError("placement_id 无效")
        with _PLACEMENT_LOCK:
            doc = self.load()
            row = next((r for r in doc["placements"]
                        if r.get("placement_id") == placement_id), None)
            if row is None:
                raise NpcEditError("placement 不存在")
            snapshot = copy.deepcopy({k: v for k, v in row.items() if k != "history"})
            row.setdefault("history", []).append({
                "action": "undo", "timestamp": self._now(),
                "previous": snapshot, "operator": self._operator(operator)})
            row["status"] = "undone"
            row["updated_at"] = self._now()
            self._save(doc)
            return row
