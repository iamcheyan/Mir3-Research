#!/usr/bin/env python3
"""提取客户端动作帧表（Actor.pas 的 THumanAction / TMonsterAction 常量）。

**这是客户端渲染的核心数据**：`CalcActorFrame` 用
`startframe := ActXxx.start + Dir * (ActXxx.frame + ActXxx.skip)` 计算起始帧。

产出 docs/source-vs-reverse/actor-frames.tsv
列: table  action  start  frame  skip  ftime  usetick  src_line
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "Client", "Actor.pas")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "actor-frames.tsv")

# 表定义起点:  NAME: TMonsterAction = (   /   HA: THumanAction = (
RE_TABLE = re.compile(r"^\s*(\w+)\s*:\s*T(?:Monster|Human)Action\s*=\s*\(\s*(?://\s*(.*))?$")
# 动作项:  ActStand:  (start: 0;      frame: 4;  skip: 6;  ftime: 200;  usetick: 0);
RE_ACT = re.compile(
    r"(\w+)\s*:\s*\(\s*start:\s*(-?\d+)\s*;\s*frame:\s*(-?\d+)\s*;\s*"
    r"skip:\s*(-?\d+)\s*;\s*ftime:\s*(-?\d+)\s*;\s*usetick:\s*(-?\d+)"
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    text, _ = read_src.read_text(SRC)
    lines = text.split("\n")

    rows = []
    cur_table = ""
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        # 跳过整行注释（如 `//ActHit: (start: 200; ...)` —— 实测 HA 表里有）
        if stripped.startswith("//"):
            continue
        mt = RE_TABLE.match(line.rstrip("\r"))
        if mt:
            cur_table = mt.group(1)
            continue
        if not cur_table:
            continue
        # 去掉行尾注释后再匹配，避免 `//ActXxx: (...)` 形式的伪项
        code = line.split("//")[0]
        for m in RE_ACT.finditer(code):
            rows.append({
                "table": cur_table,
                "action": m.group(1),
                "start": int(m.group(2)),
                "frame": int(m.group(3)),
                "skip": int(m.group(4)),
                "ftime": int(m.group(5)),
                "usetick": int(m.group(6)),
                "src_line": i,
            })
        # 表结束
        if cur_table and re.match(r"^\s*\)\s*;", line):
            cur_table = ""

    tables = {}
    for r in rows:
        tables.setdefault(r["table"], []).append(r)

    print(f"动作表: {len(tables)}   动作项: {len(rows)}")
    for t, items in tables.items():
        print(f"  {t:8s} {len(items)} 项  {items[0]['src_line']}")

    if args.stdout:
        cols = ["table", "action", "start", "frame", "skip", "ftime", "usetick", "src_line"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["table", "action", "start", "frame", "skip", "ftime", "usetick", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
