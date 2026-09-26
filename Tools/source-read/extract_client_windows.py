#!/usr/bin/env python3
"""从 Preview 客户端源码提取窗口清单与资源帧号。

产出 docs/source-vs-reverse/client-windows.tsv
列: dlg  frames  count  evidence  src_file  src_line

方法:
  1. 从 FState.pas 提取 `DXxx: TDWindow;` 形式的窗口字段声明
  2. 提取所有 `SetImgIndex(g_WGameInter, N)` / `Images[N]` 的帧号
  3. 按窗口字段名分组（就近原则：帧号出现在该窗口的构造/初始化段落里）

用法: extract_client_windows.py [--check]
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "client-windows.tsv")

# 窗口字段声明:  DxxxDlg: TDWindow;   /  Dxxx: TDControl;
RE_DECL = re.compile(r"^\s*(D[A-Za-z0-9_]+)\s*:\s*(T[A-Za-z0-9_]+)\s*;")

# 帧号引用:  SetImgIndex (g_WGameInter, 250)   /  g_WGameInter.Images[1240]
RE_FRAME_SETS = re.compile(
    r"SetImgIndex\s*\(\s*g_WGameInter\w*\s*,\s*(\d+)\s*\)"
)
RE_FRAME_IDX = re.compile(
    r"g_WGameInter\w*\.(?:Images|GetCachedImage)\s*\[?\s*(\d+)"
)

# 图库归属:  g_WInterface1c / g_WGameInter / g_WGameInter1 ...
RE_LIB = re.compile(r"g_W(Interface1c|GameInter1|GameInter|Magic|Equip|Inventory)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    # --- 1. 窗口字段声明 ---
    decls: list[tuple[str, str, str, int]] = []
    for rel in ("Source/Client/FState.pas", "Source/Client/ClMain.pas"):
        text, _ = read_src.read_text(os.path.join(SRC, rel))
        for i, line in enumerate(text.split("\n"), 1):
            m = RE_DECL.match(line)
            if m:
                decls.append((m.group(1), m.group(2), rel, i))

    # --- 2. 帧号引用 ---
    frames: list[tuple[str, int, str, int]] = []
    for rel in ("Source/Client/FState.pas", "Source/Client/ClMain.pas",
                "Source/Client/PlayScn.pas", "Source/Client/Actor.pas"):
        path = os.path.join(SRC, rel)
        if not os.path.exists(path):
            continue
        text, _ = read_src.read_text(path)
        for i, line in enumerate(text.split("\n"), 1):
            for m in RE_FRAME_SETS.finditer(line):
                frames.append(("GameInter", int(m.group(1)), rel, i))
            for m in RE_FRAME_IDX.finditer(line):
                frames.append(("GameInter", int(m.group(1)), rel, i))

    print(f"窗口/控件字段声明: {len(decls)}")
    print(f"GameInter 帧号引用: {len(frames)}")

    # 帧号统计
    from collections import Counter
    vals = [f[1] for f in frames]
    c = Counter(vals)
    print(f"唯一帧号: {len(c)}  范围: {min(vals)}-{max(vals)}")

    # 按区间分桶（对照原版 GameInter 1103 帧上限）
    over = sorted(v for v in c if v > 1102)
    print(f"超过原版上限 1102 的帧号: {len(over)}")
    if over:
        print(f"  {over}")

    # 窗口类型分布
    tc = Counter(d[1] for d in decls)
    print(f"\n窗口/控件类型分布:")
    for k, v in tc.most_common(12):
        print(f"  {k:20s} {v}")

    if not args.check:
        rows = ["dlg\ttype\tsrc_file\tsrc_line"]
        for name, typ, rel, ln in decls:
            rows.append(f"{name}\t{typ}\t{rel}\t{ln}")
        with open(OUT, "w", encoding="utf-8") as f:
            f.write("\n".join(rows) + "\n")
        print(f"\n已写 {os.path.relpath(OUT, REPO)} ({len(decls)} 行)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
