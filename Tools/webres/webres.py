#!/usr/bin/env python3
"""webres.py — 浏览器世界观测试台构建工具 (阶段1, 扩展阶段0 Spike)。

子命令:
    data     构建全部 JSON 数据清单 -> WebData/data/
    maps     批量预渲染地图瓦片 (断点续跑, 可反复执行)
    sprites  批量预渲染精灵帧 (人物纸娃娃/怪物/技能特效/图标)
    estimate 抽样估算全量体积/耗时并写报告

所有产物只写 Debug/Client/WebData (可随时重建), 素材包 (.Zl/.map) 只读。
渲染管线直接 import Tools/maps/mapviewer.py (同仓库复用)。
"""
from __future__ import annotations

import argparse
import io
import json
import math
import os
import re
import struct
import sys
import time
import zlib
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(_TOOLS / "common"))
sys.path.insert(0, str(_TOOLS / "maps"))
sys.path.insert(0, str(_TOOLS / "webres"))
import zlsdk  # noqa: E402
from PIL import Image  # noqa: E402  (maps/sprites 渲染管线需要; 服务端 import webres 时可用)

CLIENT = Path("/home/tetsuya/development/zircon/Debug/Client")
WEB = CLIENT / "WebData"
DATA_DIR = CLIENT / "Data"
MAPS_DIR = CLIENT / "Map"
WORKSPACE = _TOOLS / "dbeditor" / "workspace"
ZIRCON = Path("/home/tetsuya/development/zircon")
DB_NAMES = ZIRCON / "GodotClient" / "translations" / "db_names.json"
TILE_SZ = 512
MAP_TILE_QUALITY = 85          # 地图瓦片有损 WebP 质量
DISK_BUDGET = 3 * 1024**3      # WebData 预算红线 3G

# ---------------------------------------------------------------- C# 源解析

def _read(p: Path) -> str:
    return p.read_text(encoding="utf-8", errors="replace")

# 全部只读解析 zircon 仓库源码, 提取权威映射表 (帧公式见各调用处注释)。

def _norm_lib_name(enum_name: str, libs: dict) -> str:
    """Libraries.cs 枚举名 -> Data 实际文件名 (大小写兜底)。
    库文件名与枚举名不完全一致 (StoreItem 枚举 ↔ Storeitems.Zl 文件)。"""
    name = libs.get(enum_name, enum_name)
    if (DATA_DIR / f"{name}.Zl").exists() or (DATA_DIR / "Map Data" / f"{name}.Zl").exists():
        return name
    # 大小写不敏感兜底
    actual = {p.stem.lower(): p.stem for p in DATA_DIR.glob("*.Zl")}
    return actual.get(name.lower(), name)


import zlsdk  # noqa: E402


def parse_libraries() -> dict[str, str]:
    """Libraries.cs LibraryList -> {枚举名: 库名(无扩展)}。"""
    src = _read(ZIRCON / "LibraryCore" / "Libraries.cs")
    out = {}
    for m in re.finditer(r"\[LibraryFile\.(\w+)\]\s*=\s*@\"Data\\([\w.-]+)\.Zl\"", src):
        out[m.group(1)] = m.group(2)
    return out


def parse_monster_lookup() -> dict[str, tuple[str, int]]:
    """MonsterLookup.cs -> {MonsterImage 枚举名: (LibraryFile 枚举, shape)}。"""
    src = _read(ZIRCON / "GodotClient" / "Formats" / "MonsterLookup.cs")
    out = {}
    for m in re.finditer(r"\{\s*MonsterImage\.(\w+),\s*\(LibraryFile\.(\w+),\s*(\d+)\)\s*\}", src):
        out[m.group(1)] = (m.group(2), int(m.group(3)))
    return out


def _parse_try_switch(src: str, fn: str) -> dict[int, str]:
    """PlayerRenderer.cs TryArmour/TryHelmet/TryWeapon/TryShield/TryCostume
    switch -> {key: LibraryFile 枚举名}。"""
    m = re.search(rf"private static bool {fn}\(int key, out LibraryFile file\)\s*\{{(.*?)\n    \}}", src, re.S)
    if not m:
        return {}
    body = m.group(1)
    return {int(k): lib for k, lib in re.findall(r"case (\d+):\s*file = LibraryFile\.(\w+); return true;", body)}


def parse_appearance_tables() -> dict:
    """PlayerRenderer.cs RefreshLibraries 的装备库字典 ( armour/helmet/weapon/shield/costume )。"""
    src = _read(ZIRCON / "GodotClient" / "Scripts" / "PlayerRenderer.cs")
    return {
        "armour": _parse_try_switch(src, "TryArmour"),
        "helmet": _parse_try_switch(src, "TryHelmet"),
        "weapon": _parse_try_switch(src, "TryWeapon"),
        "shield": _parse_try_switch(src, "TryShield"),
        "costume": _parse_try_switch(src, "TryCostume"),
    }


