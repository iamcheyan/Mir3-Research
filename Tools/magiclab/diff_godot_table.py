#!/usr/bin/env python3
"""Magic Lab P0 — Godot MagicEffectTable.cs 对账（独立实现）。

独立于 extract_effect_table.py：本脚本自己解析 Godot 端
`GodotClient/Scripts/MagicEffectTable.cs`（目标格式文本解析），
与 magic-effect-table.json（原版事实源）逐技能对账，产出
docs/magiclab/GODOT_TABLE_DIFF.md —— 即"特效对不上"清单。

Godot CastEffect 语义 ↔ 原版两段 switch 的映射：
  File/StartIndex/FrameCount/DelayMs/Colour   ↔ start 段起手 或 release 无目标特效
  Source/SourceAdditional/SourcePerLocation   ↔ start 段特效
  Projectile/TargetProjectile(+Arrival)       ↔ release 段 MirProjectile (+CompleteAction)
  Impact/TargetEffect/MapImpact/Additional    ↔ release 段目标/落点特效
"""
from __future__ import annotations

import json
import re
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
ZIRCON = Path(__import__("os").environ.get(
    "MIR3_ZIRCON_ROOT", "/home/tetsuya/development/zircon")).resolve()
CS = ZIRCON / "GodotClient" / "Scripts" / "MagicEffectTable.cs"
TABLE = REPO / "Tools" / "magiclab" / "magic-effect-table.json"
OUT = REPO / "docs" / "magiclab" / "GODOT_TABLE_DIFF.md"

COLOUR_ALIAS = {  # Godot 表色彩字段名 → 原版 colour 词根
    "Fire": "Fire", "Ice": "Ice", "Lightning": "Lightning", "Wind": "Wind",
    "Holy": "Holy", "Dark": "Dark", "Phantom": "Phantom", "None": "None",
    "Purple": "Purple", "GreenYellow": "GreenYellow",
}


def balanced(src: str, start: int, open_ch: str, close_ch: str) -> tuple[str, int]:
    depth = 0
    for i in range(start, len(src)):
        if src[i] == open_ch:
            depth += 1
        elif src[i] == close_ch:
            depth -= 1
            if depth == 0:
                return src[start + 1:i], i
    raise ValueError(start)


def split_top(src: str, sep: str = ",") -> list[str]:
    parts, cur, d = [], [], 0
    for ch in src:
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
        if ch == sep and d == 0:
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur).strip())
    return [p for p in parts if p]


def parse_impact(body: str) -> dict:
    """ImpactDef/ProjectileDef 初始化体 → {file,start,count,delay,colour}"""
    d: dict = {}
    for p in split_top(body):
        m = re.match(r"(\w+)\s*=\s*(.+)$", p, re.S)
        if not m:
            continue
        k, v = m.group(1), m.group(2).strip()
        if k == "File":
            d["file"] = re.search(r"LibraryFile\.(\w+)", v).group(1)
        elif k == "StartIndex":
            d["start"] = int(v)
        elif k == "FrameCount":
            d["count"] = int(v)
        elif k == "DelayMs":
            d["delay"] = int(v)
        elif k == "Colour" and v in COLOUR_ALIAS:
            d["colour"] = v
    return d


