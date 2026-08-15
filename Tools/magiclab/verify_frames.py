#!/usr/bin/env python3
"""Magic Lab P0 — 帧可解码性交叉验证（独立于提取器）。

铁律（总纲 §0）：验证工具必须独立于生产工具。本脚本不复用
extract_effect_table.py 的任何解析逻辑——只消费其 JSON 产物，
并用 zlsdk（与提取器的文本解析完全不同的代码路径）独立回答：

  JSON 里声明的每个 (lib, frame..frame+count) 帧区间，
  在真实 .Zl 库里是否真的存在且可解码？

输出：docs/magiclab/FRAME_VERIFY.md + 退出码（0=全绿，1=有坏帧）。
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(REPO / "Tools" / "common"))
import zlsdk  # noqa: E402

ZIRCON = Path(__import__("os").environ.get(
    "MIR3_ZIRCON_ROOT", "/home/tetsuya/development/zircon")).resolve()
DATA = ZIRCON / "Debug" / "Client" / "Data"
TABLE = REPO / "Tools" / "magiclab" / "magic-effect-table.json"
OUT = REPO / "docs" / "magiclab" / "FRAME_VERIFY.md"


def main() -> int:
    table = json.loads(TABLE.read_text(encoding="utf-8"))
    table.pop("_meta", None)

    libs: dict[str, zlsdk.ZlLibrary] = {}
    problems: list[str] = []
    checked = 0
    blanks: list[str] = []
    blank_warn = 0

    for name in sorted(table):
        entry = table[name]
        for seg in ("start", "release"):
            for eff in entry.get(seg, {}).get("effects", []):
                lib = eff.get("lib")
                frame = eff.get("frame")
                count = eff.get("count") or 0
                if not lib or frame is None:
                    continue
                key = lib
                if key not in libs:
                    path = DATA / f"{lib}.Zl"
                    if not path.exists():
                        problems.append(f"{name}/{seg}: 库文件不存在 {path}")
                        libs[key] = None
                        continue
                    libs[key] = zlsdk.ZlLibrary(str(path))
                libobj = libs[key]
                if libobj is None:
                    continue
                skip = (eff.get("extra") or {}).get("Skip", 10)
                # 基准帧（Direction=0 / Direction16=0）：硬校验
                for fi in (frame, frame + count - 1):
                    checked += 1
                    if fi < 0 or fi >= libobj.count:
                        problems.append(
                            f"{name}/{seg} {lib}#{fi}: 越界 (库共 {libobj.count} 帧)")
                        continue
                    if libobj.is_blank(fi):
                        blanks.append(f"{name}/{seg} {lib}#{fi}")
                # 方向偏移组（4*Skip/15*Skip）：信息级——原版同样会算出这些
                # 帧号，库尾越界/空白时原版表现为"该方向不绘制"，行为一致即对齐
                for fi in (frame + 4 * skip, frame + 15 * skip + count - 1):
                    if fi < 0 or fi >= libobj.count or libobj.is_blank(fi):
                        blank_warn += 1

    lines = [
        "# Magic Lab — 帧可解码性交叉验证报告",
        "",
        "- 事实源: `Tools/magiclab/magic-effect-table.json`",
        f"- 基准帧检查点: {checked} 个（每特效首/尾帧硬校验）",
        f"- 库目录: `{DATA}`",
        f"- 结果: {'✅ 全部通过' if not problems else f'❌ {len(problems)} 个提取错误'}",
        f"- 原版资源现状（非提取错误）: {len(blanks)} 个基准帧空白"
        f" + {blank_warn} 个方向偏移帧空白/越界——原版播放到这些帧同样不绘制，行为一致",
    ]
    if problems:
        lines += ["## 问题清单", ""]
        lines += [f"- {p}" for p in problems]
    else:
        lines += ["全部声明基准帧在真实 .Zl 库中存在且在库界内。"]
    if blanks:
        lines += ["", "## 基准帧空白明细（原版资源现状，提取与原版一致）", ""]
        lines += [f"- {b}" for b in blanks]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"checked={checked} problems={len(problems)} blank_tail_warn={blank_warn}")
    print(f"-> {OUT}")
    return 1 if problems else 0


if __name__ == "__main__":
    raise SystemExit(main())
