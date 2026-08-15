"""mapedit.editstate — 编辑会话与保存管线（E1 任务 4/5）。

每张图一个编辑会话（互斥锁保护）：
  - parse_map 一次持有 cells 矩阵 + 原文件 bytes（serialize 模板）
  - 撤销/重做栈：每步 = [(x, y, field, old, new), ...]（笔刷一步多条目）
  - 脏计数 = 会话内已应用的编辑步数

保存管线（副本 → 独立验证 → 备份 → 原子替换 → 缓存失效）：
  1. serialize_map(template=原文件) → 写 <name>.map.new（同目录）
  2. 独立验证（§0 铁律）：map_roundtrip.indep_parse 是完全独立的解析实现；
     对「原文件 + 编辑日志」独立重放得到的期望语义，与 indep_parse(新文件)
     逐格比对；同时确认未编辑记录字节零变化（serialize 模板补丁的承诺）。
  3. 备份原文件 → <name>.map.bak-<YYYYmmdd-HHMMSS>（保留链，不覆盖）
  4. os.replace 原子替换 .map.new → <name>.map（同文件系统，原子性由内核保证）
  5. 失效 MapCache（下次 get 重解析）+ 瓦片/全图磁盘缓存目录清除

任何一步失败：原文件不动，.map.new 留检（或删除），异常上抛给 API 层。
"""
from __future__ import annotations

import os
import shutil
import threading
import time

from mapedit.mapio import MapCache, parse_map, serialize_map

# 独立验证用（铁律：不复用生产解析逻辑）
import importlib.util as _ilu

_SPEC = _ilu.spec_from_file_location(
    "map_roundtrip", os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), "map_roundtrip.py"))
_rt = _ilu.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_rt)
indep_parse = _rt.indep_parse

FIELDS = ("back_file", "back_img", "mid_file", "mid_img",
          "front_file", "front_img", "flag", "anim_a", "anim_b")
U8_FIELDS = {"back_file", "mid_file", "front_file", "flag", "anim_a", "anim_b"}
U16_FIELDS = {"back_img", "mid_img", "front_img"}
MAX_UNDO = 400


class EditError(Exception):
    pass


class EditSession:
    def __init__(self, map_path: str):
        self.path = map_path
        with open(map_path, "rb") as f:
            self.template = f.read()
        self.w, self.h, self.cells = parse_map(map_path)
        self.undo: list[list[tuple]] = []   # 每步 [(x,y,field,old,new),...]
        self.redo: list[list[tuple]] = []
        self.dirty = 0                      # 已应用步数（未保存）
        self.log: list[tuple] = []          # 全量编辑日志 (x,y,field,old,new)

    def in_bounds(self, x: int, y: int) -> bool:
        return 0 <= x < self.w and 0 <= y < self.h

    def apply(self, edits: list[dict]) -> list[tuple]:
        """应用一批格编辑（一个撤销步）。edits: [{x,y,field:value},...]

        field 省略 = 保持不变；非法字段/越界/超范围值立即拒绝（整批原子：
        先全部校验，再全部应用）。
        """
        plan: list[tuple] = []
        for e in edits:
            x, y = int(e.get("x", -1)), int(e.get("y", -1))
            if not self.in_bounds(x, y):
                raise EditError(f"越界 ({x},{y})")
            fields = e.get("fields") or {}
            if not fields:
                continue
            for field, value in fields.items():
                if field not in FIELDS:
                    raise EditError(f"未知字段 {field}")
                value = int(value)
                if field in U8_FIELDS and not (0 <= value <= 255):
                    raise EditError(f"{field} 超范围: {value}")
                if field in U16_FIELDS and not (0 <= value <= 65535):
                    raise EditError(f"{field} 超范围: {value}")
                old = getattr(self.cells[x][y], field)
                if old != value:
                    plan.append((x, y, field, old, value))
        if not plan:
            return []
        for x, y, field, old, new in plan:
            setattr(self.cells[x][y], field, new)
        self.undo.append(plan)
        if len(self.undo) > MAX_UNDO:
            self.undo.pop(0)
        self.redo.clear()
        self.dirty += 1
        self.log.extend(plan)
        return plan

    def step_undo(self) -> int:
        if not self.undo:
            return 0
        plan = self.undo.pop()
        for x, y, field, old, new in reversed(plan):
            setattr(self.cells[x][y], field, old)
        self.redo.append(plan)
        self.dirty -= 1
        return len(plan)

    def step_redo(self) -> int:
        if not self.redo:
            return 0
        plan = self.redo.pop()
        for x, y, field, old, new in plan:
            setattr(self.cells[x][y], field, new)
        self.undo.append(plan)
        self.dirty += 1
        return len(plan)

    def cell_dict(self, x: int, y: int) -> dict:
        c = self.cells[x][y]
        return {"x": x, "y": y, **{f: getattr(c, f) for f in FIELDS}}

    def brush(self, x0: int, y0: int, x1: int, y1: int, fields: dict,
              src: tuple | None = None) -> int:
        """矩形笔刷（一个撤销步）。

        src=(x,y) 时为同值替换：只改矩形内与源格三图层（file+img）完全
        相同的格；fields 仍为面板目标值。返回实际改动的字段数。
        """
        if not (0 <= x0 <= x1 < self.w and 0 <= y0 <= y1 < self.h):
            raise EditError(f"矩形越界 ({x0},{y0})-({x1},{y1})")
        if (x1 - x0 + 1) * (y1 - y0 + 1) > 20000:
            raise EditError("矩形过大（>20000 格）")
        sig_src = None
        if src:
            sx, sy = src
            if not self.in_bounds(sx, sy):
                raise EditError(f"源格越界 ({sx},{sy})")
            sig_src = (self.cells[sx][sy].back_file, self.cells[sx][sy].back_img,
                       self.cells[sx][sy].mid_file, self.cells[sx][sy].mid_img,
                       self.cells[sx][sy].front_file, self.cells[sx][sy].front_img)
        edits = []
        for x in range(x0, x1 + 1):
            for y in range(y0, y1 + 1):
                if sig_src is not None:
                    c = self.cells[x][y]
                    if (c.back_file, c.back_img, c.mid_file, c.mid_img,
                            c.front_file, c.front_img) != sig_src:
                        continue
                edits.append({"x": x, "y": y, "fields": fields})
        if not edits:
            return 0


