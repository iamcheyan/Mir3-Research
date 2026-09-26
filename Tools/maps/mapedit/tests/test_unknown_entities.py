import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1].parent))

from mapedit.data import load_unknown_entities
from mapedit.npcedit import NpcEditError, PlacementStore, WorkspaceEditor


class UnknownEntityTests(unittest.TestCase):
    def test_manifest_candidates_are_deduped_and_placed_npc_is_marked(self):
        with tempfile.TemporaryDirectory() as td:
            root = Path(td)
            ws = root / "workspace"
            ws.mkdir()
            self._write(ws / "NPCInfo.json", [{"Index": 7, "NPCName": "Merchant"}])
            self._write(ws / "MapRegion.json", [{
                "Index": 9, "Map": {"Index": 1, "Name": "0"},
                "PointRegion": {"PointCount": 1, "CenterX": 10, "CenterY": 11},
            }])
            self._write(ws / "MonsterInfo.json", [{"Index": 44, "MonsterName": "Multi"}])
            self._write(ws / "RespawnInfo.json", [])
            src = root / "source"
            src.mkdir()
            self._write(src / "npc-manifest.json", [
                {"npc_index": 7, "current_name": "Merchant", "current_map": "0",
                 "current_xy": {"x": 10, "y": 11}, "confidence": "low",
                 "apply_status": "pending-review"},
                {"npc_index": 7, "current_name": "Merchant", "confidence": "low",
                 "apply_status": "pending-review"},
            ])
            (src / "monster-manifest.tsv").write_text(
                "website_monster_name\tstatus\tconfidence\tzircon_candidates\n"
                "multi\tinvestigate\tmedium\t[{\"index\":44}]\n",
                encoding="utf-8")
            placement = root / "placements.json"
            self._write(placement, {"version": 1, "placements": [{
                "placement_id": "npc:7", "kind": "npc-placement", "npc_index": 7,
                "status": "user-placed", "map": "0", "x": 12, "y": 13,
            }]})
            doc = load_unknown_entities(str(ws), str(src), str(placement))
            self.assertEqual(len(doc["unknown_npcs"]), 1)
            self.assertEqual(doc["unknown_npcs"][0]["status"], "user-placed")
            self.assertEqual(doc["unknown_monsters"][0]["monster_index"], 44)

    def test_monster_upsert_is_idempotent_and_undo_keeps_history(self):
        with tempfile.TemporaryDirectory() as td:
            store = PlacementStore(os.path.join(td, "placements.json"))
            first = store.upsert_monster(44, "02", 121, 98, count=3, delay=30)
            again = store.upsert_monster(44, "02.map", 121, 98, count=3, delay=30)
            self.assertEqual(first["placement_id"], again["placement_id"])
            self.assertEqual(len(store.load()["placements"]), 1)
            changed = store.upsert_monster(44, "02", 121, 98, count=4, delay=30)
            self.assertEqual(changed["count"], 4)
            self.assertTrue(changed["history"])
            undone = store.undo(changed["placement_id"])
            self.assertEqual(undone["status"], "undone")
            self.assertEqual(store.load()["placements"][0]["status"], "undone")

    def test_workspace_cross_map_move_updates_region_backlinks(self):
        with tempfile.TemporaryDirectory() as td:
            ws = Path(td)
            self._write(ws / "meta.json", {"MapRegion": {"identity": ["Map", "Description"]},
                                             "NPCInfo": {"identity": ["NPCName"]}})
            self._write(ws / "MapInfo.json", [
                {"Index": 1, "FileName": "0", "Regions": [{"Index": 9, "Name": "old"}]},
                {"Index": 2, "FileName": "02", "Regions": []},
            ])
            self._write(ws / "MapRegion.json", [{
                "Index": 9, "Map": {"Index": 1, "Name": "0"},
                "Description": "Merchant", "PointRegion": {"PointCount": 1, "CenterX": 10, "CenterY": 11},
                "Size": 1, "NPCs": [{"Index": 7, "Name": "Merchant"}],
            }])
            self._write(ws / "NPCInfo.json", [{"Index": 7, "NPCName": "Merchant",
                                                "Region": {"Index": 9, "Name": "old"}}])
            ed = WorkspaceEditor(str(ws)).load("MapInfo", "MapRegion", "NPCInfo")
            result = ed.move_npc(7, 121, 98, "02")
            self.assertEqual(result["to"]["map"], "02")
            self.assertEqual(ed.tables["MapRegion"][9]["Map"]["Name"], "02")
            self.assertEqual(ed.tables["MapInfo"][1]["Regions"], [])
            self.assertEqual(ed.tables["MapInfo"][2]["Regions"][0]["Index"], 9)

    def test_validation_rejects_bounds_and_blocked_cells(self):
        ed = WorkspaceEditor("/tmp/not-used")
        ed._bounds = lambda _map: (100, 100)
        ed._cell_blocked = lambda _map, _x, _y: True
        with self.assertRaises(NpcEditError):
            ed._check_xy("02", 100, 1)
        with self.assertRaises(NpcEditError):
            ed._check_xy("02", 1, 1, require_passable=True)
        with self.assertRaises(NpcEditError):
            PlacementStore("/tmp/placements.json").upsert_monster(1, "../02", 1, 1)

    @staticmethod
    def _write(path, rows):
        if isinstance(rows, list):
            rows = {"count": len(rows), "rows": rows}
        path.write_text(json.dumps(rows, ensure_ascii=False), encoding="utf-8")


if __name__ == "__main__":
    unittest.main()
