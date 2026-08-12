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


def frame_tables() -> dict:
    """State-table constants from Finding 279 (primary-static): the three
    runtime frame tables 0x8AA5C0 (player, 33) / 0x8AA686 (monster, 9) /
    0x8AA6C8 (npc, 3) are BSS singleton fields whose contents are 100%
    compile-time immediates (writer chain 0x449C80 -> 0x44A240 -> 0x44A090).
    Each record = (w0 state-start frame, w1 block length, w2 frame interval ms).
    The simulator cycles sub-frames within [w0, w0+w1) at w2 ms and offsets by
    the closed entity formulas (player 3000*S+10*dir, monster 1000*(race%10),
    npc 100*body+10*(flag%3))."""
    ev = load("state-frame-tables-evidence.json")
    def rows(key: str, sub: str | None = None) -> list[list[int]]:
        node = ev.get(key, {})
        if sub:
            node = node.get(sub, {})
        recs = node.get("records", []) if isinstance(node, dict) else node
        return [[int(r["w0"], 16), int(r["w1"]), int(r["w2"])] for r in recs]
    out = {
        "player": rows("player_table"),
        "monster": rows("monster_table_default"),
        "npc": rows("npc_table", "default_records"),
        "source": "state-frame-tables-evidence.json Finding 279 (primary-static)",
    }
    # Finding 290 (PlayerStateActions) names the player states 0..32.
    # state names are emitted as an aligned array when the evidence exists.
    try:
        ev290 = load("player-state-actions-evidence.json")
        prows = ev290.get("player_table", {}).get("rows", [])
        names = [r.get("semantic", "") for r in prows] if isinstance(prows, list) else []
        if names:
            out["player_names"] = names
            out["source"] += " + Finding 290 (player state semantics)"
    except Exception:
        pass
    # Finding 298 (MountedGaitSpecialPairs) corrects the F290 INFERENCE labels
    # for the mounted states: frame duration is NOT gait speed. The riding
    # machine step-threshold ladder (fx 0x1A@>7 -> 0x10@>0xB -> 0x11@>0xF)
    # orders 0x10 = WALK (70ms) / 0x11 = RUN (90ms), and 0x1E/0x1F are the
    # mounted channel variants of ground 0x15/0x16 (gated on [0x629C8]).
    try:
        ev298 = load("mounted-gait-special-pairs-evidence.json")
        if isinstance(ev298, dict) and ev298.get("gait_pair"):
            overrides = {
                0x10: "骑马走 mounted WALK (steps>0xB, 70ms, fx 0x23)",
                0x11: "骑马跑 mounted RUN (steps>0xF, 90ms, fx 0x22)",
                0x1E: "mounted variant of 0x15 (mounted channel, fx 0x22 run-family)",
                0x1F: "mounted variant of 0x16 (mounted channel, fx 0x23 walk-family)",
            }
            names = out.get("player_names")
            if names:
                for idx, label in overrides.items():
                    if idx < len(names):
                        names[idx] = label
                out["source"] += " + Finding 298 (mounted gait pairs)"
    except Exception:
        pass
    # Finding 307 (NetworkMessageObjectAnatomy) - the inbound frame-type jump
    # table (0x421D8C byte table types 6..0xC8 -> 12 handler slots at 0x421D5C),
    # the queue-pump dispatch and the queue-item anatomy are compile-time data,
    # emitted here so the simulator can label inbound frame types / messages.
    out["frame_dispatch"] = {
        "jump_table": [
            {"idx": 0, "handler": "0x421CFC", "semantic": "queue push (SEH, ret 4)",
             "types": [0x6, 0x7, 0x8, 0x9, 0xa, 0xb, 0xc, 0xd, 0xe, 0xf, 0x11, 0x12,
                       0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x1b, 0x1f, 0x20, 0x21,
                       0x22, 0x32, 0x33, 0x34]},
            {"idx": 1, "handler": "0x421497", "semantic": "0xC-byte item -> 2nd queue [screen+0x3C5EFC]",
             "types": [0x1d, 0x1e]},
            {"idx": 2, "handler": "0x421BA7", "semantic": "live = 0x421BA7 front block: body+0x10 "
                                                           "base64-decode via 0x422E30 into stack, "
                                                           "discarded (dead sub-blocks 0x421BBC "
                                                           "map-change / 0x421C23 object-add / "
                                                           "0x421C81 chat)",
             "types": [0x28, 0x64, 0x65, 0x66, 0x67, 0x68]},
            {"idx": 3, "handler": "0x41EFC6", "types": [0x29]},
            {"idx": 4, "handler": "0x41F06B", "types": [0x2a]},
            {"idx": 5, "handler": "0x41EDE0", "types": [0x2c]},
            {"idx": 6, "handler": "0x41EF62", "types": [0x2d]},
            {"idx": 7, "handler": "0x41EF8B", "types": [0x2e]},
            {"idx": 8, "handler": "0x41F0F0", "types": [0x35]},
            {"idx": 9, "handler": "0x41EDC4", "semantic": "chat receive", "types": [0x36]},
            {"idx": 10, "handler": "0x41EE34", "types": [0xc8]},
            {"idx": 11, "handler": "0x421D3F", "semantic": "no-op (common epilogue)", "types": "153 remaining"},
        ],
        "large_types": [
            {"range": "== 0xC9", "handler": "0x41F175"},
            {"range": "0xCA..0x26C", "handler": "0x41F264"},
            {"range": "== 0x26D", "handler": "0x41F79E"},
            {"range": "0x26E..0x29D", "handler": "0x41F8C6"},
            {"range": "== 0x29E", "handler": "0x4203F7"},
            {"range": "> 0x29E", "handler": "0x42042B"},
        ],
        "queue_pump": "0x4227F0 (only caller 0x41BBCA); movzx ax,word[item+4]: "
                      "0x33/0x27A -> 0x422960 (death/teleport: dialog, sounds, "
                      "respawn-coords zero, live Y/X [0x777764]/[0x777768] = word[item+6]/[item+8], "
                      "map loader .\\Map\\%s.map from base64 payload, player obj vtable); "
                      "0x32 -> 0x422CC0 (enter-world self-init: own id [0x2F8784], "
                      "byte[item+0xB] -> [0x35A354], 16B+5B base64 decode, "
                      "playerObj vtable+0x8C enter-world, account -> [0x2F8788], list clears, "
                      "sound); 0x34 -> 0x423000 (full self-stats: id -> [0x35B1E8], "
                      "byte -> [0x35B1E4], 97-byte base64 -> display block [0x35B1F0], "
                      "HP/MP -> live [0x35A34C]/[0x35A34A]/[0x35A34E]); 0x2F0 -> 0x423070 "
                      "(status bytes: word[item+0] -> [0x35B251], byte[item+6..0xB] -> "
                      "[0x35B253..0x35B258]); default -> own-id (abs 0x77769C) + msgid 0x1F: "
                      "HP cur word[item+6] -> [0x35B1F5]/[0x35A34C], HP max word[item+8] -> "
                      "[0x35B1F9]/[0x35A34A], cur==0 -> death 0x40A1E0+0x4561B0; other-id -> "
                      "object-list walk [esi+0xE1158] (node +4 obj / +0xC next) -> "
                      "0x40A1E0 + 0x4561B0([ebx+0xF0]), else free",
        "queue_item": "0x421CFC malloc 0x40C: {+0 id dword, +4 msgid dword/word (+6 HP cur word), "
                      "+8 dword (+8 HP max word), +0xC byte0 + frame-content string via lstrcpyA "
                      "call [0x4760C8]}; queue field [screen+0x364458] (0x7E3370); push helper "
                      "0x4561B0; no direct callers (jump-table only)",
        "base64_encoder": "0x452740 (src, dest, len, destmax; ret 0x10): MIR b64 charset "
                          "value+0x3C, 3 bytes -> 4 chars, carry bits in edi (0/2/4/6), "
                          "null-terminated, returns byte count; emulation-validated byte-exact "
                          "(chat 6 B, hello 22 B -> 30 B, empty -> 0); decode wrapper 0x452810 "
                          "(up-to-N base64 decode)",
        "source": "network-message-object-anatomy.json Finding 307 (primary-static)",
    }
    return out


