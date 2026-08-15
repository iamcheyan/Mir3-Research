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

# ---------------------------------------------------------------- 怪物图库映射
# GodotClient 渲染怪物的真实方案（只读参考，勿改 zircon）：
#   ObjectRenderer.CreateMonster → MonsterLookup.Map[mi.Image] → (LibraryFile, BodyShape)
#   帧号 = Shape*1000 + 动作Start + FrameIndex + 方向*10（FrameSet.DefaultMonster，
#   全部怪物统一：Standing Start=0 Count=4、Walking 80/6、Combat1 160/6、Die 320/10）。
#   方向 MirDirection: 0=Up(背面)…4=Down(正面)。封面帧用 dir4 站立第 0 帧 = Shape*1000+40。
# MonImg.Zl（2150 帧）是旧版图鉴页用的整合库，帧序与 MonsterInfo.Image 无对应关系，
# 之前"怪物接 MonImg"的做法是错的 —— GodotClient 实际按 Mon-N.Zl 分库渲染。
# MonsterLookup.cs 由 Client/Models/MonsterObject.cs UpdateLibraries() 自动提取，
# 333 条（含 EI 新怪 600+）；运行时从 zircon 源码正则解析，避免手工转录 333 行。
_MONSTER_LOOKUP_SRC = ZIRCON / "GodotClient" / "Formats" / "MonsterLookup.cs"
_monster_lookup: dict[str, tuple[str, int]] | None = None   # MonsterImage名 -> (Mon-N, Shape)


def _load_monster_lookup() -> dict[str, tuple[str, int]]:
    global _monster_lookup
    if _monster_lookup is None:
        import re
        out: dict[str, tuple[str, int]] = {}
        try:
            src = _MONSTER_LOOKUP_SRC.read_text(encoding="utf-8")
            for m in re.finditer(
                    r"\{\s*MonsterImage\.(\w+),\s*\(LibraryFile\.(\w+),\s*(\d+)\)\s*\}", src):
                lib, shape = m.group(2), int(m.group(3))
                # LibraryFile.Mon_3 → 文件名 Mon-3（Libraries.cs: Data\Mon-3.Zl）
                fn = lib.replace("Mon_", "Mon-") if lib.startswith("Mon_") else lib
                out[m.group(1)] = (fn, shape)
        except Exception:
            pass
        _monster_lookup = out
    return _monster_lookup


# FrameSet.DefaultMonster（LibraryCore/FrameSet.cs 136 行起）—— GodotClient 所有怪物共用
_MONSTER_FRAMES = {
    # 动作: (Start, Count) —— 帧间距 = 方向偏移 10
    "stand": (0, 4), "walk": (80, 6), "attack": (160, 6),
    "struck": (240, 2), "die": (320, 10),
}


def _monster_icon(table: str, row: dict) -> dict | None:
    """怪物封面图标：{lib, frame}。Image 是 MonsterImage 枚举名 → MonsterLookup
    → (Mon-N.Zl, Shape)。封面 = 站立 dir4（正面）第 0 帧 = Shape*1000 + 40。
    无映射（如 None/SummonPuppet）返回 None。"""
    if table != "MonsterInfo":
        return None
    image = row.get("Image")
    if not isinstance(image, str):
        return None
    ent = _load_monster_lookup().get(image)
    if not ent:
        return None
    lib, shape = ent
    return {"lib": lib, "frame": shape * 1000 + 40}


