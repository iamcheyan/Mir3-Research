import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_map_connections_audit import inspect_map, verify


def synthetic_map(flags, width=4, height=4):
    half = (width // 2) * (height // 2) * 3
    data = bytearray(28 + half + width * height * 14)
    struct.pack_into("<HH", data, 22, width, height)
    for i, flag in enumerate(flags):
        data[28 + half + i * 14] = flag
    return data


class MapConnectionAuditVerifierTests(unittest.TestCase):
    def test_reader_uses_column_major_cell_offset_and_flag_mask(self):
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp) / "x.map"
            flags = [0] * 16
            flags[2 * 4 + 1] = 3
            flags[1 * 4 + 2] = 1
            p.write_bytes(synthetic_map(flags))
            w, h, start, n, raw = inspect_map(p)
            self.assertEqual((w, h, n), (4, 4, 16))
            self.assertEqual(raw[start + (2 * h + 1) * 14] & 3, 3)
            self.assertNotEqual(raw[start + (1 * h + 2) * 14] & 3, 3)

    def test_verify_detects_manifest_walkability_corruption(self):
        with tempfile.TemporaryDirectory() as tmp:
            d = Path(tmp); (d / "x.map").write_bytes(synthetic_map([3] * 16))
            m = {"records":[{"movement_index":1,"status":"retain-current","source":{"map_file":"x","x":1,"y":1,"in_bounds":True,"walkable":False,"terrain_available":True},"destination":{"map_file":"x","x":2,"y":2,"in_bounds":True,"walkable":True,"terrain_available":True}}]}
            mp=d/"manifest.json"; mp.write_text(json.dumps(m))
            result=verify(mp,d)
            self.assertFalse(result["pass"])
            self.assertTrue(any("walkability mismatch" in e["error"] for e in result["verification_errors"]))


if __name__ == "__main__":
    unittest.main()
