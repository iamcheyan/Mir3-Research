#!/usr/bin/env python3
"""mapedit.prewarm — 后台预渲染守护线程（瓦片/缩略图）。"""
from __future__ import annotations
import os
import threading
import time

from mapedit.api import TILE_PREWARM, _TILE_INTERACTIVE, ViewerHandler
from mapedit.constants import LAYOUT_RECT, OFFSET_NONE
from mapedit.data import scan_maps
from mapedit.frames import FramePool
from mapedit.render import (_get_pool, _render_tile_worker, tile_cache_path)

def prewarm_tiles(maps_dir: str, data_dir: str, cache_dir: str,
                  layout: str = LAYOUT_RECT, layers: tuple = (True, True, True),
                  offset_mode: str = OFFSET_NONE) -> None:
    """后台守护线程：把瓦片模式 (z=1 全量 -> z=0 全量) 预渲染进磁盘缓存。

    拖拽卡顿的根因是冷瓦片现场渲染（纯 Python 解码 0.8~9s/块）。磁盘缓存
    本就永久生效（.tilecache-v3），这里只是提前把全库 627 张地图的瓦片
    批量生成完：只补缺失文件，进程池并行（worker 各持 MapCache/FramePool，
    复用 render_tile），主进程只落盘。重启时已完成的直接跳过。
    只生成默认视图组合（g/m/f 全开、无 offset 实验），其它组合按需渲染。"""
    if not cache_dir:
        return

    def work():
        try:
            g, m_, f_ = layers   # 默认图层组合 (全开)
            maps = sorted(scan_maps(maps_dir, layout),
                          key=lambda m: m["world_w"] * m["world_h"])
            # 待办清单: [(map_path, key, disk_path)]; z0 (1:1 拖拽主视图) 优先, z1 随后
            todo = []
            for z in (0, 1):
                for m in maps:
                    tw = m["world_w"] // 512 + 1
                    th = m["world_h"] // 512 + 1
                    for ty in range(th):
                        for tx in range(tw):
                            dp = tile_cache_path(cache_dir, layout, m["name"],
                                                 tx, ty, z, g, m_, f_, offset_mode)
                            if not os.path.exists(dp):
                                todo.append((os.path.join(maps_dir, m["name"]),
                                             (m["name"], tx, ty, z, layout, offset_mode),
                                             dp))
            if not todo:
                print("[*] Tile prewarm: cache already complete")
                return
            print(f"[*] Tile prewarm: {len(todo)} tiles to render "
                  f"({len(maps)} maps, z1+z0, {layout})")
            TILE_PREWARM.update(running=True, total=len(todo), current=0,
                                done=0, failed=0, percent=0, current_map="")
            pool = _get_pool(data_dir)   # 慢池: nice(5), 后台专用
            # 交互优先调度:
            # 1) 用户正在浏览的地图 (focus) 插队 — 拖到哪, 哪先变热;
            # 2) 交互冷块在途时暂停提交新任务 (focus 除外 — 它直接服务
            #    用户接下来的拖拽), 把 CPU 让给用户正在等的那批瓦片;
            # 3) 提交前复查磁盘, 交互请求顺手渲染过的直接跳过。
            WINDOW = 3
            pending: list = []          # [(future, key, dp)]
            by_map: dict = {}           # map_name -> [todo 索引]
            for i, (_, key, _) in enumerate(todo):
                by_map.setdefault(key[0], []).append(i)
            seq = 0                     # 顺序指针 (面积升序兜底)
            focus_q: list = []
            last_focus = None
            done_idx: set = set()

            def pick_next():
                nonlocal seq, last_focus, focus_q
                fm = TILE_PREWARM.get("focus") or ""
                if fm and fm in by_map and fm != last_focus:
                    last_focus = fm
                    focus_q = [i for i in by_map[fm] if i not in done_idx]
                while focus_q:
                    i = focus_q.pop(0)
                    if i not in done_idx:
                        return i
                while seq < len(todo):
                    i = seq
                    seq += 1
                    if i not in done_idx:
                        return i
                return None

            def focus_pending():
                fm = TILE_PREWARM.get("focus") or ""
                return fm in by_map and any(i not in done_idx
                                             for i in by_map.get(fm, ()))

            while True:
                yield_since = None
                while _TILE_INTERACTIVE[0] > 0:
                    # 交互潮期间完全让路 (交互冷块是用户正在等的);
                    # 仅当用户连续浏览超 45s (马拉松拖拽) 才恢复 focus
                    # 跟进, 让后台追上用户即将到达的区域。
                    if yield_since is None:
                        yield_since = time.time()
                    elif (time.time() - yield_since > 45
                          and focus_pending()):
                        break
                    time.sleep(0.2)
                while len(pending) < WINDOW:
                    i = pick_next()
                    if i is None:
                        break
                    mp, key, dp = todo[i]
                    done_idx.add(i)
                    if os.path.exists(dp):   # 交互请求已顺手渲染
                        TILE_PREWARM["current"] += 1
                        TILE_PREWARM["done"] += 1
                        TILE_PREWARM["percent"] = int(
                            TILE_PREWARM["current"] / len(todo) * 100)
                        continue
                    pending.append((pool.submit(_render_tile_worker, (mp, key)),
                                    key, dp))
                if not pending:
                    break
                fut, key, dp = pending.pop(0)
                try:
                    res = fut.result()
                    if res:
                        _, data = res
                        os.makedirs(os.path.dirname(dp), exist_ok=True)
                        tmp = dp + ".tmp"
                        with open(tmp, "wb") as fh:
                            fh.write(data)
                        os.replace(tmp, dp)
                        TILE_PREWARM["done"] += 1
                    else:
                        TILE_PREWARM["failed"] += 1
                except Exception:
                    TILE_PREWARM["failed"] += 1
                TILE_PREWARM["current"] += 1
                TILE_PREWARM["percent"] = int(TILE_PREWARM["current"] / len(todo) * 100)
                TILE_PREWARM["current_map"] = f"{key[0]} z{key[3]} ({key[1]},{key[2]})"
            TILE_PREWARM.update(running=False, current_map="完成",
                                percent=100)
            print(f"[*] Tile prewarm done: {TILE_PREWARM['done']} rendered, "
                  f"{TILE_PREWARM['failed']} failed")
        except Exception as ex:
            TILE_PREWARM["running"] = False
            print(f"[!] Tile prewarm disabled: {ex}")

    threading.Thread(target=work, daemon=True, name="tile-prewarm").start()




