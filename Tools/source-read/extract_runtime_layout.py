#!/usr/bin/env python3
"""提取客户端运行时窗口布局（FState.pas 的 Initialize 段）。

**这是 DFM 之外的真正运行时布局** —— `client-windows.md` §2.2 已证 DFM 坐标是
编辑期布局（窗口被排成网格），真正的游戏内位置在这里：
`Dxxx.Left := (SCREENWIDTH - d.Width) div 2;` 之类的代码。

产出 docs/source-vs-reverse/client-runtime-layout.tsv
列: dlg  left_expr  top_expr  img_index  lib  src_line
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "Client", "FState.pas")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "client-runtime-layout.tsv")

# Dxxx.SetImgIndex (g_WLib, N)
RE_SETIMG = re.compile(r"(\w+)\.SetImgIndex\s*\(\s*(\w+)\s*,\s*(\d+)\s*\)")
# Dxxx.Left := EXPR  /  Dxxx.Top := EXPR
RE_POS = re.compile(r"(\w+)\.(Left|Top)\s*:=\s*(.+?);")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    text, _ = read_src.read_text(SRC)
    lines = text.split("\n")

    # 找 Initialize 范围
    start = end = None
    for i, l in enumerate(lines):
        if "procedure TFrmDlg.Initialize;" in l:
            start = i
        elif start is not None and re.match(r"^procedure TFrmDlg\.", l) and i > start:
            end = i
            break
    if start is None:
        sys.exit("[ERR] 未找到 TFrmDlg.Initialize")
    end = end or len(lines)
    print(f"Initialize 范围: {start+1} - {end}  ({end-start-1} 行)")

    rows: dict[str, dict] = {}
    for i in range(start, end):
        line = lines[i]
        for m in RE_SETIMG.finditer(line):
            d = rows.setdefault(m.group(1), {"dlg": m.group(1), "left_expr": "",
                                             "top_expr": "", "img_index": "",
                                             "lib": "", "src_line": i + 1})
            d["img_index"] = m.group(3)
            d["lib"] = m.group(2)
        for m in RE_POS.finditer(line):
            d = rows.setdefault(m.group(1), {"dlg": m.group(1), "left_expr": "",
                                             "top_expr": "", "img_index": "",
                                             "lib": "", "src_line": i + 1})
            if m.group(2) == "Left":
                d["left_expr"] = m.group(3).strip()
            else:
                d["top_expr"] = m.group(3).strip()

    out = sorted(rows.values(), key=lambda r: r["dlg"])
    print(f"涉及窗口/控件: {len(out)}")
    print()
    print("%-22s %-38s %-30s %s" % ("dlg", "Left", "Top", "帧"))
    for r in out:
        if r["left_expr"] or r["img_index"]:
            print("%-22s %-38s %-30s %s" % (r["dlg"], r["left_expr"][:36],
                                            r["top_expr"][:28], r["img_index"]))

    if args.stdout:
        cols = ["dlg", "left_expr", "top_expr", "img_index", "lib", "src_line"]
        for r in out:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["dlg", "left_expr", "top_expr", "img_index", "lib", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in out:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