def parse_casteffect(body: str) -> dict:
    """CastEffect 初始化体 → 扁平结构（嵌套 def 以列表收集）"""
    d: dict = {"extra": []}
    for p in split_top(body):
        m = re.match(r"(\w+)\s*=\s*(.+)$", p, re.S)
        if not m:
            if p:
                d["extra"].append(p)
            continue
        k, v = m.group(1), m.group(2).strip()
        if v.startswith("new ImpactDef") or v.startswith("new ProjectileDef") \
                or v.startswith("new OffsetImpactDef"):
            ip = v.index("{")
            init, _ = balanced(v, ip, "{", "}")
            d.setdefault(k, []).append(parse_impact(init))
        elif k == "Additional" or k.endswith("Additional") or k.endswith("Projectiles"):
            # 集合初始化器 { new ImpactDef {...}, ... }
            if v.startswith("{"):
                init, _ = balanced(v, 0, "{", "}")
                for item in split_top(init):
                    mm = re.match(r"new (?:Offset)?(?:Impact|Projectile)Def", item)
                    if mm:
                        ip = item.index("{")
                        ii, _ = balanced(item, ip, "{", "}")
                        d.setdefault(k, []).append(parse_impact(ii))
        elif k == "File":
            d["file"] = re.search(r"LibraryFile\.(\w+)", v).group(1)
        elif k == "StartIndex":
            d["start"] = int(v)
        elif k == "FrameCount":
            d["count"] = int(v)
        elif k == "DelayMs":
            d["delay"] = int(v)
        elif k == "Colour" and v in COLOUR_ALIAS:
            d["colour"] = v
    return d


def parse_godot_table() -> tuple[dict, set, set]:
    src = CS.read_text(encoding="utf-8-sig")
    # 白名单
    wl_m = re.search(r"HashSet<MagicType> OriginalSpellCases\s*=\s*new\(\)\s*\{", src)
    wl, _ = balanced(src, wl_m.end() - 1, "{", "}")
    original_cases = set(re.findall(r"MagicType\.(\w+)", wl))
    nv_m = re.search(r"HashSet<MagicType> NoVisualSpellCases\s*=\s*new\(\)\s*\{", src)
    no_visual: set = set()
    if nv_m:
        nv, _ = balanced(src, nv_m.end() - 1, "{", "}")
        no_visual = set(re.findall(r"MagicType\.(\w+)", nv))
    # _attackTable（MirAction.Attack 语义，单独统计不进 diff）
    at_m = re.search(r"Dictionary<MagicType, ImpactDef> _attackTable\s*=\s*new\(\)\s*\{", src)
    attack: set = set()
    if at_m:
        at, _ = balanced(src, at_m.end() - 1, "{", "}")
        attack = set(re.findall(r"\[MagicType\.(\w+)\]", at))
    # _table
    tb_m = re.search(r"Dictionary<MagicType, CastEffect> _table\s*=\s*new\(\)\s*\{", src)
    tb, _ = balanced(src, tb_m.end() - 1, "{", "}")
    table: dict[str, dict] = {}
    for m in re.finditer(r"\[MagicType\.(\w+)\]\s*=\s*new CastEffect", tb):
        name = m.group(1)
        ip = tb.index("{", m.end() - 1)
        init, _ = balanced(tb, ip, "{", "}")
        table[name] = parse_casteffect(init)
    return table, original_cases, no_visual | attack


def json_effect_triples(entry: dict) -> dict[str, list[tuple]]:
    """JSON 技能条目 → {segment: [(lib,frame,count,delay,colour)]}"""
    out: dict[str, list] = {}
    for seg in ("start", "release"):
        for e in entry.get(seg, {}).get("effects", []):
            fr = e.get("frame")
            if fr is None and e.get("frameExpr"):
                fr = e["frameExpr"]
            t = (e.get("lib"), fr, e.get("count"),
                 e.get("delayMs"), e.get("colour"))
            out.setdefault(e.get("segment", "?"), []).append(t)
    return out


