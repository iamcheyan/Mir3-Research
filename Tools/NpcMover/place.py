#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""NpcMover place.py — E2 NPC 摆放命令行（写 dbeditor workspace，不碰 .db）。

与 npcedit.py（mapedit 包引擎）共用逻辑入口：批量移动 / 新增 / 删除 NPC 与卫士、
安全区平移、diff、回滚。写完提示走 dbeditor sync（停服 → sync.sh → 起服）。

用法（全部幂等可重复，先 --diff 预览）：
  place.py move  <npcIndex> <x> <y> [mapStem]
  place.py guard <guardIndex> <x> <y> [mapStem]
  place.py safezone <safezoneIndex> <x> <y>
  place.py create <mapStem> <x> <y> <名字> [image] [entryPageIndex]
  place.py delete <npcIndex>
  place.py diff
  place.py rollback [table]

示例：
  python3 place.py move 13 410 360
  python3 place.py create 0 415 361 测试铁匠 3 5
  python3 place.py diff && bash ../../dbeditor/sync.sh
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "maps"))

from mapedit import npcedit  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_WS = os.path.join(REPO, "Tools", "dbeditor", "workspace")
DEFAULT_MAPS = os.environ.get("E2_MAPS_DIR", "")


def main() -> int:
    ap = argparse.ArgumentParser(description="NPC 摆放（workspace JSON，经 sync 入库）")
    ap.add_argument("--workspace", default=DEFAULT_WS)
    ap.add_argument("--maps-dir", default=DEFAULT_MAPS or None,
                    help=".map 目录（越界/阻挡校验；默认不校验）")
    ap.add_argument("--force", action="store_true",
                    help="允许落在阻挡格（游戏内 NPC 不可见，慎用）")
    sub = ap.add_subparsers(dest="op", required=True)
    p = sub.add_parser("move"); p.add_argument("npc", type=int)
    p.add_argument("x", type=int); p.add_argument("y", type=int)
    p.add_argument("map", nargs="?")
    p = sub.add_parser("guard"); p.add_argument("guard", type=int)
    p.add_argument("x", type=int); p.add_argument("y", type=int)
    p.add_argument("map", nargs="?")
    p = sub.add_parser("safezone"); p.add_argument("safezone", type=int)
    p.add_argument("x", type=int); p.add_argument("y", type=int)
    p = sub.add_parser("create"); p.add_argument("map")
    p.add_argument("x", type=int); p.add_argument("y", type=int)
    p.add_argument("name"); p.add_argument("image", type=int, nargs="?", default=0)
    p.add_argument("entry_page", type=int, nargs="?", default=None)
    p = sub.add_parser("delete"); p.add_argument("npc", type=int)
    sub.add_parser("diff")
    p = sub.add_parser("rollback"); p.add_argument("table", nargs="?")
    a = ap.parse_args()

    if a.op == "diff":
        d = npcedit.workspace_diff(a.workspace)
        print(f"+{d['summary']['added']} ~{d['summary']['modified']} "
              f"-{d['summary']['deleted']}")
        for table, entries in d["tables"].items():
            print(f"  {table}: {len(entries)} 处")
            for e in entries[:10]:
                fl = ",".join((e["fields"] or {}).keys()) if e["fields"] else ""
                print(f"    #{e['index']} {e['op']} {fl}")
        return 0
    if a.op == "rollback":
        r = npcedit.workspace_rollback(a.workspace, a.table)
        print("已回滚:", ",".join(r["restored"]) or "无")
        return 0

    ed = npcedit.WorkspaceEditor(a.workspace, maps_dir=a.maps_dir)
    try:
        if a.op == "move":
            r = ed.move_npc(a.npc, a.x, a.y, a.map, force=a.force)
        elif a.op == "guard":
            r = ed.move_guard(a.guard, a.x, a.y, a.map, force=a.force)
        elif a.op == "safezone":
            r = ed.move_safezone(a.safezone, a.x, a.y, force=a.force)
        elif a.op == "create":
            r = ed.create_npc(a.map, a.x, a.y, a.name, image=a.image,
                              entry_page=a.entry_page, force=a.force)
        elif a.op == "delete":
            r = ed.delete_npc(a.npc)
    except npcedit.NpcEditError as ex:
        print(f"[X] {ex}")
        return 1
    ed.commit(f"NpcMover place {a.op}")
    print("[OK]", r)
    print("下一步：停服后 bash Tools/dbeditor/sync.sh（或 dbeditor 界面「同步」）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