def _monster_actions(table: str, row: dict) -> list[dict] | None:
    """详情页动作预览帧序列：站立 8 方向 + 行走(dir4) 6 帧 + 攻击(dir4) 6 帧 + 死亡 10 帧。"""
    if table != "MonsterInfo":
        return None
    image = row.get("Image")
    if not isinstance(image, str):
        return None
    ent = _load_monster_lookup().get(image)
    if not ent:
        return None
    lib, shape = ent
    base = shape * 1000
    seq: list[dict] = []
    for d in range(8):     # 站立 8 方向（0=背面 … 4=正面）
        seq.append({"lib": lib, "frame": base + _MONSTER_FRAMES["stand"][0] + d * 10,
                    "label": f"站立·{'背面' if d == 0 else ('正面' if d == 4 else f'方向{d}')}"})
    for i in range(_MONSTER_FRAMES["walk"][1]):     # 行走序列（正面 dir4）
        seq.append({"lib": lib, "frame": base + _MONSTER_FRAMES["walk"][0] + 40 + i,
                    "label": f"行走{i + 1}"})
    for i in range(_MONSTER_FRAMES["attack"][1]):   # 攻击序列（正面 dir4）
        seq.append({"lib": lib, "frame": base + _MONSTER_FRAMES["attack"][0] + 40 + i,
                    "label": f"攻击{i + 1}"})
    for i in range(_MONSTER_FRAMES["die"][1]):      # 死亡序列
        seq.append({"lib": lib, "frame": base + _MONSTER_FRAMES["die"][0] + i,
                    "label": f"死亡{i + 1}"})
    return seq

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

# [shared] E5 Light Lab: webclient(:8822) 环境实验室面板需要跨源调用写回管线
# (GET /api/row + PUT /api/row + POST /api/sync)。只放行本机 webclient 两个来源。
from fastapi.middleware.cors import CORSMiddleware  # noqa: E402

APP.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(127\.0\.0\.1|localhost|\[::1\]):8822$",
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["*"],
)


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


def _level_bucket(value: Any) -> str | None:
    """把怪物等级映射到稳定的筛选标签。"""
    if not isinstance(value, (int, float)) or isinstance(value, bool):
        return None
    if value <= 10:
        return "0-10"
    if value <= 25:
        return "11-25"
    if value <= 50:
        return "26-50"
    if value <= 100:
        return "51-100"
    return "100+"


@APP.get("/api/categories")
def categories() -> list[dict]:
    """发现实用的分类筛选轴，并按频次返回值。

    枚举/布尔轴必须至少有两个值；枚举唯一值达到行数一半时跳过。
    int/string 轴通常要求不超过 30 个值，但允许高基数轴在前 20 个值
    覆盖至少 60% 行时出现（用于 MonsterInfo.AI）。高基数轴只展示前 20 个值。
    """
    SKIP = {"Index", "Image", "Icon", "FaceImage", "Shape", "Level"}
    out = []
    for c in CATEGORIES:
        table = c["key"]
        entry = {"key": table, "zh": c["zh"],
                 "count": len(STORE.tables.get(table, {})), "subs": c["subs"]}
        trows = list(STORE.tables.get(table, {}).values())
        tmeta = STORE.meta.get(table, {}).get("fields", {})
        facets = []
        if trows:
            # MonsterInfo.Level 是特例：连续值本身不显示，但等级段作为实用轴显示。
            if table == "MonsterInfo":
                bucket_counts: dict[str, int] = {}
                for r in trows:
                    b = _level_bucket(r.get("Level"))
                    if b:
                        bucket_counts[b] = bucket_counts.get(b, 0) + 1
                if len(bucket_counts) >= 2:
                    order = {"0-10": 0, "11-25": 1, "26-50": 2, "51-100": 3, "100+": 4}
                    facets.append({"field": "LevelBucket", "zh": "等级段",
                                   "values": sorted(bucket_counts.items(), key=lambda x: order[x[0]])})
            for field, fdef in tmeta.items():
                if field in SKIP or field.startswith("_"):
                    continue
                ftype = str(fdef.get("type", ""))
                kind = fdef.get("kind", "")
                if kind in ("ref", "reflist", "stats") or ftype not in ("enum", "bool", "int", "string"):
                    continue
                is_enum, is_bool = ftype == "enum", ftype == "bool"
                counts: dict[str, int] = {}
                for r in trows:
                    v = r.get(field)
                    if v is None:
                        continue
                    if isinstance(v, bool): key = "是" if v else "否"
                    elif isinstance(v, (int, float)) and not is_enum: key = str(v)
                    elif isinstance(v, str): key = v
                    else: continue
                    counts[key] = counts.get(key, 0) + 1
                nvalues = len(counts)
                if nvalues < 2:
                    continue
                ranked = sorted(counts.items(), key=lambda x: -x[1])
                if is_enum:
                    if nvalues >= len(trows) * 0.5:
                        continue
                    values = ranked
                elif is_bool:
                    values = ranked
                else:
                    coverage = sum(n for _, n in ranked[:20]) / len(trows)
                    if nvalues > 30 and coverage < 0.60:
                        continue
                    values = ranked[:20] if nvalues > 30 else ranked
                facets.append({"field": field, "zh": fdef.get("zh") or field,
                               "values": values})
        entry["facets"] = facets
        out.append(entry)
    return out


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
               sort: str = "Index", dir: str = "asc", facet: str = "") -> dict:
    rows = STORE.tables.get(table)
    if rows is None:
        raise HTTPException(404, f"未知表 {table}")
    items = list(rows.values())
    if facet:
        # facet 格式: "字段=值" 或多选 "字段=值1,值2"（多轴用 ; 分隔：Type=Book;Rarity=Elite）
        for part in facet.split(";"):
            if "=" not in part:
                continue
            f, vals = part.split("=", 1)
            allowed = set(vals.split(","))
            def _facet_v(v):
                if isinstance(v, bool):
                    return "是" if v else "否"
                return str(v)
            def _matches(r):
                if f == "LevelBucket":
                    return _level_bucket(r.get("Level")) in allowed
                return _facet_v(r.get(f)) in allowed
            items = [r for r in items if _matches(r)]
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
        elif table == "MonsterInfo":
            icon = _monster_icon(table, r)            # 怪物封面（Mon-N.Zl 站立正面帧）
            if icon:
                rr["__frame"], rr["__lib"] = icon["frame"], icon["lib"]
        elif table == "MagicInfo":
            if isinstance(r.get("Icon"), int):        # 技能图标 = MIcon.Zl[MagicInfo.Icon]
                rr["__frame"], rr["__lib"] = r["Icon"], "MIcon"
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
    elif table == "MonsterInfo":
        icon = _monster_icon(table, row)                  # 封面帧 + 动作预览序列
        if icon:
            row_out["__frame"], row_out["__lib"] = icon["frame"], icon["lib"]
        actions = _monster_actions(table, row)
        if actions:
            row_out["__actions"] = actions
    elif table == "MagicInfo":
        if isinstance(row.get("Icon"), int):
            row_out["__frame"], row_out["__lib"] = row["Icon"], "MIcon"
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


