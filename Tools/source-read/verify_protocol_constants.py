#!/usr/bin/env python3
"""独立校验 protocol-constants.tsv。

纪律：**不得复用 extract_protocol_constants.py 的解析逻辑**，否则错误会自洽。
本脚本刻意走完全不同的路径：

  1. 不做逐行正则匹配，而是把整个文件按 `;` 切成语句片段再解析
     （生成器是逐行 `^\\s*NAME = VALUE;`）。
  2. 用独立维护的前缀白名单，而不是生成器的 kind_of 映射。
  3. 行号通过「数到目标语句为止的换行数」独立计算。

校验内容：
  A. TSV 行数与重新解析出的常量数一致
  B. 每条 (name, value, src_line) 三元组一致
  C. 无重名
  D. 每个值都能在协议区间内（0 < v <= 0xFFFF）
  E. 所有前缀都在白名单内
  F. TSV 的 hex 列与 value 列自洽

退出码 0 = PASS，1 = FAIL。
"""
from __future__ import annotations

import csv
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TSV = os.path.join(REPO, "docs", "source-vs-reverse", "protocol-constants.tsv")
SRC = os.path.join(REPO, "reference", "mir3-source", "Source", "Common", "Grobal2.pas")

PREFIXES = {"CM", "SM", "ISM", "DBR"}

# 独立解析：按分号切语句，再从语句里抠「名字 = 值」。
# 刻意与生成器的逐行正则不同：这里允许名字与值之间跨行/带注释。
STMT_FULL = re.compile(
    r"\b((?:CM|SM|ISM|DBR)_[A-Z0-9_]+)\b\s*=\s*(\$[0-9A-Fa-f]+|\d+)"
)


def parse_independently(path: str) -> dict[str, tuple[int, int]]:
    """返回 {name: (value, line_no)}。

    编码：本文件实测为 CP949 为主 + 零星 GB18030。校验只关心 ASCII 的
    标识符与数字，所以直接按 latin-1 读字节即可 —— 这是**刻意**与生成器
    走不同的路，避免继承生成器的编码判定错误。
    """
    with open(path, "rb") as f:
        raw = f.read()
    text = raw.decode("latin-1")

    out: dict[str, tuple[int, int]] = {}
    pos = 0
    for stmt in text.split(";"):
        # 该语句结束位置对应的行号（1-based）
        end = pos + len(stmt)
        line_no = text.count("\n", 0, end) + 1
        pos = end + 1

        # 名字先找（注释里也可能出现 CM_xxx，所以优先取「有 = 值」的那个名字）
        # 注意 1：不能先 strip 注释再找名字 —— 分号切分后，片段可能以
        # 「上一行的行尾注释」开头，例如：
        #   ' //교환하는 돈이 변경됨\r\n   CM_DEALEND   = 1030'
        # 此时 split('//')[0] 会得到空串，把真正的名字一起丢掉。
        # 正确做法：在整段里找「NAME = VALUE」这个完整模式。
        # 注意 2：必须排除**被注释掉的整行定义**，例如：
        #   //SM_READYFIREHIT         = 1000;  //클라이언트에서만 쓰임
        # 这类是历史遗留/未启用常量，生成器（逐行 `^\s*NAME`）天然排除，
        # 本校验也必须排除，否则会把 5 条注释掉的常量误报成「缺失」。
        m_full = STMT_FULL.search(stmt)
        if not m_full:
            continue
        # 取该名字所在行，确认它没有被行首的 // 注释掉
        name_abs = end - len(stmt) + m_full.start(1)
        line_start = text.rfind("\n", 0, name_abs) + 1
        line_head = text[line_start:name_abs]
        if "//" in line_head:
            continue
        name = m_full.group(1)
        raw_val = m_full.group(2)
        value = int(raw_val[1:], 16) if raw_val.startswith("$") else int(raw_val)
        # 行号按值所在位置算（= 号所在行）
        val_end = end - len(stmt) + m_full.end(2)
        line_no = text.count("\n", 0, val_end) + 1
        # 同一名字只保留第一次出现（TSV 也应是首次）
        if name not in out:
            out[name] = (value, line_no)
    return out


def main() -> int:
    fails: list[str] = []

    if not os.path.exists(TSV):
        print(f"[FAIL] 缺 TSV: {TSV}")
        return 1

    rows = list(csv.DictReader(open(TSV, encoding="utf-8"), delimiter="\t"))
    print(f"[info] TSV 行数: {len(rows)}")

    # --- A/B: 与独立解析比对 ---
    indep = parse_independently(SRC)
    print(f"[info] 独立解析常量数: {len(indep)}")
    if len(rows) != len(indep):
        fails.append(f"A 行数不一致: TSV={len(rows)} 独立解析={len(indep)}")

    tsv_names = [r["name"] for r in rows]
    set_tsv = set(tsv_names)
    set_indep = set(indep)
    only_tsv = sorted(set_tsv - set_indep)
    only_indep = sorted(set_indep - set_tsv)
    if only_tsv:
        fails.append(f"B 仅 TSV 有: {only_tsv[:10]}")
    if only_indep:
        fails.append(f"B 仅独立解析有: {only_indep[:10]}")

    mismatch = []
    for r in rows:
        n = r["name"]
        if n not in indep:
            continue
        v_indep, line_indep = indep[n]
        if int(r["value"]) != v_indep:
            mismatch.append(f"{n}: 值 TSV={r['value']} vs {v_indep}")
        # 行号允许 ±2 的偏差（分号切分与逐行匹配的边界差异）
        if abs(int(r["src_line"]) - line_indep) > 2:
            mismatch.append(f"{n}: 行号 TSV={r['src_line']} vs {line_indep}")
    if mismatch:
        fails.append(f"B 字段不一致 {len(mismatch)} 条: {mismatch[:6]}")

    # --- C: 无重名 ---
    dupes = {n for n in tsv_names if tsv_names.count(n) > 1}
    if dupes:
        fails.append(f"C 重名: {sorted(dupes)[:10]}")

    # --- D: 值域 ---
    bad_range = [r["name"] for r in rows if not (0 < int(r["value"]) <= 0xFFFF)]
    if bad_range:
        fails.append(f"D 值越界: {bad_range[:10]}")

    # --- E: 前缀白名单 ---
    bad_pfx = sorted({r["prefix"] for r in rows} - PREFIXES)
    if bad_pfx:
        fails.append(f"E 未知前缀: {bad_pfx}")

    # --- F: hex 列自洽 ---
    bad_hex = [r["name"] for r in rows
               if int(r["hex"], 16) != int(r["value"]) or int(r["dec"]) != int(r["value"])]
    if bad_hex:
        fails.append(f"F hex/dec 列不自洽: {bad_hex[:10]}")

    # --- 附: 前缀分布 ---
    dist: dict[str, int] = {}
    for r in rows:
        dist[r["prefix"]] = dist.get(r["prefix"], 0) + 1
    print(f"[info] 前缀分布: {dict(sorted(dist.items()))}")

    print()
    if fails:
        for f in fails:
            print(f"[FAIL] {f}")
        print("\nVERIFY FAIL")
        return 1
    print("VERIFY PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
