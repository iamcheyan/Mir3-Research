#!/usr/bin/env python3
"""gen_cs_table.py — E5 cutover 后的特效表对账门禁 (v2)。

历史: E4/P3 版本对账 GodotClient/Scripts/MagicEffectTable.cs 硬编码表 ↔ 事实源 JSON,
并用 --fix 做过一次 JSON→C# 修复闭环 (zircon 0dc1321)。
E5/B4 cutover 后硬编码字典本体已删 (保留类/API 壳), 数据唯一来源是
zircon/ClientData/magic-effects.json (DataLayer 运行时装载)。
本工具的口径随之升级:

  --check  双重对账:
           (1) 文件层: ClientData/magic-effects.json godot 段三元组 vs 原版段
               (帧数据事实源, ACCEPTABLE 清单兜底) — 与 merge_effects 同口径独立实现;
           (2) 运行时层: headless Godot --table-snapshot 导出运行中客户端的全部表,
               与 ClientData JSON godot 段逐字段全等 (loader 保真证明)。
           运行时层需要 godot-mono (本机验收路径); --skip-runtime 只跑文件层。

  --fix    已退役 (codegen 路线被 E5 架构否决, 编辑回写直接改 JSON)。
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ZIRCON = Path(os.environ.get("MIR3_ZIRCON_ROOT", str(ROOT.parent / "zircon"))).resolve()
CD = ZIRCON / "ClientData"
ME = CD / "magic-effects.json"
GODOT_PROJECT = ZIRCON / "GodotClient"
DISPLAY = os.environ.get("E5_DISPLAY", ":77")

# GODOT_TABLE_DIFF.md 人工判读 (可接受差异) — 与 merge_effects.py 保持同口径
ACCEPTABLE = {
    "ScortchedEarth", "MonsterScortchedEarth", "AugmentPoisonDust", "ThunderStrike",
    "DoomClawLeftPinch", "DoomClawRightPinch", "GreenSludgeBall",
}

# (1) 文件层 -----------------------------------------------------------
def triples(entry: dict) -> set:
    out = set()
    for seg in ("start", "release"):
        for fx in (entry.get(seg) or {}).get("effects", []):
            lib, frame, cnt = fx.get("lib"), fx.get("frame"), fx.get("count")
            if lib is None or frame is None or cnt is None:
                continue
            out.add((lib, frame, cnt))
    return out


def check_file(doc: dict) -> list[str]:
    v: list[str] = []
    for name, sk in doc["skills"].items():
        if name in ACCEPTABLE:
            continue
        o, g = sk.get("original"), sk.get("godot")
        if o and g:
            to = triples(o)
            if not to:
                continue
            tg = set()
            def walk(x):
                if isinstance(x, dict):
                    if "file" in x and isinstance(x.get("startIndex"), int):
                        tg.add((x["file"], x["startIndex"], x["frameCount"]))
                    for vv in x.values():
                        walk(vv)
                elif isinstance(x, list):
                    for vv in x:
                        walk(vv)
            walk(g)
            if to != tg:
                v.append(f"{name}: 原版{sorted(to)} != godot段{sorted(tg)}")
    # 白名单口径: 有原版特效的技能必须在 originalSpellCases
    wl = set(doc["originalSpellCases"])
    want = {k for k, sk in doc["skills"].items() if triples(sk.get("original") or {})}
    for k in sorted(want - wl):
        v.append(f"白名单缺 {k}")
    for k in sorted(wl - want):
        v.append(f"白名单多 {k}")
    return v


# (2) 运行时层 ---------------------------------------------------------
# 运行时快照 PascalCase ↔ JSON camelCase (与 DataLayer/extract_godot_table 同映射)
FIELD_MAP = {
    "File": "file", "StartIndex": "startIndex", "FrameCount": "frameCount",
    "DelayMs": "delayMs", "Colour": "colour", "Blend": "blend",
    "BlendRate": "blendRate", "Opacity": "opacity", "Skip": "skip",
    "FrameLight": "frameLight", "DrawType": "drawType",
    "StartDelayMs": "startDelayMs", "DistanceDelayMs": "distanceDelayMs",
    "DirectionFromSource": "directionFromSource", "DirectionFromCast": "directionFromCast",
    "CastAtSource": "castAtSource", "Source": "source", "SourceAdditional": "sourceAdditional",
    "SourcePerLocation": "sourcePerLocation", "NoTargetVisual": "noTargetVisual",
    "NoLocationVisual": "noLocationVisual", "ReleaseAtCaster": "releaseAtCaster",
    "ProjectileLastLocationOnly": "projectileLastLocationOnly",
    "Projectile": "projectile", "TargetProjectile": "targetProjectile",
    "Impact": "impact", "TargetEffect": "targetEffect", "MapImpact": "mapImpact",
    "Additional": "additional", "AdditionalMapEffects": "additionalMapEffects",
    "AdditionalProjectiles": "additionalProjectiles",
    "TargetAdditionalProjectiles": "targetAdditionalProjectiles",
    "ProjectileDelayStepMs": "projectileDelayStepMs", "NoColourKey": "noColourKey",
    "Has16Directions": "has16Directions", "Explode": "explode",
    "OriginOffsetX": "originOffsetX", "OriginOffsetY": "originOffsetY",
    "OriginFromTarget": "originFromTarget", "Arrival": "arrival",
    "ArrivalSound": "arrivalSound", "CompletionSound": "completionSound",
    "SoundFrame": "soundFrame", "SoundFrameSound": "soundFrameSound",
    "DirectionStartIndices": "directionStartIndices",
    "OffsetX": "offsetX", "OffsetY": "offsetY",
}
# JSON 缺省时的 C# 默认值 (与类初始化器逐一对齐; nullable 单对象缺省 = None)
CAST_DEFAULTS = {"blend": True, "blendRate": 0.7, "opacity": 1.0, "skip": 10,
                 "frameLight": 10, "drawType": "Object", "delayMs": 100,
                 "startDelayMs": 0.0, "distanceDelayMs": 0,
                 "castAtSource": False, "directionFromSource": False,
                 "directionFromCast": False, "noTargetVisual": False,
                 "noLocationVisual": False, "releaseAtCaster": False,
                 "projectileLastLocationOnly": False, "projectileDelayStepMs": 0.0,
                 "noColourKey": False,
                 "sourceAdditional": [], "sourcePerLocation": [], "additional": [],
                 "additionalMapEffects": [], "additionalProjectiles": [],
                 "targetAdditionalProjectiles": [],
                 "source": None, "projectile": None, "targetProjectile": None,
                 "impact": None, "targetEffect": None, "mapImpact": None}
PROJ_DEFAULTS = {"delayMs": 100, "blendRate": 0.7, "opacity": 1.0, "skip": 10,
                 "drawType": "Object", "frameLight": 35, "has16Directions": True,
                 "explode": False, "originFromTarget": False, "startDelayMs": 0.0,
                 "noColourKey": False,
                 "arrivalSound": "None", "completionSound": "None",
                 "originOffsetX": 0, "originOffsetY": 0, "arrival": None}
IMPACT_DEFAULTS = {"delayMs": 100, "blendRate": 0.7, "opacity": 1.0, "skip": 10,
                   "drawType": "Object", "frameLight": 10, "soundFrame": -1,
                   "soundFrameSound": "None", "directionStartIndices": None,
                   "startDelayMs": 0.0, "distanceDelayMs": 0,
                   "directionFromSource": False, "directionFromCast": False,
                   "noColourKey": False}


def detect_kind(entry: dict) -> str:
    """JSON 侧看 _type; 运行时快照侧看 C# 类特有字段。"""
    t = entry.get("_type")
    if t == "CastEffect":
        return "cast"
    if t == "ProjectileDef":
        return "proj"
    if t == "OffsetImpactDef":
        return "offset"
    if t == "ImpactDef":
        return "impact"
    ks = set(entry)
    if ks & {"CastAtSource", "ProjectileDelayStepMs", "SourceAdditional"}:
        return "cast"
    if ks & {"Has16Directions", "ArrivalSound"}:
        return "proj"
    if ks & {"OffsetX", "OffsetY"}:
        return "offset"
    return "impact"


