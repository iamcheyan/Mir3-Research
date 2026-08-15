#!/usr/bin/env python3
"""regress_capture.py — mapviewer 行为回归采集器（E1 拆模块对照用）。

纯 HTTP 采集（刻意不 import mapviewer：同一脚本在拆分前/后对各自实例
爬行才有对照意义）。对运行中的 mapviewer 爬取：

  Tier-1（全量 627 图）: /api/cell ×3（中心+两角）+ /minimap
  Tier-2（确定性抽样 ≤12 图）: 瓦片 z0/z1/z2、fullmap(fit[+deep])、
                               /thumb、/strip（最小图）、奇数格 /api/cell
  静态面: / 与 /sim HTML、全部 JSON API（/api/progress 除外，含时钟）

每个请求记录 {status, len, sha256}；图片端点正文落盘 out/images/ 供
人工比对。两次采集结果用 regress_compare.py 逐条对照。

用法:
  python3 regress_capture.py --base http://127.0.0.1:18998 --out /tmp/e1-regress/base
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
import re
import time
import urllib.error
import urllib.request


def fetch(base, path, timeout=900):
    try:
        with urllib.request.urlopen(base + path, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        try:
            return e.code, e.read()
        except Exception:
            return e.code, b""
    except Exception as e:  # 连接层异常也要留痕（对照时暴露而非吞掉）
        return 0, repr(e).encode("utf-8")


def rec(status, body):
    return {"status": status, "len": len(body), "sha256": hashlib.sha256(body).hexdigest()}


def safe_name(path):
    return re.sub(r"[^A-Za-z0-9._-]+", "_", path)


def pick_tier2(maps):
    """确定性抽样: 首名/末名/中位 + 面积最大/最小 + 固定名单 + 首个 D 系。"""
    if not maps:
        return []
    names = [m["name"] for m in maps]
    chosen = [names[0], names[len(names) // 2], names[-1]]
    by_area = sorted(maps, key=lambda m: m["world_w"] * m["world_h"])
    chosen.append(by_area[0]["name"])
    chosen.append(by_area[-1]["name"])
    for fixed in ("0.map", "3.map", "11.map"):
        if fixed in names:
            chosen.append(fixed)
    d_first = next((n for n in names if n.upper().startswith("D")), None)
    if d_first:
        chosen.append(d_first)
    seen, out = set(), []
    for n in chosen:
        if n not in seen:
            seen.add(n)
            out.append(n)
    return out[:12]


def main():
    ap = argparse.ArgumentParser(description="mapviewer 回归采集")
    ap.add_argument("--base", default="http://127.0.0.1:18998")
    ap.add_argument("--out", required=True)
    ap.add_argument("--tier1-workers", type=int, default=6)
    ap.add_argument("--skip-tier1", action="store_true", help="只跑静态面+Tier-2")
    args = ap.parse_args()

    os.makedirs(os.path.join(args.out, "images"), exist_ok=True)
    entries = {}

    def record(path, status, body, save=False):
        entries[path] = rec(status, body)
        if save:
            with open(os.path.join(args.out, "images", safe_name(path)), "wb") as f:
                f.write(body)

    # ---- 静态面 ----
    for p in ("/", "/sim"):
        st, body = fetch(args.base, p)
        record(p, st, body)
    st, body = fetch(args.base, "/api/maps")
    record("/api/maps", st, body)
    maps = []
    if st == 200:
        try:
            maps = json.loads(body)
        except ValueError:
            pass
    print(f"[*] /api/maps: {len(maps)} maps")
    for p in ("/api/roots", "/api/graph", "/api/overview", "/api/npc_audit",
              "/api/quests", "/api/map_links_v2.json",
              "/api/connections?map=0.map", "/api/entities?map=0.map",
              "/api/quest?id=1"):
        st, body = fetch(args.base, p)
        record(p, st, body)

    by_name = {m["name"]: m for m in maps}

    # ---- Tier-1: 全量 /api/cell ×3 + /minimap ----
    if not args.skip_tier1:
        t0 = time.time()

        def tier1(m):
            w, h = m["w"], m["h"]
            paths = [
                f"/api/cell?map={m['name']}&x={w // 2}&y={h // 2}",
                f"/api/cell?map={m['name']}&x=0&y=0",
                f"/api/cell?map={m['name']}&x={w - 1}&y={h - 1}",
                f"/minimap?map={m['name']}",
            ]
            out = []
            for p in paths:
                st, body = fetch(args.base, p)
                out.append((p, st, body))
            return out

        with concurrent.futures.ThreadPoolExecutor(max_workers=args.tier1_workers) as ex:
            for res in ex.map(tier1, maps):
                for p, st, body in res:
                    record(p, st, body)
        print(f"[*] Tier-1 done: {len(maps)} maps in {time.time() - t0:.0f}s")

    # ---- Tier-2: 渲染像素对照 ----
    tier2 = pick_tier2(maps)
    smallest = min((by_name[n] for n in tier2), key=lambda m: m["w"] * m["h"])["name"] if tier2 else None
    print(f"[*] Tier-2 maps: {tier2}")
    for name in tier2:
        m = by_name[name]
        w, h, ww, wh = m["w"], m["h"], m["world_w"], m["world_h"]
        ladder = m.get("ladder") or [0]
        reqs = [
            f"/tile?map={name}&tx={ww // 1024}&ty={wh // 1024}&z=0",
            "/tile?map=%s&tx=0&ty=0&z=0" % name,
            f"/tile?map={name}&tx={ww // 2048}&ty={wh // 2048}&z=1",
            f"/tile?map={name}&tx={ww // 4096}&ty={wh // 4096}&z=2",
            f"/fullmap?map={name}&z={ladder[-1]}",
            f"/api/cell?map={name}&x={max(0, w // 2 - 1)}&y={max(0, h // 2 - 3)}",
            f"/thumb?map={name}",
            f"/minimap?map={name}",
        ]
        # deep 档只给 ≤1M 格的图（00.map 2M 格 deep 渲染代价过高且 fit 已覆盖同一代码路径）
        if ladder[0] != ladder[-1] and w * h <= 1_000_000:
            reqs.append(f"/fullmap?map={name}&z={ladder[0]}")
        if name == smallest:
            reqs.append(f"/strip?map={name}&z={ladder[-1]}")
        for p in reqs:
            t0 = time.time()
            st, body = fetch(args.base, p)
            record(p, st, body, save=True)
            print(f"    {time.time() - t0:6.1f}s {st} {p}")

    # ---- sprite 端点（NPC 库帧解码）----
    for p in ("/sprite?lib=NPC&frame=0", "/sprite?lib=NPC&frame=100",
              "/sprite?lib=tilesc.Zl&frame=10"):
        st, body = fetch(args.base, p)
        record(p, st, body, save=True)

    report = {
        "base": args.base,
        "captured_at": time.strftime("%F %T"),
        "map_count": len(maps),
        "tier2": tier2,
        "entries": entries,
    }
    with open(os.path.join(args.out, "report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"[*] {len(entries)} entries -> {args.out}/report.json")


if __name__ == "__main__":
    main()