# [shared] E2 NPC 摆放（mapedit / NpcMover）直接落 workspace JSON 后调用：
# 让内存态重新读盘，避免 dbeditor 下一次 persist 用旧内存覆写外部编辑。
@APP.post("/api/reload")
def reload_workspace() -> dict:
    with STORE.lock:
        STORE.load_all()
        if (WORKSPACE / "baseline.json").exists():
            STORE.baseline = json.loads(
                (WORKSPACE / "baseline.json").read_text(encoding="utf-8"))
        return {"ok": True, "tables": len(STORE.tables)}


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


# ---------------------------------------------------------------- 任务批量落地


class QuestApplyReq(BaseModel):
    """任务落地载荷：一批 QuestInfo + 子表（requirements/tasks/rewards）。

    语义（zdocs/quest-system.md + PlayerObject.QuestCanAccept 实证）：
      - Requirements 全部 AND；
      - Rewards 只发物品（引擎无独立金币/经验奖励，经验经伪物品发放）；
      - Tasks 仅 KillMonster / GainItem / VisitRegion 三型；
      - 缺失 HaveNotCompleted-self 时自动补（引擎惯例，防重复接取）。
    """
    quests: list[dict[str, Any]]
    dry_run: bool = False


def _qa_check_ref(value: Any, table: str, path: str, errors: list[str],
                  name_field: str = "Name") -> dict | None:
    """校验 {Index: n} 引用存在；返回规范化引用（带目标行名）。"""
    if not isinstance(value, dict) or not isinstance(value.get("Index"), int):
        errors.append(f"{path}: 需要 {{\"Index\": <int>}}")
        return None
    tgt = STORE.tables.get(table, {})
    if value["Index"] not in tgt:
        errors.append(f"{path}: 引用的 {table}#{value['Index']} 不存在")
        return None
    row = tgt[value["Index"]]
    name = row.get("_Identity")
    if not name:
        for k in ("ItemName", "MonsterName", "NPCName", "QuestName", "FileName"):
            if row.get(k):
                name = row[k]
                break
    return {"Index": value["Index"], "Name": name}


