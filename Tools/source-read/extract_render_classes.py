#!/usr/bin/env python3
"""提取客户端渲染类层次（AxeMon / HerbActor / magiceff）。

产出 docs/source-vs-reverse/client-render-classes.tsv
列: file  cls  parent  depth  line  comment
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "Client")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "client-render-classes.tsv")
FILES = ["AxeMon.pas", "HerbActor.pas", "magiceff.pas"]

RE_CLS = re.compile(r"^\s*(\w+)\s*=\s*class\s*\(\s*(\w+)\s*\)\s*;?\s*(?://\s*(.*))?$")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    rows = []
    for fn in FILES:
        p = os.path.join(SRC, fn)
        if not os.path.exists(p):
            continue
        text, _ = read_src.read_text(p)
        for i, line in enumerate(text.split("\n"), 1):
            m = RE_CLS.match(line.rstrip("\r"))
            if m:
                rows.append({"file": fn, "cls": m.group(1), "parent": m.group(2),
                             "line": i, "comment": (m.group(3) or "").strip()})

    parents = {r["cls"]: r["parent"] for r in rows}

    def depth(cls, seen=None):
        seen = seen or set()
        if cls in seen:
            return 0
        seen.add(cls)
        p = parents.get(cls)
        if not p or p not in parents:
            return 1
        return 1 + depth(p, seen)

    for r in rows:
        r["depth"] = depth(r["cls"])

    from collections import Counter
    print(f"类总数: {len(rows)}")
    print("按文件:", dict(Counter(r["file"] for r in rows)))
    print("继承深度:", dict(sorted(Counter(r["depth"] for r in rows).items())))
    print()
    print("顶层基类（parent 不在表内）:")
    for r in rows:
        if r["parent"] not in parents:
            print(f"  {r['cls']:26s} : {r['parent']:14s} ({r['file']}:{r['line']})")

    if args.stdout:
        cols = ["file", "cls", "parent", "depth", "line", "comment"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["file", "cls", "parent", "depth", "line", "comment"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
