#!/usr/bin/env python3
"""frameformulas.py — 从 Zircon C# 事实源提取动画帧表/纸娃娃公式 → frame-formulas.json。

事实源 (只读, 原版 Client/ 不碰):
  LibraryCore/FrameSet.cs        帧表 (Players/DefaultMonster/DefaultNPC/DefaultItem/Companion_*)
  LibraryCore/Functions.cs       GetAttackAnimation / GetMagicAnimation 分派
  GodotClient/Scripts/PlayerRenderer.cs   纸娃娃层公式/ArmourShift/方向分组/藏武器套装
  GodotClient/Scripts/ObjectRenderer.cs   NPC 特例帧表/怪物·NPC·物品 bodyOffset


产出: Tools/resedit/frame-formulas.json —— webport frames.js/anims.js/data.js 与
wilviewer 对照面板共读的唯一数据源 (总纲 §7.1 任务 1: 消灭 JS/C# 双份维护)。

用法:
  python3 frameformulas.py [--zircon <dir>] [--out <file>] [--check]
    --check  只校验现有 JSON 与当前 C# 源一致 (drift 门禁), 不写文件

解析全部带断言: 源码格式漂移 (升级 Zircon 后) 会在这里炸, 而不是静默产出错表。
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_ZIRCON = Path(
    __import__("os").environ.get("MIR3_ZIRCON_ROOT", "/home/tetsuya/development/zircon")
)


def camel(name: str) -> str:
    """Players → players; DefaultItem → defaultItem; Companion_Pig → companionPig。"""
    parts = name.split("_")
    return parts[0][0].lower() + parts[0][1:] + "".join(p for p in parts[1:])


def first_cap(name: str) -> str:
    return name[0].lower() + name[1:]


# ---------------------------------------------------------------- FrameSet.cs
FRAME_ENTRY = re.compile(
    r"\[MirAnimation\.(\w+)\]\s*=\s*new Frame\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*,"
    r"\s*TimeSpan\.FromMilliseconds\((\d+)\)\s*\)\s*(?:\{\s*([^}]*)\})?"
)
DELAY_OVERRIDE = re.compile(
    r"(\w+)\[MirAnimation\.(\w+)\]\.Delays\[(\d+)\]\s*=\s*TimeSpan\.FromMilliseconds\((\d+)\);"
)
DICT_BLOCK = re.compile(
    r"(\w+)\s*=\s*new Dictionary<MirAnimation,\s*Frame>\s*\{", re.S
)


def parse_frame_sets(src: str) -> dict:
    out: dict[str, dict] = {}
    for m in DICT_BLOCK.finditer(src):
        block_name = m.group(1)
        if block_name == "FrameSet":
            continue
        # 块体: 到配对的 "};" — 用括号计数
        depth, i = 0, m.end() - 1
        start = m.end() - 1
        while i < len(src):
            if src[i] == "{":
                depth += 1
            elif src[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        body = src[start : i + 1]
        entries = {}
        for em in FRAME_ENTRY.finditer(body):
            name, s, c, off, ms, mods = em.groups()
            ent = {
                "start": int(s), "count": int(c), "offset": int(off), "ms": int(ms),
                "reversed": "Reversed = true" in (mods or ""),
                "staticSpeed": "StaticSpeed = true" in (mods or ""),
            }
            entries[first_cap(name)] = ent
        if entries:
            out[camel(block_name)] = dict(sorted(entries.items()))
    # 延迟覆盖 (Players 表 Combat1/Combat2)
    for om in DELAY_OVERRIDE.finditer(src):
        block, anim, idx, ms = om.groups()
        key = camel(block)
        ent = out.get(key, {}).get(first_cap(anim))
        assert ent is not None, f"延迟覆盖指向不存在的表项: {block}.{anim}"
        ent.setdefault("delays", {})[str(int(idx))] = int(ms)
    assert "players" in out and "defaultMonster" in out and "defaultNPC" in out, \
        f"FrameSet 基础表缺失: {list(out)}"
    return out


# ---------------------------------------------------------------- Enum.cs
def parse_enum_block(src: str, name: str) -> dict:
    """显式值 + 顺序隐式值混合枚举 → {name: value} (保持声明顺序)。"""
    m = re.search(rf"public enum {name}\b[^{{]*\{{(.*?)\n    \}}", src, re.S)
    assert m, f"Enum.cs 缺少 {name}"
    body = m.group(1)
    body = re.sub(r"\[Description\([^\]]*\)\]\s*", "", body)
    body = re.sub(r"//[^\n]*", "", body)
    out: dict[str, int] = {}
    nxt = 0
    # 按逗号/行尾取成员 (最后一个成员可无尾逗号)
    for em in re.finditer(r"(\w+)\s*(?:=\s*(\d+))?\s*(?:,|$)", body, re.M):
        key, val = em.group(1), em.group(2)
        if not key:
            continue
        if val is not None:
            nxt = int(val)
        out[key] = nxt
        nxt += 1
    return out


# ------------------------------------------------------------- Functions.cs
ANIM_NAME = re.compile(r"MirAnimation\.(\w+)")
MAGIC_NAME = re.compile(r"MagicType\.(\w+)")


def _method_body(src: str, sig: str) -> str:
    m = re.search(sig, src)
    assert m, f"Functions.cs 缺少方法: {sig}"
    depth, i = 0, src.find("{", m.end() - 1)
    start = i
    while i < len(src):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                break
        i += 1
    return src[start : i + 1]

def _split_cases(body: str):
    """switch 体 → [(case magic 列表 or None=default, 段文本), ...] 按源码顺序。
    连续 case 标签 (case A: case B: <body>) 的空段累积到下一非空段。"""
    def merged(cur, pend):
        if cur is None and not pend:
            return None
        return (cur or []) + (pend or [])

    segs = []
    pend: list | None = None
    cur_magics, cur_start = None, None
    for m in re.finditer(r"\b(case MagicType\.(\w+)|default):", body):
        if cur_start is not None:
            text = body[cur_start : m.start()]
            if text.strip():
                segs.append((merged(cur_magics, pend), text))
                pend = None
            else:
                pend = (pend or []) + (cur_magics or [])
        cur_magics = [m.group(2)] if m.group(2) else None
        cur_start = m.end()
    if cur_start is not None:
        segs.append((merged(cur_magics, pend), body[cur_start:]))
    return segs


def _weapon_chain(text: str) -> list:
    """weaponShape 条件链 (C# if/else 或三元) → 有序 [{min,anim}...]。
    if (weaponShape >= 1200) animation = A; else if (>= 1100) B; else C;
    → [{min:1200,anim:A},{min:1100,anim:B},{min:0,anim:C}]"""
    chain = []
    for m in re.finditer(
        r"weaponShape >= (\d+)\)?\s*(?:\n\s*)?\??\s*(?:animation =|:\s*)\s*MirAnimation\.(\w+)", text
    ):
        chain.append({"min": int(m.group(1)), "anim": first_cap(m.group(2))})
    tail = re.search(r"else\s*\n?\s*(?:animation\s*=\s*|:\s*)MirAnimation\.(\w+)\s*;", text)
    assert chain and tail, f"无法解析武器条件链: {text[:160]!r}"
    chain.append({"min": 0, "anim": first_cap(tail.group(1))})
    # 顺序断言: min 递减
    mins = [c["min"] for c in chain]
    assert mins == sorted(mins, reverse=True), f"武器链 min 非递减: {mins}"
    return chain


def _balanced_block(src: str, start: int) -> tuple[str, int]:
    """start 指向 '{': 返回 (块体含括号, 结束下标)。"""
    depth, i = 0, start
    while i < len(src):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[start : i + 1], i + 1
        i += 1
    raise AssertionError("括号不配对")


def parse_attack_dispatch(src: str) -> dict:
    body = _method_body(src, r"public static MirAnimation GetAttackAnimation\(")
    # 先摘出嵌套 switch(@class) 块, 避免其 default: 干扰顶层分段
    nested_at = body.find("switch (@class)")
    assert nested_at >= 0, "GetAttackAnimation 缺少嵌套 switch(@class)"
    brace = body.find("{", nested_at)
    nested_src, nested_end = _balanced_block(body, brace)
    masked = body[:nested_at] + "__NESTED_CLASS_SWITCH__" + body[nested_end:]

    rules = []
    for magics, seg in _split_cases(masked):
        if magics is None:
            # default: 嵌套 switch(@class) — Assassin 武器链 + 其余职业
            am = re.search(r"case MirClass\.Assassin:(.*?)default:", nested_src, re.S)
            assert am, "嵌套 switch(@class) 的 Assassin 分支结构变化"
            rules.append({
                "type": "classWeapon", "class": "Assassin",
                "magics": None, "byWeapon": _weapon_chain(am.group(1)),
            })
            plain = re.search(r"default:\s*animation = MirAnimation\.(\w+);", nested_src)
            assert plain, "嵌套 switch(@class) default 缺 plain 结果"
            rules.append({"type": "default", "anim": first_cap(plain.group(1))})
            continue
        if "weaponShape" in seg:
            rules.append({
                "type": "groupWeapon", "magics": magics,
                "byWeapon": _weapon_chain(seg),
            })
        else:
            am = ANIM_NAME.search(seg)
            assert am, f"攻击分派段无结果动画: {seg[:80]!r}"
            rules.append({"type": "group", "magics": magics, "anim": first_cap(am.group(1))})
    # 结构断言: 必须有默认规则与刺客规则
    assert any(r["type"] == "default" for r in rules)
    assert any(r.get("class") == "Assassin" for r in rules)
    return {"rules": rules}


def parse_magic_dispatch(src: str) -> dict:
    body = _method_body(src, r"public static MirAnimation GetMagicAnimation\(")
    groups = []
    for magics, seg in _split_cases(body):
        if magics is None:
            assert "NotImplementedException" in seg, \
                "GetMagicAnimation default 不再是 NotImplementedException — 请人工复核"
            continue
        am = ANIM_NAME.search(seg)
        assert am, f"魔法分派段无结果动画: {seg[:80]!r}"
        groups.append({"magics": magics, "anim": first_cap(am.group(1))})
    return {"groups": groups, "default": None}  # C# throw; 消费端容错 combat1 (Godot 行为)


# --------------------------------------------------------- PlayerRenderer.cs
def parse_armour_shift(src: str) -> dict:
    m = re.search(
        r"private int ArmourShift => Class != MirClass\.Assassin \? 0 : Animation switch\s*\{(.*?)\};",
        src, re.S,
    )
    assert m, "ArmourShift switch 结构变化"
    out: dict[str, int] = {}
    for am in re.finditer(
        r"((?:MirAnimation\.\w+(?:\s+or\s+MirAnimation\.\w+)*))\s*=>\s*(-?\d+)", m.group(1)
    ):
        val = int(am.group(2))
        for nm in re.findall(r"MirAnimation\.(\w+)", am.group(1)):
            out[first_cap(nm)] = val
    assert "walking" in out and out["walking"] == 1600, "ArmourShift 提取值异常"
    return dict(sorted(out.items()))


def parse_paperdoll(src: str) -> dict:
    def expr_of(name: str) -> str:
        m = re.search(rf"(?:private|public) int {name} =>\s*(.*?);", src)
        assert m, f"层公式缺失: {name}"
        return " ".join(m.group(1).split())

    shape_off = re.search(
        r"ArmourShapeOffSet => Class == MirClass\.Assassin \? (\d+) : (\d+)", src)
    assert shape_off, "ArmourShapeOffSet 结构变化"
    costume = re.search(r"CostumeShapeHideWeapon = new\(\)\s*\{([^}]*)\}", src)
    assert costume, "CostumeShapeHideWeapon 结构变化"
    costume_set = sorted(int(x) for x in re.findall(r"\d+", costume.group(1)))

    # DrawPlayerAt 方向分组 (按注释锚点切段)
    dp = re.search(r"private void DrawPlayerAt\(.*?\n    \}", src, re.S)
    assert dp, "DrawPlayerAt 缺失"
    body = dp.group(0)

    def dir_group(anchor: str) -> list[int]:
        seg = re.search(anchor + r"[^\n]*\n(?:(?!//).)*?Direction is ([^)\n]+)", body, re.S)
        assert seg, f"方向分组缺失: {anchor}"
        names = [x.strip().removeprefix("MirDirection.") for x in re.split(r"\s+or\s+", seg.group(1))]
        dirs = [MIR_DIRECTION_NAMES.index(n) for n in names]
        assert len(dirs) >= 3, f"方向分组过短: {anchor} → {names}"
        return dirs

    return {
        "drawFrame": {"expr": "DrawFrame = FrameIndex + Start + OffSet * Direction",
                      "frameIndexExpr": "frameIndex + start + offset * direction"},
        "shapeOffset": {"default": int(shape_off.group(2)),
                        "Assassin": int(shape_off.group(1))},
        "layers": {
            "armour": {"expr": expr_of("ArmourFrame")},
            "hair": {"expr": expr_of("HairFrame")},
            "helmet": {"expr": expr_of("HelmetFrame")},
            "weapon": {"expr": expr_of("WeaponFrame"),
                       "shapeNormalize": expr_of("WeaponShape")},
            "shield": {"expr": expr_of("ShieldFrame")},
        },
        "drawOrder": ["horse", "backWeapon", "backShield", "body", "head", "frontWeapon"],
        "headPriority": ["helmet", "hair"],
        "directionGroups": {
            "backWeapon": dir_group(r"// 1\. 背武器"),
            "backShield": dir_group(r"// 2\. 背盾"),
            "frontWeapon": dir_group(r"// 5\. 前武器"),
        },
        "costumeShapeHideWeapon": costume_set,
        "sources": {
            "ArmourShift": "PlayerRenderer.cs:805-838",
            "layerFrames": "PlayerRenderer.cs:840-846",
            "DrawPlayerAt": "PlayerRenderer.cs:922-966",
        },
    }


# --------------------------------------------------------- ObjectRenderer.cs
def parse_npc_special(src: str) -> dict:
    m = re.search(
        r"switch \(image\)\s*\{(.*?)default:\s*return new Dictionary<MirAnimation, Frame>\(FrameSet\.DefaultNPC\);",
        src, re.S,
    )
    assert m, "NPC 特例帧表 (switch(image)) 结构变化"
    body = m.group(1)
    out: dict[str, dict] = {}
    for cm in re.finditer(r"case ([^:]+):", body):
        seg_end = body.find("case ", cm.end())
        seg = body[cm.end() : seg_end if seg_end > 0 else len(body)]
        images = [int(x) for x in re.findall(r"\d+", cm.group(1))]
        count_m = re.search(r"new Frame\((\d+),\s*(\d+),\s*(\d+),\s*TimeSpan\.From(\w+)\((\d+)\)", seg)
        assert count_m and images, f"NPC 特例段解析失败: {cm.group(1)[:60]!r}"
        unit = {"ms": 3600000 if count_m.group(4) == "Hours" else int(count_m.group(5))}
        if count_m.group(4) == "Hours":
            unit["static"] = True
        ent = {"start": int(count_m.group(1)), "count": int(count_m.group(2)),
               "offset": int(count_m.group(3)), **unit}
        for img in images:
            out[str(img)] = {"standing": ent}
    assert "56" in out and "64" in out and "156" in out, "NPC 特例关键项缺失"
    return out

def parse_objects(src: str) -> dict:
    """怪物/NPC/物品 bodyOffset — 锚 Type = Kind.X 初始化器内的 BodyOffSet 赋值。"""
    out = {}
    exprs = {
        "monster": ("Monster", 1000, "BodyFrame = DrawFrame + BodyShape * 1000"),
        "npc": ("NPC", 100, "BodyFrame = DrawFrame + Image * 100"),
        "item": ("Item", 0, "frame = DrawImage"),
    }
    for key, (kind, expect, expr) in exprs.items():
        anchor = re.search(rf"Type = Kind\.{kind},", src)
        assert anchor, f"ObjectRenderer 缺少 Kind.{kind} 初始化器"
        off = re.search(r"BodyOffSet = (\d+)", src[anchor.end():anchor.end() + 1200])
        out[key] = {"bodyOffset": int(off.group(1)), "frameExpr": expr}
        assert out[key]["bodyOffset"] == expect, f"{key} bodyOffset={out[key]['bodyOffset']} != {expect}"
    return out


# ------------------------------------------------------------------- main
def _strip_csharp_comments(src: str) -> str:
    """去 // 与 /* */ 注释 (保换行) — E5 实证: SDMob19/21/22/23 的 Show/Hide
    在源码里是注释掉的, 不去注释会把注释当数据抽出 (快照等价对账抓出)。"""
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


def build(zircon: Path) -> dict:
    enum_src = _strip_csharp_comments((zircon / "LibraryCore/Enum.cs").read_text(encoding="utf-8"))
    fs_src = _strip_csharp_comments((zircon / "LibraryCore/FrameSet.cs").read_text(encoding="utf-8"))
    fn_src = _strip_csharp_comments((zircon / "LibraryCore/Functions.cs").read_text(encoding="utf-8"))
    pr_src = (zircon / "GodotClient/Scripts/PlayerRenderer.cs").read_text(encoding="utf-8")  # 注释锚点解析, 不去注释
    or_src = _strip_csharp_comments((zircon / "GodotClient/Scripts/ObjectRenderer.cs").read_text(encoding="utf-8"))

    global MIR_DIRECTION_NAMES
    mir_direction = parse_enum_block(enum_src, "MirDirection")
    MIR_DIRECTION_NAMES = list(mir_direction.keys())

    magic_types = parse_enum_block(enum_src, "MagicType")
    frame_sets = parse_frame_sets(fs_src)

    doc = {
        "_meta": {
            "generator": "Tools/resedit/frameformulas.py",
            "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "purpose": "动画帧表/纸娃娃公式单一数据源 (webport + wilviewer 共读)",
            "rule": "本文件由提取器生成, 手改会被 --check 门禁拦下; 改 C# 后重跑生成器",
            "sources": {
                "LibraryCore/Enum.cs": "MirAction/MirAnimation/MirDirection/MirClass/MagicType",
                "LibraryCore/FrameSet.cs": "帧表 (Players/Default*/Companion_*)",
                "LibraryCore/Functions.cs": "GetAttackAnimation/GetMagicAnimation",
                "GodotClient/Scripts/PlayerRenderer.cs": "纸娃娃层公式/ArmourShift/方向分组",
                "GodotClient/Scripts/ObjectRenderer.cs": "NPC 特例帧表/怪物·NPC·物品 bodyOffset",
            },
            "notes": [
                "MirClass 本 fork 仅 4 职业 (无 Archer); webport 保留 Archer=4 别名兼容上游",
                "GetMagicAnimation default: C# throw NotImplementedException, Godot 客户端容错为 Combat1",
                "NPC 特例 image 64/65/... 的 single 帧为 FromHours(1)=3600000ms (静态帧)",
            ],
        },
        "enums": {
            "mirAction": parse_enum_block(enum_src, "MirAction"),
            "mirAnimation": list(parse_enum_block(enum_src, "MirAnimation").keys()),
            "mirDirection": list(mir_direction.keys()),
            "mirClass": parse_enum_block(enum_src, "MirClass"),
        },
        "magicTypes": magic_types,
        "frameSets": frame_sets,
        "npcSpecial": parse_npc_special(or_src),
        "attackDispatch": parse_attack_dispatch(fn_src),
        "magicDispatch": parse_magic_dispatch(fn_src),
        "armourShift": parse_armour_shift(pr_src),
        "paperdoll": parse_paperdoll(pr_src),
        "objects": parse_objects(or_src),
    }

    # 与 webport 旧手抄表的全量核对 (搬迁兜底: 提取器 bug 在此拦截)。
    # 基线由旧 frames.js 机器导出 (Tools/resedit/legacy-frames-baseline.json, 带 ms)。
    legacy = json.loads((HERE / "legacy-frames-baseline.json").read_text(encoding="utf-8"))
    for key, expect in legacy["frameSets"].items():
        got = doc["frameSets"].get(key)
        assert got is not None, f"提取结果缺帧表 {key}"
        assert got == expect, f"帧表 {key} 与 webport 旧手抄表不一致:\n提取={got}\n基线={expect}"
    # ArmourShift: 双侧只比非零项 (C# 显式 => 0 与 JS 缺省 0 等价)
    legacy_shift = {k: v for k, v in legacy["armourShift"].items() if v != 0}
    got_shift = {k: v for k, v in doc["armourShift"].items() if v != 0}
    assert legacy_shift == got_shift, \
        f"ArmourShift 非零项不一致: 提取={got_shift} 基线={legacy_shift}"
    # NPC 特例 (single 帧的 static 标记是 JS 侧语义, 提取器同款)
    assert doc["npcSpecial"] == legacy["npcSpecial"], \
        f"NPC 特例不一致: 提取={doc['npcSpecial']} 基线={legacy['npcSpecial']}"
    # 关键枚举值与旧 JS 常量抽查 (MAGIC 表锚点)
    for name in ("Slaying", "ShoulderDash", "Assault", "FireBall", "Heal", "PoisonousCloud",
                 "ElementalHurricane", "DragonRepulse", "HundredFist", "Shuriken"):
        assert doc["magicTypes"].get(name) is not None, f"MagicType 缺 {name}"
    return doc


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--zircon", type=Path, default=DEFAULT_ZIRCON)
    ap.add_argument("--out", type=Path, default=None,
                    help="默认 zircon/ClientData/frame-formulas.json (E5 canonical)")
    ap.add_argument("--check", action="store_true", help="校验现有 JSON 与源一致 (CI 门禁)")
    args = ap.parse_args()
    if args.out is None:
        args.out = Path(__import__("os").environ.get(
            "MIR3_ZIRCON_ROOT", str(DEFAULT_ZIRCON))).resolve() / "ClientData" / "frame-formulas.json"

    doc = build(args.zircon)
    if args.check:
        current = json.loads(args.out.read_text(encoding="utf-8"))
        current.pop("_meta", None), doc.pop("_meta", None)
        if current == doc:
            print("frame-formulas.json 与 C# 源一致 ✓")
            return 0
        print("frame-formulas.json 与 C# 源不一致 — 请重跑生成器", file=sys.stderr)
        return 1

    args.out.write_text(
        json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=False) + "\n",
        encoding="utf-8",
    )
    n_frames = sum(len(t) for t in doc["frameSets"].values())
    print(f"已生成 {args.out}  ({len(doc['frameSets'])} 表 {n_frames} 项, "
          f"{len(doc['magicTypes'])} MagicType, {len(doc['npcSpecial'])} NPC 特例)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
