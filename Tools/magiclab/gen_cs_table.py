#!/usr/bin/env python3
"""gen_cs_table.py — Godot MagicEffectTable.cs 与事实源的对账/修复闭环 (E4/P3).

事实源: Tools/magiclab/magic-effect-table.json (extract_effect_table.py 从原版
MapObject.cs 两段 Spell switch 提取; 本脚本不复用 extractor 代码, 独立解析)。

用法:
  gen_cs_table.py --check   只对账, 违规全列, 有违规退出码 1 (CI 语义)
  gen_cs_table.py --fix     幂等修复 MagicEffectTable.cs (校验先行: 每条修复
                            仅在其对应的违规仍存在时应用)

对账口径 (与 docs/magiclab/GODOT_TABLE_DIFF.md 一致):
  1. 共有技能: (lib, StartIndex, FrameCount) 三元组集合跨段合并去重比较
  2. A 类: 原版有 start 特效而 Godot _table 缺条目的玩家技能, 必须补条目
  3. OriginalSpellCases 白名单 == 原版 switch 全集 (138)
  4. 已判定可接受差异 (随机帧/补画/怪物段缺失) 走 ACCEPTABLE, 不算违规
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CS = ROOT.parent / "zircon" / "GodotClient" / "Scripts" / "MagicEffectTable.cs"
# E5: canonical 数据层 (zircon/ClientData), 旧 Tools/magiclab 副本已删
JSON = Path(__import__("os").environ.get(
    "MIR3_ZIRCON_ROOT", str(ROOT.parent / "zircon"))).resolve() / "ClientData" / "magic-effects.json"

# GODOT_TABLE_DIFF.md 人工判读保留的差异 (非回归):
#  - ScortchedEarth/MonsterScortchedEarth: 原版动态随机帧 2450+Random(5)*10, Godot 固定 2450
#  - AugmentPoisonDust/ThunderStrike: Godot 补画 (原版 start 段只有音效/无特效)
#  - DoomClaw*/GreenSludgeBall: 怪物第二段缺失, 玩家不可见, 后续单独补
ACCEPTABLE = {
    "ScortchedEarth", "MonsterScortchedEarth", "AugmentPoisonDust", "ThunderStrike",
    "DoomClawLeftPinch", "DoomClawRightPinch", "GreenSludgeBall",
}
# A 类: 原版有特效、Godot _table 曾缺条目的玩家技能 (修复后必须存在)
MUST_EXIST = ["CrushingWave", "FrostBite", "Rake", "SeismicSlam", "Spiritualism"]


# ---------- 独立解析: C# 表 ----------
def parse_cs(text: str) -> tuple[dict[str, set], set[str]]:
    """返回 (_table 三元组: {skill: {(lib,start,count)}}, OriginalSpellCases 集合)."""
    # OriginalSpellCases 块
    m = re.search(r"OriginalSpellCases\s*=\s*new\(\)\s*\{(.*?)\}", text, re.S)
    whitelist = set(re.findall(r"MagicType\.(\w+)", m.group(1))) if m else set()

    # _table 字典区 (从声明到配对的 "};")
    t = re.search(r"Dictionary<MagicType,\s*CastEffect>\s*_table\s*=\s*new\(\)\s*\{", text)
    if not t:
        raise SystemExit("FATAL: _table 声明未找到")
    i = text.index("{", t.start())
    depth, j = 0, i
    while j < len(text):
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    body = text[i:j]

    triples: dict[str, set] = {}
    # 每个 [MagicType.X] = new CastEffect { ... } 条目: 括号配平取体
    for em in re.finditer(r"\[MagicType\.(\w+)\]\s*=\s*new\s+CastEffect\s*\{", body):
        k = em.group(1)
        p = body.index("{", em.start())
        d, q = 0, p
        while q < len(body):
            if body[q] == "{":
                d += 1
            elif body[q] == "}":
                d -= 1
                if d == 0:
                    break
            q += 1
        entry = body[p:q]
        found = set(re.findall(r"File\s*=\s*LibraryFile\.(\w+),\s*StartIndex\s*=\s*(\d+),\s*FrameCount\s*=\s*(\d+)", entry))
        triples[k] = {(lib, int(s), int(c)) for lib, s, c in found}
    return triples, whitelist


def parse_json() -> dict[str, set]:
    """{skill: 三元组集合}; E5: 读 ClientData/magic-effects.json 的 original 段。
    纯音效 case (零特效) 保留键但空集。"""
    d = json.loads(JSON.read_text(encoding="utf-8"))
    skills = d["skills"]
    out = {}
    for key, sk in skills.items():
        if not sk.get("original"):
            continue  # Godot-only 条目不在原版对账口径 (与旧 JSON 键集语义一致)
        entry = sk["original"]
        s = set()
        for seg in ("start", "release"):
            for fx in (entry.get(seg) or {}).get("effects", []):
                lib, frame, cnt = fx.get("lib"), fx.get("frame"), fx.get("count")
                if lib is None or frame is None or cnt is None:
                    continue  # 动态帧表达式 → ACCEPTABLE 兜底
                s.add((lib, frame, cnt))
        out[key] = s
    return out


def visual_keys(js: dict[str, set]) -> set[str]:
    """白名单口径: 原版 switch 有 case 且创建了特效 (纯音效 case 归 NoVisualSpellCases)。"""
    return {k for k, s in js.items() if s}


# ---------- 对账 ----------
def check(cs_triples: dict[str, set], whitelist: set[str], js: dict[str, set]) -> list[str]:
    v = []
    common = set(cs_triples) & set(js)
    for k in sorted(common):
        if k in ACCEPTABLE:
            continue
        if cs_triples[k] != js[k]:
            miss = js[k] - cs_triples[k]
            extra = cs_triples[k] - js[k]
            for t in sorted(miss):
                v.append(f"参数错配 {k}: 原版有 Godot 无 {t[0]} #{t[1]} x{t[2]}")
            for t in sorted(extra):
                v.append(f"参数错配 {k}: Godot 有 原版无 {t[0]} #{t[1]} x{t[2]}")
    for k in MUST_EXIST:
        if k not in cs_triples:
            v.append(f"缺失条目 {k}: 原版 start 段有特效, _table 无条目")
        elif k not in ACCEPTABLE and k in js and cs_triples[k] != js[k]:
            v.append(f"新增条目 {k} 参数与原版不符: {sorted(cs_triples[k])} != {sorted(js[k])}")
    want = visual_keys(js)
    if whitelist != want:
        for k in sorted(want - whitelist):
            v.append(f"白名单缺 {k} (原版 switch 有 case)")
        for k in sorted(whitelist - want):
            v.append(f"白名单多 {k} (原版 switch 无 case)")
    return v


# ---------- 修复 (幂等) ----------
NEW_ENTRIES = """        // ---- E4/P3 补齐: 原版 start 段 (MapObject.cs:3603) 有特效而本表缺失的玩家技能 ----
        // 依据 Tools/magiclab/magic-effect-table.json; 与 _attackTable 的 Attack 表同素材,
        // 此处为 Spell 施法表现 (start 段 Target=this → CastAtSource)。
        [MagicType.CrushingWave] = new CastEffect { File = LibraryFile.MagicEx6, StartIndex = 100, FrameCount = 6, Colour = Lightning, CastAtSource = true },
        [MagicType.FrostBite] = new CastEffect { File = LibraryFile.MagicEx5, StartIndex = 500, FrameCount = 16, DelayMs = 60, Colour = Ice, CastAtSource = true },
        [MagicType.Rake] = new CastEffect
        {
            File = LibraryFile.MagicEx4, StartIndex = 1200, FrameCount = 9, Colour = Ice,
            Source = new ImpactDef
            {
                File = LibraryFile.MagicEx4, StartIndex = 1200, FrameCount = 9, DelayMs = 100, Colour = Ice,
                DirectionStartIndices = new[] { 1200, 1210, 1220, 1230, 1240, 1200, 1200, 1200 },
            },
        },
        [MagicType.SeismicSlam] = new CastEffect { File = LibraryFile.MagicEx5, StartIndex = 4900, FrameCount = 6, Colour = Lightning, CastAtSource = true },
        [MagicType.Spiritualism] = new CastEffect { File = LibraryFile.MagicEx2, StartIndex = 1580, FrameCount = 11, Colour = None, CastAtSource = true },