def visibility_dispatch() -> dict:
    """Round 12 (Finding 314, primary-static): the original client's window
    show/hide toggle dispatcher 0x42ADB0. Emitted as an additive
    semantic/reference block (same role as frame_dispatch in frame_tables):
    the simulator gates window visibility through windows[].visibility_va;
    this block documents the dispatcher state machine the original runs —
    unconditional demote-all 0x42B820 first ([obj+0x34]=0 for every listed
    window, list nodes kept), then per-id open/close via jump table
    0x42B3E4, single-active-window semantics (+0x30 per-window visible gate
    setter 0x423F80 / +0x34 active slot setter 0x423F90)."""
    ev = load("window-visibility-dispatch-evidence.json")
    disp = ev.get("dispatch", {})
    jump = [
        int(s.split("=", 1)[1], 16)
        for s in disp.get("jump_table_dwords", [])
    ]
    cases = []
    for r in ev.get("records", []):
        cases.append({
            "id": r.get("window_id"),
            "layout_id": r.get("layout_id"),
            "case_va": r.get("target"),
            "object_offset": r.get("object"),
            "state_gate": r.get("state_gate"),
            "close_va": r.get("close_va"),
            "open_va": r.get("open_va"),
            "show_hide": r.get("show_hide"),
        })
    return {
        "dispatcher_va": ev.get("routine"),
        "head": disp.get("head"),
        "jump_table_va": disp.get("jump_table_va"),
        "jump_table": jump,
        "default_target": disp.get("default_target"),
        "return_contract": disp.get("return_contract"),
        "close_all": disp.get("close_all_first"),
        "add_helper": disp.get("show_helper"),
        "remove_helper": disp.get("hide_helper"),
        "case_pattern": disp.get("case_pattern"),
        "visible_gate_setter": "0x00423F80 (mov [obj+0x30],arg; ret 4; via class setter 0x0043F020, "
                               "arg==0 -> [obj+0x274]=1; draw paths gate on [obj+0x30], e.g. 0x43F04A)",
        "active_state_setter": "0x00423F90 (mov [obj+0x34],arg; ret 4; demote-all 0x42B820 writes 0)",
        "virtual_visibility_slot": disp.get("virtual_visibility_slot"),
        "virtual_argument": disp.get("virtual_argument"),
        "cases": cases,
        "source": "window-visibility-dispatch-evidence.json Finding 314 (primary-static)",
    }


