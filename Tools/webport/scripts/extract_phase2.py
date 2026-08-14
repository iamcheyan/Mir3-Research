#!/usr/bin/env python3
"""Phase2 对象系统按需精灵提取 (比奇城实况):
- 怪物: 比奇 respawns 全部 (lib,shape), 帧段 shape*1000 + 0..460 (站/走/攻/受/死) + 640..660 (show/hide)
- NPC: 全部 unique image*100 + 0..15
- 玩家纸娃娃: M-Hum/M-Hair 块0 (0..2530), M-Weapon7 块5 (25000..27530, weapon 65)
- Interface 79/80 (血条)
"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "webres"))
import webres  # noqa: E402  (复用 extract_frame / 路径解析)

DATA = webres.WEB / "data"
plan: dict[str, set[int]] = {}

# ---- 怪物 (比奇) ----
resp = json.loads((DATA / "respawns.json").read_text())
mons = {m["id"]: m for m in json.loads((DATA / "monsters.json").read_text())}
for s in resp["0"]:
    m = mons.get(s["mid"])
    if not m or not m["lib"]:
        continue
    base = m["shape"] * 1000
    plan.setdefault(m["lib"], set()).update(range(base, base + 460))
    plan[m["lib"]].update(range(base + 640, base + 660))
# Guard 也在城内巡逻 (mid 1)
g = mons.get(1)
if g:
    plan.setdefault(g["lib"], set()).update(range(g["shape"] * 1000, g["shape"] * 1000 + 460))

# ---- NPC ----
npcs = json.loads((DATA / "npcs.json").read_text())
for img in {n["image"] for n in npcs}:
    base = img * 100
    if base + 16 <= 5600:
        plan.setdefault("NPC", set()).update(range(base, base + 16))

# ---- 玩家纸娃娃 (TestHero: armour 33→块0, hair 1→块0, weapon 65→M-Weapon7 块5) ----
plan.setdefault("M-Hum", set()).update(range(0, 2531))
plan.setdefault("M-Hair", set()).update(range(0, 2531))
plan.setdefault("M-Weapon7", set()).update(range(25000, 27531))

# ---- 血条贴图 ----
plan.setdefault("Interface", set()).update([79, 80])

total = sum(len(v) for v in plan.values())
print(f"计划: {len(plan)} 库 {total} 帧", flush=True)
wrote = skipped = missing = 0
for lib in sorted(plan):
    frames = sorted(plan[lib])
    out_dir = webres.WEB / "sprites" / lib
    for f in frames:
        got = webres.extract_frame(lib, f, out_dir, True, 90)
        if got > 0:
            wrote += 1
        elif got == 0:
            skipped += 1
        else:
            missing += 1
    print(f"  {lib}: {len(frames)} 帧 (累计 新={wrote} 已有={skipped} 无帧={missing})", flush=True)
print(f"完成: 新落盘 {wrote}, 已有 {skipped}, 库中无此帧 {missing}")
