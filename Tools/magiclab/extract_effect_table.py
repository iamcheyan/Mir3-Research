#!/usr/bin/env python3
"""Magic Lab P0 — 从原版 Client 提取技能特效事实源。

权威来源（Zircon 仓库，Client/ 源码只读）：
  1. MapObject.cs:768   case MirAction.Spell + if(!MagicCast) break  → release 段
     （施法动作释放帧触发：弹道/命中/地面特效，行号区间动态定位）
  2. MapObject.cs:3603  case MirAction.Spell（SetAction 内）→ start 段
     （施法起手特效，几乎全部 Target=this + *Start 音效）
  3. LibraryCore/Functions.cs GetMagicAnimation → 施法动作 castAnim

产出 Tools/magiclab/magic-effect-table.json（唯一事实源）。

解析策略：文本结构解析（括号/大括号平衡扫描），不 import 任何 Godot/生成器
代码——对账工具 (verify_frames.py / diff_godot_table.py) 与本工具保持独立。
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
ZIRCON = Path(__import__("os").environ.get(
    "MIR3_ZIRCON_ROOT", "/home/tetsuya/development/zircon")).resolve()
if not (ZIRCON / "Client").exists():
    ZIRCON = Path("/home/tetsuya/development/zircon").resolve()

MAPOBJ = ZIRCON / "Client" / "Models" / "MapObject.cs"
FUNCTIONS = ZIRCON / "LibraryCore" / "Functions.cs"
OUT = REPO / "Tools" / "magiclab" / "magic-effect-table.json"

CASE_RE = re.compile(r"^\s*case MagicType\.([A-Za-z0-9_]+):\s*$")

# MirEffect/MirProjectile 构造参数里的可解析字面量
COLOUR_RE = re.compile(r"Globals\.([A-Za-z]+Colour)|System\.Drawing\.Color\.([A-Za-z]+)")
LIB_RE = re.compile(r"LibraryFile\.([A-Za-z0-9_]+)")


def find_spell_regions(src: str) -> dict[str, tuple[int, int]]:
    """定位两段 MagicType switch 的行区间（0 基）。"""
    lines = src.splitlines()
    regions = {}
    # release 段：case MirAction.Spell: 且下一行是 if (!MagicCast) break;
    for i, ln in enumerate(lines):
        if re.match(r"^\s*case MirAction\.Spell:", ln):
            nxt = lines[i + 1] if i + 1 < len(lines) else ""
            if "MagicCast" in nxt:
                regions["release"] = (i, None)
            elif regions.get("release", (0, None))[1] is None and "release" in regions:
                # SetAction 内的 Spell case（第二个 case MirAction.Spell）
                if "release" in regions and regions["release"][1] is None:
                    regions["release"] = (regions["release"][0], i - 1)
                regions["start"] = (i, None)
    # start 段结束：switch 收尾 —— 用括号平衡找 switch (MagicType) 的闭合
    for name, (begin, _) in list(regions.items()):
        # 从 begin 起找 "switch (MagicType)"，然后平衡大括号
        depth = 0
        opened = False
        for i in range(begin, len(lines)):
            line = lines[i]
            if not opened and "switch (MagicType)" in line:
                opened = True
            if opened:
                depth += line.count("{") - line.count("}")
                if depth <= 0 and "{" in line:
                    regions[name] = (begin, i)
                    break
    return regions


def split_cases(region_lines: list[str], base_line: int) -> list[tuple[str, int, list[str]]]:
    """把一段 switch 拆成 (case名, 起始行号1基, body行)。

    支持 fall-through 标签组：连续多个 case 标签共享后续 body
    （如 AdamantineFireBall/MeteorShower/FireBounce 三标签一体）。
    """
    cases: list[tuple[str, int, list[str]]] = []
    pending: list[str] = []          # 尚无 body 的连续标签
    pending_start: int = 0
    cur_name, cur_start, body, cur_group = None, None, [], None
    depth = 0
    for idx, ln in enumerate(region_lines):
        m = CASE_RE.match(ln)
        if m and depth <= 1:
            if cur_name:  # 已有 body 的 case 收尾
                cases.append((cur_name, cur_start, body))
                cur_name, body = None, []
            pending.append(m.group(1))
            pending_start = pending_start or base_line + idx + 1
            continue
        if pending and not cur_name:
            # 第一个实际内容行：固化 pending 组（记录 fall-through 成员）
            group = pending if len(pending) > 1 else None
            cur_name = pending[-1]
            cur_start = pending_start
            cur_group = group
            pending, pending_start = [], 0
        if cur_name:
            depth += ln.count("{") - ln.count("}")
            body.append(ln)
            if depth <= 0 and re.match(r"^\s*break;\s*$", ln):
                cases.append((cur_name, cur_start, body))
                if cur_group:
                    for g in cur_group[:-1]:
                        cases.append((g, cur_start, list(body)))
                cur_name, body, cur_group = None, [], None
                depth = 0
    if cur_name:
        cases.append((cur_name, cur_start, body))
    if pending:
        for g in pending:
            cases.append((g, pending_start, []))
    return cases


def balanced(src: str, start: int, open_ch: str, close_ch: str) -> tuple[str, int]:
    """从 src[start]（应为 open_ch）取平衡段，返回 (内容, 结束索引)。"""
    depth = 0
    for i in range(start, len(src)):
        if src[i] == open_ch:
            depth += 1
        elif src[i] == close_ch:
            depth -= 1
            if depth == 0:
                return src[start + 1:i], i
    raise ValueError(f"unbalanced {open_ch} at {start}")


def parse_ctor_args(args_src: str) -> dict:
    """解析构造实参列表（顶层逗号分割）。"""
    parts, depth, cur = [], 0, []
    for ch in args_src:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur).strip())

    def num(p: str) -> int | None:
        p = p.strip()
        return int(p) if re.fullmatch(r"-?\d+", p) else None

    out: dict = {}
    raw0 = parts[0].strip() if parts else ""
    out["frame"] = num(raw0)
    if out["frame"] is None and raw0 and ("Random" in raw0 or "+" in raw0):
        # 原版动态帧表达式（如 2450 + CEnvir.Random.Next(5)*10 = 5 组随机起始帧）
        out["frameExpr"] = re.sub(r"\s+", " ", raw0)
    if out["frame"] is None and raw0 and re.fullmatch(r"[a-zA-Z_]\w*", raw0):
        # 帧起始为局部变量（常见于 switch(action.Direction) 方向分帧表）
        out["frameExpr"] = raw0
    out["count"] = num(parts[1]) if len(parts) > 1 else None
    # parts[2] = TimeSpan.FromMilliseconds(N)
    if len(parts) > 2:
        m = re.search(r"FromMilliseconds\((\d+)\)", parts[2])
        out["delayMs"] = int(m.group(1)) if m else None
    if len(parts) > 3:
        m = LIB_RE.search(parts[3])
        out["lib"] = m.group(1) if m else parts[3].strip()
    if len(parts) > 4:
        out["startLight"] = num(parts[4])
    if len(parts) > 5:
        out["endLight"] = num(parts[5])
    if len(parts) > 6:
        m = COLOUR_RE.search(parts[6])
        out["colour"] = (m.group(1) or m.group(2)).removesuffix("Colour") if m else parts[6].strip()
    for p in parts[7:]:
        p = p.strip()
        if p == "CurrentLocation":
            out["origin"] = "caster"
        elif p.startswith("typeof("):
            out["particle"] = p[len("typeof("):-1].split(".")[-1]
        elif p and all(x not in p for x in "(="):
            out.setdefault("rawExtra", []).append(p)
    return out


def parse_initializer(init_src: str) -> dict:
    """解析对象初始化器 {...} 的顶层属性赋值。"""
    props: dict = {}
    parts, cur = [], []
    d = 0
    for ch in init_src:
        if ch in "([{":
            d += 1
        elif ch in ")]}":
            d -= 1
        if ch == "," and d == 0:
            parts.append("".join(cur).strip())
            cur = []
        else:
            cur.append(ch)
    parts.append("".join(cur).strip())
    for p in parts:
        m = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*(\+=|=)\s*(.+)$", p, re.S)
        if not m:
            continue
        name, op, val = m.group(1), m.group(2), m.group(3).strip()
        if name in ("MapTarget", "Target", "Direction", "Blend", "Skip", "Has16Directions",
                    "Explode", "BlendRate", "Opacity", "Reversed", "Loop", "UseOffSet",
                    "Delay", "Speed", "StartTime", "AdditionalOffSet"):
            v = val
            if re.fullmatch(r"true|false", v):
                v = v == "true"
            elif re.fullmatch(r"-?\d+", v):
                v = int(v)
            elif re.fullmatch(r"-?[\d.]+F", v):
                v = float(v[:-1])
            props[name] = v
    return props



class CaseParser:
    """在 case 体内按字符扫描特效构造与音效，带上下文。"""

    def __init__(self, body_src: str, first_line: int):
        self.src = body_src
        self.first_line = first_line
        self.line_of = self._build_line_index()

    def _build_line_index(self):
        offs, n = [0], 0
        for ch in self.src:
            if ch == "\n":
                n += 1
            offs.append(len(self.src[:0]) or 0)
        # 简化：行号由 offset 计算
        self.nl = [i for i, c in enumerate(self.src) if c == "\n"]
        return None

    def line_at(self, pos: int) -> int:
        import bisect
        return bisect.bisect_right(self.nl, pos) + self.first_line

    def parse(self) -> dict:
        src = self.src
        events: list[dict] = []
        i = 0
        ctx: list[dict] = []  # 上下文栈：loop point / loop target / complete / frame-index-action
        # 逐 token 扫描
        while i < len(src):
            ch = src[i]
            if ch == "{":
                inner, end = balanced(src, i, "{", "}")
                head = src[max(0, i - 200):i]
                if "CompleteAction +=" in head[-60:] or re.search(r"CompleteAction\s*\+=\s*\(?[^;]*$", head):
                    ctx.append({"t": "arrival"})
                    self._scan_body(inner, i + 1, ctx, events)
                    ctx.pop()
                elif "FrameIndexAction" in head[-60:] or re.search(r"FrameIndexAction\s*=\s*\(?[^;]*$", head):
                    self._scan_frame_action(inner, i + 1, ctx, events)
                elif re.search(r"foreach\s*\([^)]*Point\s+\w+\s+in\s+MagicLocations\)", head[-160:]) and head.rstrip().endswith(")"):
                    ctx.append({"t": "point"})
                    self._scan_body(inner, i + 1, ctx, events)
                    ctx.pop()
                elif re.search(r"foreach\s*\([^)]*MapObject\s+\w+\s+in\s+AttackTargets\)", head[-160:]) and head.rstrip().endswith(")"):
                    ctx.append({"t": "target"})
                    self._scan_body(inner, i + 1, ctx, events)
                    ctx.pop()
                elif re.search(r"for\s*\(", head[-120:]):
                    ctx.append({"t": "for"})
                    self._scan_body(inner, i + 1, ctx, events)
                    ctx.pop()
                else:
                    self._scan_body(inner, i + 1, ctx, events)
                i = end + 1
                continue
            m = re.compile(r"new (MirEffect|MirProjectile|MirChainEffect)\s*\(").match(src, i)
            if m:
                args, close = balanced(src, m.end() - 1, "(", ")")
                ev = self._parse_effect(m.group(1), args, src, close + 1, ctx)
                events.append(ev)
                # 跳过构造+可选初始化器（由外层统一处理）
                j = close + 1
                while j < len(src) and src[j] in " \t\r\n":
                    j += 1
                if j < len(src) and src[j] == "{":
                    _, bend = balanced(src, j, "{", "}")
                    i = bend + 1
                else:
                    i = close + 1
                continue
            m = re.compile(r"DXSoundManager\.Play\((SoundIndex\.([A-Za-z0-9_]+))\)").match(src, i)
            if m:
                events.append({"kind": "sound", "sound": m.group(2),
                               "ctx": [c["t"] for c in ctx], "line": self.line_at(i)})
                i = m.end()
                continue
            i += 1
        # 合并：构造事件的初始化器已就地解析（_parse_effect 内预读）
        return self._merge(events)

    def _parse_effect(self, cls: str, args: str, src: str, after: int, ctx: list[dict]) -> dict:
        d = parse_ctor_args(args)
        d["kind"] = {"MirEffect": "effect", "MirProjectile": "projectile",
                     "MirChainEffect": "chain"}[cls]
        d["ctx"] = [c["t"] for c in ctx]
        d["line"] = self.line_at(after - len(args) - 12)
        # 预读初始化器
        j = after
        while j < len(src) and src[j] in " \t\r\n":
            j += 1
        if j < len(src) and src[j] == "{":
            init, bend = balanced(src, j, "{", "}")
            props = parse_initializer(init)
            if "MapTarget" in props:
                d["target"] = "point" if props["MapTarget"] == "point" else str(props["MapTarget"])
                del props["MapTarget"]
            if "Target" in props:
                t = props["Target"]
                d["target"] = {"this": "this", "attackTarget": "target",
                               "User": "user", "primaryTarget": "target"}.get(t, t)
                del props["Target"]
            if props:
                d["extra"] = props
            d["_init_end"] = bend
        return d

    def _scan_body(self, inner: str, offset: int, ctx: list, events: list):
        """对子块内继续找构造/音效（复用主循环逻辑，通过子 CaseParser）。"""
        sub = CaseParser(inner, self.line_at(offset))
        res = sub.parse()
        for e in res["_events"]:
            e["ctx"] = [c["t"] for c in ctx] + e["ctx"]
            events.append(e)

    def _scan_frame_action(self, inner: str, offset: int, ctx: list, events: list):
        if "ShakeScreenCount" in inner:
            m = re.search(r"ShakeScreenCount\s*=\s*([\d.]+)F?", inner)
            events.append({"kind": "shake", "atFrame": None,
                           "amount": float(m.group(1)) if m else None,
                           "ctx": [c["t"] for c in ctx] + ["frameAction"],
                           "line": self.line_at(offset)})
        for m in re.finditer(r"DXSoundManager\.Play\(SoundIndex\.([A-Za-z0-9_]+)\)", inner):
            events.append({"kind": "sound", "sound": m.group(1),
                           "ctx": [c["t"] for c in ctx] + ["frameAction"],
                           "line": self.line_at(offset)})

    def _merge(self, events):
        return {"_events": events}


def classify(evt: dict, seg: str) -> str:
    """把单个事件归入语义段：castEffect/projectile/hitEffect/aoe。"""
    if evt["kind"] == "projectile":
        return "projectile"
    if evt["kind"] == "chain":
        return "chain"
    ctx = evt.get("ctx", [])
    tgt = evt.get("target")
    if seg == "start":
        return "castEffect"  # start 段全部是起手特效
    if "arrival" in ctx:
        return "hitEffect"
    if "point" in ctx:
        return "aoe"
    if "target" in ctx:
        return "hitEffect"
    if tgt in ("this", "user", "currentLocation"):
        return "castEffect"
    if tgt == "point":
        return "aoe"
    if tgt == "target":
        return "hitEffect"
    return "castEffect"  # 顶层无目标 = 跟随施法者


def parse_get_magic_animation() -> dict[str, str]:
    src = FUNCTIONS.read_text(encoding="utf-8-sig")
    m = re.search(r"public static MirAnimation GetMagicAnimation\(MagicType m\)\s*\{", src)
    if not m:
        raise SystemExit("GetMagicAnimation not found")
    body, _ = balanced(src, m.end() - 1, "{", "}")
    out: dict[str, str] = {}
    pending: list[str] = []
    for ln in body.splitlines():
        cm = re.match(r"\s*case MagicType\.([A-Za-z0-9_]+):", ln)
        if cm:
            pending.append(cm.group(1))
            continue
        rm = re.match(r"\s*return MirAnimation\.([A-Za-z0-9_]+);", ln)
        if rm:
            for c in pending:
                out[c] = rm.group(1)
            pending = []
    return out


def main():
    src = MAPOBJ.read_text(encoding="utf-8-sig")
    regions = find_spell_regions(src)
    if "release" not in regions or "start" not in regions:
        raise SystemExit(f"spell regions not found: {regions}")
    lines = src.splitlines()

    table: dict[str, dict] = {}
    stats = {"cases": {}, "unparsed": []}

    for seg, (a, b) in regions.items():
        seg_lines = lines[a:b + 1]
        for name, first_line, body_lines in split_cases(seg_lines, a):
            body_src = "\n".join(body_lines)
            cp = CaseParser(body_src, first_line)
            res = cp.parse()
            events = res["_events"]
            entry = table.setdefault(name, {"MagicType": name})
            seg_key = {"release": "release", "start": "start"}[seg]
            seg_data = {"effects": [], "sounds": [], "shakes": []}
            for e in events:
                if e["kind"] == "sound":
                    seg_data["sounds"].append({"name": e["sound"], "ctx": e["ctx"]})
                elif e["kind"] == "shake":
                    seg_data["shakes"].append(e.get("amount"))
                else:
                    e.pop("_init_end", None)
                    e["segment"] = classify(e, seg_key)
                    seg_data["effects"].append(e)
            entry[seg_key] = seg_data
            # 方向分帧表：switch(action.Direction){ case ...: var = N; }
            # → effects 里 frameExpr 引用该 var 的，展开 directionFrames
            for m in re.finditer(r"switch \(action\.Direction\)", body_src):
                try:
                    sw, _ = balanced(body_src, body_src.index("{", m.end() - 1), "{", "}")
                except ValueError:
                    continue
                cur_vals: list[int] = []
                dir_map: dict[str, list[int]] = {}
                for ln in sw.splitlines():
                    cm = re.match(r"\s*case MirDirection\.(\w+):", ln)
                    if cm:
                        continue
                    am = re.match(r"\s*([a-zA-Z_]\w*)\s*=\s*(-?\d+)\s*;", ln)
                    if am:
                        cur_vals.append(int(am.group(2)))
                    bm = re.match(r"\s*break;\s*$", ln)
                    if bm and cur_vals:
                        var = am.group(1) if am else None
                        dir_map.setdefault("_vals", []).extend(cur_vals)
                        cur_vals = []
                vals = sorted(set(dir_map.get("_vals", [])))
                if vals:
                    for e in seg_data["effects"]:
                        fe = e.get("frameExpr", "")
                        if re.fullmatch(r"[a-zA-Z_]\w*", fe or ""):
                            e["frame"] = vals[0]
                            e["directionFrames"] = vals
                            e.pop("frameExpr", None)
            stats["cases"][f"{seg_key}:{name}"] = len(events)
            entry.setdefault("notes", f"MapObject.cs:{first_line}({seg_key})")

    anims = parse_get_magic_animation()
    for name, entry in table.items():
        entry["castAnim"] = anims.get(name)

    # 声音语义分类：start 段→start；release 顶层→travel；arrival→end
    for name, entry in table.items():
        snd = {}
        for seg in ("start", "release"):
            for s in entry.get(seg, {}).get("sounds", []):
                key = "start" if seg == "start" else (
                    "end" if "arrival" in s["ctx"] or "frameAction" in s["ctx"] else "travel")
                snd.setdefault(key, [])
                if s["name"] not in snd[key]:
                    snd[key].append(s["name"])
        if snd:
            entry["sound"] = snd

    meta = {
        "source": {
            "MapObject.cs": str(MAPOBJ),
            "releaseSwitch": list(regions["release"]),
            "startSwitch": list(regions["start"]),
            "Functions.cs": str(FUNCTIONS),
        },
        "caseCount": {"release": sum(1 for k in stats["cases"] if k.startswith("release:")),
                      "start": sum(1 for k in stats["cases"] if k.startswith("start:"))},
        "effectCount": sum(len(e.get("release", {}).get("effects", [])) +
                           len(e.get("start", {}).get("effects", [])) for e in table.values()),
        "animCoverage": sum(1 for e in table.values() if e.get("castAnim")),
    }
    OUT.write_text(json.dumps({"_meta": meta, **table}, ensure_ascii=False, indent=1),
                   encoding="utf-8")
    print(f"OK {len(table)} magics -> {OUT}")
    print(f"  release cases: {meta['caseCount']['release']}, "
          f"start cases: {meta['caseCount']['start']}, "
          f"effects: {meta['effectCount']}, "
          f"castAnim known: {meta['animCoverage']}/{len(table)}")
    no_anim = [n for n, e in table.items() if not e.get("castAnim")]
    if no_anim:
        print(f"  WARN no castAnim: {no_anim}")


if __name__ == "__main__":
    main()
