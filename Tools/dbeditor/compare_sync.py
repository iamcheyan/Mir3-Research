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


def _is_ref(v) -> bool:
    """值是否是「指向别的行的引用」（dict 含 Index，或这类 dict 的列表）。"""
    if isinstance(v, dict):
        return "Index" in v
    return isinstance(v, list) and bool(v) and all(isinstance(x, dict) and "Index" in x for x in v)


def _ref_count(v) -> int:
    if v is None:
        return 0
    return len(v) if isinstance(v, list) else 1


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
        _remap_lenient: set[int] = set()
        if remap:
            _ws = {}
            for r in ws.values():
                rr = apply_remap_row(meta, t, r, remap)
                _ws[rr["Index"]] = rr
            ws = _ws
        else:
            # 索引重映射容忍：导入器遇到索引占用会把新行重映射到高位（工作区仍保留旧索引），
            # 而 create/add 那次报告里的 REMAP 只出现在「创建行」的那一次导入。此后任何
            # 对**同一张表**的改动都不会再带 REMAP，于是整表按索引比对会误报
            # 「#旧: round-trip 缺行」+「#新: 多出旧行」成对差异。
            # 这里按 _Identity 唯一匹配把「旧索引 -> 新索引」认成同一行；这类行的回链列表
            # 目标索引已被导入器重写过，因此只比长度（不静默跳过：会打印一行 NOTE）。
            by_ident: dict[str, list[int]] = {}
            for i2, r2 in rt.items():
                id2 = r2.get("_Identity")
                if id2:
                    by_ident.setdefault(id2, []).append(i2)
            pair: dict[int, int] = {}
            for idx, wrow in ws.items():
                if idx in rt:
                    continue
                cands = by_ident.get(wrow.get("_Identity"), [])
                if len(cands) == 1:
                    pair[idx] = cands[0]
            if pair:
                print(f"[i] {t}: 检测到索引重映射 {len(pair)} 行，按 _Identity 认成同一行")
                for old, new in sorted(pair.items())[:8]:
                    print(f"    {t}#{old} ≡ #{new}")
                ws = {pair.get(i, i): r for i, r in ws.items()}
                remapped_pairs = set(pair)
                _remap_lenient = {pair[k] for k in remapped_pairs}
            else:
                _remap_lenient = set()
        for idx, wrow in ws.items():
            if idx not in rt:
                print(f"[X] {t}#{idx}: round-trip 缺行")
                bad += 1
                continue
            rrow = rt[idx]
            for k, wv in wrow.items():
                rv = rrow.get(k)
                if idx in _remap_lenient:
                    # 重映射行：自身 Index 与被导入器重写过的引用字段（dict/list）不比数值，
                    # 只比引用个数；其余字段照旧严格比对（不静默放过）。
                    if k == "Index":
                        continue
                    if _is_ref(wv) or _is_ref(rv):
                        if _ref_count(wv) != _ref_count(rv):
                            print(f"[X] {t}#{idx}.{k}: 重映射行引用个数不一致 "
                                  f"{_ref_count(wv)} != {_ref_count(rv)}")
                            bad += 1
                        continue
                if reflist_derived(meta, t, k) and isinstance(wv, list):
                    if idx in _remap_lenient:
                        # 重映射行：目标索引已被导入器改写，只比长度
                        if len(wv) != len(rv or []):
                            print(f"[X] {t}#{idx}.{k}: 重映射行回链长度不一致 "
                                  f"{len(wv)} != {len(rv or [])}")
                            bad += 1
                        continue
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