def hotkeys() -> dict:
    """Round 32 (F338, primary-bytes): hotkey table 0x42CC76 (hero hotkey
    handler 0x42CBD0, GetKeyState). Emitted as additive reference block for
    the simulator's keyboard layer: key -> window-id / action."""
    layout = load("layout.json")
    out = {}
    for r in layout.get("records", []):
        if r.get("id") == "hotkey.table-0x42CC76":
            role = r.get("role", "")
            out = {
                "dispatcher_va": "0x42CC76 (inside 0x42CBD0)",
                "gate": "[hero+0x20] OR [hero+0x24] nonzero -> suppressed",
                "keys": {
                    "Q": {"action": "toggle id0", "window_id": 0, "identity": "背包 Bag"},
                    "W": {"action": "toggle id1", "window_id": 1, "identity": "状态栏 Status"},
                    "E": {"action": "toggle id14", "window_id": 14, "identity": "技能书 Skill Book"},
                    "R": {"action": "toggle id8", "window_id": 8, "identity": "聊天 Chat"},
                    "S": {"action": "toggle id13", "window_id": 13, "identity": "坐骑 Horse"},
                    "D": {"action": "toggle id11", "window_id": 11, "identity": "信息窗口 Quest/Info"},
                    "Z": {"action": "brightness [hero+0xD40] clamp 0..0x2E (belt light)"},
                    "C": {"action": "entity find 0x41EC10 + name status line 0x451A70"},
                    "V": {"action": "minimap 0x451770 (throttle [hero+0x6210])"},
                    "B": {"action": "skill browse flip [hero+0x6208]"},
                    "G": {"action": "toggle id6", "window_id": 6, "identity": "组队 Group"},
                    "F": {"action": "guild 0x4523E0"},
                    "N": {"action": "toggle id12", "window_id": 12, "identity": "选项 Option"},
                    "T": {"action": "minimap state gate [hero+0x6518]==1"},
                },
                "note": "F329 'D->horse' corrected (F338): D->id11 quest, S->id13 horse",
                "source": "window-paint-and-hotkey-dispatch-evidence.json Finding 338 (primary-bytes)",
            }
            break
    return out