def godot_effect_triples(defn: dict) -> dict[str, list[tuple]]:
    """Godot CastEffect → {segment: [(file,start,count,delay,colour)]}"""
    out: dict[str, list] = {}
    main = (defn.get("file"), defn.get("start"), defn.get("count"),
            defn.get("delay", 100), defn.get("colour"))
    if defn.get("start") is not None:
        out["cast"] = [main]
    for key in ("Source", "SourceAdditional", "SourcePerLocation"):
        for d in defn.get(key, []):
            t = (d.get("file"), d.get("start"), d.get("count"),
                 d.get("delay", 100), d.get("colour"))
            out.setdefault("cast", []).append(t)
    for key in ("Projectile", "TargetProjectile", "AdditionalProjectiles",
                "TargetAdditionalProjectiles"):
        for d in defn.get(key, []):
            t = (d.get("file"), d.get("start"), d.get("count"),
                 d.get("delay", 100), d.get("colour"))
            out.setdefault("projectile", []).append(t)
            if isinstance(d, dict):
                pass
    # ProjectileDef.Arrival（落地特效）
    src_txt = json.dumps(defn)  # Arrival 已在 parse_impact 忽略嵌套——补解析
    for key in ("Impact", "TargetEffect", "MapImpact", "Additional",
                "AdditionalMapEffects"):
        for d in defn.get(key, []):
            t = (d.get("file"), d.get("start"), d.get("count"),
                 d.get("delay", 100), d.get("colour"))
            out.setdefault("hit", []).append(t)
    return out


# 人工判读注解：逐条对照原版源码核实后的定性（生成报告时附带）。
# 依据 2026-08-15 对 Client/Models/MapObject.cs 与 MagicEffectTable.cs 的逐行核对。
VERDICTS = {
    "AdamantineFireBall": "❌ Godot 抄错：Godot 条目复用了 FireBall 的 420/580，"
        "原版 AdamantineFireBall 与 FireBounce/MeteorShower 共用 1640 弹道 + 1800 命中"
        "（MapObject.cs:1040 fall-through 组）",
    "AugmentPoisonDust": "⚠️ Godot 补画：原版 start 段无 AugmentPoisonDust case"
        "（MapObject.cs:4264 只有 PoisonDust 60×10），Godot 复制了 PoisonDust 起手",
    "ThunderStrike": "⚠️ Godot 补画：原版 start 段 ThunderStrike 只播音效无特效"
        "（MapObject.cs:4159），Godot 把 ThunderBolt 的 1430 起手也给了它",
    "ImprovedExplosiveTalisman": "❌ Godot 库选错：原版起手是 MagicEx2#980"
        "（MapObject.cs start 段），Godot Source 写成 Magic#980",
    "SummonSkeleton": "❌ 帧号错：原版 start 740×10，Godot 用 750",
    "SummonJinSkeleton": "❌ 帧号错：同上，原版 740，Godot 750",
    "ScortchedEarth": "≈ 可接受：原版第二段为动态随机帧 2450+Random(5)*10"
        "（MapObject.cs:1219），Godot 固定 2450；Godot 未实现 ProgUse#220 地面标记与 1900×30 火墙段",
    "MonsterScortchedEarth": "≈ 可接受：同 ScortchedEarth（随机帧）",
    "GreenSludgeBall": "⚠️ Godot 缺命中段：原版 2780×6（MapObject.cs CompleteAction）",
    "DoomClawLeftPinch": "⚠️ Godot 缺第二段：原版 CompleteAction 里 2680×9 横扫",
    "DoomClawRightPinch": "⚠️ Godot 缺第二段：同上",
}


