#!/usr/bin/env python3
"""提取 Magic.pas 的 Mag* 实现特征（AoE 范围/特殊条件）。

**共同模式**（实测）：
    rlist := TList.Create;
    user.GetMapCreatures (user.PEnvir, X, Y, WIDE, rlist);   ← 取范围内实体
    for i := 0 to rlist.Count-1 do
       if user.IsProperTarget (cret) then
          cret.SendMsg (user, RM_MAGSTRUCK, 0, PWR, 0, 0, '')  ← 造成伤害

产出 docs/source-vs-reverse/magic-implementations.tsv
列: func  wide  src_line  special
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "GameServer", "Magic.pas")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "magic-implementations.tsv")

RE_FUNC = re.compile(r"^function\s+TMagicManager\.(Mag\w+)")
RE_AOE = re.compile(r"GetMapCreatures\s*\([^,]+,\s*[^,]+,\s*[^,]+,\s*([^,]+),")
RE_HIT = re.compile(r"RM_MAGSTRUCK\w*")
RE_TARGET = re.compile(r"RM_MAGSTRUCK\w*\s*\([^)]*\)|SendMsg\s*\(\s*user\s*,\s*(RM_\w+)")
# 特殊条件关键词
SPECIALS = [
    ("LA_UNDEAD", "只对亡灵全额伤害"),
    ("IsProperTarget", "目标合法性检查"),
    ("SkillLevel", "按技能等级"),
    ("Random(", "概率"),
    ("dir", "方向相关"),
    ("Abs(", "距离相关"),
    ("Div 10", "1/10 伤害"),
    ("div 10", "1/10 伤害"),
    ("BoGhost", "鬼魂"),
    ("StickMode", "粘住状态"),
]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    text, _ = read_src.read_text(SRC)
    lines = text.split("\n")

    rows = []
    cur = None
    for i, line in enumerate(lines, 1):
        mf = RE_FUNC.match(line)
        if mf:
            if cur:
                rows.append(cur)
            cur = {"func": mf.group(1), "wide": "", "src_line": i,
                   "special": "", "body_lines": 0}
            continue
        if cur:
            cur["body_lines"] += 1
            ma = RE_AOE.search(line)
            if ma and not cur["wide"]:
                cur["wide"] = ma.group(1).strip()
            # 收集特殊条件
            sp = []
            for key, desc in SPECIALS:
                if key in line and desc not in cur["special"]:
                    sp.append(desc)
            if sp:
                cur["special"] = (cur["special"] + " / ".join(sp) + " / ").strip(" /")
            if re.match(r"^end\s*;", line) and cur["body_lines"] > 3:
                rows.append(cur)
                cur = None
    if cur:
        rows.append(cur)

    aoe = [r for r in rows if r["wide"]]
    print(f"Mag* 函数: {len(rows)}   其中 AoE（有 GetMapCreatures）: {len(aoe)}")
    print()
    print("%-34s %-8s %s" % ("函数", "wide", "特殊条件"))
    for r in rows:
        print("%-34s %-8s %s" % (r["func"], r["wide"] or "—", r["special"][:56]))

    if args.stdout:
        cols = ["func", "wide", "special", "src_line"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["func", "wide", "special", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
