#!/usr/bin/env python3
"""mapedit.constants — 全局常量与路径（mapviewer 拆分，行为不变）。"""
from __future__ import annotations
import hashlib
import json
import os
import re

TILE_SZ = 512          # tile size in screen pixels
CACHE_MAPS_MAX = 3     # decoded maps kept in memory
CACHE_TILES_MAX = 400  # rendered tiles (PNG bytes) kept in memory
CACHE_FRAMES_BYTES = 256 * 1024 * 1024  # decoded frames LRU budget (per process)

def _nas_tmp_dir() -> str:
    """NAS TMP 根目录：env MIR3_NAS_TMP 优先，其次 82 机的 /data/NAS 挂载，
    最后旧机 /home/tetsuya/NAS 符号链接（82 上指向 /tmp/nas_mnt 已悬空）。
    换机器只改 env，不改代码（总纲 §9.4）。"""
    for cand in (os.environ.get("MIR3_NAS_TMP"), "/data/NAS/TMP",
                 "/home/tetsuya/NAS/TMP"):
        if cand and os.path.isdir(cand):
            return cand
    return "/home/tetsuya/NAS/TMP"

DEFAULT_CACHE_MOUNT = _nas_tmp_dir()
DEFAULT_CACHE_ROOT = os.path.join(DEFAULT_CACHE_MOUNT, "mir3-mapviewer-cache")
THUMBS_DIR = os.path.join(DEFAULT_CACHE_ROOT, "thumbs")  # shared with WikiServer/thumb_gen

# 共享文本缓存（小地图索引/地图中文名）：仓库 Tools/cache/ 优先，/tmp 兜底；
# scripts/gen_caches.sh 两处同写（§3.4 脆弱点治理）。env MIR3_CACHE_DIR 可强制。
_REPO_CACHE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "cache"))


def _cache_file(name: str) -> str:
    """按 优先级 返回缓存文件路径：MIR3_CACHE_DIR > Tools/cache > /tmp。"""
    cands = [d for d in (os.environ.get("MIR3_CACHE_DIR"), _REPO_CACHE_DIR, "/tmp") if d]
    for d in cands:
        if os.path.isfile(os.path.join(d, name)):
            return os.path.join(d, name)
    return os.path.join(cands[0], name)

MAX_FULL_DIM = 16384   # full-map single image: longest side cap (px)
FIT_FULL_DIM = 2048    # full-map "fit" level: longest side target (px)
DEFAULT_CLIENT_ROOT = "/home/tetsuya/development/Zircon/Debug/Client"
DEFAULT_CONNECTIONS = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "../../docs/database/data/map-connections.json"))
# dbeditor JSON 工作区（System.db 全表导出，编辑器保存即更新）——NPC 位置与
# 地图连接的第一数据源（NPCInfo 294 行 × MapRegion 5009 行 × MovementInfo
# 1039 行，PointRegion 质心坐标 0 缺失，且包含 NpcMover 修正后的 EI 坐标）。
DEFAULT_DBWORKSPACE = os.path.abspath(os.path.join(
    os.path.dirname(__file__), "../dbeditor/workspace"))
# 客户端显示名映射表（方案 B 本地化）：NPC/地图 中文名，zh 优先、英文兜底。
DEFAULT_DB_NAMES = os.path.expanduser(
    "~/development/zircon/GodotClient/translations/db_names.json")
# Full chinese-name map: {map stem -> cn}.  Generated from DBserver/Envir
# MapInfo.txt + System.db descriptions + mapnames rules (see gen_static_maps.py).
MAP_CN_FILE = _cache_file("map_cn_full.json")

def _load_map_cn() -> dict:
    try:
        with open(MAP_CN_FILE, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}

MAP_CN = _load_map_cn()
# Bump whenever map parsing/library mapping changes.  Old cached JPGs can be
# visually valid files but represent the pre-Sabak or pre-cell-offset parser.
CACHE_VERSION = "v3"


def default_tile_cache_dir(maps_dir: str) -> str:
    """Return a NAS-backed, source-isolated tile cache directory."""
    source = os.path.realpath(os.path.abspath(maps_dir))
    source_id = hashlib.sha256(source.encode("utf-8")).hexdigest()[:12]
    label = re.sub(r"[^A-Za-z0-9._-]+", "-", os.path.basename(source)).strip("-") or "maps"
    return os.path.join(DEFAULT_CACHE_ROOT, "tiles", CACHE_VERSION,
                        f"{label}-{source_id}")