def _expect_from_log(template: bytes, w: int, h: int,
                     log: list[tuple]) -> "_rt.IndepMap":
    m = indep_parse(template)
    for x, y, field, _old, new in log:
        i = x * h + y
        getattr(m, field)[i] = new
    return m


def save_session(s: EditSession, confirm: bool = False) -> dict:
    """保存管线（见模块头）。confirm=True 用于 API 层的显式确认参数。"""
    if not confirm:
        raise EditError("需要 confirm=true（显式确认覆盖原文件）")
    new_path = s.path + ".new"
    data = serialize_map(s.w, s.h, s.cells, template=s.template)

    # 1) 副本落盘
    tmp = new_path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, new_path)

    # 2) 独立验证：期望（原文件+日志重放） vs 实际（indep_parse(新文件)）
    expect = _expect_from_log(s.template, s.w, s.h, s.log)
    got = indep_parse(open(new_path, "rb").read())
    errs = []
    if (expect.w, expect.h) != (got.w, got.h):
        errs.append(f"尺寸 {expect.w}x{expect.h} != {got.w}x{got.h}")
    for field in FIELDS:
        ea, ga = getattr(expect, field), getattr(got, field)
        bad = next((i for i in range(expect.n) if ea[i] != ga[i]), None)
        if bad is not None:
            x, y = divmod(bad, expect.h)
            errs.append(f"{field} @({x},{y}) 期望 {ea[bad]} 实得 {ga[bad]}")
    # 未编辑字节零变化（模板补丁承诺：diff 仅允许命中已编辑记录的前 9 字节）
    touched = {x * s.h + y for x, y, *_ in s.log}
    seg1 = (s.w // 2) * (s.h // 2) * 3
    base = 28 + seg1
    allowed = set()
    for i in touched:
        allowed.update(base + i * 14 + d for d in range(9))
    raw = s.template
    stray = [k for k in range(min(len(raw), len(data)))
             if raw[k] != data[k] and k not in allowed]
    if stray:
        errs.append(f"区域外字节变化 {len(stray)} 处，首处 @{stray[0]}")
    if errs:
        os.remove(new_path)
        raise EditError("独立验证失败: " + "; ".join(errs[:6]))

    # 3) 备份（保留链） 4) 原子替换
    stamp = time.strftime("%Y%m%d-%H%M%S")
    bak = f"{s.path}.bak-{stamp}"
    shutil.copy2(s.path, bak)
    os.replace(new_path, s.path)

    # 5) 缓存失效
    s.template = data          # 保存后新基线 = 已保存内容
    s.log.clear()
    s.dirty = 0
    return {"backup": bak, "bytes": len(data)}


def invalidate_caches(cache_dir: str, map_name: str) -> None:
    """清该图瓦片/全图磁盘缓存（cache_dir/<safe>/ 整目录）。"""
    if not cache_dir:
        return
    safe = map_name.replace("/", "_").replace("\\", "_")
    shutil.rmtree(os.path.join(cache_dir, safe), ignore_errors=True)


class SessionMapCache:
    """MapCache 适配器：让 render_tile/render_full_map 渲染编辑会话的
    （可能未保存的）cells 矩阵。只实现两个被渲染管线消费的方法：
    get(name) 与 sparse_slice(name, wx0, wx1, wy0, wy1, margin, layout)。
    """

    def __init__(self, sess: EditSession):
        self.sess = sess

    def get(self, name: str):
        return self.sess.w, self.sess.h, self.sess.cells

    def sparse_slice(self, name, wx0, wx1, wy0, wy1, margin=512,
                     layout="rect"):
        w, h, cells = self.get(name)
        if layout == "iso":
            buckets = [[] for _ in range(w + h - 1)]
            for x in range(w):
                for y in range(h):
                    c = cells[x][y]
                    if c.back_file != 255 or c.mid_file != 255 or c.front_file != 255:
                        buckets[x + y].append((x, c))
            cx_lo = wx0 - margin - h * 24 - 24
            cx_hi = wx1 + margin - h * 24 - 24
            s0 = max(0, (wy0 - margin - 16 + 15) // 16)
            s1 = min(len(buckets) - 1, (wy1 + margin - 16) // 16)
            for s in range(s0, s1 + 1):
                x0 = (cx_lo + s * 24 + 47) // 48
                x1 = (cx_hi + s * 24) // 48
                for x, c in buckets[s]:
                    if x0 <= x <= x1:
                        yield x, s - x, c
            return
        x0 = max(0, (wx0 - margin) // 48)
        x1 = min(w - 1, (wx1 + margin - 1) // 48)
        y0 = max(0, (wy0 - margin) // 32)
        y1 = min(h - 1, (wy1 + margin - 1) // 32)
        for x in range(x0, x1 + 1):
            col = cells[x]
            for y in range(y0, y1 + 1):
                c = col[y]
                if c.back_file != 255 or c.mid_file != 255 or c.front_file != 255:
                    yield x, y, c
