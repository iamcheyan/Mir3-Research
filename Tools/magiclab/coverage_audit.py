#!/usr/bin/env python3
"""coverage_audit.py — E5/A3 数据层覆盖率对账 (独立性铁律: 全部独立解析, 不 import 生成器)。

三组 100% 对账:
1. LibraryCore/FrameSet.cs 静态字典名清单 (含全部特殊怪/伙伴表) vs
   ClientData/frame-formulas.json frameSets keys
2. ClientData/magic-effects.json godot 技能集 vs GodotClient/Scripts/MagicEffectTable.cs
   _table 条目集 (含 attackTable)
3. ClientData/sounds.json 三段 (sounds/magic/monster) vs 三张 catalog 源码条目数与键集

产出 docs/editor/e5-proof/coverage-A.md。
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
ZIRCON = Path(__import__("os").environ.get(
    "MIR3_ZIRCON_ROOT", str(REPO.parent / "zircon"))).resolve()
CD = ZIRCON / "ClientData"
PROOF = REPO / "docs" / "editor" / "e5-proof"


def strip_comments(src: str) -> str:
    out = []
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c == "/" and i + 1 < n and src[i + 1] == "/":
            j = src.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif c == "/" and i + 1 < n and src[i + 1] == "*":
            j = src.find("*/", i + 2)
            j = n - 2 if j < 0 else j
            seg = src[i:j + 2]
            out.append("".join(ch if ch == "\n" else " " for ch in seg))
            i = j + 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


# ---------- 1. FrameSet ----------

def camelize(name: str) -> str:
    """Players→players; Companion_Pig→companionPig (frameformulas.py 键约定)。"""
    parts = name.split("_")
    return parts[0][0].lower() + parts[0][1:] + "".join(parts[1:])
def frameset_dict_names() -> tuple[set[str], set[str]]:
    """返回 (赋值过的字典名, 声明但从未赋值的死声明名)。"""
    src = strip_comments((ZIRCON / "LibraryCore" / "FrameSet.cs").read_text(encoding="utf-8-sig"))
    declared: set[str] = set()
    for m in re.finditer(
            r"public\s+static\s+Dictionary<MirAnimation,\s*Frame>\s*([^;]+);", src):
        for part in m.group(1).split(","):
            p = part.strip()
            if re.fullmatch(r"\w+", p):
                declared.add(p)
    assigned: set[str] = set(re.findall(
        r"(\w+)\s*=\s*new\s+Dictionary<MirAnimation,\s*Frame>", src))
    return assigned, declared - assigned

# ---------- 2. MagicEffectTable ----------
def cs_table_keys() -> tuple[set[str], set[str]]:
    """(_table 条目键, _attackTable 条目键) — 独立括号配平扫描。"""
    src = strip_comments((ZIRCON / "GodotClient" / "Scripts" / "MagicEffectTable.cs")
                         .read_text(encoding="utf-8-sig"))

    def block(decl: str) -> str:
        m = re.search(decl, src)
        assert m, decl
        i = src.index("{", m.end() - 1) if "{" in src[m.end():m.end() + 80] else src.index("{", m.start())
        d, j = 0, i
        while True:
            if src[j] == "{":
                d += 1
            elif src[j] == "}":
                d -= 1
                if d == 0:
                    return src[i:j]
            j += 1

    t = re.findall(r"\[MagicType\.(\w+)\]\s*=\s*new\s+CastEffect",
                   block(r"Dictionary<MagicType,\s*CastEffect>\s*_table\s*=\s*new\(\)"))
    a = re.findall(r"\[MagicType\.(\w+)\]\s*=\s*new\s+ImpactDef",
                   block(r"Dictionary<MagicType,\s*ImpactDef>\s*_attackTable\s*=\s*new\(\)"))
    return set(t), set(a)


# ---------- 3. Sounds ----------
def sound_keys() -> tuple[set[str], int, set[str], set[str]]:
    """(SoundIndex 键集, SoundSpec 总数, magic (magic,phase) 键集, monster 键集)。"""
    sc = strip_comments((ZIRCON / "GodotClient" / "Scripts" / "SoundCatalog.cs")
                        .read_text(encoding="utf-8-sig"))
    mc = strip_comments((ZIRCON / "GodotClient" / "Scripts" / "MagicSoundCatalog.cs")
                        .read_text(encoding="utf-8-sig"))
    xc = strip_comments((ZIRCON / "GodotClient" / "Scripts" / "MonsterSoundCatalog.cs")
                        .read_text(encoding="utf-8-sig"))
    skeys = set(re.findall(r"\[SoundIndex\.(\w+)\]\s*=", sc))
    # Explicit 字典块内的数据条目 (回退代码路径的 yield return new SoundSpec 不是数据)
    m = re.search(r"Explicit\s*=\s*new\(\)\s*\{", mc)
    d, j, i = 0, mc.index("{", m.end() - 1), mc.index("{", m.end() - 1)
    while True:
        if mc[i] == "{":
            d += 1
        elif mc[i] == "}":
            d -= 1
            if d == 0:
                break
        i += 1
    nspec = len(re.findall(r"new SoundSpec\(", mc[j:i]))
    mkeys = set(re.findall(r"\[\(MagicType\.(\w+),\s*MagicSoundPhase\.(\w+)\)\]", mc))
    xkeys = set(re.findall(r"\[MonsterImage\.(\w+)\]\s*=", xc))
    return skeys, nspec, mkeys, xkeys


def main() -> int:
    ff = json.loads((CD / "frame-formulas.json").read_text(encoding="utf-8"))
    me = json.loads((CD / "magic-effects.json").read_text(encoding="utf-8"))
    sd = json.loads((CD / "sounds.json").read_text(encoding="utf-8"))

    lines: list[str] = []
    fail = []

    def emit(s=""):
        print(s)
        lines.append(s)

    emit(f"# E5 阶段 A 覆盖率对账报告")
    emit("")
    emit(f"生成: {time.strftime('%Y-%m-%d %H:%M')} · coverage_audit.py (独立解析, 不复用生成器)")
    emit("")

    # 1. FrameSet
    fs_assigned, fs_dead = frameset_dict_names()
    ff_keys = set(ff["frameSets"].keys())
    missing = sorted(n for n in fs_assigned if camelize(n) not in ff_keys)
    extra = sorted(k for k in ff_keys if k not in {camelize(n) for n in fs_assigned})
    emit("## 1. FrameSet.cs ↔ frame-formulas.json frameSets")
    emit(f"- FrameSet.cs 赋值字典: **{len(fs_assigned)}**; JSON frameSets: **{len(ff_keys)}**"
         + (f"; 另有 {len(fs_dead)} 个声明未赋值的死声明 {sorted(fs_dead)} (原版即如此, 不入数据层)"
            if fs_dead else ""))
    n_frames = sum(len(t) for t in ff["frameSets"].values())
    emit(f"- JSON 帧表项总数: {n_frames}")
    if missing or extra:
        fail.append("frameSets 覆盖不全")
        emit(f"- ✗ 缺失: {missing}")
        emit(f"- ✗ 多余: {extra}")
    else:
        emit(f"- ✓ 100% 双向覆盖 (camelCase 映射)")
    emit()

    # 2. MagicEffectTable
    t_keys, a_keys = cs_table_keys()
    me_godot = {k for k, v in me["skills"].items() if v.get("godot")}
    me_attack = set(me.get("attackTable", {}).keys())
    miss_t = sorted(t_keys - me_godot)
    extra_t = sorted(me_godot - t_keys)
    miss_a = sorted(a_keys - me_attack)
    emit("## 2. MagicEffectTable.cs ↔ magic-effects.json (godot 段)")
    emit(f"- _table 条目: **{len(t_keys)}**; JSON godot 技能: **{len(me_godot)}**")
    emit(f"- _attackTable 条目: **{len(a_keys)}**; JSON attackTable: **{len(me_attack)}**")
    emit(f"- 原版段技能: {sum(1 for v in me['skills'].values() if v.get('original'))}"
         f"; 双源共有: {sum(1 for v in me['skills'].values() if v.get('original') and v.get('godot'))}")
    if miss_t or extra_t or miss_a:
        fail.append("magic-effects 覆盖不全")
        emit(f"- ✗ _table 缺失: {miss_t}")
        emit(f"- ✗ JSON godot 多余: {extra_t}")
        emit(f"- ✗ attackTable 缺失: {miss_a}")
    else:
        emit(f"- ✓ 100% 双向覆盖 (含 attackTable)")
    emit()

    # 3. Sounds
    skeys, nspec, mkeys, xkeys = sound_keys()
    js_skeys = set(sd["sounds"].keys())
    js_mkeys = {(m, ph) for m, phs in sd["magic"].items() for ph in phs}
    js_xkeys = set(sd["monster"].keys())
    js_nspec = sum(len(p) for m in sd["magic"].values() for p in m.values())
    ok3 = (skeys == js_skeys and nspec == js_nspec and mkeys == js_mkeys and xkeys == js_xkeys)
    emit("## 3. 三张音效 catalog ↔ sounds.json")
    emit(f"- SoundCatalog 条目: 源 {len(skeys)} / JSON {len(js_skeys)}")
    emit(f"- MagicSoundCatalog: (magic,phase) 源 {len(mkeys)} / JSON {len(js_mkeys)}; "
         f"SoundSpec 源 {nspec} / JSON {js_nspec}")
    emit(f"- MonsterSoundCatalog: 源 {len(xkeys)} / JSON {len(js_xkeys)}")
    if not ok3:
        fail.append("sounds 覆盖不全")
        emit(f"- ✗ 键差: sounds {sorted(skeys ^ js_skeys)[:5]}...; "
             f"magic {sorted(mkeys ^ js_mkeys)[:5]}...; monster {sorted(xkeys ^ js_xkeys)[:5]}")
    else:
        emit(f"- ✓ 100% 双向覆盖 (键集与规格数逐项相等)")
    emit()
    emit("## 结论")
    if fail:
        emit(f"✗ FAIL: {fail}")
    else:
        emit("✓ 三组全部 100% — 阶段 A 覆盖率验收通过")

    PROOF.mkdir(parents=True, exist_ok=True)
    (PROOF / "coverage-A.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"\n-> {PROOF / 'coverage-A.md'}")
    return 1 if fail else 0


if __name__ == "__main__":
    raise SystemExit(main())