def _qa_int(payload: dict[str, Any], key: str, default: int, lo: int, hi: int,
            path: str, errors: list[str]) -> int:
    v = payload.get(key, default)
    if not isinstance(v, int) or isinstance(v, bool) or not (lo <= v <= hi):
        errors.append(f"{path}.{key}: 需要整数 [{lo},{hi}]")
        return default
    return v


def _qa_enum(payload: dict[str, Any], key: str, enum: str, default: str,
             path: str, errors: list[str]) -> str:
    v = payload.get(key, default)
    if v not in STORE.enums.get(enum, []):
        errors.append(f"{path}.{key}: {v!r} 不在枚举 {enum} 中")
        return default
    return v


def _qa_text(payload: dict[str, Any], key: str, path: str, errors: list[str],
             required: bool = False) -> str | None:
    v = payload.get(key)
    if v is None:
        if required:
            errors.append(f"{path}.{key}: 缺失（必填）")
        return None
    if not isinstance(v, str):
        errors.append(f"{path}.{key}: 需要字符串")
        return None
    return v


@APP.post("/api/quest_apply")
def quest_apply(body: QuestApplyReq) -> dict:
    """校验并落地一批任务到工作区（写 JSON + git commit；同步仍走 /api/sync）。

    校验全部通过才写（无部分写入）：前置任务存在 / 物品存在 / 区域存在 /
    怪物与 NPC 存在 / 任务名不冲突 / 任务类型与枚举合法。
    """
    with STORE.lock:
        errors: list[str] = []
        quests_out: list[dict[str, Any]] = []
        # 任务名 → 本批分配的 QuestInfo Index（供批内前置引用）
        quest_rows = STORE.tables.get("QuestInfo", {})
        existing_names = {r.get("QuestName") for r in quest_rows.values()}
        batch_index: dict[str, int] = {}
        next_qi = STORE.next_index("QuestInfo")
        for qi, q in enumerate(body.quests):
            base = f"quests[{qi}]"
            name = _qa_text(q, "quest_name", base, errors, required=True)
            if not name:
                continue
            if name in existing_names:
                errors.append(f"{base}.quest_name: 任务名「{name}」已存在（Index 冲突）")
            if name in batch_index:
                errors.append(f"{base}.quest_name: 批内重复任务名「{name}」")
            else:
                batch_index[name] = next_qi + len(batch_index)

        def resolve_quest_param(v: Any, path: str) -> dict | None:
            """前置引用：{'Index': n}（已有）或 {'quest_name': str}（本批新建/库内按名）。"""
            if isinstance(v, dict) and isinstance(v.get("Index"), int):
                if v["Index"] not in quest_rows:
                    errors.append(f"{path}: 前置任务 QuestInfo#{v['Index']} 不存在")
                    return None
                return {"Index": v["Index"], "Name": quest_rows[v["Index"]].get("QuestName")}
            if isinstance(v, dict) and isinstance(v.get("quest_name"), str):
                nm = v["quest_name"]
                if nm in batch_index:
                    return {"Index": batch_index[nm], "Name": nm}
                if nm in existing_names:
                    idx = next(i for i, r in quest_rows.items() if r.get("QuestName") == nm)
                    return {"Index": idx, "Name": nm}
                errors.append(f"{path}: 前置任务「{nm}」不存在（既不在库中也不在本批）")
                return None
            errors.append(f"{path}: 需要 {{\"Index\": int}} 或 {{\"quest_name\": str}}")
            return None

        # ---- 全量校验（收集所有错误后再决定写入）
        for qi, q in enumerate(body.quests):
            base = f"quests[{qi}]"
            _qa_enum(q, "quest_type", "QuestType", "Story", base, errors)
            for k in ("accept_text", "progress_text", "completed_text", "archive_text"):
                _qa_text(q, k, base, errors)
            for k in ("start_npc", "finish_npc"):
                _qa_check_ref(q.get(k), "NPCInfo", f"{base}.{k}", errors)
            reqs = q.get("requirements") or []
            if not isinstance(reqs, list):
                errors.append(f"{base}.requirements: 需要数组")
                reqs = []
            for ri, rq in enumerate(reqs):
                rp = f"{base}.requirements[{ri}]"
                rt = _qa_enum(rq, "requirement", "QuestRequirementType", "", rp, errors)
                if rt in ("HaveCompleted", "HaveNotCompleted", "NotAccepted"):
                    resolve_quest_param(rq.get("quest_parameter"), f"{rp}.quest_parameter")
                elif rt in ("MinLevel", "MaxLevel"):
                    _qa_int(rq, "int_parameter1", 0, 0, 1000, rp, errors)
                elif rt == "Class":
                    _qa_enum(rq, "class", "RequiredClass", "All", rp, errors)
            tasks = q.get("tasks") or []
            if not isinstance(tasks, list):
                errors.append(f"{base}.tasks: 需要数组")
                tasks = []
            if not tasks:
                errors.append(f"{base}.tasks: 至少一个任务步骤（引擎三型之一）")
            for ti, tk in enumerate(tasks):
                tp = f"{base}.tasks[{ti}]"
                tt = _qa_enum(tk, "task", "QuestTaskType", "", tp, errors)
                _qa_int(tk, "amount", 1, 1, 100000, tp, errors)
                _qa_text(tk, "mob_description", tp, errors)
                if tt == "VisitRegion":
                    _qa_check_ref(tk.get("region_parameter"), "MapRegion",
                                  f"{tp}.region_parameter", errors)
                elif tt == "GainItem":
                    _qa_check_ref(tk.get("item_parameter"), "ItemInfo",
                                  f"{tp}.item_parameter", errors)
                elif tt == "KillMonster":
                    mds = tk.get("monster_details") or []
                    if not mds:
                        errors.append(f"{tp}.monster_details: KillMonster 至少一条怪物明细")
                    for mi, md in enumerate(mds):
                        mp = f"{tp}.monster_details[{mi}]"
                        _qa_check_ref(md.get("monster"), "MonsterInfo",
                                      f"{mp}.monster", errors)
                        if md.get("map") is not None:
                            _qa_check_ref(md.get("map"), "MapInfo", f"{mp}.map", errors)
                        _qa_int(md, "chance", 1, 1, 1000, mp, errors)
                        _qa_int(md, "amount", 1, 1, 1000, mp, errors)
            rewards = q.get("rewards") or []
            if not isinstance(rewards, list):
                errors.append(f"{base}.rewards: 需要数组")
                rewards = []
            for ri, rw in enumerate(rewards):
                rp = f"{base}.rewards[{ri}]"
                _qa_check_ref(rw.get("item"), "ItemInfo", f"{rp}.item", errors)
                _qa_int(rw, "amount", 1, 1, 100000, rp, errors)
                for k in ("choice", "bound"):
                    if k in rw and not isinstance(rw[k], bool):
                        errors.append(f"{rp}.{k}: 需要布尔值")
                _qa_int(rw, "duration", 0, 0, 100000, rp, errors)
                _qa_enum(rw, "class", "RequiredClass", "All", rp, errors)

        if errors:
            return JSONResponse(status_code=400,
                                content={"ok": False, "errors": errors[:100],
                                         "error_count": len(errors)})

        if body.dry_run:
            # 预演 Index：按写入顺序推演（不触碰内存态，可重复调用）
            preview, counters = [], {"QuestRequirement": STORE.next_index("QuestRequirement"),
                                     "QuestTask": STORE.next_index("QuestTask"),
                                     "QuestReward": STORE.next_index("QuestReward"),
                                     "QuestTaskMonsterDetails":
                                         STORE.next_index("QuestTaskMonsterDetails")}
            for q in body.quests:
                reqs = list(q.get("requirements") or [])
                if not any(isinstance(r, dict)
                           and r.get("requirement") == "HaveNotCompleted"
                           and isinstance(r.get("quest_parameter"), dict)
                           and r["quest_parameter"].get("quest_name") == q["quest_name"]
                           for r in reqs):
                    reqs = [None] + reqs
                req_idx = list(range(counters["QuestRequirement"],
                                     counters["QuestRequirement"] + len(reqs)))
                counters["QuestRequirement"] += len(reqs)
                tsk_idx = list(range(counters["QuestTask"],
                                     counters["QuestTask"] + len(q.get("tasks") or [])))
                counters["QuestTask"] += len(q.get("tasks") or [])
                rwd_idx = list(range(counters["QuestReward"],
                                     counters["QuestReward"] + len(q.get("rewards") or [])))
                counters["QuestReward"] += len(q.get("rewards") or [])
                preview.append({"quest_name": q["quest_name"],
                                "quest_index": batch_index[q["quest_name"]],
                                "requirements": req_idx, "tasks": tsk_idx,
                                "rewards": rwd_idx})
            return {"ok": True, "dry_run": True, "would_apply": preview, "errors": []}

        # ---- 写入（全部校验通过；QuestInfo Index 先分配，子表按表各自顺延）
        touched: set[str] = set()
        for q in body.quests:
            name = q["quest_name"]
            qidx = batch_index[name]
            qref = {"Index": qidx, "Name": name}
            npc = STORE.tables["NPCInfo"]
            reqs = list(q.get("requirements") or [])
            if not any(r.get("requirement") == "HaveNotCompleted"
                       and isinstance(r.get("quest_parameter"), dict)
                       and (r["quest_parameter"].get("quest_name") == name
                            or r["quest_parameter"].get("Index") == qidx)
                       for r in reqs):
                reqs = [{"requirement": "HaveNotCompleted",
                         "quest_parameter": {"quest_name": name}}] + reqs
            req_rows, task_rows, reward_rows = [], [], []
            for rq in reqs:
                row: dict[str, Any] = {
                    "Index": STORE.next_index("QuestRequirement"),
                    "Quest": qref,
                    "Requirement": rq.get("requirement", "MinLevel"),
                    "IntParameter1": rq.get("int_parameter1", 0) or 0,
                    "QuestParameter": None,
                    "Class": rq.get("class") or "None"}
                if row["Requirement"] in ("HaveCompleted", "HaveNotCompleted", "NotAccepted"):
                    row["QuestParameter"] = resolve_quest_param(rq.get("quest_parameter"), "")
                STORE.tables["QuestRequirement"][row["Index"]] = row
                STORE.recompute_identity("QuestRequirement", row)
                req_rows.append(row["Index"])
            for tk in q.get("tasks") or []:
                trow: dict[str, Any] = {
                    "Index": STORE.next_index("QuestTask"),
                    "Quest": qref, "Task": tk["task"],
                    "ItemParameter": None, "RegionParameter": None,
                    "MobDescription": tk.get("mob_description") or "",
                    "Amount": tk.get("amount", 1), "MonsterDetails": []}
                if tk["task"] == "VisitRegion":
                    trow["RegionParameter"] = _qa_check_ref(
                        tk["region_parameter"], "MapRegion", "", errors)
                elif tk["task"] == "GainItem":
                    trow["ItemParameter"] = _qa_check_ref(
                        tk["item_parameter"], "ItemInfo", "", errors)
                md_rows = []
                for md in tk.get("monster_details") or []:
                    mrow = {"Index": STORE.next_index("QuestTaskMonsterDetails"),
                            "Task": {"Index": trow["Index"], "Name": None},
                            "Monster": _qa_check_ref(md["monster"], "MonsterInfo", "", errors),
                            "Map": _qa_check_ref(md["map"], "MapInfo", "", errors)
                                   if md.get("map") is not None else None,
                            "Chance": md.get("chance", 1),
                            "Amount": md.get("amount", 1),
                            "DropSet": md.get("drop_set", 0)}
                    STORE.tables["QuestTaskMonsterDetails"][mrow["Index"]] = mrow
                    STORE.recompute_identity("QuestTaskMonsterDetails", mrow)
                    md_rows.append(mrow["Index"])
                    touched.add("QuestTaskMonsterDetails")
                trow["MonsterDetails"] = [{"Index": i, "Name": None} for i in md_rows]
                STORE.tables["QuestTask"][trow["Index"]] = trow
                STORE.recompute_identity("QuestTask", trow)
                task_rows.append(trow["Index"])
            for rw in q.get("rewards") or []:
                rrow = {"Index": STORE.next_index("QuestReward"),
                        "Quest": qref,
                        "Item": _qa_check_ref(rw["item"], "ItemInfo", "", errors),
                        "Amount": rw.get("amount", 1),
                        "Choice": bool(rw.get("choice", False)),
                        "Bound": bool(rw.get("bound", True)),
                        "Duration": rw.get("duration", 0) or 0,
                        "Class": rw.get("class") or "All"}
                STORE.tables["QuestReward"][rrow["Index"]] = rrow
                STORE.recompute_identity("QuestReward", rrow)
                reward_rows.append(rrow["Index"])
            qi_row = {
                "Index": qidx, "_Identity": name, "QuestName": name,
                "QuestType": q.get("quest_type", "Story"),
                "AcceptText": q.get("accept_text") or "",
                "ProgressText": q.get("progress_text") or "",
                "CompletedText": q.get("completed_text") or "",
                "ArchiveText": q.get("archive_text") or "",
                "Requirements": [{"Index": i, "Name": None} for i in req_rows],
                "StartNPC": {"Index": q["start_npc"]["Index"],
                             "Name": npc[q["start_npc"]["Index"]].get("_Identity")},
                "FinishNPC": {"Index": q["finish_npc"]["Index"],
                              "Name": npc[q["finish_npc"]["Index"]].get("_Identity")},
                "Rewards": [{"Index": i, "Name": None} for i in reward_rows],
                "Tasks": [{"Index": i, "Name": None} for i in task_rows],
            }
            STORE.tables["QuestInfo"][qidx] = qi_row
            quests_out.append({"quest_name": name, "quest_index": qidx,
                               "requirements": req_rows, "tasks": task_rows,
                               "rewards": reward_rows})
            touched.update(("QuestInfo", "QuestRequirement", "QuestTask", "QuestReward"))

        for t in touched:
            STORE.persist(t)
        STORE.git_commit(f"任务落地 {len(quests_out)} 个（"
                         + "、".join(x["quest_name"] for x in quests_out[:5])
                         + ("…" if len(quests_out) > 5 else "") + "）")
        return {"ok": True, "dry_run": False, "applied": quests_out, "errors": []}


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
    """返回某行的真实图标帧号+图库（货币物品走 CurrencyInfoImage 换算）。
    前端拿帧号再请求 /zl/{lib}/{frame}.png。"""
    rows = STORE.tables.get(table, {})
    row = rows.get(index)
    if row is None:
        raise HTTPException(404, "no row")
    if table == "ItemInfo":
        if not isinstance(row.get("Image"), int):
            raise HTTPException(404, "no image")
        cur = _currency_image(table, index)
        if cur is not None:
            return {"frame": cur, "lib": "Storeitems"}
        return {"frame": row["Image"], "lib": "Storeitems"}
    if table == "MonsterInfo":
        icon = _monster_icon(table, row)
        if not icon:
            raise HTTPException(404, "no image")
        return icon
    if table == "MagicInfo":
        if not isinstance(row.get("Icon"), int):
            raise HTTPException(404, "no image")
        return {"frame": row["Icon"], "lib": "MIcon"}
    raise HTTPException(404, "no image")


@APP.get("/zl/{lib}/{frame:int}.png")
def zl_icon(lib: str, frame: int):
    """实时解码 ZL 库指定帧。

    物品图标必须用 StoreItem.Zl —— 客户端 DXItemCell.ItemLibraryFile 默认就是
    StoreItem（2370 帧），Inventory.Zl 是另一套帧序（直接当物品图标=张冠李戴）。
    怪物 = Mon-N.Zl（GodotClient MonsterLookup 分库渲染，帧号=Shape*1000+偏移）。
    技能 = MIcon.Zl（LibraryFile.MagicIcon，MagicBar/MagicDialog 取 Info.Icon）。
    颜色通道由 zlsdk 正确处理（BGRA→RGBA）。
    lib 只允许 Data 目录下的 .Zl 文件名（防路径穿越）。
    """
    import re as _re
    if not _re.fullmatch(r"[A-Za-z0-9_\-]+", lib):
        raise HTTPException(404, "bad lib")
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
