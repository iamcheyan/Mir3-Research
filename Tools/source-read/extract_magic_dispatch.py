#!/usr/bin/env python3
"""提取 Magic.pas 的技能分派表（MagicId -> 处理函数）。

来源: Source/GameServer/Magic.pas  SpellNow 的 `case pum.pDef.MagicId of`
产出 docs/source-vs-reverse/magic-dispatch.tsv
列: magic_id  comment  handler  src_line
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
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "magic-dispatch.tsv")

# case 标签行:  "   1, //화염장"  /  "   5: //금강화염장"  /  "   37,//기공파"
RE_CASE = re.compile(r"^\s*(\d+)\s*[,:]\s*(?://\s*(.*))?$")
# 处理函数调用: MagXxx( / WindCutHit( / ...
RE_HANDLER = re.compile(r"\b(Mag[A-Za-z0-9_]+|WindCutHit|UseBujuk|MagPassThroughMagic)\s*\(")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    text, _ = read_src.read_text(SRC)
    lines = text.split("\n")

    # 找所有 `case pum.pDef.MagicId of` 起点（实测有 4 处，各自是不同上下文）
    starts = [i for i, l in enumerate(lines) if "case pum.pDef.MagicId of" in l]
    if not starts:
        sys.exit("[ERR] 未找到 case pum.pDef.MagicId of")

    rows = []
    for blk, start in enumerate(starts, 1):
        cur = None
        depth = 1
        # 嵌套 case 的深度守卫：只在 depth==1（本层）时接受 case 标签
        nested_case = 0
        for i in range(start + 1, len(lines)):
            line = lines[i]
            stripped = line.strip()
            # 检测嵌套 case（如 case pstd.Shape of）—— 在其内部不采集标签
            if re.match(r"^\s*case\b", line) and i != start:
                nested_case += 1
                continue
            depth += len(re.findall(r"\bbegin\b", stripped))
            depth -= len(re.findall(r"\bend\b", stripped))
            if depth <= 0:
                break
            m = RE_CASE.match(line.rstrip("\r"))
            if m and nested_case == 0:
                if cur:
                    rows.append(cur)
                cur = {"block": blk, "block_line": start + 1,
                       "magic_id": int(m.group(1)),
                       "comment": (m.group(2) or "").strip(),
                       "handler": "", "src_line": i + 1}
                continue
            if cur and not cur["handler"] and nested_case == 0:
                for hm in RE_HANDLER.finditer(line):
                    h = hm.group(1)
                    if h in ("MagPassThroughMagic", "MagCanHitTarget"):
                        continue
                    cur["handler"] = h
                    break
        if cur:
            rows.append(cur)

    print(f"case 块: {len(starts)} 处   分派条目: {len(rows)}")
    for r in rows:
        print(f"  blk{r['block']} @{r['block_line']:5d}  id={r['magic_id']:3d}  "
              f"{r['handler'] or '(内联)':28s} {r['comment']}")

    if args.stdout:
        cols = ["block", "block_line", "magic_id", "comment", "handler", "src_line"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["block", "block_line", "magic_id", "comment", "handler", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
