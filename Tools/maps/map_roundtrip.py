#!/usr/bin/env python3
"""map_roundtrip.py — .map 往返验证工具（E1 任务 3，§0 铁律：验证逻辑独立实现）。

被验证对象：生产管线 parse_map / serialize_map（mapedit.mapio）。
验证手段：本工具自带一套**完全独立**的解析实现（array 平铺 + 手工字节
索引，不复用 mapedit 的 struct.unpack_from + MapCell 对象模型），用它做
三重判定（20 张图，含动画格/边界尺寸/截断文件）：

  A 字节级  serialize(parse(f), template=f) == f
           （模板补丁策略：未建模字节 Light@+12/填充/头 22B/截断长度全保留）
  B 语义级  indep_parse(f) == indep_parse(serialize(parse(f), template=None))
           （parse∘serialize 严格互逆，无模板时尾 5 字节为 0 但不影响语义字段）
  C 编辑钻  改 1 格（flag+mid 三字段）→ serialize(template) → indep_parse：
           仅目标字段变化；尾 5 字节与其它全部字节逐字节不变
           （保存管线真实用法：改格不产生附带损伤）

任一失败退出码 1。--json 输出机读报告。

用法:
  python3 Tools/maps/map_roundtrip.py [--maps-dir DIR] [--count 20] [--json OUT]
"""
import argparse
import hashlib
import json
import os
import sys
from array import array

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

# 生产管线（被验证对象；验证逻辑不使用它）
from mapviewer import parse_map, serialize_map  # noqa: E402

FIELDS = ("back_file", "back_img", "mid_file", "mid_img",
          "front_file", "front_img", "flag", "anim_a", "anim_b")


class IndepMap:
    """独立解析结果：平铺 array（与生产的嵌套 MapCell 对象模型刻意不同）。

    索引：cell i = x*Height + y（列优先，与磁盘记录顺序一致）。
    back 层只有偶格有值（半分辨率表），奇格 back_file=255。
    """

    __slots__ = ("w", "h", "n", "back_file", "back_img", "mid_file",
                 "mid_img", "front_file", "front_img", "flag", "anim_a",
                 "anim_b", "n_records", "tail", "sha")

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.n = w * h
        self.back_file = bytearray(self.n)
        self.back_img = array("H", bytes(2 * self.n))
        self.mid_file = bytearray(self.n)
        self.mid_img = array("H", bytes(2 * self.n))
        self.front_file = bytearray(self.n)
        self.front_img = array("H", bytes(2 * self.n))
        self.flag = bytearray(self.n)
        self.anim_a = bytearray(self.n)
        self.anim_b = bytearray(self.n)
        for i in range(self.n):          # 与生产 MapCell 默认值对齐的空态
            self.back_file[i] = 255
            self.mid_file[i] = 255
            self.front_file[i] = 255
            self.anim_a[i] = 255
            self.anim_b[i] = 255
        self.n_records = 0
        self.tail = None                 # 每记录尾 5 字节（+9..+13）快照
        self.sha = None


