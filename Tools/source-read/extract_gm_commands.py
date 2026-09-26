#!/usr/bin/env python3
"""提取服务端 GM 命令表（ObjBase.pas 的 CompareText(cmd, ...) 分派链）。

产出 docs/source-vs-reverse/gm-commands.tsv
列: line  english  korean_aliases  handler

用法: extract_gm_commands.py [--stdout]
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "GameServer")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "gm-commands.tsv")

# 命令分派所在文件（ObjBase 的 TUserHuman 段）
FILES = ["ObjBase.pas", "CmdMgr.pas", "UsrEngn.pas", "UserMgr.pas"]

RE_CMD = re.compile(r"CompareText\s*\(\s*cmd\s*,\s*'([^']+)'\s*\)")
# 同一块里的处理函数调用（CmdXxx / RCmdXxx），排除类型/变量名
RE_HANDLER = re.compile(r"\b((?:R?Cmd)[A-Za-z0-9_]{3,})\s*[\(;]")
# 内联动作：SysMsg / Bo* 赋值 / 其他可读的语句
RE_INLINE = re.compile(r"\b(SysMsg|BoxMsg|Bo[A-Za-z]+|BlockWhisper|Set[A-Za-z]+|Send[A-Za-z]+|MainOutMessage|Cmd[A-Za-z]+)\b")
HANDLER_BLOCKLIST = {
    "CmdMgr", "CmdMsg", "CmdNum", "CmdChange", "CmdList", "CmdArray",
    "CmdMgrEngine", "CmdRecord",
}
# 一个命令块的最大跨度（行）。命令判定后 N 行内的语句算该命令的动作。
BLOCK_SPAN = 8


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    groups: dict[int, list[str]] = {}
    handlers: dict[int, str] = {}

    for fn in FILES:
        p = os.path.join(SRC, fn)
        if not os.path.exists(p):
            continue
        text, _ = read_src.read_text(p)
        lines = text.split("\n")
        for i, line in enumerate(lines, 1):
            names = RE_CMD.findall(line)
            if names:
                groups.setdefault(i, []).extend(names)
            # 记录每个 Cmd* 调用的行号（供块内归属）
            for m in RE_HANDLER.finditer(line):
                h = m.group(1)
                if h in HANDLER_BLOCKLIST:
                    continue
                handlers.setdefault(i, h)

    rows = []
    all_lines = {}
    for fn2 in FILES:
        p2 = os.path.join(SRC, fn2)
        if os.path.exists(p2):
            t2, _ = read_src.read_text(p2)
            for k2, l2 in enumerate(t2.split('\n')):
                all_lines[k2 + 1] = l2
    hlines = sorted(handlers)
    for ln in sorted(groups):
        names = groups[ln]
        eng = [n for n in names if all(ord(c) < 128 for c in n)]
        kor = [n for n in names if not all(ord(c) < 128 for c in n)]
        # 归属：命令判定行之后 BLOCK_SPAN 行内、最靠前的 Cmd* 调用
        h = ""
        for hl in hlines:
            if ln <= hl <= ln + BLOCK_SPAN:
                h = handlers[hl]
                break
        # 内联动作：块内出现的可读语句（去重、保序）
        inline: list[str] = []
        for j in range(ln, min(ln + BLOCK_SPAN, len(all_lines))):
            for m in RE_INLINE.finditer(all_lines[j]):
                w = m.group(1)
                if w not in HANDLER_BLOCKLIST and w not in inline:
                    inline.append(w)
        rows.append({
            "line": ln,
            "english": " / ".join(dict.fromkeys(eng)),
            "korean_aliases": " / ".join(dict.fromkeys(kor)),
            "handler": h or " / ".join(inline[:4]),
        })

    print(f"GM 命令分派块: {len(rows)}")
    all_eng = sorted({n for r in rows for n in r["english"].split(" / ") if n})
    all_kor = sorted({n for r in rows for n in r["korean_aliases"].split(" / ") if n})
    print(f"英文命令唯一: {len(all_eng)}")
    print(f"韩文别名唯一: {len(all_kor)}")

    if args.stdout:
        for r in rows:
            print(f"{r['line']}\t{r['english']}\t{r['korean_aliases']}\t{r['handler']}")
        return 0

    cols = ["line", "english", "korean_aliases", "handler"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