OFFSET_DEFAULTS = dict(IMPACT_DEFAULTS, offsetX=0, offsetY=0)
DEFAULTS = {"cast": CAST_DEFAULTS, "proj": PROJ_DEFAULTS,
            "impact": IMPACT_DEFAULTS, "offset": OFFSET_DEFAULTS}


def norm_entry(entry: dict, colors: dict) -> dict:
    """运行时/JSON 任一侧的 def 条目 → 统一 camelCase + 默认补全 + colour 数值化。"""
    kind = detect_kind(entry)
    out: dict = dict(DEFAULTS[kind])
    for k, v in entry.items():
        if k == "_type":
            continue
        ck = FIELD_MAP.get(k, k)
        if isinstance(v, dict):
            out[ck] = norm_entry(v, colors)
        elif isinstance(v, list):
            out[ck] = [norm_entry(x, colors) if isinstance(x, dict) else x for x in v]
        else:
            out[ck] = v
    c = out.get("colour")
    if isinstance(c, str):
        out["colour"] = colors[c]
    elif isinstance(c, list) and len(c) == 3:
        out["colour"] = c + [1]
    return out


def check_runtime(doc: dict) -> list[str]:
    with tempfile.NamedTemporaryFile(suffix=".json", delete=False) as tf:
        snap_path = tf.name
    env = dict(os.environ)
    env["DISPLAY"] = DISPLAY
    r = subprocess.run(
        ["godot-mono", "--path", str(GODOT_PROJECT), "--headless",
         "res://Scenes/MapTestScene.tscn", "--", f"--table-snapshot={snap_path}"],
        capture_output=True, text=True, timeout=240, env=env, cwd=str(GODOT_PROJECT))
    if "TableSnapshot] PASS" not in r.stdout:
        Path(snap_path).unlink(missing_ok=True)
        return [f"运行时快照失败: {r.stdout[-300:]} {r.stderr[-300:]}"]
    snap = json.loads(Path(snap_path).read_text(encoding="utf-8"))
    Path(snap_path).unlink(missing_ok=True)
    met = snap["magicEffectTable"]
    colors = {k: v for k, v in met.get("colors", {}).items()}

    def kind_of(entry: dict) -> str:
        if "has16Directions" in entry or "arrivalSound" in entry:
            return "proj"
        if "offsetX" in entry or "offsetY" in entry:
            return "offset"
        return "impact"

    v: list[str] = []
    # _table
    snap_table = met["_table"]
    json_table = {k: s["godot"] for k, s in doc["skills"].items() if s.get("godot")}
    if set(snap_table) != set(json_table):
        v.append(f"技能集不等: 快照缺 {sorted(set(json_table) - set(snap_table))}, "
                 f"快照多 {sorted(set(snap_table) - set(json_table))}")
    for k in sorted(set(snap_table) & set(json_table)):
        a = norm_entry(snap_table[k], colors)
        b = norm_entry(json_table[k], colors)
        if a != b:
            v.append(f"{k}: 运行时 != JSON")
    # _attackTable
    snap_at = met["_attackTable"]
    json_at = doc["attackTable"]
    if set(snap_at) != set(json_at):
        v.append(f"attackTable 技能集不等")
    for k in sorted(set(snap_at) & set(json_at)):
        a = norm_entry(snap_at[k], colors)
        b = norm_entry(json_at[k], colors)
        if a != b:
            v.append(f"attackTable.{k}: 运行时 != JSON")
    return v


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--fix":
        print("--fix 已退役 (E5 架构: 编辑回写直接改 ClientData JSON, 无 codegen)", file=sys.stderr)
        return 2
    doc = json.loads(ME.read_text(encoding="utf-8"))
    v = check_file(doc)
    print(f"文件层: {len(doc['skills'])} 技能, 白名单 {len(doc['originalSpellCases'])}, "
          f"可接受差异 {len(ACCEPTABLE)}, 违规 {len(v)}")
    if not v and "--skip-runtime" not in sys.argv:
        v += check_runtime(doc)
        print(f"运行时层: {'全等 ✓' if not v else '不等 ✗'}")
    if v:
        print("CHECK FAIL:", file=sys.stderr)
        for x in v[:20]:
            print(" -", x, file=sys.stderr)
        return 1
    print("OK: ClientData/magic-effects.json 文件层+运行时层全绿 ✓")
    return 0


if __name__ == "__main__":
    main()
