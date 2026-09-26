#!/usr/bin/env python3
"""提取 NPC 脚本语言命令表（LocalDB.pas 的 LoadMarketDef 解析器）。

`DecodeConditionStr` 解析 `#IF` 条件（QI_* 标识），
`DecodeActionStr` 解析 `#ACT` 动作（QA_* 标识）。
两者合起来就是 **NPC 脚本语言的全部关键字**。

产出 docs/source-vs-reverse/npc-script-commands.tsv
列: kind  keyword  ident  src_line
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "GameServer", "LocalDB.pas")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "npc-script-commands.tsv")

# if UpperCase(cmdstr) = 'CHECKGOLD' then begin / ident := QI_CHECKGOLD;
RE_KW = re.compile(r"UpperCase\(cmdstr\)\s*=\s*'([A-Z0-9_]+)'")
RE_IDENT = re.compile(r"ident\s*:=\s*(QI_[A-Z0-9_]+|QA_[A-Z0-9_]+)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    text, _ = read_src.read_text(SRC)
    lines = text.split("\n")

    # 定位两个解码函数区间
    bounds = {}
    for i, l in enumerate(lines, 1):
        for fn in ("DecodeConditionStr", "DecodeActionStr"):
            if re.match(rf"\s*function\s+{fn}\b", l):
                bounds[fn] = i
    print("解析器位置:", ", ".join(f"{k}@{v}" for k, v in bounds.items()))

    rows = []
    cur_kw = ""
    for i, line in enumerate(lines, 1):
        mk = RE_KW.search(line)
        if mk:
            cur_kw = mk.group(1)
        mi = RE_IDENT.search(line)
        if mi and cur_kw:
            ident = mi.group(1)
            kind = "condition" if ident.startswith("QI_") else "action"
            rows.append({"kind": kind, "keyword": cur_kw, "ident": ident, "src_line": i})
            cur_kw = ""

    from collections import Counter
    k = Counter(r["kind"] for r in rows)
    print(f"命令总数: {len(rows)}   条件: {k['condition']}   动作: {k['action']}")
    print()
    for kind in ("condition", "action"):
        kws = [r["keyword"] for r in rows if r["kind"] == kind]
        print(f"--- {kind} ({len(kws)}) ---")
        for n in range(0, len(kws), 6):
            print("  " + "  ".join(f"{x:24s}" for x in kws[n:n + 6]))

    if args.stdout:
        cols = ["kind", "keyword", "ident", "src_line"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["kind", "keyword", "ident", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
