#!/usr/bin/env python3
"""提取 SQL 表定义（DataBaseServer/DBSvr/tablesdefine.cpp）。

**这是 `System.db` 的上游 SQL 表结构**。
格式：`MIRDB_FIELDS __XXXFIELDS[] = { { "FLD_NAME", TABLETYPE_XXX, is_primary, size }, ... };`

产出 docs/source-vs-reverse/sql-tables.tsv
列: array  table_hint  field  type  primary  size  src_line
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
        ma = RE_ARRAY.search(line)
        if ma:
            cur_arr = ma.group(1)
            continue
        for m in RE_FIELD.finditer(line):
            rows.append({
                "array": cur_arr or "(未归属)",
                "table_hint": "",
                "field": m.group(1),
                "type": m.group(2),
                "primary": m.group(3),
                "size": m.group(4),
                "src_line": i,
            })
        # 数组结束
        if cur_arr and re.match(r"^\s*\};", line):
            cur_arr = ""

    for r in rows:
        r["table_hint"] = tbl_map.get(r["array"], "")

    from collections import Counter, OrderedDict
    by: dict[str, list] = OrderedDict()
    for r in rows:
        by.setdefault(r["array"], []).append(r)

    print(f"字段数组: {len(by)}   字段总数: {len(rows)}")
    print()
    print("%-26s %-16s %4s  %s" % ("数组", "表名", "字段", "主键字段"))
    for arr, items in by.items():
        pk = [x["field"] for x in items if x["primary"] == "true"]
        print("%-26s %-16s %4d  %s" % (arr, tbl_map.get(arr, "—"), len(items),
                                       ", ".join(pk)))

    if args.stdout:
        cols = ["array", "table_hint", "field", "type", "primary", "size", "src_line"]
        for r in rows:
            print("\t".join(str(r[c]) for c in cols))
        return 0

    cols = ["array", "table_hint", "field", "type", "primary", "size", "src_line"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")
    print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