def _nas_cache_available() -> bool:
    """NAS 缓存挂载可用性。os.path.ismount 对 reparse=nfs 的 CIFS 转义
    挂载会误报 False（内核 mount 表存在、Python 判定无），故 ismount 通过
    或缓存根目录可访问任一成立即视为可用。"""
    if os.path.ismount(DEFAULT_CACHE_MOUNT):
        return True
    return os.path.isdir(DEFAULT_CACHE_ROOT)

# Layout modes.  Mir3.exe (EI 2002) renders the map grid axis-aligned:
# every draw call projects cell (x,y) with a single-axis term (x*48, y*32)
# and the viewport is a plain 36x36 square; the 8-way scroll table moves
# N/E/S/W by a single pixel axis.  The apparent "isometric" look of the
# game comes from perspective baked into the sprites, not the projection.
# "iso" is kept only as a legacy/debug view.
LAYOUT_RECT = "rect"
LAYOUT_ISO = "iso"

# WIL frame-offset modes (rect layout only; iso keeps the legacy
# centre-anchor + offset behaviour and ignores this switch).
# Disassembly of Mir3.exe is conclusive that the EI map layers NEVER read
# the frame +4/+6 offset fields (ground 0x43b440/0x43b9a0/0x43c3xx/0x43c4c9,
# animated ground 0x434a20, mid/front 0x43bb10/0x43be00, blend 0x43bcf5) —
# only the actor layer (0x41cbd0/0x40b5xx/0x40fbxx/0x430axx) does.  These
# modes exist purely to record the divergence ("none" = the original).
OFFSET_NONE = "none"      # original: no offsets anywhere
OFFSET_ALL = "all"        # hypothetical: back + mid/front shifted by frame offsets
OFFSET_MIDFRONT = "midfront"  # hypothetical: only mid/front shifted
OFFSET_MODES = (OFFSET_NONE, OFFSET_ALL, OFFSET_MIDFRONT)



# KROrder Mapping from LibraryCore/Libraries.cs
KR_ORDER = {
    0: "tilesc",
    1: "tiles30c",
    2: "tiles5c",
    3: "smtilesc",
    4: "housesc",
    5: "cliffsc",
    6: "dungeonsc",
    7: "innersc",
    8: "furnituresc",
    9: "wallsc",
    10: "smobjectsc",
    11: "animationsc",
    12: "object1c",
    13: "object2c",

    15: "wood_tilesc",
    16: "wood_tiles30c",
    17: "wood_tiles5c",
    18: "wood_smtilesc",
    19: "wood_housesc",
    20: "wood_cliffsc",
    21: "wood_dungeonsc",
    22: "wood_innersc",
    23: "wood_furnituresc",
    24: "wood_wallsc",
    25: "wood_smobjectsc",
    26: "wood_animationsc",

    30: "sand_tilesc",
    31: "sand_tiles30c",
    32: "sand_tiles5c",
    33: "sand_smtilesc",
    34: "sand_housesc",
    35: "sand_cliffsc",
    36: "sand_dungeonsc",
    37: "sand_innersc",
    38: "sand_furnituresc",
    39: "sand_wallsc",
    40: "sand_smobjectsc",
    41: "sand_animationsc",

    45: "snow_tilesc",
    46: "snow_tiles30c",
    47: "snow_tiles5c",
    48: "snow_smtilesc",
    49: "snow_housesc",
    50: "snow_cliffsc",
    51: "snow_dungeonsc",
    52: "snow_innersc",
    53: "snow_furnituresc",
    54: "snow_wallsc",
    55: "snow_smobjectsc",
    56: "snow_animationsc",

    60: "forest_tilesc",
    61: "forest_tiles30c",
    62: "forest_tiles5c",
    63: "forest_smtilesc",
    64: "forest_housesc",
    65: "forest_cliffsc",
    66: "forest_dungeonsc",
    67: "forest_innersc",
    68: "forest_furnituresc",
    69: "forest_wallsc",
    70: "forest_smobjectsc",
    71: "forest_animationsc",
    # Zircon client custom Sabak package; 3.map uses this slot in all layers.
    200: "sabak",
}


