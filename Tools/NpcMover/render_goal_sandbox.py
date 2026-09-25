#!/usr/bin/env python3
"""Render offline original/current/hero NPC points over independent map masks."""
from __future__ import annotations
import argparse, json, struct
from pathlib import Path
from PIL import Image, ImageDraw

FOCUS = ["0", "01", "02", "2", "4", "5", "3", "74", "D202"]

def read_mask(path: Path):
    raw = path.read_bytes(); width, height = struct.unpack_from("<HH", raw, 22)
    base = 28 + (width // 2) * (height // 2) * 3
    mask = [[False] * height for _ in range(width)]
    for x in range(width):
        for y in range(height): mask[x][y] = (raw[base + (x * height + y) * 13] & 3) == 3
    return width, height, mask

def find_map(root: Path, stem: str) -> Path | None:
    for p in root.glob("*.map"):
        if p.stem.casefold() == stem.casefold(): return p
    return None

def panel(path: Path | None, points: list[tuple[int,int,str,str]], title: str):
    if path is None:
        im = Image.new("RGB", (520, 560), (35, 35, 38)); ImageDraw.Draw(im).text((12,12), title + "\nmap file missing", fill=(255,130,130)); return im
    w, h, mask = read_mask(path); px = max(1, max(w,h) // 120); outw, outh = (w + px - 1)//px, (h + px - 1)//px
    im = Image.new("RGB", (outw, outh + 28), (30,30,34)); d = ImageDraw.Draw(im)
    for x in range(outw):
        for y in range(outh):
            x0, x1 = x*px, min(w,(x+1)*px); y0, y1 = y*px, min(h,(y+1)*px); total=(x1-x0)*(y1-y0)
            walk=sum(mask[xx][yy] for xx in range(x0,x1) for yy in range(y0,y1)); v=180 if walk*2 >= total else 55; d.point((x,y), fill=(v,v,v))
    d.rectangle((0,0,outw-1,outh+27), outline=(120,120,120)); d.text((5, outh+6), title + f" {w}×{h}", fill=(240,240,240))
    for x,y,kind,label in points:
        if x is None or y is None: continue
        qx, qy = min(outw-1,max(0,x//px)), min(outh-1,max(0,y//px)); colour={"original":(255,170,40),"current":(70,160,255),"target":(50,240,120)}.get(kind,(255,255,255)); r=3 if kind=="target" else 2
        d.ellipse((qx-r,qy-r,qx+r,qy+r), fill=colour, outline=(0,0,0));
        if label: d.text((qx+4,qy-5), label, fill=colour)
    return im

def main():
    ap=argparse.ArgumentParser(); ap.add_argument("--manifest",type=Path,required=True); ap.add_argument("--target-map-dir",type=Path,required=True); ap.add_argument("--legacy-map-dir",type=Path,required=True); ap.add_argument("--out",type=Path,required=True); args=ap.parse_args(); args.out.mkdir(parents=True,exist_ok=True)
    rows=json.loads(args.manifest.read_text(encoding="utf-8"))["npcs"]; produced=[]
    for stem in FOCUS:
        legacy_points=[]; current_points=[]; target_points=[]
        for n in rows:
            if (n.get("original_map") or "").casefold()==stem.casefold() and n.get("original_xy"):
                p=n["original_xy"]; legacy_points.append((p["x"],p["y"],"original",str(n["current_npc_index"])))
            if (n.get("current_map") or "").casefold()==stem.casefold() and n.get("current_xy"):
                p=n["current_xy"]; current_points.append((p["x"],p["y"],"current",str(n["current_npc_index"])))
            if (n.get("hero_kill_map") or "").casefold()==stem.casefold() and n.get("hero_kill_xy"):
                p=n["hero_kill_xy"]; target_points.append((p["x"],p["y"],"target",str(n["current_npc_index"])))
        lp=find_map(args.legacy_map_dir,stem); tp=find_map(args.target_map_dir,stem); left=panel(lp,legacy_points,f"original {stem}"); right=panel(tp,current_points+target_points,f"hero/current+target {stem}")
        canvas=Image.new("RGB",(left.width+right.width,max(left.height,right.height)),(18,18,20)); canvas.paste(left,(0,0)); canvas.paste(right,(left.width,0)); path=args.out/f"sandbox-{stem}.png"; canvas.save(path)
        produced.append({"map":stem,"path":str(path),"original_npc_points":len(legacy_points),"current_npc_points":len(current_points),"target_points":len(target_points)})
    (args.out/"sandbox-index.json").write_text(json.dumps({"mode":"dry-run","focus":produced,"database_write":False},ensure_ascii=False,indent=2),encoding="utf-8"); print(json.dumps(produced,ensure_ascii=False,indent=2))

if __name__ == "__main__": main()
