#!/usr/bin/env python3
"""extract_sound_catalogs.py — 三张 Godot 音效 catalog → zircon/ClientData/sounds.json。

E5/A2: SoundCatalog.cs (SoundIndex→文件/类别/循环) + MagicSoundCatalog.cs
(技能分阶段 Start/End/Travel/Duration + 门控) + MonsterSoundCatalog.cs
(怪物 Attack/Struck/Die) → 单一 JSON。

后缀回退规则 (MagicSoundCatalog.ResolveSpecs 无显式条目时) 是代码行为，
以 `fallback` 字段记录在 JSON meta 中供消费端实现，数据只存显式条目。
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
ZIRCON = Path(__import__("os").environ.get(
    "MIR3_ZIRCON_ROOT", str(REPO.parent / "zircon"))).resolve()
GODOT_SCRIPTS = ZIRCON / "GodotClient" / "Scripts"

SOUND_RE = re.compile(
    r"\[SoundIndex\.(\w+)\]\s*=\s*new\(\"([^\"]+)\",\s*SoundCategory\.(\w+)"
    r"(?:,\s*(true|false))?\)")
MAGIC_RE = re.compile(
    r"\[\(MagicType\.(\w+),\s*MagicSoundPhase\.(\w+)\)\]\s*=\s*new\[\]")
SPEC_RE = re.compile(
    r"new SoundSpec\(SoundIndex\.(\w+),\s*MagicSoundGate\.(\w+)\)")
MONSTER_RE = re.compile(
    r"\[MonsterImage\.(\w+)\]\s*=\s*new\(([^)]*)\)")


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


def parse_sound_catalog(src: str) -> dict[str, dict]:
    """SoundIndex → {file, category, loop}。"""
    out: dict[str, dict] = {}
    for m in SOUND_RE.finditer(src):
        idx, fname, cat, loop = m.groups()
        out[idx] = {"file": fname, "category": cat, "loop": loop == "true"}
    return out


def parse_magic_catalog(src: str) -> dict[str, dict]:
    """(magic, phase) → [{sound, gate}...]（保持源码顺序）。"""
    out: dict[str, dict[str, list]] = {}
    for m in MAGIC_RE.finditer(src):
        # 条目体: "= new[]" 后第一个 '{' 的括号平衡块
        # (条目以 '},' 结尾, 只有字典最后一项才是 '};' — 不能找 "};")
        b0 = src.index("{", m.end())
        depth, i = 0, b0
        while i < len(src):
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        body = src[b0 + 1:i]
        specs = [{"sound": s, "gate": g} for s, g in SPEC_RE.findall(body)]
        magic, phase = m.group(1), m.group(2)
        out.setdefault(magic, {})[phase] = specs
    return out


def parse_monster_catalog(src: str) -> dict[str, dict]:
    """MonsterImage → {attack, struck, die}（SoundIndex 名）。"""
    out: dict[str, dict] = {}
    for m in MONSTER_RE.finditer(src):
        image = m.group(1)
        args = [a.strip() for a in m.group(2).split(",")]
        vals = [a.split("SoundIndex.")[-1] for a in args]
        if len(vals) != 3:
            raise ValueError(f"monster sound arg count: {image} {args}")
        out[image] = {"attack": vals[0], "struck": vals[1], "die": vals[2]}
    return out


ZIRCON = Path(__import__("os").environ.get(
    "MIR3_ZIRCON_ROOT", str(REPO.parent / "zircon"))).resolve()
OUT = ZIRCON / "ClientData" / "sounds.json"


def main() -> int:
    out_path = OUT
    if "--out" in sys.argv:
        out_path = Path(sys.argv[sys.argv.index("--out") + 1])
    if "--check" in sys.argv:
        cur = json.loads(out_path.read_text(encoding="utf-8"))
        return 0 if cur.get("_meta", {}).get("deadRefs") is not None and \
            len(cur.get("sounds", {})) == len(parse_sound_catalog(
                strip_comments((GODOT_SCRIPTS / "SoundCatalog.cs").read_text(encoding="utf-8-sig"))
            )) else 1

    sc = strip_comments((GODOT_SCRIPTS / "SoundCatalog.cs").read_text(encoding="utf-8-sig"))
    mc = strip_comments((GODOT_SCRIPTS / "MagicSoundCatalog.cs").read_text(encoding="utf-8-sig"))
    xc = strip_comments((GODOT_SCRIPTS / "MonsterSoundCatalog.cs").read_text(encoding="utf-8-sig"))

    sounds = parse_sound_catalog(sc)
    magic = parse_magic_catalog(mc)
    monster = parse_monster_catalog(xc)

    doc = {
        "_meta": {
            "schema": "sounds/1",
            "generated_at": __import__("time").strftime("%Y-%m-%dT%H:%M:%S%z"),
            "generator": "Tools/magiclab/extract_sound_catalogs.py",
            "sources": {
                "SoundCatalog.cs": "SoundIndex→文件/类别/循环 (DXSoundManager.SoundList 移植)",
                "MagicSoundCatalog.cs": "技能分阶段音效+门控 (显式表)",
                "MonsterSoundCatalog.cs": "怪物 Attack/Struck/Die",
            },
            "fallback": {
                "rule": "MagicSoundCatalog.ResolveSpecs: 无显式条目时按 {magic}{phase后缀} "
                        "试解析 SoundIndex 枚举且须存在于 catalog; 显式 None 压制回退",
                "phaseSuffix": {"start": "Start", "travel": "Travel", "end": "End",
                                "duration": "Duration"},
            },
            "gates": ["always", "locations", "targets", "locationsOrTargets"],
        },
        "sounds": sounds,
        "magic": magic,
        "monster": monster,
    }
    # 自检: magic/monster 引用的 SoundIndex 不在 catalog = 原版死引用
    # (枚举存在但 DXSoundManager.SoundList 无 wav 映射, 原版 Play() 静默跳过 —
    #  已实证: DragonRepulseStart/RakeStart/WraithGripEnd)。记入 meta 不算失败。
    dead = set()
    for m_, phases in magic.items():
        for specs in phases.values():
            for s in specs:
                if s["sound"] != "None" and s["sound"] not in sounds:
                    dead.add(s["sound"])
    for entry in monster.values():
        for v in entry.values():
            if v != "None" and v not in sounds:
                dead.add(v)
    doc["_meta"]["deadRefs"] = sorted(dead)
    print(f"OK: sounds={len(sounds)} magicEntries={len(magic)} "
          f"(specs={sum(len(p) for m_ in magic.values() for p in m_.values())}) "
          f"monster={len(monster)} deadRefs={sorted(dead) or '无'}")
    if out_path:
        out_path.parent.mkdir(parents=True, exist_ok=True)
        out_path.write_text(json.dumps(doc, ensure_ascii=False, indent=1) + "\n",
                            encoding="utf-8")
        print(f"  -> {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
