#!/usr/bin/env python3
"""交叉验证：QuestDiary 脚本用到的宏 vs 源码里实现的宏。

**目的**：找出「脚本用了但源码没实现」的宏 —— 这些是源码包缺失的部分。

产出 docs/source-vs-reverse/quest-macros-coverage.tsv
列: macro  style  script_count  in_source  src_file  src_line
"""
from __future__ import annotations

import collections
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

QUESTDIR = os.path.join(REPO, "reference", "mir3-source", "Mud3-Config",
                        "Envir3", "QuestDiary")
SRCDIR = os.path.join(REPO, "reference", "mir3-source", "Source")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "quest-macros-coverage.tsv")

# 两种风格：<$NAME>（$ 宏）与 {NAME}（花括号宏）
RE_DOLLAR = re.compile(r"<\$([A-Z0-9_]+)>")
RE_BRACE = re.compile(r"\{([A-Z_][A-Z0-9_]*)(?:/[^}]*)?\}")


def scan_scripts() -> collections.Counter:
    c = collections.Counter()
    n = 0
    for root, dirs, fs in os.walk(QUESTDIR):
        dirs[:] = [d for d in dirs if d not in (".svn", "__history")]
        for fn in fs:
            p = os.path.join(root, fn)
            try:
                data = open(p, "rb").read()
            except OSError:
                continue
            text = None
            for enc in ("gb18030", "cp949", "utf-8"):
                try:
                    text = data.decode(enc)
                    break
                except UnicodeDecodeError:
                    pass
            if text is None:
                continue
            n += 1
            for m in RE_DOLLAR.finditer(text):
                c[("$", m.group(1))] += 1
            for m in RE_BRACE.finditer(text):
                c["{}", m.group(1)] += 1
    return c, n


def scan_source() -> dict[str, list[tuple[str, int]]]:
    """在全部源码里找宏名出现（任意上下文）。"""
    found: dict[str, list[tuple[str, int]]] = {}
    for root, dirs, fs in os.walk(SRCDIR):
        dirs[:] = [d for d in dirs if d not in (".git", ".svn", "__history")]
        for fn in fs:
            if os.path.splitext(fn)[1].lower() not in (".pas", ".cpp", ".h", ".dpr"):
                continue
            p = os.path.join(root, fn)
            rel = os.path.relpath(p, SRCDIR)
            try:
                text, _ = read_src.read_text(p)
            except OSError:
                continue
            for i, line in enumerate(text.split("\n"), 1):
                for m in RE_DOLLAR.finditer(line):
                    found.setdefault("$" + m.group(1), []).append((rel, i))
                for m in RE_BRACE.finditer(line):
                    found.setdefault("{}" + m.group(1), []).append((rel, i))
    return found


def main() -> int:
    scripts, nfiles = scan_scripts()
    src = scan_source()
    print(f"扫描 QuestDiary 文件: {nfiles}")
    print(f"脚本用到的宏（去重）: {len(scripts)}")
    print(f"源码里出现的宏（去重）: {len(src)}")
    print()

    rows = []
    for (style, name), cnt in scripts.most_common():
        key = style + name
        hits = src.get(key, [])
        rows.append({
            "macro": key,
            "script_count": cnt,
            "in_source": "yes" if hits else "**NO**",
            "src_file": hits[0][0] if hits else "",
            "src_line": hits[0][1] if hits else "",
        })

    missing = [r for r in rows if r["in_source"] == "**NO**"]
    print(f"脚本用了但源码里找不到的宏: {len(missing)}")
    for r in missing:
        print(f"  {r['macro']:26s} {r['script_count']:5d} 次")
    print()
    print("脚本用了且源码里有的宏:")
    for r in rows:
        if r["in_source"] == "yes":
            print(f"  {r['macro']:26s} {r['script_count']:5d} 次   {r['src_file']}:{r['src_line']}")

    cols = ["macro", "script_count", "in_source", "src_file", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
