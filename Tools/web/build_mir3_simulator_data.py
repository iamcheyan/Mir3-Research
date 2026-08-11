#!/usr/bin/env python3
"""Build the unified data model consumed by the Mir3 EI 800x600 client
simulator (Tools/mir3_client_simulator/).

All coordinates come from the evidence catalog (docs/research/ei-ui-layout/).
Nothing here invents primary facts: window origins that the binary has not
exposed are emitted as `candidate` (centered within the 800x600 viewport) or
`pending`, and every control carries its evidence_level. The HTML simulator
renders candidate geometry with the candidate marker so it can never be
mistaken for original-binary fact.

Outputs (all under Tools/mir3_client_simulator/data/):
  windows.json        window containers: id, screen rect, frame, visibility, evidence
  controls.json       every interactive/display control: id, rect, frame pair,
                      state list, zIndex, hitTest, evidence, window_id
  resources.json      WIL library registry with frame counts (from catalog)
  entities.json       scene entities: player, monsters, NPCs, drops
  equipment_slots.json  character panel equipment slots
  skills.json         skill grid entries
  maps.json           map background / minimap frames (derived bindings)
  map_bindings.json   map stem -> library/frame crossref rows (server MiniMap.txt)
  hud.json            HUD bars + target info + chat region + minimap widget
"""

from __future__ import annotations

import json
from pathlib import Path

EVIDENCE = Path("docs/research/ei-ui-layout")
OUT = Path("Tools/mir3_client_simulator/data")

VIEW_W, VIEW_H = 800, 600
HUD_ORIGIN = (0, 465)  # GameInter F50 800x136; top = 601 - 136


def load(name: str) -> dict:
    return json.loads((EVIDENCE / name).read_text(encoding="utf-8"))


def rel_to_abs(pos: dict, base: tuple[int, int]) -> tuple[int, int]:
    x, y = pos.get("x", {}), pos.get("y", {})
    ox = x.get("offset", 0) if isinstance(x, dict) else 0
    oy = y.get("offset", 0) if isinstance(y, dict) else 0
    if isinstance(x, dict) and x.get("base") in ("hud.left", "hud.right"):
        bx = base[0] if x["base"] == "hud.left" else 0
    else:
        bx = base[0]
    if isinstance(y, dict) and y.get("base") in ("hud.top", "hud.bottom"):
        by = base[1] if y["base"] == "hud.top" else 0
    else:
        by = base[1]
    return bx + ox, by + oy


