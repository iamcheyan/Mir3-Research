#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""compare_sync.py —— 同步后 round-trip 语义对比。

对比「导入器写出的 System.db 重导出」与「工作区」：
  - 只检查有改动的表（工作区 vs _baseline 有 diff 的表）；
  - 派生回链（reflist 且子表带回指 ref，如 ItemInfo.Drops）按 Index 集合比较（顺序无关）；
  - ref 对象只比 Index（Name 是展示字段，工作区与重导出的生成时机不同，身份链可能差一级）；
  - 其余字段严格相等；
  - MirDB 计数器与工作区 max+1 不一致时，导入器会重映射新行 Index 并在报告里输出
    REMAP=表:ws=real,... —— 对比前把工作区按映射换算（行 Index + 指向被换算表的引用），
    并以换算后的 Index 作为行的匹配键。
退出码 0 = 全部一致；1 = 有差异（打印明细）。
"""
import copy
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1])
rt_dir = Path(sys.argv[2])
report = Path(sys.argv[3]) if len(sys.argv) > 3 else None


def load_remap() -> dict[str, dict[int, int]]:
    """导入器报告的 REMAP=表:ws=real,... → {表: {ws: real}}。"""
    out: dict[str, dict[int, int]] = {}
    if report is None or not report.exists():
        return out
    for line in report.read_text(encoding="utf-8").splitlines():
        if not line.startswith("REMAP="):
            continue
        body = line[len("REMAP="):]
        table, _, pairs = body.partition(":")
        m: dict[int, int] = {}
        for p in pairs.split(","):
            ws, _, real = p.partition("=")
            if ws and real:
                m[int(ws)] = int(real)
        out[table] = m
    return out


def load(d: Path, name: str):
    p = d / f"{name}.json"
    if not p.exists():
        return None
    return {r["Index"]: r for r in json.loads(p.read_text(encoding="utf-8"))["rows"]}


def changed_tables():
    names = set()
    for f in workspace.glob("*.json"):
        if f.name in ("baseline.json", "meta.json", "state.json", "sync_report.txt"):
            continue
        base = workspace / "_baseline" / f.name
        if not base.exists():
            names.add(f.stem)
            continue
        if f.read_text(encoding="utf-8") != base.read_text(encoding="utf-8"):
            names.add(f.stem)
    return names


def reflist_derived(meta: dict, table: str, field: str) -> bool:
    tm = meta.get(table) or {}
    fm = (tm.get("fields") or {}).get(field) or {}
    child = fm.get("to")
    if not child:
        return False
    for cf in ((meta.get(child) or {}).get("fields") or {}).values():
        if cf.get("type") == "ref" and cf.get("to") == table:
            return True
    return False


def apply_remap_row(meta: dict, table: str, row: dict,
                    remap: dict[str, dict[int, int]]) -> dict:
    """把工作区行按 REMAP 换算（深拷贝）：行 Index 及所有指向被换算表的 ref/reflist 元素。"""
    r = copy.deepcopy(row)
    if table in remap and r["Index"] in remap[table]:
        r["Index"] = remap[table][r["Index"]]
    fields = (meta.get(table) or {}).get("fields") or {}
    for k, fm in fields.items():
        to = fm.get("to")
        if not to or to not in remap:
            continue
        m = remap[to]
        v = r.get(k)
        if fm.get("type") == "ref" and isinstance(v, dict) and v.get("Index") in m:
            r[k] = {"Index": m[v["Index"]], "Name": v.get("Name")}
        elif fm.get("type") == "reflist" and isinstance(v, list):
            r[k] = [{"Index": m.get(x["Index"], x["Index"]),
                     "Name": x.get("Name")} if isinstance(x, dict) else x for x in v]
    return r


def eq_field(wv, rv) -> bool:
    """ref/reflist 只比 Index 集合；其余严格相等。"""
    if isinstance(wv, dict) and isinstance(rv, dict) and "Index" in wv and "Index" in rv:
        return wv["Index"] == rv["Index"]
    if isinstance(wv, list) and isinstance(rv, list) and wv and rv \
            and isinstance(wv[0], dict) and isinstance(rv[0], dict) \
            and "Index" in wv[0] and "Index" in rv[0]:
        return sorted(x["Index"] for x in wv) == sorted(x["Index"] for x in rv)
    return wv == rv


def main() -> int:
    meta = json.loads((workspace / "meta.json").read_text(encoding="utf-8"))
    remap = load_remap()
    bad = 0
    for t in sorted(changed_tables()):
        ws = load(workspace, t)
        rt = load(rt_dir, t)
        if rt is None:
            print(f"[X] {t}: round-trip 导出缺失")
            bad += 1
            continue
        if remap:
            _ws = {}
            for r in ws.values():
                rr = apply_remap_row(meta, t, r, remap)
                _ws[rr["Index"]] = rr
            ws = _ws
        for idx, wrow in ws.items():
            if idx not in rt:
                print(f"[X] {t}#{idx}: round-trip 缺行")
                bad += 1
                continue
            rrow = rt[idx]
            for k, wv in wrow.items():
                rv = rrow.get(k)
                if reflist_derived(meta, t, k) and isinstance(wv, list):
                    if not eq_field(wv, rv or []):
                        wi = sorted(x.get("Index") for x in wv if isinstance(x, dict))
                        ri = sorted(x.get("Index") for x in (rv or []) if isinstance(x, dict))
                        print(f"[X] {t}#{idx}.{k}: 回链集合不一致 {wi} != {ri}")
                        bad += 1
                elif not eq_field(wv, rv):
                    print(f"[X] {t}#{idx}.{k}: {json.dumps(wv, ensure_ascii=False)[:60]}"
                          f" != {json.dumps(rv, ensure_ascii=False)[:60]}")
                    bad += 1
        for idx in set(rt) - set(ws):
            print(f"[X] {t}#{idx}: round-trip 多出旧行")
            bad += 1
    if bad:
        print(f"[FAIL] {bad} 处 round-trip 差异")
        return 1
    print("[OK] round-trip 语义一致")
    return 0


if __name__ == "__main__":
    sys.exit(main())
