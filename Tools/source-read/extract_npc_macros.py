#!/usr/bin/env python3
"""提取 NPC 对话的 `$` 宏替换表（CheckNpcSayCommand）。

这是任务脚本语言的最后一块：`<$USERNAME>` 这类宏在运行时被替换为实际值。

产出 docs/source-vs-reverse/npc-say-macros.tsv
列: macro  source_expr  src_line
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "GameServer", "ObjNpc.pas")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "npc-say-macros.tsv")

# 触发:  if tag = '$NAME' then begin
RE_TAG = re.compile(r"^\s*if\s+tag\s*=\s*'(\$[A-Z0-9_]+)'\s*then")
# 替换:  ChangeNpcSayTag (source, '<$NAME>', EXPR)
RE_SUB = re.compile(r"ChangeNpcSayTag\s*\(\s*source\s*,\s*'([^']+)'\s*,\s*(.+?)\)\s*;")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    text, _ = read_src.read_text(SRC)
    lines = text.split("\n")

    rows = []
    cur = None
    for i, line in enumerate(lines, 1):
        m = RE_TAG.match(line)
        if m:
            if cur:
                rows.append(cur)
            cur = {"macro": m.group(1), "source_expr": "", "src_line": i}
            continue
        if cur:
            ms = RE_SUB.search(line)
            if ms and not cur["source_expr"]:
                cur["source_expr"] = ms.group(2).strip()
            # 块结束（下一个 if 或 end;）
            if re.match(r"^\s*end\s*;", line):
                rows.append(cur)
                cur = None
    if cur:
        rows.append(cur)

    print(f"`$` 宏: {len(rows)}")
    for r in rows:
        print(f"  {r['macro']:20s} -> {r['source_expr'] or '(未捕获表达式)'}")

    if args.stdout:
        cols = ["macro", "source_expr", "src_line"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["macro", "source_expr", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
