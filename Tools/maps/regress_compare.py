#!/usr/bin/env python3
"""regress_compare.py — 对照两次 regress_capture/regress_pyapi 产物。

退出码 0 = 全部一致；非 0 = 存在差异（逐条打印）。
用法:
  python3 regress_compare.py /tmp/e1-regress/base /tmp/e1-regress/new
  python3 regress_compare.py --pyapi a.json b.json
"""
import argparse
import json
import sys


def compare_captures(a_dir, b_dir):
    a = json.load(open(f"{a_dir}/report.json", encoding="utf-8"))
    b = json.load(open(f"{b_dir}/report.json", encoding="utf-8"))
    ae, be = a["entries"], b["entries"]
    only_a = sorted(set(ae) - set(be))
    only_b = sorted(set(be) - set(ae))
    diffs = []
    for k in sorted(set(ae) & set(be)):
        if ae[k] != be[k]:
            diffs.append((k, ae[k], be[k]))
    print(f"[*] entries: base={len(ae)} new={len(be)}")
    for k in only_a:
        print(f"[!] 仅基线有: {k} ({ae[k]})")
    for k in only_b:
        print(f"[!] 仅新跑有: {k} ({be[k]})")
    for k, x, y in diffs:
        print(f"[!] 不一致: {k}\n      base={x}\n      new ={y}")
    ok = not (only_a or only_b or diffs)
    print(f"[*] 结论: {'全部一致 ✓' if ok else '存在差异 ✗'}")
    return 0 if ok else 1


def compare_pyapi(a_path, b_path):
    a = json.load(open(a_path, encoding="utf-8"))
    b = json.load(open(b_path, encoding="utf-8"))
    ok = True
    for k in sorted(set(a) | set(b)):
        if a.get(k) != b.get(k):
            ok = False
            print(f"[!] 不一致: {k}\n      base={a.get(k)}\n      new ={b.get(k)}")
    print(f"[*] 结论: {'库 API 指纹一致 ✓' if ok else '库 API 指纹差异 ✗'}")
    return 0 if ok else 1


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("base")
    ap.add_argument("new")
    ap.add_argument("--pyapi", action="store_true")
    args = ap.parse_args()
    if args.pyapi:
        sys.exit(compare_pyapi(args.base, args.new))
    sys.exit(compare_captures(args.base, args.new))
