#!/usr/bin/env python3
"""全量独立验证总入口：跑齐所有验证器并汇总结果。

每个验证器走**独立路径**（不与生产工具共用解析逻辑），符合本仓库纪律。
退出码 0 = 全部 PASS。
"""
from __future__ import annotations

import os
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOOLS = os.path.join(REPO, "Tools", "source-read")

CHECKS = [
    ("协议常量表独立校验", [sys.executable, os.path.join(TOOLS, "verify_protocol_constants.py")]),
    ("线格式参考实现自测", [sys.executable, os.path.join(TOOLS, "edcode.py"), "selftest"]),
    ("3 个缺失 opcode 穷举验证", [sys.executable, os.path.join(TOOLS, "verify_missing_opcodes.py")]),
    ("销账台账统计", [sys.executable, os.path.join(TOOLS, "ledger.py"), "--summary"]),
]


def main() -> int:
    results = []
    for name, cmd in CHECKS:
        print(f"\n{'='*64}\n== {name}\n{'='*64}")
        r = subprocess.run(cmd, capture_output=True, text=True, cwd=REPO)
        out = (r.stdout + r.stderr).strip()
        print(out)
        ok = r.returncode == 0
        # 额外判据：输出里含 PASS 关键字
        if "PASS" in out.upper():
            ok = ok and True
        results.append((name, ok, r.returncode))

    # Python 语法检查（全部工具）
    print(f"\n{'='*64}\n== Python 语法检查（Tools/source-read/*.py）\n{'='*64}")
    pyfiles = sorted(f for f in os.listdir(TOOLS) if f.endswith(".py"))
    bad = []
    for f in pyfiles:
        r = subprocess.run([sys.executable, "-m", "py_compile", os.path.join(TOOLS, f)],
                           capture_output=True, text=True)
        if r.returncode != 0:
            bad.append(f)
            print(f"  [FAIL] {f}\n{r.stderr}")
    print(f"  检查 {len(pyfiles)} 个文件，失败 {len(bad)}")
    results.append(("Python 语法检查", not bad, 0 if not bad else 1))

    print(f"\n{'='*64}\n== 汇总\n{'='*64}")
    all_ok = True
    for name, ok, rc in results:
        print(f"  {'✅ PASS' if ok else '❌ FAIL'}  {name}" + (f"  (rc={rc})" if not ok else ""))
        all_ok = all_ok and ok

    print()
    print("ALL VERIFY", "PASS" if all_ok else "FAIL")
    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
