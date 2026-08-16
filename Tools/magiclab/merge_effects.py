#!/usr/bin/env python3
"""merge_effects.py — 双源合并产出 zircon/ClientData/magic-effects.json (E5/A1)。

事实源分工:
- 原版源 (extract_effect_table.py): 帧数据事实源 — (lib, frame, count) 三元组、
  时序语义 (StartDelayMs/DistanceDelayMs)、方向语义、原版 ctx/target 语义段。
- Godot 源 (extract_godot_table.py): 结构事实源 — CastEffect/ImpactDef/ProjectileDef
  全字段再组织 (Source/MapImpact/Additional/DirectionFromCast/NoColourKey/...)。

合并规则:
- 共有技能的 (lib,frame,count) 三元组集合 (跨段合并) 必须一致; 不一致即停,
  除非技能在 ACCEPTABLE (docs/magiclab/GODOT_TABLE_DIFF.md 人工判读清单)。
- 产出单文件: skills.<name>.original (原版段) / skills.<name>.godot (结构段, 可 null),
  attackTable, originalSpellCases/noVisualSpellCases 白名单。
- _meta 记录两源 zircon commit hash 与生成时间。
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
ZIRCON = Path(__import__("os").environ.get(
    "MIR3_ZIRCON_ROOT", str(REPO.parent / "zircon"))).resolve()
ORIGINAL = ZIRCON / "ClientData" / "_meta" / "original-effects.json"
GODOT_OUT = ZIRCON / "ClientData" / "_meta" / "godot-table.json"
CLIENT_DATA = ZIRCON / "ClientData" / "magic-effects.json"
# GODOT_TABLE_DIFF.md 人工判读 (可接受差异) — 与 gen_cs_table.py 保持同口径
ACCEPTABLE = {
    "ScortchedEarth": "原版第二段动态随机帧 2450+Random(5)*10, Godot 固定 2450",
    "MonsterScortchedEarth": "同上 (怪物版)",
    "AugmentPoisonDust": "Godot 补画: 原版 start 段无此 case, 复制 PoisonDust 起手",
    "ThunderStrike": "Godot 补画: 原版 start 只播音效, 复用 ThunderBolt 1430 起手",
    "DoomClawLeftPinch": "Godot 缺第二段 MonMagicEx19#2680 (怪物横扫, 待补)",
    "DoomClawRightPinch": "同上",
    "GreenSludgeBall": "Godot 缺命中段 MonMagicEx23#2780 (待补)",
}


def git_commit(path: Path) -> str:
    r = subprocess.run(["git", "-C", str(path), "rev-parse", "HEAD"],
                       capture_output=True, text=True, check=True)
    return r.stdout.strip()


def triples_original(entry: dict) -> set:
    out = set()
    for seg in ("start", "release"):
        for fx in (entry.get(seg) or {}).get("effects", []):
            lib, frame, cnt = fx.get("lib"), fx.get("frame"), fx.get("count")
            if lib is None or frame is None or cnt is None:
                continue  # 动态帧表达式 → 无法静态比对, 交给 ACCEPTABLE 兜底
            out.add((lib, frame, cnt))
    return out


def triples_godot(defn: dict) -> set:
    out = set()
    def walk(o):
        if isinstance(o, dict):
            if "_type" in o and "file" in o and isinstance(o.get("startIndex"), int) \
                    and isinstance(o.get("frameCount"), int):
                out.add((o["file"], o["startIndex"], o["frameCount"]))
            for v in o.values():
                walk(v)
        elif isinstance(o, list):
            for v in o:
                walk(v)
    walk(defn)
    return out


def load_godot() -> dict:
    sys.path.insert(0, str(HERE))
    import extract_godot_table
    return extract_godot_table.parse_table()


def main() -> int:
    check = "--check" in sys.argv
    original = json.loads(ORIGINAL.read_text(encoding="utf-8"))
    godot = load_godot()

    conflicts: list[str] = []
    skills: dict[str, dict] = {}
    all_names = sorted((set(original) - {"_meta"}) | set(godot["table"]))
    for name in all_names:
        o = {k: v for k, v in original.get(name, {}).items()} if name in original else None
        g = godot["table"].get(name)
        entry: dict = {}
        if o is not None:
            entry["castAnim"] = o.get("castAnim")
            entry["notes"] = o.get("notes")
            entry["sound"] = o.get("sound")
            entry["original"] = {k: o[k] for k in ("start", "release") if k in o}
        if g is not None:
            entry["godot"] = g
        # 共有技能三元组冲突检测
        if o is not None and g is not None:
            to_, tg = triples_original(o), triples_godot(g)
            if to_ and to_ != tg and name not in ACCEPTABLE:
                conflicts.append(
                    f"{name}: 原版{sorted(to_)} != Godot{sorted(tg)}")
        skills[name] = entry
    if conflicts:
        print("FATAL: 共有字段冲突 (需人工裁决 GODOT_TABLE_DIFF.md):", file=sys.stderr)
        for c in conflicts:
            print(" ", c, file=sys.stderr)
        return 1

    doc = {
        "_meta": {
            "schema": "magic-effects/2",
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "generators": {
                "original": "Tools/magiclab/extract_effect_table.py",
                "godot": "Tools/magiclab/extract_godot_table.py",
                "merge": "Tools/magiclab/merge_effects.py",
            },
            "sources": {
                "original": {"repo": "zircon", "commit": git_commit(ZIRCON),
                             "files": ["Client/Models/MapObject.cs",
                                       "LibraryCore/Functions.cs"]},
                "godot": {"repo": "zircon", "commit": git_commit(ZIRCON),
                          "files": ["GodotClient/Scripts/MagicEffectTable.cs"]},
            },
            "acceptable": ACCEPTABLE,
            "rule": "original=帧数据事实源, godot=结构事实源; 编辑回写改 godot 段, "
                    "gen_cs_table.py --check 对账 Godot 硬编码表",
        },
        "originalSpellCases": godot["originalSpellCases"],
        "noVisualSpellCases": godot["noVisualSpellCases"],
        "attackTable": godot["attackTable"],
        "skills": skills,
    }

    # godot 中间产物落盘 _meta (provenance; canonical 是本文件产物)
    GODOT_OUT.parent.mkdir(parents=True, exist_ok=True)
    GODOT_OUT.write_text(json.dumps(godot, ensure_ascii=False, indent=1) + "\n",
                         encoding="utf-8")

    if check:
        current = json.loads(CLIENT_DATA.read_text(encoding="utf-8"))
        cur_meta, cur = dict(current), dict(current)
        cur.pop("_meta"), cur_meta.pop("_meta", None)
        new = {k: v for k, v in doc.items() if k != "_meta"}
        if current.get("_meta", {}).get("schema") != doc["_meta"]["schema"] or cur != new:
            print("magic-effects.json 与源不一致 — 重跑 merge_effects.py", file=sys.stderr)
            return 1
        print(f"magic-effects.json 与双源一致 ✓ ({len(skills)} 技能, "
              f"冲突 0, 可接受差异 {len(ACCEPTABLE)})")
        return 0

    CLIENT_DATA.parent.mkdir(parents=True, exist_ok=True)
    CLIENT_DATA.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n",
                           encoding="utf-8")
    n_godot = sum(1 for s in skills.values() if s.get("godot"))
    print(f"OK -> {CLIENT_DATA}")
    print(f"  技能 {len(skills)} (原版 {len(original) - 1} + Godot 独有 "
          f"{n_godot - len([s for s in skills.values() if s.get('original') and s.get('godot')])}), "
          f"冲突 0, 可接受 {len(ACCEPTABLE)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