def main() -> None:
    layout = load("layout.json")
    OUT.mkdir(parents=True, exist_ok=True)

    records = layout["records"]
    hud_records = [r for r in records if r["kind"] == "button"]
    window_records = [r for r in records if r["kind"] == "window"]
    other = [r for r in records if r["kind"] not in ("button", "window")]

    # ---------------------------------------------------------------- windows
    windows: list[dict] = []
    init_evidence = layout.get("window_initialization_evidence", {}).get("records", [])
    init_by_id = {r.get("layout_id"): r for r in init_evidence}
    confirmed_origins = {
        "window.guild-candidate": (102, 22),
        "window.group": (272, 123),
        "window.chat-pop": (114, 76),
        "window.option": (276, 113),
        "window.notice-prompt-candidate": (107, 110),
    }
    for rec in window_records:
        wid = rec["id"]
        res = rec.get("resource", {})
        size = rec.get("size", {})
        w, h = size.get("width", 0), size.get("height", 0)
        pos = rec.get("position", {})
        origin = confirmed_origins.get(wid)
        evidence = "primary-static"
        if origin is None:
            px, py = pos.get("x"), pos.get("y")
            if isinstance(px, dict) and isinstance(px.get("offset"), (int, float)) \
               and isinstance(py, dict) and isinstance(py.get("offset"), (int, float)):
                origin = (px["offset"], py["offset"])
                evidence = "primary-static"
            else:
                origin = ((VIEW_W - w) // 2, (VIEW_H - h) // 2)
                evidence = "candidate"
        windows.append({
            "id": wid,
            "title": wid.replace("window.", "").replace("-candidate", ""),
            "rect": [origin[0], origin[1], w, h],
            "frame": res.get("frame") if isinstance(res.get("frame"), int) else res.get("frames", {}).get("normal"),
            "resource_library": res.get("file"),
            "evidence_level": evidence,
            "init_va": init_by_id.get(wid, {}).get("va"),
            "visibility_va": init_by_id.get(wid, {}).get("default_visibility", ""),
        })

    # -------------------------------------------------------------- controls
    controls: list[dict] = []
    specialized = layout.get("specialized_control_rects", [])
    for i, c in enumerate(specialized):
        rel = c["relative_rect"]
        wid = c["window_id"]
        base = next((w for w in windows if w["id"] == wid), None)
        bx, by = (base["rect"][0], base["rect"][1]) if base else (0, 0)
        frame_pair = c.get("frame_pair") or [None, None]
        controls.append({
            "id": c.get("id", f"specialized-{i}"),
            "window_id": wid,
            "rect": [bx + rel[0], by + rel[1], rel[2], rel[3]],
            "relative_rect": rel,
            "frame_pair": frame_pair,
            "resource_library": c.get("resource_library", "GameInter.wil"),
            "state": ["normal", "hover", "pressed"],
            "zIndex": 40,
            "hitTest": True,
            "evidence_level": c.get("evidence_level", "candidate"),
            "source": c.get("source", ""),
            "role": c.get("role", ""),
            "call_va": c.get("call_va"),
            "paint_va": c.get("paint_va"),
        })
        if c.get("chat_command") is not None:
            controls[-1]["chat_command"] = c["chat_command"]
            controls[-1]["chat_help"] = c.get("chat_help", "")

    # HUD buttons as controls
    for rec in hud_records:
        frames = rec["resource"]["frames"]
        size = rec["size"]
        x, y = rel_to_abs(rec["position"], HUD_ORIGIN)
        w, h = size["width"], size["height"]
        controls.append({
            "id": rec["id"],
            "window_id": "hud",
            "rect": [x, y, w, h],
            "relative_rect": [x - HUD_ORIGIN[0], y - HUD_ORIGIN[1], w, h],
            "frame_pair": [frames["normal"], frames.get("state")],
            "resource_library": rec["resource"]["file"],
            "state": ["normal", "hover", "pressed"],
            "zIndex": 60,
            "hitTest": True,
            "evidence_level": rec["evidence"]["level"],
            "source": ";".join(rec["evidence"].get("addresses", [])),
        })

    # -------------------------------------------------------------- resources
    resource_family = load("resource-family-catalog.json").get("records", [])
    resources: list[dict] = []
    for r in resource_family:
        p = r.get("path", "")
        lib = r.get("library", {})
        resources.append({
            "path": p,
            "library": p.rsplit("/", 1)[-1],
            "frame_count": lib.get("frame_count"),
            "nonblank_frame_count": lib.get("nonblank_frame_count"),
            "category": r.get("category"),
        })

    # -------------------------------------------------------------- entities
    # Scene entity definitions are data-driven from Tools/mir3_client_simulator/
    # data/entities.json (evidence-derived: type byte -> element -> WIL path slot
    # idx = 139-element, per scene-entity-render-evidence.json Finding 269; race ->
    # Mon-(race/10+1).wil per server-data-crossref.json Finding 273 + Zircon
    # MonsterImage enum). Fall back to the legacy demo list only if absent.
    entities_path = OUT / "entities.json"
    if entities_path.exists():
        entities: list[dict] = json.loads(entities_path.read_text(encoding="utf-8"))
    else:
        entities: list[dict] = [
            {"id": "player", "name": "玩家", "kind": "player",
             "x": 320, "y": 300, "library": "M-Hum.wil", "frame": 0,
             "evidence_level": "candidate",
             "note": "player sprite demo; real M-Hum.wil frame"},
            {"id": "npc.guild", "name": "行会管理员", "kind": "npc",
             "x": 380, "y": 340, "library": "NPC.wil", "frame": 0,
             "evidence_level": "candidate",
             "note": "NPC dialogue opens on click"},
            {"id": "npc.store", "name": "商店老板", "kind": "npc",
             "x": 440, "y": 360, "library": "NPC.wil", "frame": 1,
             "evidence_level": "candidate",
             "note": "store window opens on click"},
            {"id": "mon.1", "name": "稻草人", "kind": "monster",
             "x": 260, "y": 320, "library": "DMon-1.wil", "frame": 0,
             "evidence_level": "candidate",
             "note": "targetable monster"},
            {"id": "mon.2", "name": "鸡", "kind": "monster",
             "x": 480, "y": 280, "library": "DMon-1.wil", "frame": 2,
             "evidence_level": "candidate",
             "note": "targetable monster"},
            {"id": "drop.1", "name": "金创药", "kind": "drop",
             "x": 300, "y": 350, "library": "Ground.wil", "frame": 0,
             "evidence_level": "candidate",
             "note": "ground drop item"},
        ]

    # -------------------------------------------------------- equipment slots
    # 8x38x38 evidence rects (window-relative) from status-window-render-evidence.json /
    # equipment-slots-evidence.json: SetRect chain 0x44B1BC-0x44B2C6, hit test 0x44B720.
    # Icon frames are item-shape driven (WORD[graphics+0x28]) -> placeholder frames stay
    # candidate; geometry is primary-static-constructor-order.
    equipment_slots: list[dict] = [
        {"id": "slot.helmet", "name": "头盔", "x": 177, "y": 70, "w": 38, "h": 38,
         "library": "Equip.wil", "frame": 0, "evidence_level": "primary-static",
         "note": "loop0 this+0x1F0 (177,70)-(215,108); abs (455,206); icon frame candidate"},
        {"id": "slot.torch", "name": "火把", "x": 27, "y": 264, "w": 38, "h": 38,
         "library": "Equip.wil", "frame": 1, "evidence_level": "primary-static",
         "note": "loop1 this+0x1E0 (27,264)-(65,302); abs (305,400); icon frame candidate"},
        {"id": "slot.poison", "name": "毒药", "x": 64, "y": 264, "w": 38, "h": 38,
         "library": "Equip.wil", "frame": 2, "evidence_level": "primary-static",
         "note": "loop2 this+0x250 (64,264)-(102,302); abs (342,400); icon frame candidate"},
        {"id": "slot.braceletL", "name": "左手镯", "x": 27, "y": 186, "w": 38, "h": 38,
         "library": "Equip.wil", "frame": 3, "evidence_level": "primary-static",
         "note": "loop3 this+0x210 (27,186)-(65,224); abs (305,322); icon frame candidate"},
        {"id": "slot.braceletR", "name": "右手镯", "x": 175, "y": 186, "w": 38, "h": 38,
         "library": "Equip.wil", "frame": 4, "evidence_level": "primary-static",
         "note": "loop4 this+0x220 (175,186)-(213,224); abs (453,322); icon frame candidate"},
        {"id": "slot.ringL", "name": "左戒指", "x": 27, "y": 227, "w": 38, "h": 38,
         "library": "Equip.wil", "frame": 5, "evidence_level": "primary-static",
         "note": "loop5 this+0x230 (27,227)-(65,265); abs (305,363); icon frame candidate"},
        {"id": "slot.ringR", "name": "右戒指", "x": 175, "y": 227, "w": 38, "h": 38,
         "library": "Equip.wil", "frame": 6, "evidence_level": "primary-static",
         "note": "loop6 this+0x240 (175,227)-(213,265); abs (453,363); icon frame candidate"},
        {"id": "slot.shoes", "name": "鞋子", "x": 103, "y": 264, "w": 38, "h": 38,
         "library": "Equip.wil", "frame": 7, "evidence_level": "primary-static",
         "note": "loop10 this+0x260 (103,264)-(141,302); abs (381,400); icon frame candidate"},
    ]

    # ---------------------------------------------------------------- skills
    skills: list[dict] = []
    for i in range(12):
        frame = 410 + i
        skills.append({
            "id": f"skill.{i}",
            "name": f"技能 {i + 1}",
            "x": 30 + (i % 4) * 40, "y": 60 + (i // 4) * 40,
            "w": 36, "h": 36,
            "library": "GameInter.wil", "frame": frame,
            "evidence_level": "candidate",
            "note": f"skill grid slot; F{frame} from skill-window evidence",
        })

    # ------------------------------------------------------------------ maps
    # map.bg / map.minimap bind to the demo scene map (0.map = 比奇县). The
    # library+frame follow the client's map-select rule (0x0043D780: map_id >=
    # 1000 -> FMMap.wil frame map_id-1000, else MMap.wil frame map_id) with the
    # original server MiniMap.txt giving 0.map -> 1001 -> FMMap.wil F0. The
    # select rule is primary-static; the row binding is secondary-server.
    maps: list[dict] = [
        {"id": "map.bg", "name": "地图背景", "library": "FMMap.wil", "frame": 0,
         "evidence_level": "derived",
         "note": "0.map 比奇县 -> server 1001 -> FMMap.wil F0 (client select 0x43D780 + MiniMap.txt)"},
        {"id": "map.minimap", "name": "小地图", "library": "FMMap.wil", "frame": 0,
         "evidence_level": "derived",
         "note": "0.map 比奇县 -> FMMap.wil F0 scaled into fixed 128x128 widget (672,0)"},
    ]

    # map_bindings: crossref rows (client_map_exists + frame decodes) so the
    # simulator can switch scenes through real map->library/frame pairs.
    try:
        xref = load("minimap-server-crossref.json")
        map_bindings = [
            {"map": r["map_stem"], "name": (r.get("server_map_names") or [r["map_stem"]])[0],
             "library": r["library"], "frame": r["frame"]}
            for r in xref.get("rows", [])
            if r.get("client_map_exists") and r.get("frame_in_library_range")
            and r.get("frame_nonblank_decodes")
        ]
    except FileNotFoundError:
        map_bindings = []

    # ------------------------------------------------------------------- hud
    hud: dict = {
        "origin": list(HUD_ORIGIN),
        "background_frame": 50,
        "resource_library": "GameInter.wil",
        "hp_bar": {"rect": [61, 496, 104, 566], "frame": 60,
                   "evidence_level": "primary-static",
                   "note": "0x004276D6 SetRect; (血量)%d/%d formatter"},
        "mp_bar": {"rect": [105, 496, 147, 566], "frame": 61,
                   "evidence_level": "primary-static",
                   "note": "0x004276F0 SetRect; (魔法)%d/%d formatter"},
        "exp_bar": {"rect": [61, 586, 400, 597], "frame": 63,
                    "evidence_level": "primary-static",
                    "note": "0x0042770D SetRect; (经验)%d/%d formatter"},
        "target_info": {"rect": [235, 496, 400, 586], "evidence_level": "primary-static",
                        "note": "0x004276B3 text region candidate"},
        "target_box": {"evidence_level": "primary-static",
                       "note": "hover target box = code-drawn composite anchored at HUD+0xE4/+0xE8: "
                               "name-plate box 0x40B850 (0xA0A0A border, width=text width, 15px tall, "
                               "15..30px above anchor), name text 0x40B750 (selector 0x566DD4 F2/F3 at "
                               "anchor+(7,-0x38)), HP bar 0x40A8A0 (element 0x5600FC+[8D]*0x144, frame=HP "
                               "value, centered via 400/300 float pair), layout rects 0x629FC/0x629EC "
                               "per-frame by 0x40F5F0; anchor world-derived 48x32 tile math or fixed "
                               "(376,227) via 0x4120B0; see docs/research/ei-ui-layout/target-box-evidence.json"},
        "chat_region": {"rect": [224, 492, 578, 566], "evidence_level": "primary-static",
                        "note": "0x00427696 SetRect; chat/text total region"},
        "minimap": {"rect": [672, 0, 800, 128], "evidence_level": "primary-static",
                    "note": "fixed minimap rect (672,0)-(800,128)"},
    }

    out = {
        "windows": windows,
        "controls": controls,
        "resources": resources,
        "entities": entities,
        "equipment_slots": equipment_slots,
        "skills": skills,
        "maps": maps,
        "map_bindings": map_bindings,
        "hud": hud,
        "viewport": {"width": VIEW_W, "height": VIEW_H},
        "meta": {
            "source": "docs/research/ei-ui-layout/layout.json + specialist evidence",
            "version": layout.get("version"),
            "generated_by": "Tools/web/build_mir3_simulator_data.py",
            "evidence_rule": "candidate geometry is never presented as primary fact",
        },
    }

    # Split into per-domain files (docs-required layout) plus a full bundle.
    for domain in ("windows", "controls", "resources", "entities",
                   "equipment_slots", "skills", "maps", "hud"):
        (OUT / f"{domain}.json").write_text(
            json.dumps(out[domain], ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "map_bindings.json").write_text(
        json.dumps(out["map_bindings"], ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "layout.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"windows={len(windows)} controls={len(controls)} resources={len(resources)}")
    print(f"entities={len(entities)} equipment_slots={len(equipment_slots)} skills={len(skills)}")
    print(f"maps={len(maps)} bindings={len(map_bindings)} wrote={OUT}/layout.json")


if __name__ == "__main__":
    main()
