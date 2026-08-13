#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""dbeditor — Zircon System.db 在线编辑器（FastAPI 后端）。

工作流（见 dbeditor_goal.md）：
  浏览器编辑 → 保存只落 JSON 工作区（Tools/dbeditor/workspace/）+ git 自动 commit
  「同步到数据库」→ sync.sh → C# DBImporter：校验 → 备份 → 双库写入 → round-trip 验证

后端职责：
  - 工作区表数据内存缓存 + CRUD（四类 P0 表 + 子表嵌套保存）
  - 类型/枚举/引用校验（meta.json + docs/database/data/enums.md）
  - 改动追踪（相对基线 diff）+ 按记录回滚
  - 同步执行（7000 端口检测 → 拒绝）
  - 图标静态伺服（docs/quest-design/data/item-icons-web/）

绝不直接读写 .db 文件——写库只经 sync.sh/importer。

MirDB 语义（Zircon LibraryCore 源码实证）：
  - [Association] ref 属性 setter 自动维护反向 DBBindingList（DBObject.OnChanged →
    CreateLink/RemoveLink）——因此 ItemInfo.Drops 这类「派生回链」以 DropInfo.Item
    为权威，编辑器/导入器一律不直接写它们；
  - 普通数组 of DBObject（如 SetInfo.Items）是真存储数据，按引用数组读写；
  - DBObject.Delete() 走 Session 级联（Aggregate 关联一并删）。
