#!/usr/bin/env python3
"""extract_godot_table.py — 机械全保真解析 GodotClient/Scripts/MagicEffectTable.cs。

E5/A1: 把 Godot 硬编码特效表逐字段抽成 JSON（结构事实源）。
- OriginalSpellCases / NoVisualSpellCases 白名单
- _attackTable (ImpactDef) / _table (CastEffect) 全字段，含嵌套
  Source/SourceAdditional/SourcePerLocation/Projectile/TargetProjectile/
  Impact/TargetEffect/MapImpact/Additional/AdditionalMapEffects/
  AdditionalProjectiles/TargetAdditionalProjectiles
- 值形态: 枚举成员(LibraryFile/SoundIndex/EffectLayer)、bool、int、float(f后缀)、
  颜色名(Fire/Ice/.../White)、new Color(r,g,b[,a])、new[]{int,...}

JSON 字段名 camelCase (Loader 侧映射回 C# PascalCase)。
独立性铁律: 本工具与 gen_cs_table.py 的解析互不复用 (对账才有意义)。
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
ZIRCON = Path(__import__("os").environ.get(
    "MIR3_ZIRCON_ROOT", str(REPO.parent / "zircon"))).resolve()
CS = ZIRCON / "GodotClient" / "Scripts" / "MagicEffectTable.cs"

# JSON 键 (camelCase) ↔ C# 字段名 (PascalCase)
FIELD_MAP = {
    "File": "file", "StartIndex": "startIndex", "FrameCount": "frameCount",
    "DelayMs": "delayMs", "Colour": "colour", "Blend": "blend",
    "BlendRate": "blendRate", "Opacity": "opacity", "Skip": "skip",
    "FrameLight": "frameLight", "DrawType": "drawType",
    "StartDelayMs": "startDelayMs", "DistanceDelayMs": "distanceDelayMs",
    "DirectionFromSource": "directionFromSource",
    "DirectionFromCast": "directionFromCast", "CastAtSource": "castAtSource",
    "Source": "source", "SourceAdditional": "sourceAdditional",
    "SourcePerLocation": "sourcePerLocation",
    "NoTargetVisual": "noTargetVisual", "NoLocationVisual": "noLocationVisual",
    "ReleaseAtCaster": "releaseAtCaster",
    "ProjectileLastLocationOnly": "projectileLastLocationOnly",
    "Projectile": "projectile", "TargetProjectile": "targetProjectile",
    "Impact": "impact", "TargetEffect": "targetEffect", "MapImpact": "mapImpact",
    "Additional": "additional", "AdditionalMapEffects": "additionalMapEffects",
    "AdditionalProjectiles": "additionalProjectiles",
    "TargetAdditionalProjectiles": "targetAdditionalProjectiles",
    "ProjectileDelayStepMs": "projectileDelayStepMs",
    "NoColourKey": "noColourKey",
    "Has16Directions": "has16Directions", "Explode": "explode",
    "OriginOffsetX": "originOffsetX", "OriginOffsetY": "originOffsetY",
    "OriginFromTarget": "originFromTarget",
    "Arrival": "arrival", "ArrivalSound": "arrivalSound",
    "CompletionSound": "completionSound",
    "SoundFrame": "soundFrame", "SoundFrameSound": "soundFrameSound",
    "DirectionStartIndices": "directionStartIndices",
    "OffsetX": "offsetX", "OffsetY": "offsetY",
}

# 初始化器里合法的嵌套类型
NESTED_TYPES = {"CastEffect", "ImpactDef", "ProjectileDef", "OffsetImpactDef"}
# 集合初始化器字段 (值 = 对象列表)
LIST_FIELDS = {
    "SourceAdditional", "SourcePerLocation", "Additional",
    "AdditionalMapEffects", "AdditionalProjectiles", "TargetAdditionalProjectiles",
}
# 颜色标识符 (MagicEffectTable 静态色 + Colors.White 默认)
COLOR_NAMES = {"Fire", "Ice", "Lightning", "Wind", "Holy", "Dark", "Phantom",
               "None", "Purple", "GreenYellow", "White"}


def strip_comments(src: str) -> str:
    """去 // 与 /* */ 注释，保持换行数（行号不漂移）。字符串字面量表内无。"""
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


def balanced(src: str, open_idx: int) -> tuple[str, int]:
    """src[open_idx] 必须是 '{'：返回 (体, 闭括号下标)。"""
    depth = 0
    for i in range(open_idx, len(src)):
        if src[i] == "{":
            depth += 1
        elif src[i] == "}":
            depth -= 1
            if depth == 0:
                return src[open_idx + 1:i], i
    raise ValueError(f"unbalanced brace at {open_idx}")


def split_top(src: str, sep: str = ",") -> list[str]:
    """顶层按 sep 分割（忽略括号/大括号内）。"""
    parts, cur, depth = [], [], 0
    for ch in src:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == sep and depth == 0:
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    tail = "".join(cur).strip()
    if tail:
        parts.append(tail)
    return parts


