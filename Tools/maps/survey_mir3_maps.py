#!/usr/bin/env python3
"""survey_mir3_maps.py — per-map survey for all Mir3 EI maps (objective §9).

Reads every .map file in the original EI client (28-byte header + 3-byte/block
ground layer + 13/14-byte/cell object layer), and records per map:

  - filename / cn name (from catalog) / theme / W×H / md5 / legacy 13B flag
  - ground layer: resolved libraries (KR_ORDER id, cells, frame min/max,
    frame_oob, reserved 0xFF00+, lib frame count) PLUS the empty-ground
    breakdown the audit doesn't separate:
      * file==0xFF (unresolvable, v=237>69 → never drawn)
      * valid file but frame==0xFFFF (draw gate 3, 0x43b440)
      * valid file but frame==0xFF7F (non-0xFFFF out-of-range → not drawn)
  - mid/front object layers: resolved libs (cells, frame min/max, oob,
    reserved, lib_frames), unresolved-file cells (v-transform ok but no
    KR_ORDER entry / v>69 non-marker files)
  - anomaly classification against the 8-class taxonomy (MAP-SURVEY §7):
      1 map-file   2 library   3 frame-decode   4 offset
      5 coord      6 layer-order               7 version-diff   8 special
  - md5 duplicate cluster id (exact-duplicate maps)

Semantics are shared with audit_mir3_maps.py (v_lookup / kr_lib_id) and the
renderer (FramePool), so numbers match map-audit.json; this script ADDS the
empty-ground marker detail and the duplicate clustering.

Usage:
    python3 Tools/maps/survey_mir3_maps.py <maps_dir> --data <data_dir> \
        --catalog docs/research/mir3-map-reconstruction/catalog/map-catalog.json \
        [-o survey-round14.json]
"""

import argparse
import hashlib
import json
import os
import sys
from collections import Counter, defaultdict

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import mapviewer  # KR_ORDER, FramePool
from audit_mir3_maps import v_lookup, kr_lib_id, EMPTY_FRAME, NO_OBJECT_FILE

# Ground draw gates from Mir3.exe 0x43b440 (F275): r<=2, v<=0x45,
# frame!=0xFFFF, lib lookup non-empty.
GROUND_FILE_EMPTY = 0xFF  # file byte used as the "no ground" marker


def class_of(anomaly_key: str) -> int:
    """Map an audit anomaly key to the 8-class taxonomy (MAP-SURVEY §7)."""
    if anomaly_key.endswith("_frame_oob") or anomaly_key.endswith("_ground_frame_oob"):
        return 3  # frame-decode
    if anomaly_key == "size_mismatch":
        return 1  # map-file
    if anomaly_key.endswith("_unresolved_file"):
        return 2  # library
    if anomaly_key == "ground_not_drawn":
        return 8  # special (empty marker / black backing)
    return 8  # reserved/black-frame handling