def main():
    jtable = json.loads(TABLE.read_text(encoding="utf-8"))
    meta = jtable.pop("_meta", None)
    gtable, original_cases, excluded = parse_godot_table()

    jnames = set(jtable)
    gnames = set(gtable)

    player_magics = {n for n in jnames
                     if not re.match(r"(Monster|Sama|DoomClaw)", n)}
    # 原版有 case 但两段 effects 全空 = 只播音效无视觉（Godot NoVisual 白名单语义）
    no_visual_j = {n for n in player_magics
                   if all(not jtable[n].get(s, {}).get("effects")
                          for s in ("start", "release"))}
    eff_magics = player_magics - no_visual_j

    missing = sorted(eff_magics - gnames)
    extra = sorted(gnames - jnames)
    common = sorted(jnames & gnames)


    # 白名单 vs 原版 switch：白名单声明"原版有特效"但 switch 没有的
    wl_extra = sorted(original_cases - jnames)
    wl_missing = sorted(eff_magics - original_cases)

    diffs: list[str] = []
    matched = 0
    for name in common:
        jt = json_effect_triples(jtable[name])
        gt = godot_effect_triples(gtable[name])
        jset = {(t[0], t[1], t[2]) for seg in ("castEffect", "projectile", "hitEffect", "aoe")
                for t in jt.get(seg, [])}
        gset = {(t[0], t[1], t[2]) for seg in ("cast", "projectile", "hit")
                for t in gt.get(seg, [])}
        if jset == gset:
            matched += 1
            continue
        only_j = jset - gset
        only_g = gset - jset
        lines = [f"### {name}"]
        for t in sorted(only_j, key=str):
            lines.append(f"- 原版有 Godot 无: {t[0]} #{t[1]} ×{t[2]}")
        for t in sorted(only_g, key=str):
            lines.append(f"- Godot 有原版无: {t[0]} #{t[1]} ×{t[2]}")
        if name in VERDICTS:
            lines.append(f"- 判读: {VERDICTS[name]}")
        diffs.append("\n".join(lines))

    report = [
        "# Godot MagicEffectTable 对账报告",
        "事实源：原版 `Client/Models/MapObject.cs` 两段 Spell switch（release :768 + start :3603）"
        "→ `magic-effect-table.json`；对照 `GodotClient/Scripts/MagicEffectTable.cs`。"
        "比对口径：每技能特效 (lib, StartIndex, FrameCount) 三元组集合（跨施法/弹道/命中/地面段合并去重）。",
        "",
        f"- 原版 switch 技能数: **{len(jnames)}**（玩家 {len(player_magics)} + 怪物 "
        f"{len(jnames) - len(player_magics)}）",
        f"- Godot `_table` 条目: **{len(gtable)}**；`OriginalSpellCases` 白名单: **{len(original_cases)}**",
        f"- 共有技能: {len(common)}，其中三元组 (lib,frame,count) 完全一致: **{matched}**",
        f"- 参数错配技能: **{len(common) - matched}**",
        "",
        "## A. Godot 完全缺失的玩家技能（原版有特效、Godot 表无条目）",
        "",
    ]
    report += [f"- {m}（{jtable[m].get('castAnim') or '怪物'}）" for m in missing] or ["（无）"]
    report += ["", "## B. Godot 有、原版 Spell switch 没有的条目（非 Spell 语义或已失源）", ""]
    report += [f"- {e}" for e in extra] or ["（无）"]
    report += ["", "## C. 白名单 `OriginalSpellCases` vs 原版 switch 的口径差", ""]
    report += [f"- 白名单多出（switch 无此 case）: {wl_extra or '（无）'}"]
    report += [f"- 玩家技能在 switch 有特效但白名单未收录: {wl_missing or '（无）'}"]
    report += ["", "## D. 共有技能的特效参数错配明细", ""]
    report += diffs or ["（无——全部一致）"]
    report += ["", "## 判读指南", "",
               "- A/C 类 = Godot 端缺视觉（游戏内表现为无特效/诊断日志）",
               "- D 类 = Godot 端帧号/帧数/库选错（游戏内表现为特效错乱——用户主诉）",
               "- 怪物技能（Monster*/Sama*/DoomClaw*）原版由怪物分支处理，此处只对玩家技能判缺失",
               "", f"_source: {CS}_", f"_json: {meta and meta.get('source', {}).get('MapObject.cs')}_", ""]
    OUT.write_text("\n".join(report), encoding="utf-8")
    print(f"common={len(common)} matched={matched} mismatched={len(common)-matched} "
          f"missing_in_godot={len(missing)} extra_in_godot={len(extra)}")
    print(f"-> {OUT}")


if __name__ == "__main__":
    main()