def parse_value(val: str) -> object:
    """初始化器值表达式 → JSON 值。无法解析时抛 ValueError（宁可失败不静默丢字段）。"""
    val = val.strip()
    if val in ("true", "false"):
        return val == "true"
    if re.fullmatch(r"-?\d+", val):
        return int(val)
    if re.fullmatch(r"-?\d+[fF]", val):
        return float(val[:-1])
    if re.fullmatch(r"-?\d+\.\d+[fF]?", val):
        return float(val.rstrip("fF"))
    m = re.fullmatch(r"LibraryFile\.(\w+)", val)
    if m:
        return m.group(1)
    m = re.fullmatch(r"SoundIndex\.(\w+)", val)
    if m:
        return m.group(1)
    m = re.fullmatch(r"MirEffectNode\.EffectLayer\.(\w+)", val)
    if m:
        return m.group(1)
    if val in COLOR_NAMES:
        return val
    # new Color(r, g, b[, a])
    m = re.fullmatch(r"new Color\(([^)]*)\)", val)
    if m:
        comps = [float(x.strip().rstrip("fF")) for x in m.group(1).split(",")]
        return comps
    # new[] { int, ... }
    m = re.fullmatch(r"new\[\]\s*\{(.*)\}", val, re.S)
    if m:
        return [int(x.strip()) for x in m.group(1).split(",") if x.strip()]
    # 嵌套对象 new Xxx { ... }
    m = re.fullmatch(r"new (\w+)\s*(\{.*)", val, re.S)
    if m and m.group(1) in NESTED_TYPES:
        body, _ = balanced(m.group(2), 0)
        obj = parse_initializer_body(body)
        obj["_type"] = m.group(1)
        return obj
    raise ValueError(f"unparseable value: {val!r}")


def parse_initializer_body(body: str) -> dict:
    """对象初始化器体 → {camelField: value}。"""
    out: dict = {}
    for part in split_top(body):
        m = re.match(r"(\w+)\s*=\s*(.+)$", part, re.S)
        if not m:
            raise ValueError(f"unparseable initializer part: {part!r}")
        name, val = m.group(1), m.group(2).strip()
        key = FIELD_MAP.get(name)
        if key is None:
            raise ValueError(f"unknown field in table: {name!r}")
        if name in LIST_FIELDS:
            # 集合初始化器 { new ImpactDef {...}, ... }
            if not val.startswith("{"):
                raise ValueError(f"list field {name} non-collection: {val!r}")
            inner, _ = balanced(val, 0)
            items = []
            for it in split_top(inner):
                items.append(parse_value(it))
            out[key] = items
        else:
            out[key] = parse_value(val)
    return out


def find_dict_block(src: str, decl_re: str) -> str:
    """定位字典声明，返回配平的大括号块体。"""
    m = re.search(decl_re, src)
    if not m:
        raise ValueError(f"declaration not found: {decl_re}")
    i = src.index("{", m.end() - 1) if "{" not in m.group(0) else src.index("{", m.start())
    body, _ = balanced(src, i)
    return body


def parse_dict_entries(block: str) -> dict[str, dict]:
    """`[MagicType.X] = new T {...}` 条目序列 → {skill: 初始化器解析结果}。"""
    out: dict[str, dict] = {}
    for em in re.finditer(r"\[MagicType\.(\w+)\]\s*=\s*new\s+(\w+)\s*\{", block):
        skill, cls = em.group(1), em.group(2)
        i = block.index("{", em.start())
        body, _ = balanced(block, i)
        obj = parse_initializer_body(body)
        obj["_type"] = cls
        if skill in out:
            raise ValueError(f"duplicate key {skill}")
        out[skill] = obj
    return out


def parse_hashset(src: str, name: str) -> list[str]:
    m = re.search(rf"{name}\s*=\s*new\(\)\s*\{{", src)
    if not m:
        raise ValueError(f"hashset {name} not found")
    body, _ = balanced(src, src.index("{", m.end() - 1))
    return sorted(re.findall(r"MagicType\.(\w+)", body))


def parse_table(cs_path: Path = CS) -> dict:
    """全保真解析 → dict (schema 见模块 docstring)。"""
    src = strip_comments(cs_path.read_text(encoding="utf-8-sig"))
    return {
        "originalSpellCases": parse_hashset(src, "OriginalSpellCases"),
        "noVisualSpellCases": parse_hashset(src, "NoVisualSpellCases"),
        "attackTable": parse_dict_entries(find_dict_block(
            src, r"Dictionary<MagicType,\s*ImpactDef>\s*_attackTable\s*=\s*new\(\)\s*\{")),
        "table": parse_dict_entries(find_dict_block(
            src, r"Dictionary<MagicType,\s*CastEffect>\s*_table\s*=\s*new\(\)\s*\{")),
    }


def main() -> int:
    out = Path(sys.argv[sys.argv.index("--out") + 1]) if "--out" in sys.argv else None
    data = parse_table()
    n_defs = sum(count_defs(e) for e in data["table"].values())
    print(f"OK {CS}")
    print(f"  originalSpellCases: {len(data['originalSpellCases'])}, "
          f"noVisual: {len(data['noVisualSpellCases'])}")
    print(f"  _table: {len(data['table'])} 条目, 嵌套 def 总数 {n_defs}")
    print(f"  _attackTable: {len(data['attackTable'])} 条目")
    if out:
        out.write_text(json.dumps(data, ensure_ascii=False, indent=1),
                       encoding="utf-8")
        print(f"  -> {out}")
    return 0


def count_defs(obj) -> int:
    n = 0
    if isinstance(obj, dict):
        if "_type" in obj:
            n += 1
        for v in obj.values():
            n += count_defs(v)
    elif isinstance(obj, list):
        for v in obj:
            n += count_defs(v)
    return n


if __name__ == "__main__":
    raise SystemExit(main())
