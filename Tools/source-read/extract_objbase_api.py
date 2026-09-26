#!/usr/bin/env python3
"""提取 ObjBase.pas（31,768 行）的类结构与方法清单。

ObjBase.pas 是全仓最大文件，含 TCreature / TAnimal / TUserHuman 三个类、
521 个方法声明。本工具把它们结构化，便于按主题销账。

产出 docs/source-vs-reverse/objbase-methods.tsv
列: cls  kind  name  line  vis
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "GameServer", "ObjBase.pas")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "objbase-methods.tsv")

RE_CLS = re.compile(r"^\s*(T[A-Za-z0-9_]+)\s*=\s*class\s*(?:\((\w+)\))?")
RE_METHOD = re.compile(
    r"^\s*(procedure|function|constructor|destructor)\s+([A-Za-z_][A-Za-z0-9_.]*)"
)
VIS = ("private", "protected", "public", "published")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    ap.add_argument("--by-class", action="store_true")
    args = ap.parse_args()

    text, _ = read_src.read_text(SRC)
    lines = text.split("\n")

    impl = next((i for i, l in enumerate(lines, 1) if l.strip() == "implementation"), len(lines))

    rows = []
    cur_cls, cur_vis = "", "public"
    for i, line in enumerate(lines, 1):
        if i > impl:
            break
        mc = RE_CLS.match(line)
        if mc:
            cur_cls, cur_vis = mc.group(1), "public"
            rows.append({"cls": cur_cls, "kind": "class", "name": mc.group(2) or "(base)",
                         "line": i, "vis": ""})
            continue
        v = line.strip().lower().rstrip(";")
        if v in VIS:
            cur_vis = v
            continue
        if re.match(r"^\s*end\s*;", line):
            cur_cls = ""
            continue
        if not cur_cls:
            continue
        mm = RE_METHOD.match(line)
        if mm:
            rows.append({"cls": cur_cls, "kind": mm.group(1), "name": mm.group(2),
                         "line": i, "vis": cur_vis})

    methods = [r for r in rows if r["kind"] != "class"]
    print(f"接口段 305..{impl}   类: {sum(1 for r in rows if r['kind']=='class')}   "
          f"方法: {len(methods)}")

    from collections import Counter
    print()
    for cls in dict.fromkeys(r["cls"] for r in methods):
        ms = [r for r in methods if r["cls"] == cls]
        k = Counter(r["kind"] for r in ms)
        v = Counter(r["vis"] for r in ms)
        print(f"  {cls:14s} {len(ms):4d} 方法   "
              f"proc={k['procedure']} func={k['function']} ctor={k['constructor']} "
              f"dtor={k['destructor']}")
        print(f"  {'':14s}      可见性: " + "  ".join(f"{x}={v[x]}" for x in VIS if v[x]))

    if args.by_class:
        print()
        for cls in dict.fromkeys(r["cls"] for r in methods):
            print(f"\n--- {cls} ---")
            for r in methods:
                if r["cls"] == cls:
                    print(f"  {r['line']:6d}  {r['vis']:9s} {r['kind']:11s} {r['name']}")

    if args.stdout:
        cols = ["cls", "kind", "name", "line", "vis"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["cls", "kind", "name", "line", "vis"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
