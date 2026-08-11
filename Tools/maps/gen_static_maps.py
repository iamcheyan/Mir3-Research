#!/usr/bin/env python3
"""预生成所有地图为静态 JPG，供 static_out/index.html 直接浏览。

用法：
  python3 Tools/maps/gen_static_maps.py            # 全量
  python3 Tools/maps/gen_static_maps.py 0.map 3.map # 指定
  python3 Tools/maps/gen_static_maps.py --list /path/to/extra.txt
"""
from __future__ import annotations
import argparse, json, os, sys, time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import mapviewer
from mapnames import resolve as map_cn
DEFAULT_ROOT = Path(mapviewer.DEFAULT_CLIENT_ROOT)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("maps", nargs="*", help="指定地图名（默认全量）")
    ap.add_argument("--client-root", type=Path, default=DEFAULT_ROOT)
    ap.add_argument("--out", type=Path, default=HERE / "static_out" / "out")
    ap.add_argument("--workers", type=int, default=1, help="并行进程数")
    args = ap.parse_args()

    maps_dir = args.client_root / "Map"
    data_dir = args.client_root / "Data" / "Map Data"
    out_dir = args.out
    out_dir.mkdir(parents=True, exist_ok=True)

    cache = mapviewer.MapCache(str(maps_dir))
    pool = mapviewer.FramePool(str(data_dir))

    if args.maps:
        names = [m if m.endswith(".map") else m + ".map" for m in args.maps]
    else:
        names = sorted(os.path.basename(p) for p in maps_dir.glob("*.map"))


    t0 = time.time()
    index = []
    ok = 0; fail = 0
    for i, name in enumerate(names):
        stem = name[:-4]
        out_path = out_dir / f"{stem}.jpg"
        try:
            w, h, _ = cache.get(name)
            ladder = mapviewer.map_ladder(w, h, mapviewer.LAYOUT_RECT)
            zoom = ladder[-1]  # 最大缩放（最小分辨率，文件最小）
            payload = mapviewer.render_full_map(cache, pool, name, zoom,
                                                fmt="JPEG", layout=mapviewer.LAYOUT_RECT)
            out_path.write_bytes(payload)
            cn = ""
            try: cn = map_cn(stem) or ""
            except Exception: pass
            index.append({"name": name, "w": w, "h": h, "cn": cn})
            ok += 1
            if (i + 1) % 10 == 0 or i == len(names) - 1:
                print(f"  [{i+1}/{len(names)}] {name} {w}x{h} -> {out_path.name} ({len(payload)//1024}KB)  {ok}ok/{fail}fail  {time.time()-t0:.0f}s")
        except Exception as e:
            fail += 1
            print(f"  [{i+1}/{len(names)}] {name} FAIL: {e}")

    (HERE / "static_out" / "index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1))
    print(f"[*] 完成: {ok} 成功 / {fail} 失败 / {len(names)} 总  耗时 {time.time()-t0:.0f}s")
    print(f"[*] 索引: static_out/index.json ({len(index)} 条)")
    print(f"[*] 浏览器打开: file://{HERE/'static_out'/'index.html'}")

if __name__ == "__main__":
    main()