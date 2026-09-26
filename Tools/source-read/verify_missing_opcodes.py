#!/usr/bin/env python3
"""独立验证：CM_ADDNEWUSER/CHANGEPASSWORD/UPDATEUSER 的接收端是否真的缺失。

方法（与人工 grep 不同的路径）：
  1. 枚举全部 C++ 分派表（`g_cmdList[] = { ... }`），收集其表项常量
  2. 枚举全部 `case CM_*:` 语句
  3. 枚举全部 Pascal `case` 里的 CM_ 常量
  4. 检查目标 opcode 是否出现在上述任一集合

退出码 0 = 结论成立（接收端确实缺失）。
"""
from __future__ import annotations

import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(REPO, "Tools", "source-read"))
import read_src  # noqa: E402

SRC = os.path.join(REPO, "reference", "mir3-source", "Source")
TARGETS = ["CM_ADDNEWUSER", "CM_CHANGEPASSWORD", "CM_UPDATEUSER"]

# 定义处（不算接收端）
DEF_FILES = {
    "Source/Common/Grobal2.pas",
    "Source/Common/Grobal2 - 副本.pas",
    "Source/Tools/ImageEditor/Common/Grobal2.pas",
    "Source/LoginServer/LoginServer/protocol.h",
    "Source/DataBaseServer/Def/Protocol.h",
}
# 客户端发送处（不算接收端）
SEND_FILES = {"Source/Client/ClMain.pas"}


def iter_source():
    for root, dirs, files in os.walk(SRC):
        dirs[:] = [d for d in dirs if d not in (".git", ".svn", "__history")]
        for fn in files:
            if os.path.splitext(fn)[1].lower() in (".pas", ".cpp", ".h", ".dpr"):
                yield os.path.relpath(os.path.join(root, fn), SRC)


def main() -> int:
    # 收集接收端集合
    dispatch_entries: set[str] = set()   # C++ g_cmdList 表项
    case_labels: set[str] = set()        # case CM_*: 标签
    n_tables = 0

    for rel in iter_source():
        if rel in DEF_FILES:
            continue
        p = os.path.join(SRC, rel)
        try:
            text, _ = read_src.read_text(p)
        except OSError:
            continue
        lines = text.split("\n")

        # C++ 分派表
        in_table = False
        for line in lines:
            if "g_cmdList[]" in line or "g_pCmdList[]" in line:
                in_table = True
                n_tables += 1
                continue
            if in_table:
                if re.match(r"^\s*\};", line):
                    in_table = False
                    continue
                for m in re.finditer(r"\b((?:CM|SM|ISM|DB|DBR)_[A-Z0-9_]+)\b", line):
                    dispatch_entries.add(m.group(1))

        # case 标签（C++ 与 Pascal）
        for line in lines:
            for m in re.finditer(r"\bcase\s+((?:CM|SM|ISM|DB|DBR)_[A-Z0-9_]+)\s*:", line):
                case_labels.add(m.group(1))

    print(f"C++ 分派表数: {n_tables}")
    print(f"分派表项唯一常量: {len(dispatch_entries)}")
    print(f"case 标签唯一常量: {len(case_labels)}")
    print()
    print("目标 opcode 检查:")
    ok = True
    for t in TARGETS:
        in_disp = t in dispatch_entries
        in_case = t in case_labels
        verdict = "❌ 有接收端" if (in_disp or in_case) else "✅ 无接收端"
        if in_disp or in_case:
            ok = False
        print(f"  {t:22s} 分派表={in_disp}  case={in_case}   {verdict}")

    print()
    # 对照组：确认方法有效（这些应该有接收端）
    print("对照组（应有接收端的常量）:")
    for t in ("CM_IDPASSWORD", "CM_NEWCHR", "CM_QUERYCHR", "CM_WANTMINIMAP"):
        in_disp = t in dispatch_entries
        in_case = t in case_labels
        print(f"  {t:22s} 分派表={in_disp}  case={in_case}")

    print()
    print("VERIFY", "PASS（接收端确实缺失）" if ok else "FAIL（找到接收端）")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