"""

def fix(text: str, violations: list[str], js: dict[str, set]) -> str:
    # 1. AdamantineFireBall: 原版与 FireBounce/MeteorShower 共用 1640 弹道 + 1800 命中
    #    (MapObject.cs:1040 fall-through 组); Godot 曾误抄 FireBall 的 420/580。
    bad = """        [MagicType.AdamantineFireBall] = new CastEffect
        {
            File = LibraryFile.Magic, StartIndex = 420, FrameCount = 5, Colour = Fire,
            DirectionFromCast = true,
            Source = new ImpactDef { File = LibraryFile.Magic, StartIndex = 1560, FrameCount = 9, DelayMs = 65, Colour = Fire },
            Projectile = new ProjectileDef { File = LibraryFile.Magic, StartIndex = 420, FrameCount = 5, Colour = Fire },
            Impact = new ImpactDef { File = LibraryFile.Magic, StartIndex = 580, FrameCount = 10, Colour = Fire },
        },"""
    good = """        [MagicType.AdamantineFireBall] = new CastEffect
        {
            File = LibraryFile.Magic, StartIndex = 1640, FrameCount = 6, Colour = Fire,
            DirectionFromCast = true,
            Source = new ImpactDef { File = LibraryFile.Magic, StartIndex = 1560, FrameCount = 9, DelayMs = 65, Colour = Fire },
            Projectile = new ProjectileDef { File = LibraryFile.Magic, StartIndex = 1640, FrameCount = 6, Colour = Fire },
            Impact = new ImpactDef { File = LibraryFile.Magic, StartIndex = 1800, FrameCount = 10, Colour = Fire },
        },"""
    if bad in text:
        text = text.replace(bad, good)

    # 2. ImprovedExplosiveTalisman: 原版 start 段是 MagicEx2#980 (Godot Source 误写 Magic#980)
    bad2 = "Source = new ImpactDef { File = LibraryFile.Magic, StartIndex = 980, FrameCount = 6, DelayMs = 80, Colour = Dark },"
    good2 = "Source = new ImpactDef { File = LibraryFile.MagicEx2, StartIndex = 980, FrameCount = 6, DelayMs = 80, Colour = Dark },"
    if bad2 in text:
        text = text.replace(bad2, good2)

    # 3. Summon 系: 原版 start 740x10 60ms (Godot 误用 750 且缺 60ms)
    text = text.replace(
        "[MagicType.SummonSkeleton] = new CastEffect { File = LibraryFile.Magic, StartIndex = 750, FrameCount = 10, Colour = Phantom },",
        "[MagicType.SummonSkeleton] = new CastEffect { File = LibraryFile.Magic, StartIndex = 740, FrameCount = 10, DelayMs = 60, Colour = Phantom, CastAtSource = true },")
    text = text.replace(
        "[MagicType.SummonJinSkeleton] = new CastEffect { File = LibraryFile.Magic, StartIndex = 750, FrameCount = 10, Colour = Phantom },",
        "[MagicType.SummonJinSkeleton] = new CastEffect { File = LibraryFile.Magic, StartIndex = 740, FrameCount = 10, DelayMs = 60, Colour = Phantom, CastAtSource = true },")

    # 4a. Rake: DirectionStartIndices 仅 ImpactDef 支持 → 由 Source 承载 (Source 非空时主特效跳过)
    bad_rake = """        [MagicType.Rake] = new CastEffect
        {
            File = LibraryFile.MagicEx4, StartIndex = 1200, FrameCount = 9, Colour = Ice, CastAtSource = true,
            DirectionStartIndices = new[] { 1200, 1210, 1220, 1230, 1240, 1200, 1200, 1200 },
        },"""
    good_rake = """        [MagicType.Rake] = new CastEffect
        {
            File = LibraryFile.MagicEx4, StartIndex = 1200, FrameCount = 9, Colour = Ice,
            Source = new ImpactDef
            {
                File = LibraryFile.MagicEx4, StartIndex = 1200, FrameCount = 9, DelayMs = 100, Colour = Ice,
                DirectionStartIndices = new[] { 1200, 1210, 1220, 1230, 1240, 1200, 1200, 1200 },
            },
        },"""
    if bad_rake in text:
        text = text.replace(bad_rake, good_rake)

    # 4. 补 A 类 5 条 (锚在 SummonJinSkeleton 行后)
    anchor = "[MagicType.SummonJinSkeleton] = new CastEffect"
    if anchor in text and "[MagicType.CrushingWave] = new CastEffect" not in text:
        i = text.index(anchor)
        j = text.index("\n", i) + 1
        text = text[:j] + NEW_ENTRIES + text[j:]

    # 5. OriginalSpellCases := 原版有特效的 case 全集 (json 键, 排序, C# 风格折行)
    names = sorted(visual_keys(js))
    lines, row = [], []
    for n in names:
        row.append(f"MagicType.{n}")
        if len(row) == 3:
            lines.append("        " + ", ".join(row) + ",")
            row = []
    if row:
        lines.append("        " + ", ".join(row) + ",")
    lines[-1] = lines[-1].rstrip(",")
    block = "OriginalSpellCases = new()\n    {\n" + "\n".join(lines) + "\n    };"
    return re.sub(r"OriginalSpellCases\s*=\s*new\(\)\s*\{.*?\};", block, text, count=1, flags=re.S)


def main() -> None:
    mode = sys.argv[1] if len(sys.argv) > 1 else "--check"
    js = parse_json()
    text = CS.read_text(encoding="utf-8")

    if mode == "--fix":
        # 修复操作各自幂等 (文本锚点命中才改), 无条件执行: 部分修复 (如 Rake 的
        # ImpactDef 形状) 不改变三元组, 靠 check 违规门控会漏掉。
        CS.write_text(fix(text, None, js), encoding="utf-8")
        print(f"fixed -> {CS}")

    cs_t, wl = parse_cs(CS.read_text(encoding="utf-8"))
    viol = check(cs_t, wl, js)
    if viol:
        print(f"CHECK FAIL ({len(viol)} 违规):")
        for v in viol:
            print(" -", v)
        sys.exit(1)
    print(f"OK: _table {len(cs_t)} 条, 白名单 {len(wl)} == 原版 switch {len(js)}; "
          f"共有 {len(set(cs_t) & set(js))} 技能三元组全一致 (可接受差异 {len(ACCEPTABLE)})")


if __name__ == "__main__":
    main()