def indep_parse(path_or_bytes) -> IndepMap:
    """独立 .map 解析：手工字节索引，不用 struct/MapCell。"""
    if isinstance(path_or_bytes, (bytes, bytearray)):
        data = bytes(path_or_bytes)
    else:
        with open(path_or_bytes, "rb") as f:
            data = f.read()
    if len(data) < 28:
        raise ValueError("shorter than header")
    w = data[22] | (data[23] << 8)       # little-endian u16 手工拼
    h = data[24] | (data[25] << 8)
    if w == 0 or h == 0:
        raise ValueError("zero dimension")
    seg1 = (w // 2) * (h // 2) * 3
    if len(data) < 28 + seg1:
        raise ValueError("truncated segment-1")
    m = IndepMap(w, h)
    # 段1：back 半分辨率表（3B/项）
    off = 28
    for bx in range(w // 2):
        for by in range(h // 2):
            bf = data[off]
            bi = data[off + 1] | (data[off + 2] << 8)
            m.back_file[(bx * 2) * h + (by * 2)] = bf
            m.back_img[(bx * 2) * h + (by * 2)] = bi
            off += 3
    # 段2：全分辨率记录（14B/格，列优先）
    n_records = (len(data) - 28 - seg1) // 14
    m.n_records = n_records
    m.tail = [None] * m.n
    for i in range(min(n_records, m.n)):
        o = 28 + seg1 + i * 14
        m.flag[i] = data[o]
        m.anim_a[i] = data[o + 1]
        m.anim_b[i] = data[o + 2]
        m.front_file[i] = data[o + 3]
        m.mid_file[i] = data[o + 4]
        m.mid_img[i] = data[o + 5] | (data[o + 6] << 8)
        m.front_img[i] = data[o + 7] | (data[o + 8] << 8)
        m.tail[i] = data[o + 9:o + 14]
    m.sha = hashlib.sha256(data).hexdigest()
    return m


def first_diffs(a: IndepMap, b: IndepMap, limit: int = 5) -> list[str]:
    """两份独立解析结果的语义差异（字段级，最多 limit 条）。

    记录数差异不在此判定（截断图的 canonical 补全由 verify_one 上下文判定）。
    """
    errs = []
    if (a.w, a.h) != (b.w, b.h):
        return [f"尺寸 {a.w}x{a.h} != {b.w}x{b.h}"]
    for f in FIELDS:
        fa, fb = getattr(a, f), getattr(b, f)
        shown = 0
        for i in range(a.n):
            if fa[i] != fb[i]:
                x, y = divmod(i, a.h)
                errs.append(f"{f} @({x},{y}) {fa[i]} != {fb[i]}")
                shown += 1
                if shown >= limit:
                    errs.append(f"{f}: ……(仅示前 {limit} 条)")
                    break
    return errs


def pick_maps(maps_dir: str, count: int) -> list[str]:
    """确定性抽样：固定名单（含截断/动画/大小极值）+ 语义扫描补足。"""
    fixed = ["0.map", "3.map", "11.map", "00.map", "D0002_001.map", "z014.map",
             "kt0005.map", "D601.map", "d608.map", "0_0031.map"]
    names = sorted(f for f in os.listdir(maps_dir) if f.lower().endswith(".map"))
    fixed = [f for f in fixed if f in names]
    info = {}
    for fn in names:
        p = os.path.join(maps_dir, fn)
        with open(p, "rb") as fh:
            head = fh.read(28)
            fh.seek(0, 2)
            size = fh.tell()
        w = head[22] | (head[23] << 8)
        h = head[24] | (head[25] << 8)
        info[fn] = (w, h, size)
    by_area = sorted(names, key=lambda n: info[n][0] * info[n][1])
    extra = []
    if by_area:
        extra += [by_area[0], by_area[-1]]
    truncated = [n for n in names
                 if info[n][2] < 28 + (info[n][0] // 2) * (info[n][1] // 2) * 3
                 + info[n][0] * info[n][1] * 14]
    for n in truncated[:2]:
        if n not in fixed + extra:
            extra.append(n)
    out = fixed + [n for n in extra if n not in fixed]
    i = 0
    while len(out) < count and i < len(names):
        if names[i] not in out:
            out.append(names[i])
        i += 1
    return out[:max(count, len(fixed))]


def verify_one(maps_dir: str, name: str) -> dict:
    path = os.path.join(maps_dir, name)
    with open(path, "rb") as f:
        raw = f.read()
    res = {"map": name, "A_byte_exact": None, "B_semantic": None,
           "C_edit_drill": None, "errors": [], "anim_cells": 0, "truncated": False}

    w, h, cells = parse_map(path)

    # A 字节级（模板补丁）
    out_a = serialize_map(w, h, cells, template=raw)
    res["A_byte_exact"] = (hashlib.sha256(out_a).hexdigest()
                           == hashlib.sha256(raw).hexdigest())

    # B 语义级（无模板 → canonical 零尾；语义字段必须互逆）
    # 记录数仅对非截断原图要求相等：截断图的尾部记录在磁盘上本不存在
    # （parse 已按默认值解析），canonical 序列化补全后语义仍等价 ——
    # 物理布局的保留由 A（模板字节级）与 C（区域外零变化）约束。
    out_b = serialize_map(w, h, cells)
    before_b, after_b = indep_parse(raw), indep_parse(out_b)
    berrs = first_diffs(before_b, after_b)
    if before_b.n_records < before_b.n and after_b.n_records != before_b.n:
        berrs.append(f"截断图 canonical 重序列化应补全到 {before_b.n} 条，"
                     f"实得 {after_b.n_records}")
    if before_b.n_records == before_b.n and after_b.n_records != before_b.n_records:
        berrs.append(f"记录数 {before_b.n_records} != {after_b.n_records}")
    res["B_semantic"] = not berrs
    res["errors"] += [f"B: {e}" for e in berrs]
    # C 编辑钻：改中心格 flag/mid_file/mid_img，其余必须逐字节不动
    cx, cy = w // 2, min(h // 2, h - 1)
    c = cells[cx][cy]
    old = (c.flag, c.mid_file, c.mid_img)
    c.flag, c.mid_file, c.mid_img = (c.flag ^ 0x03) & 0x03, 10, 777
    try:
        out_c = serialize_map(w, h, cells, template=raw)
        before, after = indep_parse(raw), indep_parse(out_c)
        errs = []
        i = cx * h + cy
        allowed = {"flag", "mid_file", "mid_img"}
        # 逐字段全量比对：目标格的 allowed 字段跳过（那正是编辑本身），
        # 其余任何字段/任何格的变化都是意外损伤。
        for f in FIELDS:
            fa, fb = getattr(before, f), getattr(after, f)
            shown = 0
            for j in range(before.n):
                if fa[j] == fb[j] or (j == i and f in allowed):
                    continue
                x, y = divmod(j, before.h)
                errs.append(f"C: 意外变化 {f} @({x},{y}) {fa[j]} != {fb[j]}")
                shown += 1
                if shown >= 5:
                    errs.append("C: ……(仅示前 5 条)")
                    break
        for f in sorted(allowed):        # 编辑必须真的生效
            if getattr(before, f)[i] == getattr(after, f)[i]:
                errs.append(f"C: 目标字段 {f} 未变化（编辑未生效）")
        # 尾字节：所有记录（含被编辑记录）的 +9..+13 必须原样保留
        for j in range(min(before.n_records, after.n_records)):
            if before.tail[j] != after.tail[j]:
                errs.append(f"C: 记录 {j} 尾 5 字节被改动（应原样保留）")
                break
        # 区域外字节零变化：diff 只允许落在目标记录前 9 字节
        diff_bytes = [k for k in range(len(raw)) if raw[k] != out_c[k]]
        seg1 = (w // 2) * (h // 2) * 3
        base = 28 + seg1
        rec = cx * h + cy
        allowed_region = {base + rec * 14 + d for d in range(9)}
        stray = [k for k in diff_bytes if k not in allowed_region]
        if stray:
            errs.append(f"C: 区域外字节变化 {len(stray)} 处，首处 @{stray[0]}")
        res["C_edit_drill"] = not errs
        res["errors"] += errs
    finally:
        c.flag, c.mid_file, c.mid_img = old

    # 元信息（抽样多样性核对）
    m = indep_parse(raw)
    res["anim_cells"] = sum(1 for i in range(m.n)
                            if m.anim_a[i] != 255 or m.anim_b[i] != 255)
    res["truncated"] = m.n_records < m.n
    return res


def main():
    ap = argparse.ArgumentParser(description=".map 往返验证（独立实现）")
    ap.add_argument("--maps-dir",
                    default=os.path.expanduser(
                        "~/development/zircon/Debug/Client/Map"))
    ap.add_argument("--count", type=int, default=20)
    ap.add_argument("--json", help="机读报告输出路径")
    args = ap.parse_args()

    names = pick_maps(args.maps_dir, args.count)
    print(f"[*] 抽样 {len(names)} 张: {names}")
    results = []
    for n in names:
        r = verify_one(args.maps_dir, n)
        ok = r["A_byte_exact"] and r["B_semantic"] and r["C_edit_drill"]
        print(f"  {'✓' if ok else '✗'} {n:16s} A字节={r['A_byte_exact']} "
              f"B语义={r['B_semantic']} C编辑={r['C_edit_drill']} "
              f"动画格={r['anim_cells']} 截断={r['truncated']}")
        for e in r["errors"]:
            print(f"      [!] {e}")
        results.append(r)

    n_anim = sum(1 for r in results if r["anim_cells"])
    n_trunc = sum(1 for r in results if r["truncated"])
    passed = sum(1 for r in results if r["A_byte_exact"] and r["B_semantic"]
                 and r["C_edit_drill"])
    print(f"[*] 结论: {passed}/{len(results)} 通过；含动画格 {n_anim} 张，"
          f"截断文件 {n_trunc} 张")
    if args.json:
        with open(args.json, "w", encoding="utf-8") as f:
            json.dump({"passed": passed, "total": len(results),
                       "anim_maps": n_anim, "truncated_maps": n_trunc,
                       "results": results}, f, ensure_ascii=False, indent=1)
    sys.exit(0 if passed == len(results) else 1)


if __name__ == "__main__":
    main()
