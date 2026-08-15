#!/usr/bin/env python3
"""mapedit.mapio — .map 二进制解析与单元矩阵（MapCell / parse_map / MapCache）。"""
from __future__ import annotations
import os
import struct
import threading

from mapedit.constants import (CACHE_MAPS_MAX, LAYOUT_ISO, LAYOUT_RECT)

# ------------------------------------------------------------------- .map I/O

class MapCell:
    __slots__ = ('back_file', 'back_img', 'mid_file', 'mid_img', 'front_file', 'front_img',
                 'flag', 'anim_a', 'anim_b')

    def __init__(self):
        self.back_file = 255
        self.back_img = 0
        self.mid_file = 255
        self.mid_img = 0
        self.front_file = 255
        self.front_img = 0
        self.flag = 0
        self.anim_a = 0xFF
        self.anim_b = 0xFF


def parse_map_header(path: str) -> tuple[int, int]:
    with open(path, "rb") as f:
        hdr = f.read(28)
    w = struct.unpack_from("<H", hdr, 22)[0]
    h = struct.unpack_from("<H", hdr, 24)[0]
    return w, h


def parse_map(path: str) -> tuple[int, int, list[list[MapCell]]]:
    """Parse Zircon / Mir3 EI .map file into cell matrix Cells[Width][Height]."""
    with open(path, "rb") as f:
        data = f.read()

    w = struct.unpack_from("<H", data, 22)[0]
    h = struct.unpack_from("<H", data, 24)[0]

    cells = [[MapCell() for _ in range(h)] for _ in range(w)]

    offset = 28
    # Segment 1: Back (Ground) layer (Half-res, 3 bytes per entry for even cells)
    for x in range(w // 2):
        for y in range(h // 2):
            bf = data[offset]
            bi = struct.unpack_from("<H", data, offset + 1)[0]
            offset += 3
            cells[x * 2][y * 2].back_file = bf
            cells[x * 2][y * 2].back_img = bi

    # Segment 2: Full-res Cells (14 bytes each).  This segment follows the
    # half-resolution Back table; restarting at offset 28 would interpret
    # Back bytes as flags/library ids and produces a mostly black map.
    cell_base = offset
    n_cells = min(w * h, max(0, (len(data) - cell_base) // 14))
    for i in range(n_cells):
        x, y = divmod(i, h)
        offset = cell_base + i * 14
        # cell structure:
        # 0: flag, 1: midAnim, 2: frontAnim, 3: frontFile, 4: midFile
        # 5-6: midImg (uint16), 7-8: frontImg (uint16), 9+: unused/padding
        ff = data[offset + 3]
        mf = data[offset + 4]
        mi = struct.unpack_from("<H", data, offset + 5)[0]
        fi = struct.unpack_from("<H", data, offset + 7)[0]

        c = cells[x][y]
        c.flag = data[offset]
        c.anim_a = data[offset + 1]
        c.anim_b = data[offset + 2]
        c.mid_file = mf
        c.mid_img = mi
        c.front_file = ff
        c.front_img = fi

    return w, h, cells


class MapCache:
    """LRU of parsed maps + two cell indexes.

    Index A (iso): cells bucketed by s = x + y (isometric screen row),
    within a bucket sorted by x.  Index B (rect): cells bucketed by x,
    within a bucket sorted by y — used for the axis-aligned (original)
    projection where a tile window is a plain x/y rectangle.
    """

    def __init__(self, maps_dir: str, max_keep: int = CACHE_MAPS_MAX):
        self.maps_dir = maps_dir
        self.max_keep = max_keep
        self._store: dict[str, tuple[int, int, list[list[MapCell]]]] = {}
        self._buckets: dict[str, list[list[tuple[int, MapCell]]]] = {}
        self._bxs: dict[str, list[list[int]]] = {}
        self._rows: dict[str, list[list[tuple[int, MapCell]]]] = {}
        self._rys: dict[str, list[list[int]]] = {}
        self._lock = threading.Lock()
        self._build_locks: dict[str, threading.Lock] = {}

    def _build_lock(self, name: str) -> threading.Lock:
        with self._lock:
            lk = self._build_locks.get(name)
            if lk is None:
                lk = self._build_locks[name] = threading.Lock()
            return lk

    def get(self, name: str) -> tuple[int, int, list[list[MapCell]]]:
        """Parse (once) and return (w, h, cells). Never holds the global lock
        while parsing, so concurrent tile requests are not serialized on a
        slow first parse."""
        with self._lock:
            entry = self._store.get(name)
        if entry is None:
            with self._build_lock(name):
                with self._lock:
                    entry = self._store.get(name)
                if entry is None:
                    entry = parse_map(os.path.join(self.maps_dir, name))
                    with self._lock:
                        self._store[name] = entry
                        while len(self._store) > self.max_keep:
                            k = next(iter(self._store))
                            self._store.pop(k)
                            self._buckets.pop(k, None)
                            self._bxs.pop(k, None)
                            self._rows.pop(k, None)
                            self._rys.pop(k, None)
        return self._store[name]

    def sparse(self, name: str) -> tuple[list, list]:
        """(buckets, bxs): buckets[s] = [(x, cell), ...] sorted by x, with
        parallel x-only lists for bisect. s = x + y in [0, w+h-2]."""
        with self._lock:
            buckets = self._buckets.get(name)
            bxs = self._bxs.get(name)
        if buckets is None:
            entry = self.get(name)  # ensure parsed; may block on the parse lock
            with self._build_lock(name):
                with self._lock:
                    buckets = self._buckets.get(name)
                if buckets is None:
                    w, h, cells = entry
                    buckets = [[] for _ in range(w + h - 1)]
                    for x in range(w):
                        for y in range(h):
                            c = cells[x][y]
                            if c.back_file != 255 or c.mid_file != 255 or c.front_file != 255:
                                buckets[x + y].append((x, c))
                    bxs = []
                    for b in buckets:
                        b.sort(key=lambda t: t[0])
                        bxs.append([t[0] for t in b])
                    with self._lock:
                        self._buckets[name] = buckets
                        self._bxs[name] = bxs
        return self._buckets[name], self._bxs[name]

    def sparse_rows(self, name: str) -> tuple[list, list]:
        """(rows, rys): rows[x] = [(y, cell), ...] sorted by y, with parallel
        y-only lists for bisect.  Used by the axis-aligned (rect) layout."""
        with self._lock:
            rows = self._rows.get(name)
            rys = self._rys.get(name)
        if rows is None:
            entry = self.get(name)
            with self._build_lock(name):
                with self._lock:
                    rows = self._rows.get(name)
                if rows is None:
                    w, h, cells = entry
                    rows = [[] for _ in range(w)]
                    for x in range(w):
                        for y in range(h):
                            c = cells[x][y]
                            if c.back_file != 255 or c.mid_file != 255 or c.front_file != 255:
                                rows[x].append((y, c))
                    rys = []
                    for r in rows:
                        r.sort(key=lambda t: t[0])
                        rys.append([t[0] for t in r])
                    with self._lock:
                        self._rows[name] = rows
                        self._rys[name] = rys
        return self._rows[name], self._rys[name]

    def sparse_slice(self, name: str, wx0: int, wx1: int, wy0: int, wy1: int,
                     margin: int = 512, layout: str = LAYOUT_RECT):
        """Yield (x, y, cell) for every non-empty cell whose anchor lies inside
        [wx0-margin, wx1+margin] x [wy0-margin, wy1+margin] (world px)."""
        import bisect
        w, h, _ = self.get(name)
        if layout == LAYOUT_ISO:
            buckets, bxs = self.sparse(name)
            # screen rows: cy = s*16 + 16 must intersect [wy0-margin, wy1+margin]
            s0 = max(0, (wy0 - margin - 16 + 15) // 16)
            s1 = min(len(buckets) - 1, (wy1 + margin - 16) // 16)
            # per-row screen x: cx = (2x - s)*24 + h*24 + 24
            cx_lo = wx0 - margin - h * 24 - 24
            cx_hi = wx1 + margin - h * 24 - 24
            for s in range(s0, s1 + 1):
                xs = bxs[s]
                x0 = (cx_lo + s * 24 + 47) // 48  # ceil
                x1 = (cx_hi + s * 24) // 48       # floor
                i0 = bisect.bisect_left(xs, x0)
                i1 = bisect.bisect_right(xs, x1)
                if i0 >= i1:
                    continue
                bucket = buckets[s]
                for k in range(i0, i1):
                    x, c = bucket[k]
                    yield x, s - x, c
            return

        rows, rys = self.sparse_rows(name)
        x0 = max(0, (wx0 - margin) // 48)
        x1 = min(w - 1, (wx1 + margin - 1) // 48)
        y0 = max(0, (wy0 - margin) // 32)
        y1 = min(h - 1, (wy1 + margin - 1) // 32)
        for x in range(x0, x1 + 1):
            ys = rys[x]
            i0 = bisect.bisect_left(ys, y0)
            i1 = bisect.bisect_right(ys, y1)
            if i0 >= i1:
                continue
            row = rows[x]
            for k in range(i0, i1):
                y, c = row[k]
                yield x, y, c


