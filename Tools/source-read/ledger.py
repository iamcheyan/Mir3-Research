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

# 载入时的原始快照（用于防降级守卫）
_ORIG_STATUS: dict[str, tuple[str, str]] = {}


def _git_head_status() -> dict[str, tuple[str, str]]:
    """读 git HEAD 版本的台账状态，作为防降级基线。

    文件在工作区被改坏时，载入值不可信；git HEAD 是最后一个已提交的好状态。
    非 git 环境或路径未跟踪时返回空 dict（守卫静默跳过）。
    """
    import subprocess

    rel = os.path.relpath(OUT, REPO)
    try:
        out = subprocess.run(
            ["git", "-C", REPO, "show", f"HEAD:{rel}"],
            capture_output=True, text=True, timeout=20,
        )
    except (OSError, subprocess.SubprocessError):
        return {}
    if out.returncode != 0:
        return {}
    res: dict[str, tuple[str, str]] = {}
    for line in out.stdout.splitlines()[1:]:
        parts = line.split("\t")
        if len(parts) >= 5:
            res[parts[1]] = (parts[4], parts[5] if len(parts) > 5 else "")
    return res


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
    ap.add_argument("--allow-downgrade", action="store_true",
                    help="允许把 covered 降级（默认拒绝，防误抹）")
    args = ap.parse_args()

    _load_status()
    _ORIG_STATUS.clear()
    _ORIG_STATUS.update(STATUS)

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
    downgraded: list[str] = []
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

    # 防降级守卫：covered 是最高状态，绝不允许被 covered->partial/pending 的
    # 编辑意外抹掉（2026-09-26 真实踩过：改 note 时把 LocalDB.pas / ObjNpc.pas
    # 从 covered 降成 partial，covered 行数 42730 -> 33672）。
    # 判据取 **git HEAD 版本**（不是本次载入值），否则文件已被改坏时无从察觉。
    # 需要真正降级时，显式传 --allow-downgrade。
    if not args.allow_downgrade:
        baseline = _git_head_status()
        for r in found:
            old = baseline.get(r["rel_path"])
            if old and old[0] == "covered" and r["status"] != "covered":
                r["status"], r["note"] = old
                downgraded.append(r["rel_path"])

    # 写回 STATUS（含守卫修正后的值）
    for r in found:
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

    if downgraded:
        print(f"\n⚠️ 阻止了 {len(downgraded)} 个文件的 covered 降级（已保留原状态）:")
        for d in downgraded:
            print(f"  {d}")
        print("  确实要降级请加 --allow-downgrade")

    if not args.summary:
        _save(found)
        print(f"\n已写 {os.path.relpath(OUT, REPO)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
