#!/usr/bin/env python3
"""mapviewer.py — 兼容垫片：实现已拆分到 Tools/maps/mapedit/ 包。

E1 拆模块（2026-08-15）：本文件从 5612 行实现退化为 re-export 垫片，
历史 API（十个兄弟工具 `import mapviewer` 依赖）全部保留、名字不变。
服务入口行为不变：`python3 mapviewer.py <Map目录> --port 8899`。
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
# mapedit/__init__ 会把 Tools/maps 塞进 sys.path（wilsdk/zlsdk/mapnames 平铺导入）
from mapedit import _HERE, _PARENT  # noqa: F401

from mapedit.constants import (CACHE_FRAMES_BYTES, CACHE_MAPS_MAX, CACHE_TILES_MAX,
                               CACHE_VERSION, DEFAULT_CACHE_MOUNT, DEFAULT_CACHE_ROOT,
                               DEFAULT_CLIENT_ROOT, DEFAULT_CONNECTIONS,
                               DEFAULT_DBWORKSPACE, DEFAULT_DB_NAMES, FIT_FULL_DIM,
                               KR_ORDER, LAYOUT_ISO, LAYOUT_RECT, MAP_CN, MAP_CN_FILE,
                               MAX_FULL_DIM, OFFSET_ALL, OFFSET_MIDFRONT,
                               OFFSET_MODES, OFFSET_NONE, THUMBS_DIR, TILE_SZ)
from mapedit.constants import _load_map_cn, default_tile_cache_dir, _nas_cache_available

from mapedit.mapio import MapCache, MapCell, parse_map, parse_map_header
from mapedit.frames import FramePool, _find_library_path
from mapedit.geom import cell_anchor, map_ladder, world_bounds
from mapedit.render import (LIB_IDS, PARALLEL_MIN_FRAMES, _blit,
                            _decode_frame_worker, _get_fast_pool, _get_pool,
                            _init_fast_worker, _init_worker, _render_tile_worker,
                            _sprite_opaque, is_object_library, render_full_map,
                            render_offset_strip, render_tile, tile_cache_path)
from mapedit.render import _FAST_POOL, _POOL, _POOL_MU  # noqa: F401
from mapedit.render import (_WORKER_DATA_DIR, _WORKER_LIBS, _WORKER_MC,  # noqa: F401
                            _WORKER_POOL)
from mapedit.minimap import (MINIMAP_EI_FILE, MINIMAP_EI_LIBS, MINIMAP_LIB_NAME,
                             MINIMAP_MAP_FILE, MiniMapSource, _minimap_index,
                             _minimap_index_ei)
from mapedit.data import (GUARD_LEVEL_CAP, GUARD_MONSTER_LIBS,
                          MIR_DIRECTION_INDEX, NPC_FUNC_RULES, SPAWN_STEMS,
                          _articulation_points, _region_block, _ws_rows,
                          api_maps_payload, build_atlas, level_tier,
                          load_catalog, load_connections, load_db_names,
                          load_drops, load_entities, load_workspace_connections,
                          load_workspace_entities, load_workspace_guards,
                          map_category, respawn_tier, scan_maps, write_map_links_v2)
from mapedit.data import _DROPS_CACHE  # noqa: F401
from mapedit.api import (BATCH_PROGRESS, KNOWN_CANDIDATE_ROOTS, TILE_PREWARM,  # noqa: F401
                         ViewerHTTPServer, ViewerHandler, get_client_roots)
from mapedit.api import _TILE_INTERACTIVE, _INTERACTIVE_LOCK  # noqa: F401
from mapedit.prewarm import prewarm_thumbs, prewarm_tiles
from mapedit.templates import HTML_TEMPLATE, SIM_TEMPLATE  # noqa: F401
from mapedit.api import main

if __name__ == "__main__":
    main()
