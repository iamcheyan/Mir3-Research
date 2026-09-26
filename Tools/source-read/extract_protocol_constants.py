#!/usr/bin/env python3
"""从 Grobal2.pas 提取 CM_*/SM_*/ISM_*/DBR_* 常量表 -> TSV。

产出 docs/source-vs-reverse/protocol-constants.tsv
列: prefix  name  value  dec  hex  kind  comment  src_file  src_line

用法:
  extract_protocol_constants.py            # 写 TSV
  extract_protocol_constants.py --check    # 只报告统计，不写文件
  extract_protocol_constants.py --stdout   # 打到 stdout

注意: 解析逻辑必须与校验脚本 verify_protocol_constants.py 独立实现
      （本仓库纪律：验证工具不得与生产工具共用同一错误）。
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC_ROOT = os.path.join(REPO, "reference", "mir3-source")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "protocol-constants.tsv")

# 主表 + 旧版备份 + ImageEditor 第三份副本
TABLES = [
    ("Source/Common/Grobal2.pas", "primary"),
    ("Source/Common/Grobal2 - 副本.pas", "backup"),
    ("Source/Tools/ImageEditor/Common/Grobal2.pas", "imageeditor"),
]

# 形如:  CM_FOO   = 1033;   // 注释
# 允许 = 号前后任意空白；注释以 // 起
RE_CONST = re.compile(
    r"^\s*(?P<name>(?:CM|SM|ISM|DBR|OSM|SSM|NSM|GSM|LSM|CSM|RMS)_[A-Z0-9_]+)"
    r"\s*=\s*(?P<value>\$[0-9A-Fa-f]+|\d+)"
    r"\s*;\s*(?://\s*(?P<comment>.*))?\s*$"
)


def parse_table(rel: str) -> list[dict]:
    path = os.path.join(SRC_ROOT, rel)
    if not os.path.exists(path):
        print(f"[WARN] 缺表: {rel}", file=sys.stderr)
        return []
    text, enc = read_src.read_text(path)
    rows = []
    for i, line in enumerate(text.split("\n"), 1):
        m = RE_CONST.match(line.rstrip("\r"))
        if not m:
            continue
        raw = m.group("value")
        value = int(raw[1:], 16) if raw.startswith("$") else int(raw)
        name = m.group("name")
        rows.append({
            "prefix": name.split("_", 1)[0],
            "name": name,
            "value": value,
            "dec": value,
            "hex": "0x%X" % value,
            "kind": "",
            "comment": (m.group("comment") or "").strip(),
            "src_file": rel,
            "src_line": i,
            "enc": enc,
        })
    return rows


def kind_of(prefix: str) -> str:
    return {
        "CM": "client->server",
        "SM": "server->client",
        "ISM": "inter-server",
        "DBR": "db-reply",
        "OSM": "other-server",
    }.get(prefix, "other")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    all_rows: dict[str, list[dict]] = {}
    for rel, tag in TABLES:
        rows = parse_table(rel)
        for r in rows:
            r["kind"] = kind_of(r["prefix"])
        all_rows[tag] = rows
        print(f"[{tag}] {rel}: {len(rows)} 常量", file=sys.stderr)

    primary = all_rows.get("primary", [])
    if not primary:
        sys.exit("[ERR] primary 表为空，解析逻辑失效")

    # 重复名 / 重复值检测
    by_name: dict[str, list[dict]] = {}
    for r in primary:
        by_name.setdefault(r["name"], []).append(r)
    dup_name = {k: v for k, v in by_name.items() if len(v) > 1}

    by_val: dict[int, list[dict]] = {}
    for r in primary:
        by_val.setdefault(r["value"], []).append(r)
    dup_val = {k: v for k, v in by_val.items() if len(v) > 1}

    prefixes: dict[str, int] = {}
    for r in primary:
        prefixes[r["prefix"]] = prefixes.get(r["prefix"], 0) + 1

    print("\n=== 统计 ===", file=sys.stderr)
    print(f"常量总数: {len(primary)}", file=sys.stderr)
    print(f"前缀分布: {dict(sorted(prefixes.items()))}", file=sys.stderr)
    print(f"重名: {len(dup_name)}", file=sys.stderr)
    for k, v in sorted(dup_name.items()):
        print(f"   {k}: {[x['src_line'] for x in v]}", file=sys.stderr)
    print(f"重复值: {len(dup_val)}", file=sys.stderr)
    for k, v in sorted(dup_val.items()):
        print(f"   {k} ({hex(k)}): {[x['name'] for x in v]}", file=sys.stderr)

    # 与备份表比对：名字集合差集 = 协议演进
    for tag in ("backup", "imageeditor"):
        other = {r["name"] for r in all_rows.get(tag, [])}
        mine = {r["name"] for r in primary}
        if other:
            print(f"\n=== primary vs {tag} ===", file=sys.stderr)
            print(f"仅 primary 有 ({len(mine - other)}): {sorted(mine - other)}", file=sys.stderr)
            print(f"仅 {tag} 有 ({len(other - mine)}): {sorted(other - mine)}", file=sys.stderr)

    if args.check:
        return

    cols = ["prefix", "name", "value", "dec", "hex", "kind", "comment", "src_file", "src_line"]
    lines = ["\t".join(cols)]
    for r in primary:
        lines.append("\t".join(str(r[c]) for c in cols))
    body = "\n".join(lines) + "\n"

    if args.stdout:
        sys.stdout.write(body)
        return

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        f.write(body)
    print(f"\n已写 {os.path.relpath(OUT, REPO)}  ({len(primary)} 行)", file=sys.stderr)


if __name__ == "__main__":
    main()
