#!/usr/bin/env python3
"""build_env_assets.py — E5 Light Lab P0: 天气素材提取 + 环境数据快照。

产物（全部入仓库，供 webclient /env 页面与文档引用）:
  1. Tools/webclient/static/assets/weather/*.webp
     ProgUse.Zl 帧 500(雪)/509-514(雨+水花)/540(闪电)/550(雾)
     —— MapWeatherLayer.cs 消费的同四类帧, zlsdk 解码原样转 WebP(无损)。
  2. docs/lightlab/env-snapshot.json
     627 图 {Index, FileName, Description, Light, Weather} + 24 个 Light 物品
     {ItemIndex, Name, Stat Amount} —— 实验室下拉框数据源 + 分布统计证据。

数据源: Tools/dbeditor/workspace/{MapInfo,ItemInfo,ItemInfoStat}.json (只读)。
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

MIR3 = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(MIR3 / "Tools" / "common"))

from zlsdk import ZlLibrary  # noqa: E402

ZIRCON_DATA = Path("/home/tetsuya/development/zircon/Debug/Client/Data")
WEATHER_FRAMES = [500, 509, 510, 511, 512, 513, 514, 540, 550]
FRAME_ZH = {500: "snow", 509: "rain", 510: "splash1", 511: "splash2",
            512: "splash3", 513: "splash4", 514: "splash5",
            540: "lightning", 550: "fog"}


def extract_weather_assets() -> list[dict]:
    lib = ZlLibrary(str(ZIRCON_DATA / "ProgUse.Zl"))
    out_dir = MIR3 / "Tools" / "webclient" / "static" / "assets" / "weather"
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for idx in WEATHER_FRAMES:
        img = lib.decode(idx)
        if img is None:
            raise SystemExit(f"ProgUse.Zl 帧 {idx} 解码失败")
        p = out_dir / f"{FRAME_ZH[idx]}.webp"
        img.save(p, "WEBP", lossless=True)
        hdr = lib.headers[idx]
        manifest[FRAME_ZH[idx]] = {"frame": idx, "w": hdr.width, "h": hdr.height,
                                   "offX": hdr.offset_x, "offY": hdr.offset_y,
                                   "bytes": p.stat().st_size}
        print(f"  {p.name:14s} frame={idx:3d} {hdr.width}x{hdr.height} "
              f"off=({hdr.offset_x},{hdr.offset_y}) {p.stat().st_size}B")
    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=1))
    return manifest


def build_snapshot() -> dict:
    ws = MIR3 / "Tools" / "dbeditor" / "workspace"
    maps = json.loads((ws / "MapInfo.json").read_text())["rows"]
    items = json.loads((ws / "ItemInfo.json").read_text())["rows"]
    stats = json.loads((ws / "ItemInfoStat.json").read_text())["rows"]

    maps_out = [{"Index": m["Index"], "FileName": m["FileName"],
                 "Description": m.get("Description", ""),
                 "Light": m.get("Light", "Default"),
                 "Weather": m.get("Weather", "None")} for m in maps]

    light_rows = [s for s in stats if s.get("Stat") == "Light"]
    by_item = {i["Index"]: i for i in items}
    torches_out = []
    for s in light_rows:
        it = by_item.get(s["Item"]["Index"])
        if not it:
            continue
        torches_out.append({
            "ItemIndex": it["Index"], "Name": it.get("ItemName", it["_Identity"]),
            "ItemType": it.get("ItemType", ""), "Light": s["Amount"],
        })
    torches_out.sort(key=lambda t: (-t["Light"], t["Name"]))

    from collections import Counter
    light_dist = Counter(m["Light"] for m in maps_out)
    weather_dist = Counter(m["Weather"] for m in maps_out)
    amount_dist = Counter(t["Light"] for t in torches_out)

    snap = {
        "_meta": {
            "generated": "2026-08-15",
            "source": "Tools/dbeditor/workspace/{MapInfo,ItemInfo,ItemInfoStat}.json",
            "mapCount": len(maps_out), "lightItemCount": len(torches_out),
            "lightDist": dict(light_dist), "weatherDist": dict(weather_dist),
            "lightAmountDist": {str(k): v for k, v in sorted(amount_dist.items())},
            "refs": {
                "ambientFor": "GodotClient/Scripts/MapLightLayer.cs AmbientFor",
                "weather": "GodotClient/Scripts/MapWeatherLayer.cs",
                "originals": "Client/Scenes/Views/MapControl.cs; Client/Models/Particles/Weather/",
            },
        },
        "maps": maps_out,
        "lightItems": torches_out,
    }
    out = MIR3 / "docs" / "lightlab" / "env-snapshot.json"
    out.write_text(json.dumps(snap, ensure_ascii=False, indent=1))
    print(f"  env-snapshot.json: {len(maps_out)} maps, {len(torches_out)} light items")
    print(f"  Light dist: {dict(light_dist)}")
    print(f"  Weather dist: {dict(weather_dist)}")
    print(f"  Light amount dist: { {str(k): v for k, v in sorted(amount_dist.items())} }")
    return snap


def main() -> None:
    print("[1/2] ProgUse.Zl 天气帧 -> WebP")
    extract_weather_assets()
    print("[2/2] env-snapshot.json")
    build_snapshot()
    print("OK")


if __name__ == "__main__":
    main()