def _match_braces(src: str, start: int) -> tuple[int, int]:
    """返回从 start ('{' 位置) 开始的花括号平衡区间 (含两端) 的 (开, 闭)。"""
    depth = 0
    for i in range(start, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return start, i
    return start, len(src) - 1


_SCALAR_TYPES = {"File", "StartIndex", "FrameCount", "DelayMs", "Skip", "FrameLight",
                 "BlendRate", "Opacity", "StartDelayMs", "DistanceDelayMs"}


def _parse_effect_obj(body: str) -> dict:
    """CastEffect/ImpactDef/ProjectileDef 对象体 -> dict (标量 + 嵌套对象)。
    标量只取本层 (嵌套 {} 区域先遮蔽), 否则 Impact 的 File 会污染顶层。"""
    out: dict = {}
    masked = list(body)
    # 嵌套对象: Source/Impact/Projectile/MapImpact/TargetEffect/Arrival/Additional...
    pos = 0
    while True:
        m = re.search(r"(\w+)\s*=\s*new\s+\w+\s*\{", body[pos:])
        if not m:
            break
        key = m.group(1)
        ob = pos + m.end() - 1
        oe = _match_braces(body, ob)[1]
        for i in range(pos + m.start(), oe + 1):
            masked[i] = " "
        if key.endswith(("Additional", "Projectiles", "Effects")) or key.startswith("Additional"):
            out.setdefault(key, []).append(_parse_effect_obj(body[ob + 1:oe]))
        else:
            out[key] = _parse_effect_obj(body[ob + 1:oe])
        pos = oe + 1
    top = "".join(masked)
    for m in re.finditer(r"(\w+)\s*=\s*([^,;{}\n]+)", top):
        k, v = m.group(1), m.group(2).strip()
        if k in _SCALAR_TYPES or k in ("Colour", "Blend", "DrawType", "Has16Directions", "Explode",
                                       "DirectionFromSource", "DirectionFromCast", "CastAtSource",
                                       "NoTargetVisual", "NoLocationVisual", "ReleaseAtCaster",
                                       "NoColourKey", "ProjectileLastLocationOnly", "OriginOffsetX",
                                       "OriginOffsetY", "OriginFromTarget", "ProjectileDelayStepMs"):
            if k == "File":
                v = v.split(".")[-1]          # LibraryFile.Magic -> Magic
            if re.fullmatch(r"-?\d+(\.\d+)?f?", v):
                out[k] = float(v.rstrip("f")) if ("." in v or "f" in v and "." in v) else int(v.rstrip("f"))
            else:
                out[k] = v
    return out


def parse_magic_effects() -> dict[str, dict]:
    """MagicEffectTable.cs -> {MagicType 枚举名: CastEffect dict}。"""
    src = _read(ZIRCON / "GodotClient" / "Scripts" / "MagicEffectTable.cs")
    table: dict[str, dict] = {}
    for m in re.finditer(r"\[MagicType\.(\w+)\]\s*=\s*new\s+CastEffect\s*\{", src):
        name = m.group(1)
        ob = m.end() - 1
        oe = _match_braces(src, ob)[1]
        table[name] = _parse_effect_obj(src[ob + 1:oe])
    return table


# ---------------------------------------------------------------- workspace 载入

def ws_rows(table: str) -> list[dict]:
    return json.loads((WORKSPACE / f"{table}.json").read_text(encoding="utf-8"))["rows"]


def load_db_names() -> dict[str, dict[str, str]]:
    d = json.loads(DB_NAMES.read_text(encoding="utf-8"))
    out = {}
    for section, mapping in d.items():
        out[section] = {en: (v.get("zh") or en) for en, v in mapping.items()}
    return out


def map_cn_names() -> dict[str, str]:
    """地图中文名: /tmp/map_cn_full.json (gen_static_maps.py) -> map_links_v2 names 兜底。"""
    out = {}
    try:
        out.update(json.loads(Path("/tmp/map_cn_full.json").read_text(encoding="utf-8")))
    except Exception:
        pass
    try:
        d = json.loads((_TOOLS / "maps" / "map_links_v2.json").read_text(encoding="utf-8"))
        for stem, cn in d.get("names", {}).items():
            out.setdefault(stem, cn)
    except Exception:
        pass
    return out


# ---------------------------------------------------------------- .map 头/可行走

def parse_map_header(path: Path) -> tuple[int, int] | None:
    try:
        with open(path, "rb") as f:
            hdr = f.read(28)
        if len(hdr) < 28:
            return None
        w, h = struct.unpack_from("<HH", hdr, 22)
        return w, h
    except OSError:
        return None


def walkability_bits(path: Path, w: int, h: int) -> bytes | None:
    """ServerLibrary/Models/Map.cs: 可行走 iff (flag & 0x02) && (flag & 0x01)。
    输出 zlib 压缩位图, 行主序 (bit = x + y*w)。"""
    data = path.read_bytes()
    off = 28 + w * h // 4 * 3
    n = w * h
    if off + n * 14 > len(data):
        return None
    bits = bytearray((n + 7) // 8)
    for i in range(n):
        flag = data[off + i * 14]
        if flag & 0x03 == 0x03:
            bits[i >> 3] |= 1 << (i & 7)
    return zlib.compress(bytes(bits), 9)


# ---------------------------------------------------------------- 帧号公式 (权威依据)
# LibraryCore/FrameSet.cs:
#   Players:    Standing(0,4,10) Walking(80,6,10) Running(160,6,10) Combat2(640,5,10) Struck(1840,3,10) Die(1920,10,10)
#   DefaultMonster: Standing(0,4,10) Walking(80,6,10) Combat1(160,6,10) Die(320,10,10)
#   DefaultNPC: Standing(0,4,0) — NPC.Zl 帧 = Image*100 + i (ObjectRenderer BodyOffSet=100)
# PlayerRenderer.cs:
#   DrawFrame   = frameIndex + animStart + dir*10
#   ArmourFrame = DrawFrame + (ArmourShape%11)*ArmourOffSet(5000/3000刺) + ArmourShift
#   WeaponFrame = DrawFrame + (WeaponShape%10)*5000   (WeaponShape = Shape>=1000 ? Shape-1000 : Shape)
#   HairFrame   = DrawFrame + (HairType-1)*5000
#   HelmetFrame = DrawFrame + ((HelmetShape-1)%10)*ArmourOffSet + ArmourShift

PLAYER_ANIMS = {
    "standing": (0, 4), "walking": (80, 6), "running": (160, 6),
    "combat2": (640, 5), "struck": (1840, 3), "die": (1920, 10),
}
MONSTER_ANIMS = {"standing": (0, 4), "walking": (80, 6), "combat1": (160, 6), "die": (320, 10)}
DIRS = 8


def player_frames(anim: str, armour_shape: int, is_assassin: bool) -> list[int]:
    """玩家身体 (同样适用于 hair 前提 HairType=1 / weapon shape 0 块) 需要的帧号集合。"""
    start, count = PLAYER_ANIMS[anim]
    off = 3000 if is_assassin else 5000
    shift = 0 if not is_assassin else {"standing": 0, "walking": 1600, "running": 1600,
                                       "combat2": 0, "struck": -640, "die": -400}[anim]
    frames = []
    for d in range(DIRS):
        for i in range(count):
            f = i + start + d * 10
            frames.append(f + (armour_shape % 11) * off + shift)
    return frames


def monster_frames(shape: int, anims: tuple[str, ...] = ("standing",),
                   dirs: range | list[int] = range(8)) -> list[int]:
    out = []
    for anim in anims:
        start, count = MONSTER_ANIMS[anim]
        for d in dirs:
            for i in range(count):
                out.append(shape * 1000 + i + start + d * 10)
    return out


# ---------------------------------------------------------------- WebP 落盘

_lib_cache: dict[str, zlsdk.ZlLibrary] = {}


def get_lib(name: str) -> zlsdk.ZlLibrary | None:
    """按库名 (如 'M-Hum') 打开 Data 下 .Zl (mmap, 只读)。"""
    if name in _lib_cache:
        return _lib_cache[name]
    p = DATA_DIR / f"{name}.Zl"
    if not p.exists():
        p = DATA_DIR / "Map Data" / f"{name}.Zl"
    lib = zlsdk.ZlLibrary(str(p)) if p.exists() else None
    _lib_cache[name] = lib
    return lib


def encode_webp(im, lossless: bool = True, quality: int = 90, method: int = 4) -> bytes:
    buf = io.BytesIO()
    if lossless:
        im.save(buf, format="WEBP", lossless=True, method=method)
    else:
        im.save(buf, format="WEBP", quality=quality, method=method)
    return buf.getvalue()


def extract_frame(lib_name: str, frame: int, out_dir: Path,
                  lossless: bool = True, quality: int = 90) -> int:
    """解码单帧 -> WebP 落盘 (存在即跳过 = 断点续跑), 返回字节数 (-1 失败/跳过)。"""
    out = out_dir / f"{frame}.webp"
    if out.exists():
        return -1
    lib = get_lib(lib_name)
    if lib is None or lib.is_blank(frame):
        return -1
    im = lib.decode(frame)
    if im is None:
        return -1
    out_dir.mkdir(parents=True, exist_ok=True)
    data = encode_webp(im, lossless=lossless, quality=quality)
    out.write_bytes(data)
    return len(data)


def write_json(path: Path, obj) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")


# ---------------------------------------------------------------- data 子命令

def cmd_data(args) -> int:
    t0 = time.time()
    out = WEB / "data"
    out.mkdir(parents=True, exist_ok=True)

    libs_raw = parse_libraries()
    libs = {k: _norm_lib_name(v, libs_raw) for k, v in libs_raw.items()}
    mon_lookup = parse_monster_lookup()
    appear_tables = parse_appearance_tables()
    magic_effects = parse_magic_effects()
    names = load_db_names()
    cn_maps = map_cn_names()
    enum2file = libs

    # ---- MapInfo 627 ----
    mapinfo_rows = ws_rows("MapInfo")
    regions = {r["Index"]: r for r in ws_rows("MapRegion")}
    movements = ws_rows("MovementInfo")

    # 出口: per-map 列表
    exits: dict[str, list] = {}
    for mv in movements:
        src = regions.get(mv["SourceRegion"]["Index"])
        dst = regions.get(mv["DestinationRegion"]["Index"])
        if not src or not dst:
            continue
        smap = src.get("Map", {}).get("Name")
        dmap = dst.get("Map", {}).get("Name")
        sp = src.get("PointRegion") or {}
        dp = dst.get("PointRegion") or {}
        if not smap or not dmap or sp.get("CenterX") in (None, 0) or dp.get("CenterX") in (None, 0):
            continue
        size = src.get("Size") or sp.get("PointCount") or 1
        r = max(1, int(math.sqrt(size) / 2))
        exits.setdefault(smap, []).append({
            "x": int(sp["CenterX"]), "y": int(sp["CenterY"]), "r": r,
            "to": dmap, "tx": int(dp["CenterX"]), "ty": int(dp["CenterY"]),
            "icon": mv.get("Icon") or "None",
        })

    maps_manifest = {"tile": TILE_SZ, "generated": time.strftime("%Y-%m-%d %H:%M:%S"), "maps": {}}
    walk_dir = out / "walk"
    walk_dir.mkdir(parents=True, exist_ok=True)
    missing_maps = []
    for row in mapinfo_rows:
        stem = row["FileName"]
        name_en = row.get("Description") or stem
        name_cn = cn_maps.get(stem) or names["maps"].get(name_en) or name_en
        mp = MAPS_DIR / f"{stem}.map"
        wh = parse_map_header(mp) if mp.exists() else None
        if wh is None:
            missing_maps.append(stem)
            continue
        w, h = wh
        nx, ny = math.ceil(w * 48 / TILE_SZ), math.ceil(h * 32 / TILE_SZ)
        maps_manifest["maps"][stem] = {
            "id": row["Index"], "name_en": name_en, "name_cn": name_cn,
            "w": w, "h": h, "tiles": [nx, ny],
            "minimap": row.get("MiniMap") or 0,
            "light": row.get("Light") or "Default",
            "weather": row.get("Weather") or "None",
            "big": w * h * 48 * 32 * 4 > 50 * 1024 * 1024,   # >50MB 位图 -> 分瓦片
            "exits": exits.get(stem, []),
        }
        wb = walkability_bits(mp, w, h)
        if wb is not None:
            (walk_dir / f"{stem}.bin").write_bytes(wb)

    # 出生点: 比奇 (map 0) 城区质心附近第一个可行走格
    spawn = find_spawn("0", maps_manifest)
    maps_manifest["spawn"] = spawn

    write_json(out / "maps_manifest.json", maps_manifest)

    # ---- NPC 294 ----
    npcs = []
    for row in ws_rows("NPCInfo"):
        reg = regions.get(row["Region"]["Index"]) if row.get("Region") else None
        if not reg:
            continue
        p = reg.get("PointRegion") or {}
        if p.get("CenterX") in (None, 0):
            continue
        en = row.get("NPCName") or f"NPC{row['Index']}"
        npcs.append({
            "id": row["Index"], "name": en, "zh": names["npcs"].get(en, en),
            "map": reg["Map"]["Name"], "x": int(p["CenterX"]), "y": int(p["CenterY"]),
            "image": row.get("Image") or 0, "face": row.get("FaceImage") or 0,
            "cat": reg.get("Description") or "",
        })
    write_json(out / "npcs.json", npcs)

    # ---- Monster 434 ----
    mons = []
    for row in ws_rows("MonsterInfo"):
        img = row.get("Image") or ""
        lk = mon_lookup.get(img)
        mons.append({
            "id": row["Index"], "name": row.get("MonsterName") or img,
            "zh": names["monsters"].get(row.get("MonsterName", ""), row.get("MonsterName", "")),
            "level": row.get("Level") or 0, "boss": bool(row.get("IsBoss")),
            "img": img, "lib": enum2file.get(lk[0], "") if lk else "", "shape": lk[1] if lk else -1,
        })
    write_json(out / "monsters.json", mons)

    # ---- Respawn 2475 (按地图分组) ----
    mon_by_id = {m["id"]: m for m in mons}
    resp: dict[str, list] = {}
    for row in ws_rows("RespawnInfo"):
        reg = regions.get(row["Region"]["Index"]) if row.get("Region") else None
        mon = mon_by_id.get(row["Monster"]["Index"]) if row.get("Monster") else None
        if not reg or not mon or not mon.get("lib"):
            continue
        p = reg.get("PointRegion") or {}
        if p.get("CenterX") in (None, 0):
            continue
        stem = reg["Map"]["Name"]
        size = reg.get("Size") or p.get("PointCount") or 1
        r = max(1, int(math.sqrt(size) / 2))
        resp.setdefault(stem, []).append({
            "mid": mon["id"], "x": int(p["CenterX"]), "y": int(p["CenterY"]),
            "r": r, "n": row.get("Count") or 1,
        })
    write_json(out / "respawns.json", resp)

    # ---- Magic 174 + 特效映射 ----
    magics = []
    for row in ws_rows("MagicInfo"):
        en = row.get("Name") or row.get("Magic", "")
        key = row.get("Magic", "")
        eff = magic_effects.get(key)
        rec = {
            "id": row["Index"], "key": row.get("Magic", ""), "name": en, "zh": names["magics"].get(en, en),
            "cls": row.get("Class") or "Warrior", "icon": row.get("Icon") or 0,
            "effect": None, "proj": None, "impact": None,
        }
        if eff:
            def conv(e: dict | None) -> dict | None:
                if not e:
                    return None
                f = enum2file.get(str(e.get("File", "")), "")
                if not f:
                    return None
                return {"lib": f, "start": int(e.get("StartIndex", 0)),
                        "count": int(e.get("FrameCount", 1)), "ms": int(e.get("DelayMs", 100))}
            rec["effect"] = conv(eff)
            rec["proj"] = conv(eff.get("Projectile"))
            rec["impact"] = conv(eff.get("Impact")) or conv(eff.get("MapImpact"))
        magics.append(rec)
    write_json(out / "magics.json", magics)

    # ---- Item 1078 ----
    items = []
    for row in ws_rows("ItemInfo"):
        en = row.get("ItemName") or f"Item{row['Index']}"
        items.append({
            "id": row["Index"], "name": en, "zh": names["items"].get(en, en),
            "type": row.get("ItemType") or "Nothing", "cls": row.get("RequiredClass") or "All",
            "shape": row.get("Shape") or 0, "image": row.get("Image") or 0,
            "stack": row.get("StackSize") or 1,
        })
    write_json(out / "items.json", items)

    # ---- 外观模型 (库选择表, 客户端 JS 同公式计算帧号) ----
    appearance = {
        "libraries": enum2file,
        "tables": appear_tables,
        "npc_lib": enum2file.get("NPC", "NPC"),
        "icon_libs": {"magic": enum2file.get("MagicIcon", "MIcon"),
                      "store": enum2file.get("StoreItem", "Storeitems"),
                      "ground": enum2file.get("Ground", "Ground"),
                      "minimap": enum2file.get("MiniMap", "MiniMap")},
    }
    write_json(out / "appearance.json", appearance)

    print(f"[data] maps={len(maps_manifest['maps'])} (缺失.map {len(missing_maps)}) "
          f"npcs={len(npcs)} monsters={len(mons)} respawn组={len(resp)} "
          f"magics={len(magics)} items={len(items)} spawn={spawn} "
          f"耗时 {time.time() - t0:.1f}s")
    if missing_maps:
        print(f"[data] 缺失 .map: {missing_maps[:10]} ...")
    return 0


def find_spawn(stem: str, manifest: dict) -> dict:
    """出生点: 地图中心附近找可行走格 (walk 位图), 兜底 (0,0)。"""
    import zlib as _z
    m = manifest["maps"].get(stem)
    if not m:
        return {"map": "0", "x": 0, "y": 0}
    wb_path = WEB / "data" / "walk" / f"{stem}.bin"
    bits = None
    if wb_path.exists():
        bits = _z.decompress(wb_path.read_bytes())
    w, h = m["w"], m["h"]
    cx, cy = w // 2, h // 2
    for r in range(0, max(w, h)):
        for dx in range(-r, r + 1):
            for dy in (-r, r):
                for x, y in ((cx + dx, cy + dy), (cx + dx, cy - dy)):
                    if 0 <= x < w and 0 <= y < h:
                        if bits is None or bits[(x + y * w) >> 3] >> ((x + y * w) & 7) & 1:
                            return {"map": stem, "x": x, "y": y}
    return {"map": stem, "x": cx, "y": cy}


# ---------------------------------------------------------------- maps 子命令

def _map_order(manifest: dict) -> list[str]:
    """城镇/野外优先 (有 NPC 或非 D 前缀), 洞窟靠后。"""
    stems = list(manifest["maps"].keys())
    def key(s: str) -> tuple:
        m = manifest["maps"][s]
        return (0 if not s.upper().startswith("D") and not s.startswith("d") else 1, -m["w"] * m["h"])
    return sorted(stems, key=key)


def render_map_tiles(stem: str, manifest: dict, quality: int = MAP_TILE_QUALITY,
                     only: tuple[int, int] | None = None) -> dict:
    """渲染地图瓦片 (已存在跳过)。only=(tx,ty) 时只渲染该瓦片 (按需路径, 不写 done.json)。"""
    import mapviewer
    cache = mapviewer.MapCache(str(MAPS_DIR))
    pool = mapviewer.FramePool(str(DATA_DIR / "Map Data"))
    m = manifest["maps"][stem]
    nx, ny = m["tiles"]
    out_dir = WEB / "maps" / stem
    t0 = time.time()
    done_bytes = new_tiles = 0
    coords = [only] if only else [(tx, ty) for ty in range(ny) for tx in range(nx)]
    for tx, ty in coords:
        out = out_dir / f"{tx}_{ty}.webp"
        if out.exists():
            done_bytes += out.stat().st_size
            continue
        png = mapviewer.render_tile(cache, pool, f"{stem}.map", tx, ty, 0,
                                    layout=mapviewer.LAYOUT_RECT)
        im = Image.open(io.BytesIO(png)).convert("RGB")
        out_dir.mkdir(parents=True, exist_ok=True)
        data = encode_webp(im, lossless=False, quality=quality)
        out.write_bytes(data)
        done_bytes += len(data)
        new_tiles += 1
    stat = {"nx": nx, "ny": ny, "bytes": done_bytes, "tiles": nx * ny,
            "new": new_tiles, "secs": round(time.time() - t0, 1)}
    if not only:
        write_json(out_dir / "done.json", stat)
    return stat

def cmd_maps(args) -> int:
    manifest = json.loads((WEB / "data" / "maps_manifest.json").read_text(encoding="utf-8"))
    order = _map_order(manifest)
    if args.stems:
        src = Path(args.stems[1:]) if args.stems.startswith("@") else None
        want = set((src.read_text() if src else args.stems).replace("\n", ",").split(","))
        want = {w.strip() for w in want if w.strip() and w in manifest["maps"]}
        order = [s for s in order if s in want]
    limit = getattr(args, "limit", 0) or len(order)
    quality = args.quality
    t_all = b_all = n_all = 0
    results = []
    for stem in order[:limit]:
        st = render_map_tiles(stem, manifest, quality)
        results.append({"stem": stem, **st})
        t_all += st["secs"]; b_all += st["bytes"]; n_all += 1
        print(f"[maps] {stem}: tiles={st['tiles']} new={st['new']} "
              f"{st['bytes'] / 1048576:.1f}MB {st['secs']}s", flush=True)
        if args.sample:      # 抽样估算模式: 跳过已完成也算 0
            pass
    if args.sample and n_all:
        avg_b = b_all / n_all
        avg_t = t_all / n_all
        total = len(manifest["maps"])
        est = {
            "sampled": n_all, "avg_mb": round(avg_b / 1048576, 2), "avg_secs": round(avg_t, 1),
            "total_maps": total, "est_total_mb": round(avg_b * total / 1048576, 0),
            "est_total_hours": round(avg_t * total / 3600, 1),
            "budget_gb": DISK_BUDGET / 1024**3,
            "fits_budget": avg_b * total <= DISK_BUDGET,
        }
        write_json(WEB / "maps" / "_estimate.json", est)
        print(f"[maps] 估算: {json.dumps(est, ensure_ascii=False)}")
    return 0


# ---------------------------------------------------------------- sprites 子命令

def appearance_frame_plan() -> dict[str, list[int]]:
    """需要预渲染的人物外观帧计划: {库名: [帧号...]}。
    覆盖: 4 职业×2 性别基础体 + ItemInfo 全部 Armour/Weapon/Helmet/Hair 外观块。"""
    libs = parse_libraries()
    tables = parse_appearance_tables()
    items = ws_rows("ItemInfo")
    plan: dict[str, set] = {}

    def add(lib_enum: str, frames: list[int]):
        name = libs.get(lib_enum)
        if not name:
            return
        plan.setdefault(name, set()).update(frames)

    # 基础体: 战/法/道 (M-Hum/WM-Hum) + 刺客 (M-HumA/WM_HumA), armour shape 0 块
    for body, is_sin in (("M_Hum", False), ("WM_Hum", False), ("M_HumA", True), ("WM_HumA", True)):
        for anim in PLAYER_ANIMS:
            add(body, player_frames(anim, 0, is_sin))
        hair = "M_HairA" if is_sin else "M_Hair"
        if body.startswith("WM"):
            hair = "WM_HairA" if is_sin else "WM_Hair"
        for ht in range(1, 11):   # 10 发型
            for anim in ("standing", "walking", "running"):
                start, count = PLAYER_ANIMS[anim]
                add(hair, [i + start + d * 10 + (ht - 1) * 5000
                           for d in range(DIRS) for i in range(count)])

    female = False
    for it in items:
        t = it.get("ItemType")
        shape = it.get("Shape") or 0
        if t == "Armour" and shape >= 0:
            key = shape // 11 + (50000 if it.get("RequiredClass") == "Assassin" else 0)
            lib = tables["armour"].get(key)
            if lib:
                is_sin = it.get("RequiredClass") == "Assassin"
                for anim in PLAYER_ANIMS:
                    add(lib, player_frames(anim, shape, is_sin))
        elif t == "Weapon" and shape >= 0:
            ws = shape - 1000 if shape >= 1000 else shape
            key = shape // 10
            lib = tables["weapon"].get(key)
            if lib:
                for anim in PLAYER_ANIMS:
                    start, count = PLAYER_ANIMS[anim]
                    add(lib, [i + start + d * 10 + (ws % 10) * 5000
                              for d in range(DIRS) for i in range(count)])
        elif t == "Helmet" and shape > 0:
            key = (shape - 1) // 10
            lib = tables["helmet"].get(key)
            if lib:
                for anim in ("standing", "walking", "running"):
                    start, count = PLAYER_ANIMS[anim]
                    add(lib, [i + start + d * 10 + ((shape - 1) % 10) * 5000
                              for d in range(DIRS) for i in range(count)])
    return {k: sorted(v) for k, v in plan.items()}


def cmd_sprites(args) -> int:
    t0 = time.time()
    total_bytes = total_new = 0
    sprites_dir = WEB / "sprites"

    def run_plan(plan: dict[str, list[int]], lossless=True, quality=90, label=""):
        nonlocal total_bytes, total_new
        n = miss = 0
        for lib_name, frames in plan.items():
            out_dir = sprites_dir / lib_name
            for f in frames:
                got = extract_frame(lib_name, f, out_dir, lossless, quality)
                if got >= 0:
                    total_bytes += got
                    total_new += 1
                else:
                    miss += 1
                n += 1
        print(f"[sprites:{label}] 帧={n} 新落盘={total_new} 缺失/已有={miss} "
              f"{total_bytes / 1048576:.1f}MB {time.time() - t0:.0f}s", flush=True)

    what = args.what
    if what in ("players", "all"):
        run_plan(appearance_frame_plan(), label="players")
    if what in ("monsters", "all"):
        mons = json.loads((WEB / "data" / "monsters.json").read_text(encoding="utf-8"))
        plan: dict[str, set] = {}
        for m in mons:
            if m["lib"]:
                plan.setdefault(m["lib"], set()).update(
                    monster_frames(m["shape"], ("standing",), range(DIRS)))
        run_plan({k: sorted(v) for k, v in plan.items()}, label="monsters")
    if what in ("magic", "all"):
        magics = json.loads((WEB / "data" / "magics.json").read_text(encoding="utf-8"))
        app = json.loads((WEB / "data" / "appearance.json").read_text(encoding="utf-8"))
        plan = {}
        for mg in magics:
            if mg["icon"] >= 0:
                plan.setdefault(app["icon_libs"]["magic"], set()).add(mg["icon"])
            for e in (mg["effect"], mg["proj"], mg["impact"]):
                if e:
                    plan.setdefault(e["lib"], set()).update(range(e["start"], e["start"] + e["count"]))
        run_plan({k: sorted(v) for k, v in plan.items()}, label="magic")
    if what in ("npc", "all"):
        npcs = json.loads((WEB / "data" / "npcs.json").read_text(encoding="utf-8"))
        app = json.loads((WEB / "data" / "appearance.json").read_text(encoding="utf-8"))
        lib = app["npc_lib"]
        plan = {lib: sorted({n["image"] * 100 + i for n in npcs for i in range(4)})}
        run_plan(plan, label="npc")
    if what in ("items", "all"):
        app = json.loads((WEB / "data" / "appearance.json").read_text(encoding="utf-8"))
        items = json.loads((WEB / "data" / "items.json").read_text(encoding="utf-8"))
        plan = {app["icon_libs"]["store"]: sorted({i["image"] for i in items if i["image"] > 0})}
        run_plan(plan, label="items")
    print(f"[sprites] 完成: 新帧 {total_new} 共 {total_bytes / 1048576:.1f}MB "
          f"耗时 {time.time() - t0:.0f}s")
    return 0


# ---------------------------------------------------------------- manifest 子命令
# 逐库精灵清单 (帧元数据: 宽/高/偏移), 供客户端锚定合成; 惰性生成后落盘复用。


def cmd_manifest(args) -> int:
    lib_name = args.lib
    lib = get_lib(lib_name)
    if lib is None:
        print(f"[manifest] 找不到库: {lib_name}")
        return 1
    out = {}
    for idx in sorted(lib.headers):
        h = lib.header(idx)
        if h:
            out[str(idx)] = [h["width"], h["height"], h["offsetX"], h["offsetY"]]
    write_json(WEB / "sprites" / lib_name / "manifest.json", out)
    print(f"[manifest] {lib_name}: {len(out)} 帧元数据")
    return 0


# ---------------------------------------------------------------- estimate 子命令


def cmd_estimate(args) -> int:
    """10 张抽样 -> WebData/maps/_estimate.json + ESTIMATE.md 追加章节。"""
    manifest = json.loads((WEB / "data" / "maps_manifest.json").read_text(encoding="utf-8"))
    order = _map_order(manifest)
    sample = order[:args.sample]
    t_all = b_all = 0
    rows = []
    for stem in sample:
        st = render_map_tiles(stem, manifest)
        rows.append(st)
        t_all += st["secs"]; b_all += st["bytes"]
        print(f"[estimate] {stem} ({manifest['maps'][stem]['name_cn']}): "
              f"{st['bytes'] / 1048576:.1f}MB {st['secs']}s tiles={st['tiles']}", flush=True)
    total = len(manifest["maps"])
    avg_b, avg_t = b_all / len(sample), t_all / len(sample)
    fits = avg_b * total <= DISK_BUDGET
    est = {
        "sampled": len(sample), "avg_mb": round(avg_b / 1048576, 2),
        "avg_secs": round(avg_t, 1), "total_maps": total,
        "est_total_mb": round(avg_b * total / 1048576), "est_total_hours": round(avg_t * total / 3600, 1),
        "fits_budget": fits,
    }
    write_json(WEB / "maps" / "_estimate.json", est)
    md = f"""
## 阶段1 全量地图估算 ({time.strftime('%Y-%m-%d %H:%M')})

抽样 {len(sample)} 张 (城镇/野外优先序): 平均 {est['avg_mb']}MB/张, {est['avg_secs']}s/张。
外推 {total} 张: **约 {est['est_total_mb']}MB ({est['est_total_mb'] / 1024:.1f}GB)**,
耗时约 {est['est_total_hours']}h。预算 3G: {'✅ 可全量' if fits else '❌ 超线 → 分级方案'}。

| 地图 | 瓦片 | 体积 | 耗时 |
|---|---|---|---|
"""
    for st, stem in zip(rows, sample):
        md += f"| {stem} {manifest['maps'][stem]['name_cn']} | {st['tiles']} | {st['bytes'] / 1048576:.1f}MB | {st['secs']}s |\n"
    est_md = Path(__file__).parent / "ESTIMATE.md"
    est_md.write_text(est_md.read_text(encoding="utf-8") + md, encoding="utf-8")
    print(f"[estimate] {json.dumps(est, ensure_ascii=False)}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="webres — 浏览器测试台构建工具")
    sub = ap.add_subparsers(dest="cmd", required=True)

    sub.add_parser("data", help="生成数据清单 (地图/NPC/怪物/技能/物品 + walk 位图)")

    p = sub.add_parser("maps", help="批量渲染地图瓦片 (断点续跑)")
    p.add_argument("--stems", default="", help="逗号分隔或 @文件: 只渲染这些图")
    p.add_argument("--limit", type=int, default=0)
    p.add_argument("--quality", type=int, default=MAP_TILE_QUALITY)
    p.add_argument("--sample", action="store_true", help="输出估算")

    p = sub.add_parser("sprites", help="批量预渲染精灵帧")
    p.add_argument("--what", default="all",
                   choices=["players", "monsters", "magic", "npc", "items", "all"])

    p = sub.add_parser("manifest", help="生成单库帧元数据 manifest")
    p.add_argument("lib")

    p = sub.add_parser("estimate", help="抽样 10 张估算")
    p.add_argument("--sample", type=int, default=10)

    args = ap.parse_args()
    if args.cmd == "data":
        return cmd_data(args)
    if args.cmd == "maps":
        return cmd_maps(args)
    if args.cmd == "sprites":
        return cmd_sprites(args)
    if args.cmd == "manifest":
        return cmd_manifest(args)
    if args.cmd == "estimate":
        return cmd_estimate(args)
    return 1


if __name__ == "__main__":
    from PIL import Image  # noqa: E402  (maps 路径需要)
    sys.exit(main())