"""
from __future__ import annotations

import hashlib
import json
import shutil
import socket
import subprocess
import threading
import time
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

# ---------------------------------------------------------------- 路径

DBEDITOR = Path(__file__).resolve().parent
REPO = DBEDITOR.parent.parent                    # Mir3-Research 仓库根
WORKSPACE = DBEDITOR / "workspace"
STATIC = DBEDITOR / "static"
ENUMS_MD = REPO / "docs" / "database" / "data" / "enums.md"
ICONS_DIR = REPO / "docs" / "quest-design" / "data" / "item-icons-web"
DB_NAMES = Path("/home/tetsuya/development/zircon/GodotClient/translations/db_names.json")
ZIRCON = Path("/home/tetsuya/development/zircon")
SERVER_DB = ZIRCON / "Debug" / "ServerCore" / "Database" / "System.db"
CLIENT_DB = ZIRCON / "Debug" / "Client" / "Data" / "System.db"
SYNC_SH = DBEDITOR / "sync.sh"
SERVER_PORT = 7000

# P0 编辑范围（四类；子表嵌进父表详情页）。readonly 子表仅展示。
CATEGORIES: list[dict[str, Any]] = [
    {"key": "ItemInfo", "zh": "物品", "subs": [
        {"table": "ItemInfoStat", "zh": "属性加成", "parent_field": "Item"},
        {"table": "StoreInfo", "zh": "商店上架", "parent_field": "Item"},
        {"table": "DropInfo", "zh": "被怪物掉落", "parent_field": "Item"},
        {"table": "SetInfo", "zh": "所属套装", "parent_field": "@Items", "readonly": True},
    ]},
    {"key": "MonsterInfo", "zh": "怪物", "subs": [
        {"table": "MonsterInfoStat", "zh": "属性成长", "parent_field": "Monster"},
        {"table": "RespawnInfo", "zh": "刷新点", "parent_field": "Monster"},
        {"table": "GuardInfo", "zh": "守卫点", "parent_field": "Monster"},
        {"table": "DropInfo", "zh": "掉落列表", "parent_field": "Monster"},
    ]},
    {"key": "MagicInfo", "zh": "技能", "subs": []},
    {"key": "DropInfo", "zh": "掉落", "subs": []},
]

# 表 -> db_names.json 类目（中文行名）
TABLE_TO_ZH_CAT = {
    "ItemInfo": "items", "MagicInfo": "magics", "MonsterInfo": "monsters",
    "NPCInfo": "npcs", "MapInfo": "maps",
}

MAX_INT = 2_147_483_647
NAME_FIELDS = ("ItemName", "MonsterName", "Name", "SetName")


def _md5(path: Path) -> str:
    h = hashlib.md5()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def parse_enums_md() -> dict[str, list[str]]:
    """docs/database/data/enums.md → {枚举名: [成员名...]}"""
    import re
    out: dict[str, list[str]] = {}
    if not ENUMS_MD.exists():
        return out
    cur = None
    for line in ENUMS_MD.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^## (\S+)", line)
        if m:
            cur = m.group(1)
            out[cur] = []
            continue
        m = re.match(r"^\| (\S+) \| -?\d+ \|", line)
        if m and cur:
            out[cur].append(m.group(1))
    return {k: v for k, v in out.items() if v}


class Store:
    """全部工作区表内存缓存；所有变更 = 内存更新 + 落盘 + git commit。"""

    def __init__(self) -> None:
        self.lock = threading.RLock()
        self.meta: dict[str, Any] = {}
        self.tables: dict[str, dict[int, dict]] = {}   # 表 -> {Index: row}
        self.enums = parse_enums_md()
        self.zh_rows: dict[str, dict[str, str]] = {}   # 类目 -> {英文名: 中文名}
        self.baseline: dict[str, Any] = {}
        if DB_NAMES.exists():
            raw = json.loads(DB_NAMES.read_text(encoding="utf-8"))
            for cat, names in raw.items():
                self.zh_rows[cat] = {k: v.get("zh") or k for k, v in names.items()}
        if (WORKSPACE / "baseline.json").exists():
            self.baseline = json.loads((WORKSPACE / "baseline.json").read_text(encoding="utf-8"))

    # ---------- 载入 / 基线

    def ensure_baseline(self) -> str:
        """工作区就绪；缺失/不完整则从服务端 System.db 全量重导出。

        幂等：workspace/*.json 与 baseline.json/_baseline/ 快照齐备即复用；
        任何缺失 → 整组重导出（防半途进程死亡留下无基线的工作区）。
        """
        with self.lock:
            complete = (WORKSPACE / "baseline.json").exists() and \
                (WORKSPACE / "meta.json").exists() and \
                (WORKSPACE / "_baseline").is_dir() and \
                any(WORKSPACE.glob("ItemInfo.json"))
            if complete:
                self.load_all()
                return "exists"
            if not SERVER_DB.exists():
                raise RuntimeError(f"服务端数据库不存在: {SERVER_DB}")
            WORKSPACE.mkdir(parents=True, exist_ok=True)
            for j in WORKSPACE.glob("*.json"):           # 清掉可能的半成品
                j.unlink()
            shutil.rmtree(WORKSPACE / "_baseline", ignore_errors=True)
            tmp = Path(subprocess.run(
                ["mktemp", "-d", "/tmp/dbeditor_src.XXXXXX"],
                capture_output=True, text=True, check=True).stdout.strip())
            try:
                shutil.copy2(SERVER_DB, tmp / "System.db")
                subprocess.run(
                    ["dotnet", "build", str(REPO / "Tools" / "SystemDbProbe" / "SystemDbProbe.csproj"),
                     "-v", "q"], cwd=REPO, check=True, capture_output=True, text=True)
                r = subprocess.run(
                    ["dotnet", "run", "--project", str(REPO / "Tools" / "SystemDbProbe"),
                     "--no-build", "--", "--json", str(WORKSPACE) + "/", str(tmp) + "/"],
                    cwd=REPO, capture_output=True, text=True, check=True)
                ver = ""
                for line in r.stdout.splitlines():
                    if line.startswith("版本"):
                        ver = line.split(":", 1)[-1].split("：", 1)[-1].strip()
                n_tables = len([j for j in WORKSPACE.glob("*.json") if j.name != "baseline.json"])
                if not (WORKSPACE / "meta.json").exists() or n_tables == 0:
                    raise RuntimeError("SystemDbProbe 导出结果异常（meta 缺失或 0 表）")
                self.baseline = {
                    "version": ver,
                    "server_md5": _md5(SERVER_DB),
                    "client_md5": _md5(CLIENT_DB) if CLIENT_DB.exists() else None,
                    "exported_at": time.strftime("%Y-%m-%d %H:%M:%S"),
                }
                (WORKSPACE / "baseline.json").write_text(
                    json.dumps(self.baseline, ensure_ascii=False, indent=2), encoding="utf-8")
                bs = WORKSPACE / "_baseline"               # 基线快照（diff/回滚参照）
                bs.mkdir(exist_ok=True)
                for j in WORKSPACE.glob("*.json"):
                    if j.name != "baseline.json":
                        shutil.copy2(j, bs / j.name)
                self.git_commit(f"基线导出（版本 {ver}，{n_tables} 表）")
            finally:
                shutil.rmtree(tmp, ignore_errors=True)
            self.load_all()
            return "exported"

    def load_all(self) -> None:
        self.meta = json.loads((WORKSPACE / "meta.json").read_text(encoding="utf-8"))
        self.tables = {}
        for j in WORKSPACE.glob("*.json"):
            if j.name == "baseline.json":
                continue
            data = json.loads(j.read_text(encoding="utf-8"))
            self.tables[j.stem] = {r["Index"]: r for r in data.get("rows", [])}

    def persist(self, table: str) -> None:
        rows = sorted(self.tables[table].values(), key=lambda r: r["Index"])
        out = {"count": len(rows), "rows": rows}
        (WORKSPACE / f"{table}.json").write_text(
            json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")

    def git_commit(self, msg: str) -> bool:
        """只提交 workspace 目录（绝不碰用户未提交文件）。"""
        try:
            subprocess.run(["git", "add", "Tools/dbeditor/workspace"],
                           cwd=REPO, check=True, capture_output=True)
            r = subprocess.run(["git", "diff", "--cached", "--quiet", "--", "Tools/dbeditor/workspace"],
                               cwd=REPO, capture_output=True)
            if r.returncode == 0:
                return False
            subprocess.run(["git", "commit", "-m", f"dbeditor: {msg}"],
                           cwd=REPO, check=True, capture_output=True, text=True)
            return True
        except subprocess.CalledProcessError as e:
            raise RuntimeError(f"git 提交失败: {e.stderr or e.stdout or e}") from e

    # ---------- schema 工具

    def fields(self, table: str) -> dict:
        return (self.meta.get(table) or {}).get("fields") or {}

    def reflist_derived(self, table: str, field: str) -> bool:
        """reflist 是否为 Association 派生回链（子表带 ref 回指本表 → 运行时维护）。

        如 ItemInfo.Drops（DropInfo.Item 回指）派生；SetInfo.Items（ItemInfo 无回指）为存储权威。
        """
        fm = self.fields(table).get(field) or {}
        child = fm.get("to")
        if not child:
            return False
        return any(cf.get("type") == "ref" and cf.get("to") == table
                   for cf in self.fields(child).values())

    def next_index(self, table: str) -> int:
        return max(self.tables[table].keys(), default=0) + 1

    def baseline_rows(self, table: str) -> dict[int, dict]:
        p = WORKSPACE / "_baseline" / f"{table}.json"
        if not p.exists():
            return {}
        data = json.loads(p.read_text(encoding="utf-8"))
        return {r["Index"]: r for r in data.get("rows", [])}

    # ---------- 校验

    def validate_row(self, table: str, row: dict, skip_refs_deep: bool = False) -> None:
        """按 meta 校验：类型/枚举/引用/Stats。违规抛 ValueError。"""
        fields = self.fields(table)
        if not fields:
            raise ValueError(f"未知表 {table}")
        for key, val in row.items():
            if key in ("Index", "_Identity"):
                continue
            fm = fields.get(key)
            if fm is None:
                raise ValueError(f"字段 {key} 不在 {table} 的 schema 中")
            t = fm.get("type")
            if t == "int":
                if not isinstance(val, int) or isinstance(val, bool):
                    raise ValueError(f"{key}: 需要整数")
                if not (-MAX_INT - 1 <= val <= MAX_INT):
                    raise ValueError(f"{key}: 超出 int32 范围")
            elif t == "bool":
                if not isinstance(val, bool):
                    raise ValueError(f"{key}: 需要布尔值")
            elif t in ("float", "number"):
                if not isinstance(val, (int, float)) or isinstance(val, bool):
                    raise ValueError(f"{key}: 需要数值")
            elif t == "enum":
                members = self.enums.get(fm.get("to") or key, [])
                if members and val not in members:
                    raise ValueError(f"{key}: 枚举值 {val!r} 不合法（{fm.get('to')}）")
            elif t == "ref":
                if not isinstance(val, dict) or "Index" not in val:
                    raise ValueError(f"{key}: 引用格式错误")
                if not skip_refs_deep:
                    tgt = fm.get("to")
                    if tgt and tgt in self.tables and val["Index"] not in self.tables[tgt]:
                        raise ValueError(f"{key}: 引用的 {tgt}#{val['Index']} 不存在")
            elif t == "stats":
                if not isinstance(val, list):
                    raise ValueError(f"{key}: Stats 需为数组")
                stat_names = set(self.enums.get("Stat", []))
                for it in val:
                    if not isinstance(it, dict) or "Stat" not in it or "Value" not in it:
                        raise ValueError(f"{key}: Stats 项需含 Stat/Value")
                    if stat_names and it["Stat"] not in stat_names:
                        raise ValueError(f"{key}: 未知属性 {it['Stat']!r}")
                    if not isinstance(it["Value"], int) or isinstance(it["Value"], bool):
                        raise ValueError(f"{key}: Stats 值需为整数")
            elif t == "reflist":
                continue    # 派生回链不收提交值；存储型数组仅经详情页白名单路径写
            elif t == "string":
                if val is not None and not isinstance(val, str):
                    raise ValueError(f"{key}: 需要字符串")
            # 其余类型（datetime/bytes/points 等）编辑器不开放，透传

    def recompute_identity(self, table: str, row: dict) -> None:
        ident_fields = (self.meta.get(table) or {}).get("identity") or []
        parts = []
        for f in ident_fields:
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

    # ---------- diff 引擎

    def diff(self) -> dict[str, Any]:
        """工作区 vs 基线：按表/记录/字段。"""
        result: dict[str, Any] = {"tables": {}, "summary": {"added": 0, "modified": 0, "deleted": 0}}
        for table in sorted(self.tables):
            base = self.baseline_rows(table)
            cur = self.tables[table]
            entries = []
            for idx in sorted(set(base) | set(cur)):
                if idx not in base:
                    entries.append({"op": "added", "index": idx, "fields": None})
                elif idx not in cur:
                    entries.append({"op": "deleted", "index": idx, "fields": None})
                else:
                    changed = {}
                    for k in sorted(set(base[idx]) | set(cur[idx])):
                        if base[idx].get(k) != cur[idx].get(k):
                            changed[k] = {"old": base[idx].get(k), "new": cur[idx].get(k)}
                    if changed:
                        entries.append({"op": "modified", "index": idx, "fields": changed})
            if entries:
                result["tables"][table] = entries
                for e in entries:
                    result["summary"][e["op"]] += 1
        return result


STORE = Store()
APP = FastAPI(title="dbeditor", docs_url=None, redoc_url=None)


# ---------------------------------------------------------------- 模型


class RowSave(BaseModel):
    row: dict[str, Any]
    subs: dict[str, list[dict]] | None = None      # {子表: 该父记录的完整行列表}


class BulkReq(BaseModel):
    indexes: list[int]
    patch: dict[str, Any]
    dry: bool = False


class RollbackReq(BaseModel):
    table: str
    index: int


def _zh(table: str, name: str | None) -> str:
    if not name:
        return ""
    cat = TABLE_TO_ZH_CAT.get(table)
    return (STORE.zh_rows.get(cat) or {}).get(name, "")


def _name_of(table: str, row: dict) -> str:
    for k in NAME_FIELDS:
        if row.get(k):
            return str(row[k])
    v = row.get("_Identity")
    return str(v) if v else f"#{row.get('Index')}"


def _label(table: str, row: dict) -> str:
    name = _name_of(table, row)
    z = _zh(table, name)
    return name + (f"（{z}）" if z and z != name else "")


def _find_ref_rows(parent_table: str, parent_index: int, sub_table: str, parent_field: str) -> list[int]:
    """子表中 parent_field 指向 parent_index 的行 Index 列表。"""
    trows = STORE.tables.get(sub_table, {})
    return sorted(i for i, r in trows.items()
                  if isinstance(r.get(parent_field), dict)
                  and r[parent_field].get("Index") == parent_index)


# ---------------------------------------------------------------- API


@APP.get("/api/status")
def status() -> dict:
    server_running = False
    try:
        with socket.create_connection(("127.0.0.1", SERVER_PORT), timeout=0.4):
            server_running = True
    except OSError:
        pass
    return {
        "baseline": STORE.baseline,
        "tables": {t: len(rows) for t, rows in sorted(STORE.tables.items())},
        "server_running": server_running,
        "server_db_md5": _md5(SERVER_DB) if SERVER_DB.exists() else None,
        "client_db_md5": _md5(CLIENT_DB) if CLIENT_DB.exists() else None,
        "icons_count": len(list(ICONS_DIR.glob("*.png"))) if ICONS_DIR.exists() else 0,
    }


@APP.get("/api/categories")
def categories() -> list[dict]:
    return [{
        "key": c["key"], "zh": c["zh"],
        "count": len(STORE.tables.get(c["key"], {})),
        "subs": c["subs"],
    } for c in CATEGORIES]


@APP.get("/api/meta")
def meta(table: str | None = None) -> dict:
    if table:
        if table not in STORE.meta:
            raise HTTPException(404, f"未知表 {table}")
        return {"table": table, **STORE.meta[table], "enums": STORE.enums}
    return {"meta": STORE.meta, "enums": STORE.enums,
            "tables": sorted(STORE.tables.keys())}


@APP.get("/api/options/{table}")
def options(table: str) -> list[dict]:
    rows = STORE.tables.get(table)
    if rows is None:
        raise HTTPException(404, f"未知表 {table}")
    out = []
    for idx in sorted(rows):
        r = rows[idx]
        name = _name_of(table, r)
        out.append({"Index": idx, "Name": name, "zh": _zh(table, name)})
    return out


@APP.get("/api/table/{table}")
def table_rows(table: str, page: int = 1, per: int = 50, q: str = "",
               sort: str = "Index", dir: str = "asc") -> dict:
    rows = STORE.tables.get(table)
    if rows is None:
        raise HTTPException(404, f"未知表 {table}")
    items = list(rows.values())
    if q:
        ql = q.lower()

        def _hit(r: dict) -> bool:
            if ql in str(r.get("Index")).lower():
                return True
            if ql in str(r.get("_Identity", "")).lower():
                return True
            for k in NAME_FIELDS:
                if r.get(k) and ql in str(r[k]).lower():
                    return True
            z = _zh(table, _name_of(table, r))
            return bool(z) and ql in z.lower()

        items = [r for r in items if _hit(r)]
    if sort and sort != "Index":
        items.sort(key=lambda r: (r.get(sort) is None, str(r.get(sort))))
    else:
        items.sort(key=lambda r: r["Index"])
    if dir == "desc":
        items.reverse()
    total = len(items)
    start = (page - 1) * per
    out = []
    for r in items[start:start + per]:
        rr = dict(r)
        rr["__zh"] = _zh(table, _name_of(table, r))   # 中文名（db_names.json）
        if table == "ItemInfo":
            cur = _currency_image(table, r["Index"])  # 货币物品真实图标帧（同步注入，无闪烁）
            if cur is not None:
                rr["__frame"] = cur
        out.append(rr)
    return {"count": total, "page": page, "per": per,
            "rows": out}


@APP.get("/api/row/{table}/{index}")
def row_detail(table: str, index: int) -> dict:
    rows = STORE.tables.get(table)
    if rows is None or index not in rows:
        raise HTTPException(404, f"{table}#{index} 不存在")
    row = rows[index]
    subs: dict[str, Any] = {}
    cat = next((c for c in CATEGORIES if c["key"] == table), None)
    if cat:
        for s in cat["subs"]:
            t, pf = s["table"], s["parent_field"]
            if pf.startswith("@"):
                # 反向：SetInfo.Items 数组含本 Index → 只读展示
                arr_field = pf[1:]
                val = [{"Index": r["Index"], "Name": _name_of(t, r)}
                       for r in STORE.tables.get(t, {}).values()
                       if any(isinstance(it, dict) and it.get("Index") == index
                              for it in r.get(arr_field) or [])]
                subs[t] = {"readonly": True, "rows": sorted(val, key=lambda x: x["Index"])}
            else:
                matched = sorted(
                    (STORE.tables.get(t, {}).get(i) for i in _find_ref_rows(table, index, t, pf)),
                    key=lambda r: r["Index"])
                subs[t] = {"readonly": bool(s.get("readonly")), "parent_field": pf,
                           "rows": matched}
    row_out = dict(row)
    row_out["__zh"] = _zh(table, _name_of(table, row))   # 详情页也带中文名
    if table == "ItemInfo":
        cur = _currency_image(table, index)               # 货币物品真实图标帧
        if cur is not None:
            row_out["__frame"] = cur
    return {"row": row_out, "subs": subs, "meta": STORE.meta.get(table)}


def _apply_subs(parent_table: str, parent_index: int, subs: dict[str, list[dict]]) -> str:
    """整组替换父记录的子表行：payload 缺席的行删除、带 Index 的更新、无 Index 的新增。"""
    cat = next((c for c in CATEGORIES if c["key"] == parent_table), None)
    if not cat:
        return ""
    notes = []
    for s in cat["subs"]:
        if s.get("readonly"):
            continue
        t, pf = s["table"], s["parent_field"]
        if t not in subs or pf.startswith("@"):
            continue
        incoming = subs[t]
        trows = STORE.tables[t]
        have = set(_find_ref_rows(parent_table, parent_index, t, pf))
        keep: set[int] = set()
        parent = STORE.tables[parent_table].get(parent_index, {})
        for r in incoming:
            STORE.validate_row(t, r)
            parent_ref = {"Index": parent_index}
            pn = parent.get("ItemName") or parent.get("MonsterName") or parent.get("Name")
            if pn:
                parent_ref["Name"] = pn
            r[pf] = parent_ref
            idx = r.get("Index")
            if idx in trows:
                trows[idx].clear()
                trows[idx].update(r)
            else:
                idx = STORE.next_index(t)
                r["Index"] = idx
                trows[idx] = r
            keep.add(idx)
            STORE.recompute_identity(t, trows[idx])
        for idx in have - keep:
            del trows[idx]
        if have != keep or incoming:
            STORE.persist(t)
            notes.append(f"{t}:{len(incoming)}行")
    return "、".join(notes)


@APP.put("/api/row/{table}/{index}")
def row_save(table: str, index: int, body: RowSave) -> dict:
    with STORE.lock:
        rows = STORE.tables.get(table)
        if rows is None:
            raise HTTPException(404, f"未知表 {table}")
        if index not in rows:
            raise HTTPException(404, f"{table}#{index} 不存在")
        # 合并语义：提交中**缺席**的键 = 未编辑，保留工作区现值（防部分提交清字段）；
        # 显式提交 null/None = 有意清空。前端全量提交时行为不变。
        row = {**rows[index], **body.row}
        row["Index"] = index
        # 派生回链（reflist）字段以工作区当前值为准，不接受提交
        for k, fm in STORE.fields(table).items():
            if fm.get("type") == "reflist" and STORE.reflist_derived(table, k) and k in row:
                row[k] = rows[index].get(k)
        try:
            STORE.validate_row(table, row)
        except ValueError as e:
            raise HTTPException(400, str(e))
        STORE.recompute_identity(table, row)
        rows[index] = row
        STORE.persist(table)
        sub_note = _apply_subs(table, index, body.subs or {})
        STORE.git_commit(f"修改 {table}#{index}（{_label(table, row)}）"
                         + (f"；子表 {sub_note}" if sub_note else ""))
        return {"ok": True, "row": row}


@APP.post("/api/row/{table}")
def row_create(table: str, body: RowSave) -> dict:
    with STORE.lock:
        rows = STORE.tables.get(table)
        if rows is None:
            raise HTTPException(404, f"未知表 {table}")
        row = dict(body.row)
        for k in list(row):
            fm = STORE.fields(table).get(k) or {}
            if fm.get("type") == "reflist":
                row.pop(k)         # 新行不带列表（派生回链运行时生成；数组另行编辑）
        try:
            STORE.validate_row(table, row, skip_refs_deep=True)
        except ValueError as e:
            raise HTTPException(400, str(e))
        ni = STORE.next_index(table)
        row["Index"] = ni
        STORE.recompute_identity(table, row)
        rows[ni] = row
        STORE.persist(table)
        sub_note = _apply_subs(table, ni, body.subs or {})
        STORE.git_commit(f"新增 {table}#{ni}（{_label(table, row)}）"
                         + (f"；子表 {sub_note}" if sub_note else ""))
        return {"ok": True, "row": row}


@APP.post("/api/row/{table}/{index}/duplicate")
def row_duplicate(table: str, index: int) -> dict:
    import copy
    with STORE.lock:
        rows = STORE.tables.get(table)
        if rows is None or index not in rows:
            raise HTTPException(404, f"{table}#{index} 不存在")
        row = copy.deepcopy(rows[index])
        ni = STORE.next_index(table)
        row["Index"] = ni
        # reflist 一律不复制：派生回链由子表 ref 在导入时重建；存储型数组清空待编辑
        for k, fm in STORE.fields(table).items():
            if fm.get("type") == "reflist":
                row.pop(k, None)
        for k in NAME_FIELDS:                        # 名称加后缀便于识别
            if k in row and isinstance(row[k], str):
                row[k] = row[k] + "-副本"
        STORE.recompute_identity(table, row)
        rows[ni] = row
        STORE.persist(table)
        # 子表行一并复制（导入时子表 ref 会自动回链父记录）
        cat = next((c for c in CATEGORIES if c["key"] == table), None)
        sub_note = ""
        if cat:
            for s in cat["subs"]:
                t, pf = s["table"], s["parent_field"]
                if s.get("readonly") or pf.startswith("@") or t not in STORE.tables:
                    continue
                src = []
                for i in _find_ref_rows(table, index, t, pf):
                    c = copy.deepcopy(STORE.tables[t][i])
                    c.pop("Index", None)
                    # 派生回链同样剔除
                    for k2, fm2 in STORE.fields(t).items():
                        if fm2.get("type") == "reflist":
                            c.pop(k2, None)
                    src.append(c)
                if src:
                    sub_note = _apply_subs(table, ni, {t: src}) or sub_note
        STORE.git_commit(f"复制 {table}#{index} → #{ni}（{_label(table, row)}）")
        return {"ok": True, "row": row}




@APP.delete("/api/row/{table}/{index}")
def row_delete(table: str, index: int) -> dict:
    with STORE.lock:
        rows = STORE.tables.get(table)
        if rows is None or index not in rows:
            raise HTTPException(404, f"{table}#{index} 不存在")
        # 1) 先算级联子行（只读不写）与「子表→父字段」归属对
        cat = next((c for c in CATEGORIES if c["key"] == table), None)
        owned: dict[str, set[int]] = {}
        owned_pairs: set[tuple[str, str]] = set()
        if cat:
            for s in cat["subs"]:
                t, pf = s["table"], s["parent_field"]
                if s.get("readonly") or pf.startswith("@") or t not in STORE.tables:
                    continue
                owned[t] = set(_find_ref_rows(table, index, t, pf))
                owned_pairs.add((t, pf))
        # 2) 悬空引用检查（全有或全无：任何拒绝都不改任何数据）。
        #    子表经归属字段指回本记录的行 = 即将级联删除的属产行，不算悬空。
        danglers = []
        for t, trows in STORE.tables.items():
            for k, fm in STORE.fields(t).items():
                ft = fm.get("type")
                if ft == "ref" and fm.get("to") == table:
                    for r in trows.values():
                        if (t, k) in owned_pairs and r["Index"] in owned.get(t, set()):
                            continue    # 属产行，随父删除
                        v = r.get(k)
                        if isinstance(v, dict) and v.get("Index") == index:
                            danglers.append(f"{t}#{r['Index']}.{k}")
                elif ft == "reflist" and fm.get("to") == table and \
                        not STORE.reflist_derived(t, k):
                    for r in trows.values():
                        for it in r.get(k) or []:
                            if isinstance(it, dict) and it.get("Index") == index:
                                danglers.append(f"{t}#{r['Index']}.{k}[]")
        if danglers:
            raise HTTPException(400, f"存在 {len(danglers)} 处悬空引用，先处理: "
                                     + "、".join(danglers[:10]))
        # 3) 提交变更：级联删子行 → 删本行 → 落盘 → 一次 git commit
        label = _label(table, rows[index])
        for t, idxs in owned.items():
            for i in idxs:
                del STORE.tables[t][i]
            if idxs:
                STORE.persist(t)
        del rows[index]
        STORE.persist(table)
        STORE.git_commit(f"删除 {table}#{index}（{label}）")
        return {"ok": True}


@APP.post("/api/bulk/{table}")
def bulk(table: str, body: BulkReq) -> dict:
    with STORE.lock:
        rows = STORE.tables.get(table)
        if rows is None:
            raise HTTPException(404, f"未知表 {table}")
        fields = STORE.fields(table)
        for k in body.patch:
            if k in ("Index", "_Identity"):
                raise HTTPException(400, f"不允许批量修改 {k}")
            fm = fields.get(k)
            if fm is None:
                raise HTTPException(400, f"字段 {k} 不在 schema 中")
            if fm.get("type") in ("reflist", "ref", "stats"):
                raise HTTPException(400, f"字段 {k} 类型 {fm.get('type')} 不支持批量修改")
        test = dict(next(iter(rows.values())))
        test.update(body.patch)
        try:
            STORE.validate_row(table, test)
        except ValueError as e:
            raise HTTPException(400, f"补丁值不合法: {e}")
        if body.dry:
            return {"ok": True, "dry": True, "count": len(body.indexes)}
        hit = 0
        for idx in body.indexes:
            if idx in rows:
                rows[idx].update(body.patch)
                STORE.recompute_identity(table, rows[idx])
                hit += 1
        STORE.persist(table)
        STORE.git_commit(f"批量修改 {table} {hit} 行："
                         + ", ".join(f"{k}={v}" for k, v in body.patch.items()))
        return {"ok": True, "count": hit}


@APP.get("/api/changes")
def changes() -> dict:
    with STORE.lock:
        return STORE.diff()


@APP.post("/api/rollback")
def rollback(body: RollbackReq) -> dict:
    with STORE.lock:
        rows = STORE.tables.get(body.table)
        base = STORE.baseline_rows(body.table)
        if rows is None:
            raise HTTPException(404, f"未知表 {body.table}")
        if body.index not in base and body.index not in rows:
            raise HTTPException(404, f"{body.table}#{body.index} 无基线记录")
        if body.index in base:
            rows[body.index] = json.loads(json.dumps(base[body.index]))
        else:
            del rows[body.index]
        STORE.persist(body.table)
        STORE.git_commit(f"回滚 {body.table}#{body.index} 至基线")
        return {"ok": True}


@APP.post("/api/sync")
def sync_execute() -> dict:
    if not SYNC_SH.exists():
        raise HTTPException(500, f"缺少 {SYNC_SH}")
    try:
        with socket.create_connection(("127.0.0.1", SERVER_PORT), timeout=0.4):
            return JSONResponse(status_code=409, content={
                "ok": False, "error": "服务端正在运行（端口 7000 有监听）。请先停止服务端再同步。"})
    except OSError:
        pass
    diff = STORE.diff()
    if diff["summary"]["added"] + diff["summary"]["modified"] + diff["summary"]["deleted"] == 0:
        return {"ok": True, "skipped": "工作区无改动"}
    r = subprocess.run(["bash", str(SYNC_SH)], cwd=REPO, capture_output=True,
                       text=True, timeout=900)
    report = ""
    rp = WORKSPACE / "sync_report.txt"
    if rp.exists():
        report = rp.read_text(encoding="utf-8")
    if r.returncode == 0:
        # 同步成功后基线已被 sync.sh 重置 → 重载内存态
        if (WORKSPACE / "baseline.json").exists():
            STORE.baseline = json.loads(
                (WORKSPACE / "baseline.json").read_text(encoding="utf-8"))
        STORE.load_all()
    return {"ok": r.returncode == 0, "code": r.returncode,
            "stdout": r.stdout[-8000:], "stderr": r.stderr[-4000:], "report": report}


# ---------------------------------------------------------------- 静态

APP.mount("/static", StaticFiles(directory=STATIC), name="static")
APP.mount("/icons", StaticFiles(directory=ICONS_DIR), name="icons")

# ---------------------------------------------------------------- 实时 ZL 图标解码
# 缓存目录的 PNG 偏蓝（dbeditor goal 生成时未做 BGRA→RGBA 交换）且帧不全；
# 这里改用 Tools/common/zlsdk.py（wilviewer 同款）实时解 Storeitems.Zl / MonImg.Zl，
# 解码结果落盘缓存 item-icons-live/，保证颜色正确。
_LIVE_ICONS = DBEDITOR / "item-icons-live"
_LIVE_ICONS.mkdir(exist_ok=True)
_zl_libs: dict[str, Any] = {}
_zl_lock = threading.Lock()


def _get_zl_lib(lib_file: str):
    """lib_file: 'Storeitems.Zl' / 'MonImg.Zl' —— 按 wilviewer 方式加载 zlsdk.ZlLibrary。"""
    import sys as _sys
    if str(REPO / "Tools" / "common") not in _sys.path:
        _sys.path.insert(0, str(REPO / "Tools" / "common"))
    with _zl_lock:
        if lib_file not in _zl_libs:
            import zlsdk
            path = ZIRCON / "Debug" / "Client" / "Data" / lib_file
            _zl_libs[lib_file] = zlsdk.ZlLibrary(str(path))
        return _zl_libs[lib_file]


def _currency_image(table: str, index: int) -> int | None:
    """货币物品的真实图标（客户端 IsCurrencyItem→CurrencyImage 逻辑）：
    CurrencyInfo.DropItem == 该物品 → 取 CurrencyInfoImage 中 Amount 最大的档位 Image。
    非货币返回 None。"""
    try:
        currencies = STORE.tables.get("CurrencyInfo", {})
        images = STORE.tables.get("CurrencyInfoImage", {})
        for cur in currencies.values():
            drop = cur.get("DropItem") or {}
            if isinstance(drop, dict) and drop.get("Index") == index:
                best = max(
                    (img for img in images.values()
                     if (img.get("Currency") or {}).get("Index") == cur.get("Index")),
                    key=lambda x: x.get("Amount", 0), default=None)
                if best is not None and isinstance(best.get("Image"), int):
                    return best["Image"]
    except Exception:
        pass
    return None


@APP.get("/api/icon/{table}/{index}")
def api_icon(table: str, index: int) -> dict:
    """返回某行的真实图标帧号（货币物品走 CurrencyInfoImage 换算）。
    前端拿帧号再请求 /zl/{lib}/{frame}.png。"""
    rows = STORE.tables.get(table, {})
    row = rows.get(index)
    if row is None or not isinstance(row.get("Image"), int):
        raise HTTPException(404, "no image")
    if table == "ItemInfo":
        cur = _currency_image(table, index)
        if cur is not None:
            return {"frame": cur, "lib": "Storeitems"}
    return {"frame": row["Image"], "lib": "Storeitems" if table == "ItemInfo" else "MonImg"}


@APP.get("/zl/{lib}/{frame:int}.png")
def zl_icon(lib: str, frame: int):
    """实时解码 ZL 库指定帧。

    物品图标必须用 StoreItem.Zl —— 客户端 DXItemCell.ItemLibraryFile 默认就是
    StoreItem（2370 帧），Inventory.Zl 是另一套帧序（直接当物品图标=张冠李戴）。
    怪物用 MonImg.Zl。颜色通道由 zlsdk 正确处理（BGRA→RGBA）。
    """
    cache = _LIVE_ICONS / f"{lib}_{frame}.png"
    if cache.exists():
        return FileResponse(cache, media_type="image/png")
    try:
        lib_obj = _get_zl_lib(lib if lib.endswith(".Zl") else lib + ".Zl")
        img = lib_obj.decode(frame)
    except Exception as exc:  # 库缺失/帧越界 → 1x1 透明
        raise HTTPException(404, f"decode failed: {exc}") from exc
    if img is None:
        raise HTTPException(404, "no frame")
    img.save(cache, format="PNG")
    return FileResponse(cache, media_type="image/png")


@APP.get("/")
def index() -> FileResponse:
    return FileResponse(STATIC / "index.html")


def main() -> None:
    import fcntl
    import uvicorn
    # 单实例守卫：防两个进程并发导出/写工作区
    lock_file = open(WORKSPACE.with_suffix(".lock"), "w")
    try:
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        raise SystemExit("[!] 已有 dbeditor 实例在运行（workspace.lock 被占用），退出。")
    state = STORE.ensure_baseline()
    print(f"[*] 工作区: {WORKSPACE}（{state}）")
    print(f"[*] 基线: {STORE.baseline}")
    print("[*] http://127.0.0.1:8810/")
    uvicorn.run(APP, host="0.0.0.0", port=8810, log_level="warning")


if __name__ == "__main__":
    main()
