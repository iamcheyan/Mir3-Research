#!/usr/bin/env python3
"""提取 DataBaseServer/DBSvr/tablesdefine.cpp 的 SQL 字段元数据。

此表描述源码声明的 SQL Server 字段，不等同于 System.db/Users.db 文件结构。
`MIRDB_FIELDS` 中的 `fIsKey` 是查询/更新生成器的键字段标志，不代表已验证数据库约束。

产出 docs/source-vs-reverse/sql-tables.tsv
列: array  table_hint  field  type  key_flag  size  src_line
"""
from __future__ import annotations

import argparse
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "DataBaseServer",
                   "DBSvr", "tablesdefine.cpp")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "sql-tables.tsv")

# 数组定义:  MIRDB_FIELDS __XXXFIELDS[] = {
RE_ARRAY = re.compile(r"MIRDB_FIELDS\s+(\w+)\s*\[\s*\]\s*=")
# 字段项:  { "FLD_NAME", TABLETYPE_XXX, true/false, N },
RE_FIELD = re.compile(
    r'\{\s*"(FLD_[A-Za-z_0-9]+)"\s*,\s*(TABLETYPE_\w+)\s*,\s*(true|false)\s*,\s*(\d+)\s*\}'
)
# 表名映射:  MIRDB_TABLE __XXXTABLE = { "TBL_XXX", ..., __XXXFIELDS };
RE_TBLMAP = re.compile(
    r'MIRDB_TABLE\s+(\w+)\s*=\s*\{\s*"(TBL_[A-Z_]+)"\s*,.*?(\w+FIELDS)\s*\}'
)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--stdout", action="store_true")
    args = ap.parse_args()

    text, _ = read_src.read_text(SRC)
    lines = text.split("\n")

    # 先建 array -> table 映射
    tbl_map: dict[str, str] = {}
    for line in lines:
        m = RE_TBLMAP.search(line)
        if m:
            tbl_map[m.group(3)] = m.group(2)

    rows = []
    cur_arr = ""
    for i, line in enumerate(lines, 1):
        # First field often shares the array declaration line; ignore // comments.
        code_line = line.split("//", 1)[0]
        ma = RE_ARRAY.search(code_line)
        if ma:
            cur_arr = ma.group(1)
        for m in RE_FIELD.finditer(code_line):
            rows.append({
                "array": cur_arr or "(未归属)",
                "table_hint": "",
                "field": m.group(1),
                "type": m.group(2),
                "key_flag": m.group(3),
                "size": m.group(4),
                "src_line": i,
            })
        # 数组结束
        if cur_arr and re.match(r"^\s*\};", line):
            cur_arr = ""

    for r in rows:
        r["table_hint"] = tbl_map.get(r["array"], "")

    from collections import OrderedDict
    by: dict[str, list] = OrderedDict()
    for r in rows:
        by.setdefault(r["array"], []).append(r)

    print(f"字段数组: {len(by)}   字段总数: {len(rows)}")
    print()
    print("%-26s %-16s %4s  %s" % ("数组", "表名", "字段", "键字段(fIsKey)"))
    for arr, items in by.items():
        key_fields = [x["field"] for x in items if x["key_flag"] == "true"]
        print("%-26s %-16s %4d  %s" % (arr, tbl_map.get(arr, "—"), len(items),
                                       ", ".join(key_fields)))

    if args.stdout:
        cols = ["array", "table_hint", "field", "type", "key_flag", "size", "src_line"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["array", "table_hint", "field", "type", "key_flag", "size", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