def prewarm_thumbs(maps_dir: str, data_dir: str, thumbs_dir: str) -> None:
    """后台守护线程：为总览视图逐张预渲染缩略图（/tmp/wiki_thumbs，磁盘缓存）。

    只渲染缺失项，已存在的跳过；与 /thumb 端点共享 per-map 渲染锁避免并发
    写坏 PNG。"""
    def work():
        try:
            from thumb_gen import render_one, MapCache13
            mc = MapCache13(maps_dir, max_keep=4)
            pool = FramePool(data_dir)
            names = sorted(f for f in os.listdir(maps_dir) if f.lower().endswith(".map"))
            done = 0
            for name in names:
                out = os.path.join(thumbs_dir, name + ".png")
                if os.path.exists(out):
                    continue
                lock = ViewerHandler._render_lock(("thumb", name))
                try:
                    with lock:
                        if os.path.exists(out):
                            continue
                        w, h, _ = mc.get(name)
                        render_one(mc, pool, thumbs_dir, name, w, h)
                        done += 1
                except Exception as ex:
                    print(f"[!] thumb prewarm {name}: {ex}")
            if done:
                print(f"[*] Thumb prewarm: {done} new thumbnails rendered")
        except Exception as ex:
            print(f"[!] Thumb prewarm disabled: {ex}")

    threading.Thread(target=work, daemon=True, name="thumb-prewarm").start()


