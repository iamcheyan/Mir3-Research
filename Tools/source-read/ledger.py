#!/usr/bin/env python3
"""全量源码精读销账台账：列出所有源码文件 + 阅读状态。

产出 docs/source-vs-reverse/coverage-ledger.tsv
列: area  rel_path  lines  bytes  status  note

status 取值:
  covered    已精读并写入文档
  partial    读了主要结构/部分区段
  pending    待读
  excluded   明确排除（第三方/非源码）
  missing    文件不存在（源码包缺失）

状态表写在 STATUS 字典里，由人工/agent 维护；脚本负责与磁盘实际文件对账，
报告「磁盘上有但状态表里没有」的文件，防止漏读。
"""
from __future__ import annotations

import argparse
import os
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(REPO, "reference", "mir3-source")
OUT = os.path.join(REPO, "docs", "source-vs-reverse", "coverage-ledger.tsv")

# 源码扩展名（只统计真源码，不含配置）
CODE_EXT = {".pas", ".dpr", ".cpp", ".h", ".hpp", ".c", ".sln", ".vcproj"}

# 第三方/非本项目源码：明确排除
EXCLUDE_PREFIXES = (
    "Source/Tools/ImageEditor/Plug/",      # 62,337 行第三方组件
)

# 状态表：rel_path -> (status, note)
STATUS: dict[str, tuple[str, str]] = {}


def _load_status():
    """状态表以 TSV 持久化，便于跨轮次累积。"""
    if not os.path.exists(OUT):
        return
    with open(OUT, encoding="utf-8") as f:
        next(f, None)
        for line in f:
            parts = line.rstrip("\n").split("\t")
            if len(parts) >= 5:
                STATUS[parts[1]] = (parts[4], parts[5] if len(parts) > 5 else "")


def _save(rows):
    cols = ["area", "rel_path", "lines", "bytes", "status", "note"]
    with open(OUT, "w", encoding="utf-8") as f:
        f.write("\t".join(cols) + "\n")
        for r in rows:
            f.write("\t".join(str(r[c]) for c in cols) + "\n")


def area_of(rel: str) -> str:
    if rel.startswith("Source/Client/"):
        return "D-client"
    if rel.startswith("Source/GameServer/"):
        return "A/C-server"
    if rel.startswith("Source/Common/"):
        return "C-common"
    if rel.startswith("Source/LoginServer/"):
        return "E-login"
    if rel.startswith("Source/DataBaseServer/"):
        return "E-db"
    if rel.startswith("Source/Tools/"):
        return "E-tools"
    return "other"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="只报告未登记文件")
    ap.add_argument("--summary", action="store_true", help="只打印统计")
    args = ap.parse_args()

    _load_status()

    found = []
    for root, dirs, files in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in (".git", ".svn", "__history")]
        for fn in sorted(files):
            ext = os.path.splitext(fn)[1].lower()
            if ext not in CODE_EXT:
                continue
            p = os.path.join(root, fn)
            rel = os.path.relpath(p, SRC)
            try:
                with open(p, "rb") as f:
                    n = sum(1 for _ in f)
            except OSError:
                n = 0
            found.append({
                "area": area_of(rel),
                "rel_path": rel,
                "lines": n,
                "bytes": os.path.getsize(p),
                "status": "",
                "note": "",
            })

    # 排除第三方
    for r in found:
        for pref in EXCLUDE_PREFIXES:
            if r["rel_path"].startswith(pref):
                r["status"] = "excluded"
                r["note"] = "第三方组件（GraphicEx/MyDirect9/pngimage/DelphiZlib）"
                break

    # 套用状态表
    unregistered = []
    for r in found:
        if r["status"] == "excluded":
            continue
        st = STATUS.get(r["rel_path"])
        if st:
            r["status"], r["note"] = st
        else:
            r["status"] = "pending"
            r["note"] = ""
            unregistered.append(r["rel_path"])

    # 合并：把本次新识别的状态写回 STATUS，避免下次运行丢失
    for r in found:
        if r["rel_path"] not in STATUS:
            STATUS[r["rel_path"]] = (r["status"], r["note"])

    # 统计
    by_status: dict[str, list] = {}
    for r in found:
        by_status.setdefault(r["status"], []).append(r)

    total_lines = sum(r["lines"] for r in found)
    covered_lines = sum(r["lines"] for r in by_status.get("covered", []))
    partial_lines = sum(r["lines"] for r in by_status.get("partial", []))
    pending_lines = sum(r["lines"] for r in by_status.get("pending", []))

    print("=== 源码文件销账统计 ===")
    print(f"文件总数      : {len(found)}")
    print(f"代码总行数    : {total_lines}")
    for st in sorted(by_status):
        v = by_status[st]
        print(f"  {st:10s}: {len(v):4d} 文件 / {sum(x['lines'] for x in v):7d} 行")
    print()
    print(f"已覆盖行数    : {covered_lines}  ({100*covered_lines/max(1,total_lines):.1f}%)")
    print(f"部分覆盖行数  : {partial_lines}  ({100*partial_lines/max(1,total_lines):.1f}%)")
    print(f"待读行数      : {pending_lines}  ({100*pending_lines/max(1,total_lines):.1f}%)")

    if unregistered:
        print(f"\n⚠️ 磁盘上有但状态表未登记的文件 ({len(unregistered)}):")
        for u in unregistered[:40]:
            print(f"  {u}")
        if len(unregistered) > 40:
            print(f"  ... 另有 {len(unregistered)-40} 个")

    if not args.summary:
        _save(found)
        print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
