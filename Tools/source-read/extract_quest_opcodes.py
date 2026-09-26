#!/usr/bin/env python3
"""提取任务脚本语言的条件/动作 opcode 表。

来源:
  - Source/Common/Grobal2.pas  QI_*（条件）与 QA_*（动作）常量
  - Source/GameServer/LocalDB.pas  脚本关键字 -> opcode 的映射（解析器）
  - Source/GameServer/ObjNpc.pas   CheckSayingCondition / 动作执行

产出 docs/source-vs-reverse/quest-opcodes.tsv
列: kind  name  value  hex  keyword  comment  src_line
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
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "quest-opcodes.tsv")

RE_DEF = re.compile(
    r"^\s*(?P<name>(?:QI|QA)_[A-Z0-9_]+)\s*=\s*(?P<val>\d+)\s*;\s*(?://\s*(?P<cmt>.*))?\s*$"
)
# LocalDB 里:  if UpperCase(cmdstr) = 'CHECKLEVEL' then ident := QI_CHECKLEVEL;
RE_KW = re.compile(
    r"UpperCase\s*\(\s*cmdstr\s*\)\s*=\s*'(?P<kw>[A-Z0-9_]+)'\s*\)?\s*then\s+ident\s*:=\s*(?P<ident>[A-Z0-9_]+)"
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    # 1. opcode 定义
    defs: dict[str, dict] = {}
    for rel in ("Source/Common/Grobal2.pas",):
        p = os.path.join(SRC, rel)
        text, _ = read_src.read_text(p)
        for i, line in enumerate(text.split("\n"), 1):
            m = RE_DEF.match(line.rstrip("\r"))
            if not m:
                continue
            name = m.group("name")
            defs[name] = {
                "kind": "condition" if name.startswith("QI_") else "action",
                "name": name,
                "value": int(m.group("val")),
                "hex": "0x%X" % int(m.group("val")),
                "keyword": "",
                "comment": (m.group("cmt") or "").strip(),
                "src_line": i,
            }

    # 2. 脚本关键字映射
    kw: dict[str, str] = {}
    p = os.path.join(SRC, "Source/GameServer/LocalDB.pas")
    if os.path.exists(p):
        text, _ = read_src.read_text(p)
        for i, line in enumerate(text.split("\n"), 1):
            m = RE_KW.search(line)
            if m:
                kw[m.group("ident")] = m.group("kw")

    for name, d in defs.items():
        if name in kw:
            d["keyword"] = kw[name]

    rows = sorted(defs.values(), key=lambda d: (d["kind"], d["value"]))

    cond = [r for r in rows if r["kind"] == "condition"]
    act = [r for r in rows if r["kind"] == "action"]
    print(f"条件 opcode (QI_*): {len(cond)}")
    print(f"动作 opcode (QA_*): {len(act)}")
    print(f"有脚本关键字映射: {sum(1 for r in rows if r['keyword'])}")

    if args.stdout:
        for r in rows:
            print("\t".join(str(r[c]) for c in
                            ("kind", "name", "value", "hex", "keyword", "comment", "src_line")))
        return 0

    cols = ["kind", "name", "value", "hex", "keyword", "comment", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
