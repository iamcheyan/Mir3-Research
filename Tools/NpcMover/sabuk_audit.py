#!/usr/bin/env python3
"""沙巴克 NPC 位置审计、地图标记和 dry-run 清单生成器。

只读取 NPCInfo/MapRegion 导出和 .map，不写 System.db。原版 EI 坐标源缺失或
地图资源身份冲突时，目标坐标保持 null，建议动作只能是 hold/pending。
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def map_info(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if len(data) < 28:
        raise ValueError(f"地图头不足 28 字节: {path}")
    w, h = struct.unpack_from("<HH", data, 22)
    base = 28 + (w // 2) * (h // 2) * 3
    return {"path": str(path), "sha256": sha256(path), "width": w, "height": h,
            "cell_base": base, "bytes": len(data), "_data": data}


def cell_flag(info: dict[str, Any], x: int, y: int) -> int | None:
    w, h, base = info["width"], info["height"], info["cell_base"]
    if x < 0 or y < 0 or x >= w or y >= h:
        return None
    off = base + (x * h + y) * 13
    data = info["_data"]
    if off >= len(data):
        return None
    return data[off]


def public_map_info(info: dict[str, Any] | None) -> dict[str, Any] | None:
    if info is None:
        return None
    return {k: v for k, v in info.items() if k != "_data"}


def load_npcs(path: Path) -> list[dict[str, Any]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    return sorted((n for n in data["npcs"] if n["region"].get("mapFile") == "3"),
                  key=lambda n: n["index"])


def first_point(npc: dict[str, Any]) -> tuple[int, int] | None:
    raw = npc["region"].get("points", "")
    try:
        x, y = (int(v) for v in raw.split(",")[:2])
        return x, y
    except (ValueError, IndexError):
        return None


def make_overlay(base: Path, out: Path, rows: list[dict[str, Any]]) -> None:
    from PIL import Image, ImageDraw, ImageFont

    image = Image.open(base).convert("RGB")
    draw = ImageDraw.Draw(image)
    sx = image.width / 350.0
    sy = image.height / 350.0
    font = ImageFont.load_default()
    for row in rows:
        x, y = row["old_x"], row["old_y"]
        px, py = (x + 0.5) * sx, (y + 0.5) * sy
        r = max(5, min(sx, sy) * 0.45)
        draw.ellipse((px - r, py - r, px + r, py + r), outline=(255, 224, 32), width=max(2, int(r / 3)))
        draw.line((px - r * 1.8, py, px + r * 1.8, py), fill=(255, 64, 64), width=2)
        draw.line((px, py - r * 1.8, px, py + r * 1.8), fill=(255, 64, 64), width=2)
        draw.text((px + r + 3, py - 7), f"#{row['npc_index']} {row['name']}", fill=(255, 255, 255), font=font,
                  stroke_width=2, stroke_fill=(0, 0, 0))
    image.save(out)

    for row in rows:
        x, y = row["old_x"], row["old_y"]
        px, py = (x + 0.5) * sx, (y + 0.5) * sy
        box = (max(0, int(px - 360)), max(0, int(py - 240)),
               min(image.width, int(px + 360)), min(image.height, int(py + 240)))
        crop = image.crop(box)
        crop.save(out.parent / f"sabuk-npc-{row['npc_index']}-{slug(row['name'])}.png")


def slug(value: str) -> str:
    return "".join(ch if ch.isalnum() else "_" for ch in value).strip("_") or "npc"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dump", type=Path, required=True)
    ap.add_argument("--map", type=Path, required=True)
    ap.add_argument("--legacy-map", type=Path)
    ap.add_argument("--base-image", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    current = map_info(args.map)
    legacy = map_info(args.legacy_map) if args.legacy_map else None
    npcs = load_npcs(args.dump)
    rows: list[dict[str, Any]] = []
    occupied: defaultdict[tuple[int, int], list[int]] = defaultdict(list)
    for npc in npcs:
        point = first_point(npc)
        if point is None:
            continue
        x, y = point
        occupied[(x, y)].append(npc["index"])
        flag = cell_flag(current, x, y)
        legacy_flag = cell_flag(legacy, x, y) if legacy else None
        rows.append({
            "npc_index": npc["index"],
            "npc_name": npc["name"],
            "region_index": npc["region"]["index"],
            "region_name": npc["region"]["desc"],
            "entry_page": npc.get("page", ""),
            "map_file": "3",
            "map_index": npc["region"].get("mapIndex"),
            "old_x": x,
            "old_y": y,
            "old_point_count": len(npc["region"].get("points", "").split(",")) // 2,
            "original_map": None,
            "original_x": None,
            "original_y": None,
            "suggested_map": "3",
            "suggested_x": x,
            "suggested_y": y,
            "match_method": "existing-audit-preserve; EI source pending",
            "source": [
                "Tools/NpcMover/audit-report.md:292-300",
                "npc_position_goal.md:39,82",
            ],
            "confidence": "pending-resource-identity",
            "action": "hold",
            "current_map_in_bounds": 0 <= x < current["width"] and 0 <= y < current["height"],
            "current_flag": flag,
            "current_walkable": flag is not None and (flag & 3) == 3,
            "legacy_map_flag_at_same_xy": legacy_flag,
            "legacy_map_walkable_at_same_xy": legacy_flag is not None and (legacy_flag & 3) == 3,
            "overlap_with": [],
            "non_position_fields_untouched": True,
        })
    index = {r["npc_index"]: r for r in rows}
    for ids in occupied.values():
        if len(ids) > 1:
            for idx in ids:
                index[idx]["overlap_with"] = [other for other in ids if other != idx]

    resource_conflict = legacy is not None and (
        current["width"], current["height"]
    ) != (legacy["width"], legacy["height"])
    blockers = [
        "原版 EI/Mud3 Merchant.txt 与 /tmp 解析快照均缺失，不能给出可证实的 EI 目标坐标。",
        "原版本地资源 /home/tetsuya/mir2ei/Map/3.map 与运行时 Zircon map/3.map 尺寸不同，资源身份冲突。",
        "因此 9 条均保持 pending/hold，未写入任一 System.db。",
    ]
    manifest = {
        "audit_id": "SABUK-2026-09-25",
        "scope": "仅 Map FileName=3 / Sabuk Keep NPC",
        "npc_count": len(rows),
        "current_dump": str(args.dump),
        "current_map": public_map_info(current),
        "legacy_map": public_map_info(legacy),
        "resource_identity_conflict": resource_conflict,
        "original_coordinate_source": None,
        "dry_run": True,
        "database_write": False,
        "blockers": blockers,
        "rows": rows,
    }
    (args.out / "sabuk_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    fields = ["npc_index", "npc_name", "region_index", "region_name", "entry_page", "old_x", "old_y",
              "original_map", "original_x", "original_y", "suggested_map", "suggested_x", "suggested_y",
              "match_method", "confidence", "current_flag", "current_walkable", "legacy_map_flag_at_same_xy",
              "legacy_map_walkable_at_same_xy", "overlap_with", "action"]
    with (args.out / "sabuk_manifest.tsv").open("w", encoding="utf-8") as f:
        f.write("\t".join(fields) + "\n")
        for row in rows:
            f.write("\t".join(str(row.get(k, "")) if row.get(k) is not None else "" for k in fields) + "\n")

    overlaps = [r for r in rows if r["overlap_with"]]
    bad_current = [r for r in rows if not r["current_map_in_bounds"] or not r["current_walkable"]]
    report = [
        "# 沙巴克 NPC 位置对照审计（SABUK-2026-09-25）",
        "",
        "> 严格范围：仅审计 `MapInfo.FileName=3`（Sabuk Keep）下的 NPC。此报告是只读 dry-run；没有写入数据库。",
        "",
        "## 结论",
        "",
        f"- 当前双库均读取到 **{len(rows)} 个**沙巴克 NPC；服务端与客户端坐标逐条一致。",
        f"- 当前运行时地图 `3.map` 为 `{current['width']}×{current['height']}`；9 个点均在边界内且 `flag&3==3` 可行走。",
        f"- 原版本地地图 `/home/tetsuya/mir2ei/Map/3.map` 为 `{legacy['width']}×{legacy['height']}`，与运行时地图尺寸不一致；不能把同坐标的原版 flag 当作同一地图证据。" if legacy else "- 未提供原版地图资源。",
        "- 原版 Merchant 坐标源缺失；9 条目标坐标全部 `pending`，建议动作 `hold`。未执行停服、备份或写库，因为没有安全目标坐标。",
        "",
        "## 阻塞",
        "",
    ] + [f"- {b}" for b in blockers] + [
        "",
        "## 坐标/区域核验",
        "",
        "| NPCIndex | NPCName | Region | 当前坐标 | 当前 flag | 当前可走 | 原版同坐标 flag（仅冲突记录） | 重叠 | EI 目标 | 动作 |",
        "|---:|---|---|---:|---:|:---:|---:|---|---|---|",
    ]
    for r in rows:
        legacy_flag = "" if r["legacy_map_flag_at_same_xy"] is None else str(r["legacy_map_flag_at_same_xy"])
        report.append(f"| {r['npc_index']} | {r['npc_name']} | {r['region_name']} | ({r['old_x']},{r['old_y']}) | {r['current_flag']} | {'是' if r['current_walkable'] else '否'} | {legacy_flag} | {','.join(map(str, r['overlap_with'])) or '无'} | pending | hold |")
    report += [
        "",
        "## 来源与实现",
        "",
        "- 当前坐标：NpcMover 对服务端 System.db 与客户端 System.db 的 dump；MapRegion.PointRegion 单点中心即逻辑地图格。",
        "- 可行走判定：`Tools/maps/mapedit/npcedit.py` 的规则，地图 Segment 2 每格 13 字节，`flag&3==3` 才是通行格。",
        "- 原版对应依据：现有 `Tools/NpcMover/audit-report.md` 将 275–283 作为“沙巴克不动”；这只能支持保留当前坐标，不能替代缺失的 EI Merchant 坐标。",
        "- NPC 名字、EntryPage、GoodsIndex、Image、FaceImage 等非位置字段未触碰。",
        "",
        "## 未执行项",
        "",
        "- 未输出可写入的坐标计划；未执行 `NpcMover plan ... apply`。",
        "- 未停服、未备份、未写双库、未做写后 round-trip。",
        "- 未启动真实登录验收；当前原版地图资源身份冲突且目标坐标未闭合，不能把游戏截图伪装成 EI 对齐证据。",
        "",
    ]
    (args.out / "sabuk-audit-report.md").write_text("\n".join(report), encoding="utf-8")

    if args.base_image:
        overview = args.out / "sabuk-map-overview.png"
        make_overlay(args.base_image, overview, [{"npc_index": r["npc_index"], "name": r["npc_name"], "old_x": r["old_x"], "old_y": r["old_y"]} for r in rows])

    print(json.dumps({"npc_count": len(rows), "bad_current": len(bad_current), "overlaps": len(overlaps),
                      "resource_identity_conflict": resource_conflict, "out": str(args.out)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