def audit_map(path: str, pool: mapviewer.FramePool) -> dict:
    """Per-map survey record. Mirrors audit_mir3_maps.audit_map but adds the
    empty-ground marker breakdown and per-layer frame ranges."""
    with open(path, "rb") as f:
        data = np.frombuffer(f.read(), dtype=np.uint8)

    theme = int(np.frombuffer(data[20:22], dtype="<u2")[0])
    w = int(np.frombuffer(data[22:24], dtype="<u2")[0])
    h = int(np.frombuffer(data[24:26], dtype="<u2")[0])
    cell_off = 28 + (w // 2) * (h // 2) * 3
    rem = int(data.size) - cell_off
    cell_bytes = rem / (w * h) if w and h else 0
    md5 = hashlib.md5(data.tobytes()).hexdigest()

    if cell_bytes not in (13.0, 14.0):
        return {
            "name": os.path.basename(path), "theme": theme, "w": w, "h": h,
            "size": int(data.size), "md5": md5, "size_ok": False,
            "cell_bytes": cell_bytes, "size_mismatch": True,
            "anomalies": {"size_mismatch": 1}, "anomaly_total": 1,
        }
    cb = int(cell_bytes)
    legacy = cb == 13

    result = {
        "name": os.path.basename(path), "theme": theme, "w": w, "h": h,
        "size": int(data.size), "md5": md5, "size_ok": True,
        "cell_bytes": cb, "legacy_13b": legacy,
    }

    anom = Counter()

    # ---- ground layer ----
    g = data[28:cell_off].reshape((w // 2) * (h // 2), 3)
    g_file = g[:, 0].copy()
    g_frame = g[:, 1:3].copy().view("<u2").reshape(-1)
    gq, gr, gv = v_lookup(g_file)
    g_draw = (gr <= 2) & (gv <= 69)
    g_used = {}
    g_kr = kr_lib_id(gq, gr, gv, g_file)
    for lid in np.unique(g_kr[g_draw & (g_kr >= 0)]):
        m = g_draw & (g_kr == lid)
        frames = g_frame[m]
        lib = pool._get_lib(int(lid))
        cap = lib.count if lib is not None else 0
        reserved = (frames >= 0xFF00) & (frames <= 0xFFFE)
        oob = int(np.count_nonzero((frames != EMPTY_FRAME) & (frames >= cap) & ~reserved))
        if oob:
            anom[f"ground_lib{int(lid)}_frame_oob"] += oob
        g_used[str(int(lid))] = {
            "lib": mapviewer.KR_ORDER.get(int(lid)),
            "cells": int(np.count_nonzero(m)),
            "frame_min": int(frames.min()), "frame_max": int(frames.max()),
            "frame_oob": oob, "reserved_frames": int(np.count_nonzero(reserved)),
            "lib_frames": cap,
        }

    # empty-ground marker breakdown (class 8 special handling)
    empty = {
        "file_0xFF": int(np.count_nonzero(g_file == GROUND_FILE_EMPTY)),
        "valid_file_frame_FFFF": int(np.count_nonzero(
            (g_file != GROUND_FILE_EMPTY) & (g_frame == EMPTY_FRAME) & g_draw)),
        "valid_file_frame_FF7F": int(np.count_nonzero(
            (g_file != GROUND_FILE_EMPTY) & (g_frame == 0xFF7F) & g_draw)),
        "undrawn_total": int(np.count_nonzero(~g_draw)),
    }
    if empty["undrawn_total"]:
        anom["ground_not_drawn"] = empty["undrawn_total"]
    result["ground"] = {"libs": g_used, "empty": empty}

    # ---- object layers ----
    cells = data[cell_off:cell_off + w * h * cb].reshape(w, h, cb)

    def object_check(file_arr, frame_arr, label):
        q, r, v = v_lookup(file_arr)
        lib_id = kr_lib_id(q, r, v, file_arr)
        skip = (frame_arr == EMPTY_FRAME) | (file_arr == NO_OBJECT_FILE) | (r <= 2) | (v > 69) | (lib_id < 0)
        draw = ~skip
        libs = {}
        for lid in np.unique(lib_id[draw]):
            m = draw & (lib_id == lid)
            frames = frame_arr[m]
            lib = pool._get_lib(int(lid))
            cap = lib.count if lib is not None else 0
            reserved = (frames >= 0xFF00) & (frames <= 0xFFFE)
            oob = int(np.count_nonzero((frames >= cap) & ~reserved))
            if oob:
                anom[f"{label}_lib{int(lid)}_frame_oob"] += oob
            libs[str(int(lid))] = {
                "lib": mapviewer.KR_ORDER.get(int(lid)),
                "cells": int(np.count_nonzero(m)),
                "frame_min": int(frames.min()), "frame_max": int(frames.max()),
                "frame_oob": oob, "reserved_frames": int(np.count_nonzero(reserved)),
                "lib_frames": cap,
            }
        unresolved = int(np.count_nonzero((lib_id < 0) & ~skip))
        if unresolved:
            anom[f"{label}_unresolved_file"] += unresolved
        return libs

    mid_file = cells[:, :, 4].copy()
    mid_frame = cells[:, :, 5:7].copy().view("<u2").reshape(w, h)
    front_file = cells[:, :, 3].copy()
    front_frame = cells[:, :, 7:9].copy().view("<u2").reshape(w, h)
    result["mid"] = object_check(mid_file, mid_frame, "mid")
    result["front"] = object_check(front_file, front_frame, "front")

    result["anomalies"] = {k: int(v) for k, v in sorted(anom.items())}
    result["anomaly_total"] = int(sum(anom.values()))
    result["anomaly_classes"] = sorted({class_of(k) for k in result["anomalies"]})
    return result


def main():
    ap = argparse.ArgumentParser(description="Per-map survey of Mir3 EI maps")
    ap.add_argument("maps_dir")
    ap.add_argument("--data", required=True, help="EI Data dir")
    ap.add_argument("--catalog", required=True, help="map-catalog.json path (cn names)")
    ap.add_argument("-o", "--out", default="survey-round14.json")
    args = ap.parse_args()

    catalog = json.load(open(args.catalog, encoding="utf-8"))
    cn = {m["name"]: m.get("cn") for m in catalog["maps"]}
    display = {m["name"]: m.get("display") for m in catalog["maps"]}

    pool = mapviewer.FramePool(args.data)
    names = sorted(f for f in os.listdir(args.maps_dir) if f.lower().endswith(".map"))

    # md5 duplicate clustering
    md5_to_names = defaultdict(list)
    for n in names:
        with open(os.path.join(args.maps_dir, n), "rb") as f:
            md5_to_names[hashlib.md5(f.read()).hexdigest()].append(n)
    cluster = {}
    for i, (h, group) in enumerate(sorted(md5_to_names.items(), key=lambda kv: -len(kv[1]))):
        for n in group:
            cluster[n] = i
    n_clusters = len(md5_to_names)

    results = []
    for name in names:
        rec = audit_map(os.path.join(args.maps_dir, name), pool)
        rec["cn"] = cn.get(name)
        rec["display"] = display.get(name)
        rec["dup_cluster"] = cluster[name]
        results.append(rec)

    summary = {
        "maps_dir": args.maps_dir, "data_dir": args.data,
        "map_count": len(results),
        "md5_unique_count": n_clusters,
        "md5_duplicate_clusters": sum(1 for v in md5_to_names.values() if len(v) > 1),
        "legacy_13b_count": sum(1 for r in results if r.get("legacy_13b")),
        "size_mismatch_count": sum(1 for r in results if r.get("size_mismatch")),
        "anomaly_maps": sum(1 for r in results if r.get("anomaly_total")),
        "anomaly_total": sum(r.get("anomaly_total", 0) for r in results),
        "anomaly_class_totals": {},
    }
    for r in results:
        for c in r.get("anomaly_classes", []):
            summary["anomaly_class_totals"][c] = summary["anomaly_class_totals"].get(c, 0) + 1

    out = {"summary": summary, "maps": results}
    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(f"wrote {args.out}: {len(results)} maps, {summary['anomaly_maps']} with anomalies, "
          f"{summary['anomaly_total']} anomaly cells, {summary['md5_duplicate_clusters']} md5 dup clusters")


if __name__ == "__main__":
    main()