def window_catalog() -> dict:
    """Round 29-33 window catalog: id -> {obj offset, ctor, frame, rect, identity}
    from layout.json window-catalog.hero-builder-0x427600 (primary-bytes)."""
    layout = load("layout.json")
    for r in layout.get("records", []):
        if r.get("id") == "window-catalog.hero-builder-0x427600":
            windows = r.get("windows", [])
            return {
                "builder_va": "0x427600",
                "hero_object": "main+0x2A548C = 0x7243A4",
                "windows": windows,
                "source": "window-catalog-evidence.json (Round 29) + F337/F338 identity resolutions",
            }
    return {"windows": []}


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
    # Round 29-33 window catalog (F337/F338, primary-bytes): exact ctor x/y per window id.
    # layout records carry window.id (from window.* records) or the catalog windows table.
    catalog_by_frame = {}
    catalog_by_winid = {}
    for r in layout.get("records", []):
        if r.get("id") == "window-catalog.hero-builder-0x427600":
            for w in r.get("windows", []):
                catalog_by_winid[w["id"]] = (w["x"], w["y"])
                catalog_by_frame[w["frame"]] = (w["x"], w["y"])
    for rec in window_records:
        wid = rec["id"]
        res = rec.get("resource", {})
        size = rec.get("size", {})
        w, h = size.get("width", 0), size.get("height", 0)
        pos = rec.get("position", {})
        frame = res.get("frame") if isinstance(res.get("frame"), int) else res.get("frames", {}).get("normal")
        origin = confirmed_origins.get(wid)
        evidence = "primary-static"
        if origin is None:
            # prefer explicit window-id key (window.X records with window.id), else frame key
            winid = (rec.get("window") or {}).get("id")
            if isinstance(winid, int) and winid in catalog_by_winid:
                origin = catalog_by_winid[winid]
            elif isinstance(frame, int) and frame in catalog_by_frame:
                origin = catalog_by_frame[frame]
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
            "frame": frame,
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
    # Round 45 (F351): real Magic.exp records (F37 0x4525F0 decoder, 50 skills
    # with id/name/attribute/element/levels) - first 12 map to the skill grid
    # slots (frames 410+, candidate slot geometry from skill-window evidence).
    skills: list[dict] = []
    try:
        magic = load("magic-exp-records.json")
        recs = magic if isinstance(magic, list) else magic.get("records", magic.get("magic", []))
    except Exception:
        recs = []
    for i in range(12):
        frame = 410 + i
        m = recs[i] if i < len(recs) else None
        lvl1 = (m.get("levels") or [{}])[0] if m else {}
        skills.append({
            "id": f"skill.{i}",
            "name": (m or {}).get("name", f"技能 {i + 1}"),
            "magic_id": (m or {}).get("id"),
            "attribute": (m or {}).get("attribute"),
            "element": (m or {}).get("element"),
            "required_level": lvl1.get("required_level"),
            "practice": lvl1.get("practice_value"),
            "x": 30 + (i % 4) * 40, "y": 60 + (i // 4) * 40,
            "w": 36, "h": 36,
            "library": "GameInter.wil", "frame": frame,
            "evidence_level": "primary-static" if m else "candidate",
            "note": (f"Magic.exp id {m['id']} {m['name']} (F37/F351)" if m
                     else f"skill grid slot; F{frame} from skill-window evidence"),
        })

    # ------------------------------------------------------------------ maps
    # map.bg / map.minimap bind to the demo scene map (0.map = 比奇县). The
    # library+frame follow the client's map-select rule (setter 0x0043D780,
    # caller 0x420C3A does the dec; Finding 277 primary-static): server_value
    # >= 1001 -> FMMap.wil frame value-1001, else MMap.wil frame value-1.
    # The original server MiniMap.txt gives 0.map -> 1001 -> FMMap.wil F0.
    # Select rule is primary-static; the row binding is secondary-server.
    maps: list[dict] = [
        {"id": "map.bg", "name": "地图背景", "library": "FMMap.wil", "frame": 0,
         "evidence_level": "derived",
         "note": "0.map 比奇县 -> server 1001 -> FMMap.wil F0 (client select 0x43D780 + MiniMap.txt)"},
        {"id": "map.minimap", "name": "小地图", "library": "FMMap.wil", "frame": 0,
         "evidence_level": "derived",
         "note": "0.map 比奇县 -> FMMap.wil F0; panel (672,0)-(800,128) primary-static; "
                 "placement formula (Finding 277 confirmed): painted rect (0,0,W*1.5,H), "
                 "1.5 px/tile X / 1 px/tile Y, frame = ceil4(W*1.5) x H; live client scrolls "
                 "the source window with the player — static sim shows center crop (cover)"},
    ]

    # map_bindings: crossref rows (client_map_exists + frame decodes) so the
    # simulator can switch scenes through real map->library/frame pairs.
    try:
        xref = load("minimap-server-crossref.json")
        try:
            cat = json.loads((Path("docs/research/mir3-map-reconstruction/catalog/map-catalog.json")).read_text(encoding="utf-8"))
            cat_by_stem = {m["name"].rsplit(".", 1)[0]: m for m in cat.get("maps", [])}
        except Exception:
            cat_by_stem = {}
        map_bindings = [
            {"map": r["map_stem"], "name": (r.get("server_map_names") or [r["map_stem"]])[0],
             "library": r["library"], "frame": r["frame"]}
            for r in xref.get("rows", [])
            if r.get("client_map_exists") and r.get("frame_in_library_range")
            and r.get("frame_nonblank_decodes")
        ]
        for b in map_bindings:
            c = cat_by_stem.get(b["map"])
            if c:
                b["w"] = c["w"]
                b["h"] = c["h"]
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
                    "note": "minimap widget 0x48512C = screen+0x6214 (Finding 310); D3D target "
                            "rect {672,0,800,128} byte-exact (0x2A0,0,0x320,0x80); per-frame "
                            "update 0x43D850 (called from screen tick 0x4294E0 when "
                            "[screen+0x6518]!=0) reads live player coords [0x777764]/[0x777768] "
                            "(Y/X = screen+0x2F884C/+0x2F8850), stores widget [+0x2F8]/[+0x2FC], "
                            "scroll = fild(pos)*[0x476904] - half-extent, clamped to "
                            "[+0x2D8]/[+0x2DC]; draw 0x43DA80: map texture (mapid<0x3E8 -> "
                            "MMap.wil widget+4 frame mapid, else FMMap.wil widget+0x148 frame "
                            "mapid-1000; blit 0x465560) + 10x10 player box 0x96C8FF at "
                            "[+0x2C8]/[+0x2CC] + 4x4 blinking dot 0x64FA64 (gate "
                            "0<[+0x300]<0x1F4, [+0x300] wraps at 0x320); object markers: "
                            "[0x560070] list (screen+0xE1158) type-byte-0x32 objs drawn 2x2 "
                            "yellow 0xFFFF at obj+0xCC/+0xD0, [0x5600A0] list (screen+0xE1188) "
                            "generic objs 2x2 green 0x64C864 bounds-culled; fill helper "
                            "0x45E570(0x8AB7A8,&rect,0,color,1); live coords written only by "
                            "pump death/teleport handler 0x422A9E/0x422AC5 (0x7D9234/0x7D9238 = "
                            "separate death/respawn pair, NOT minimap input)"},
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
        "frame_tables": frame_tables(),
        "visibility_dispatch": visibility_dispatch(),
        "hotkeys": hotkeys(),
        "window_catalog": window_catalog(),
        "viewport": {"width": VIEW_W, "height": VIEW_H},
        "meta": {
            "source": "docs/research/ei-ui-layout/layout.json + specialist evidence",
            "version": layout.get("version"),
            "generated_by": "Tools/web/build_mir3_simulator_data.py",
            "evidence_rule": "candidate geometry is never presented as primary fact",
        },
    }

    # Split into per-domain files (docs-required layout) plus a full bundle.
    for domain in ("controls", "resources", "entities",
                   "equipment_slots", "skills", "maps", "hud"):
        (OUT / f"{domain}.json").write_text(
            json.dumps(out[domain], ensure_ascii=False, indent=2), encoding="utf-8")
    # windows.json = array + additive visibility_dispatch block (Round 12,
    # Finding 314; nothing consumes windows.json directly — layout.json bundle
    # carries the same top-level block).
    (OUT / "windows.json").write_text(
        json.dumps({"windows": out["windows"], "visibility_dispatch": out["visibility_dispatch"]},
                   ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "map_bindings.json").write_text(
        json.dumps(out["map_bindings"], ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "frame_tables.json").write_text(
        json.dumps(out["frame_tables"], ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT / "layout.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"windows={len(windows)} controls={len(controls)} resources={len(resources)}")
    print(f"entities={len(entities)} equipment_slots={len(equipment_slots)} skills={len(skills)}")
    print(f"maps={len(maps)} bindings={len(map_bindings)} wrote={OUT}/layout.json")


if __name__ == "__main__":
    main()
