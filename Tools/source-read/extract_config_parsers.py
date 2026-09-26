#!/usr/bin/env python3
"""从 LocalDB.pas 提取所有配置解析器的字段序列。

对每个 `Load*` 函数，提取其 `GetValidStr3/GetValidStrCap/ArrestStringEx`
调用序列（即字段读取顺序）与赋值的记录字段，产出格式文档。

产出 docs/source-vs-reverse/config-parsers.tsv
列: func  file_const  file_name  line  seq  field  reader
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
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "config-parsers.tsv")

# 文件名常量定义:  NAME = 'file.txt';
RE_CONST = re.compile(r"^\s*([A-Z0-9_]+)\s*=\s*'([^']+)'\s*;")
# 函数定义
RE_FUNC = re.compile(r"^function\s+TFrmDB\.(Load\w+|Reload\w+)")
# 字段读取：str := GetValidStr3 (str, VAR, [...])  /  GetValidStrCap
RE_READ = re.compile(
    r"str\s*:=\s*(GetValidStr3|GetValidStrCap|ArrestStringEx)\s*\(\s*str\s*,\s*(\w+)"
)
# 赋值到记录字段：  pz.MapName := ...  /  merchant.CX := ...
RE_ASSIGN = re.compile(r"^\s*(\w+)\.(\w+)\s*:=")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    p = os.path.join(SRC, "LocalDB.pas")
    text, _ = read_src.read_text(p)
    lines = text.split("\n")

    consts: dict[str, str] = {}
    for line in lines:
        m = RE_CONST.match(line)
        if m:
            consts[m.group(1)] = m.group(2)

    rows = []
    cur_func = ""
    seq = 0
    for i, line in enumerate(lines, 1):
        mf = RE_FUNC.match(line)
        if mf:
            cur_func = mf.group(1)
            seq = 0
            continue
        if not cur_func:
            continue
        mr = RE_READ.search(line)
        if mr:
            seq += 1
            rows.append({
                "func": cur_func, "line": i, "seq": seq,
                "field": mr.group(2), "reader": mr.group(1),
                "file_const": "", "file_name": "",
            })
            continue
        ma = RE_ASSIGN.match(line)
        if ma and rows and rows[-1]["func"] == cur_func:
            rows[-1]["field"] = f"{ma.group(1)}.{ma.group(2)}"

    # 关联文件名常量
    FUNC_TO_CONST = {
        "LoadZenLists": "ZENFILE", "LoadGenMsgLists": "ZENMSGFILE",
        "LoadMapFiles": "MAPDEFFILE", "LoadAdminFiles": "ADMINDEFFILE",
        "LoadMerchants": "MERCHANTFILE", "LoadNpcs": "NPCLISTFILE",
        "LoadGuards": "GUARDLISTFILE", "LoadMakeItemList": "MAKEITEMFILE",
        "LoadStartPoints": "STARTPOINTFILE", "LoadSafePoints": "SAFEPOINTFILE",
        "LoadDecoItemList": "DECOITEMFILE", "LoadMiniMapInfos": "MINIMAPFILE",
        "LoadUnbindItemLists": "UNBINDFILE", "LoadMapQuestInfos": "MAPQUESTFILE",
    }
    for r in rows:
        c = FUNC_TO_CONST.get(r["func"], "")
        r["file_const"] = c
        r["file_name"] = consts.get(c, "")

    funcs = sorted({r["func"] for r in rows})
    print(f"解析器函数: {len(funcs)}")
    print(f"字段读取点: {len(rows)}")
    print()
    for f in funcs:
        fr = [r for r in rows if r["func"] == f]
        print(f"{f:24s} {fr[0]['file_name'] or '(非文件解析)':18s} {len(fr)} 字段")

    if args.stdout:
        cols = ["func", "file_const", "file_name", "line", "seq", "field", "reader"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["func", "file_const", "file_name", "line", "seq", "field", "reader"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
