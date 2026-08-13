#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""compare_sync.py —— 同步后 round-trip 语义对比。

对比「导入器写出的 System.db 重导出」与「工作区」：
  - 只检查有改动的表（工作区 vs _baseline 有 diff 的表）；
  - 派生回链（reflist 且子表带回指 ref，如 ItemInfo.Drops）按 Index 集合比较（顺序无关）；
  - 其余字段严格相等（含 ref 对象的 Index/Name）。
退出码 0 = 全部一致；1 = 有差异（打印明细）。
"""
import json
import sys
from pathlib import Path

workspace = Path(sys.argv[1])
rt_dir = Path(sys.argv[2])


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


def main() -> int:
    meta = json.loads((workspace / "meta.json").read_text(encoding="utf-8"))
    bad = 0
    for t in sorted(changed_tables()):
        ws = load(workspace, t)
        rt = load(rt_dir, t)
        if rt is None:
            print(f"[X] {t}: round-trip 导出缺失")
            bad += 1
            continue
        for idx, wrow in ws.items():
            if idx not in rt:
                print(f"[X] {t}#{idx}: round-trip 缺行")
                bad += 1
                continue
            rrow = rt[idx]
            for k, wv in wrow.items():
                rv = rrow.get(k)
                if reflist_derived(meta, t, k) and isinstance(wv, list):
                    wi = sorted(x.get("Index") for x in wv if isinstance(x, dict))
                    ri = sorted(x.get("Index") for x in (rv or []) if isinstance(x, dict))
                    if wi != ri:
                        print(f"[X] {t}#{idx}.{k}: 回链集合不一致 {wi} != {ri}")
                        bad += 1
                elif wv != rv:
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
