#!/usr/bin/env python3
"""Render offline map overlays for NPC and monster alignment evidence."""
from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from PIL import Image, ImageDraw

FOCUS = ["0", "01", "02", "2", "4", "5", "74", "3", "D202", "D1105", "D203"]


def map_grid(path: Path):
    raw = path.read_bytes()
    w, h = struct.unpack_from("<HH", raw, 22)
    start = 28 + (w // 2) * (h // 2) * 3
    if start + w * h * 13 > len(raw):
        return None
    return w, h, raw, start


def find(root: Path, stem: str):
    for p in root.glob("*.map"):
        if p.stem.casefold() == stem.casefold():
            return p
    return None


def panel(path: Path | None, points: list[tuple[int, int, str, str]], title: str):
    parsed = map_grid(path) if path else None
    if parsed is None:
        image = Image.new("RGB", (520, 560), (35, 35, 38))
        ImageDraw.Draw(image).text((12, 12), title + "\nmap missing or malformed", fill=(255, 130, 130))
        return image
    w, h, raw, start = parsed
    scale = max(1, max(w, h) // 160)
    out_w, out_h = (w + scale - 1) // scale, (h + scale - 1) // scale
    image = Image.new("RGB", (out_w, out_h + 30), (30, 30, 34))
    draw = ImageDraw.Draw(image)
    for px in range(out_w):
        for py in range(out_h):
            x0, x1 = px * scale, min(w, (px + 1) * scale)
            y0, y1 = py * scale, min(h, (py + 1) * scale)
            total = (x1 - x0) * (y1 - y0)
            pass_cells = 0
            for x in range(x0, x1):
                for y in range(y0, y1):
                    if raw[start + (x * h + y) * 13] & 3 == 3:
                        pass_cells += 1
            value = 180 if pass_cells * 2 >= total else 55
            draw.point((px, py), fill=(value, value, value))
    draw.rectangle((0, 0, out_w - 1, out_h + 29), outline=(120, 120, 120))
    draw.text((5, out_h + 7), f"{title} {w}×{h}", fill=(240, 240, 240))
    colors = {"current": (70, 160, 255), "original": (255, 170, 40), "target": (50, 240, 120), "monster": (240, 60, 190)}
    for x, y, kind, label in points:
        qx, qy = min(out_w - 1, max(0, x // scale)), min(out_h - 1, max(0, y // scale))
        color = colors.get(kind, (255, 255, 255))
        radius = 3 if kind in {"target", "monster"} else 2
        draw.ellipse((qx - radius, qy - radius, qx + radius, qy + radius), fill=color, outline=(0, 0, 0))
        if label:
            draw.text((qx + 4, qy - 5), label, fill=color)
    return image


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", type=Path, required=True)
    ap.add_argument("--hero-map-dir", type=Path, required=True)
    ap.add_argument("--zircon-map-dir", type=Path, required=True)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    data = json.loads(args.manifest.read_text(encoding="utf-8"))
    produced = []
    for stem in FOCUS:
        hero_points, current_points, target_points, monster_points = [], [], [], []
        for row in data["npcs"]:
            if (row.get("original_map") or "").casefold() == stem.casefold() and row.get("original_xy"):
                p = row["original_xy"]
                hero_points.append((p["x"], p["y"], "original", f"N{row['current_npc_index']}"))
            if (row.get("old_map") or "").casefold() == stem.casefold() and row.get("old_xy"):
                p = row["old_xy"]
                current_points.append((p["x"], p["y"], "current", f"N{row['current_npc_index']}"))
            if (row.get("hero_kill_map") or "").casefold() == stem.casefold() and row.get("hero_kill_xy"):
                p = row["hero_kill_xy"]
                target_points.append((p["x"], p["y"], "target", f"N{row['current_npc_index']}"))
        for row in data["monster_respawns"]:
            old = row["old_respawn"]
            if (old.get("map") or "").casefold() == stem.casefold() and old.get("xy"):
                p = old["xy"]
                monster_points.append((p["x"], p["y"], "monster", f"M{old['index']}"))
        left = panel(find(args.hero_map_dir, stem), hero_points, f"hero-kill {stem}")
        right = panel(find(args.zircon_map_dir, stem), current_points + target_points + monster_points, f"Zircon current/target {stem}")
        canvas = Image.new("RGB", (left.width + right.width, max(left.height, right.height)), (18, 18, 20))
        canvas.paste(left, (0, 0))
        canvas.paste(right, (left.width, 0))
        output = args.out / f"sandbox-{stem}.png"
        canvas.save(output)
        produced.append({"map": stem, "path": str(output), "hero_npc_points": len(hero_points), "current_npc_points": len(current_points), "target_npc_points": len(target_points), "current_monster_respawns": len(monster_points), "database_write": False})
    (args.out / "sandbox-index.json").write_text(json.dumps({"mode": "offline-dry-run", "focus": produced, "database_write": False, "legend": {"orange": "hero-kill/original NPC", "blue": "current Zircon NPC", "green": "candidate target NPC", "magenta": "current Zircon monster respawn"}}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(produced, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
