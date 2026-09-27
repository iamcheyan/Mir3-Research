from __future__ import annotations

import csv
import subprocess
import sys
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
EXTRACTOR = ROOT / "Tools" / "source-read" / "extract_sql_tables.py"


def extracted_rows() -> list[dict[str, str]]:
    output = subprocess.check_output(
        [sys.executable, str(EXTRACTOR), "--stdout"],
        cwd=ROOT,
        text=True,
    )
    lines = output.splitlines()
    header = "array\ttable_hint\tfield\ttype\tkey_flag\tsize\tsrc_line"
    rows = [
        line for line in lines
        if line.count("\t") == 6 and line.split("\t", 1)[0].startswith("__")
    ]
    return list(csv.DictReader([header, *rows], delimiter="\t"))


class ExtractSqlTablesTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.rows = extracted_rows()
        cls.fields = {(r["array"], r["field"]) for r in cls.rows}

    def test_extracts_first_field_on_array_declaration_line(self) -> None:
        self.assertIn(("__CHARACTERFIELDS", "FLD_CHARACTER"), self.fields)
        self.assertIn(("__CHARACTERFIELDS", "FLD_USERID"), self.fields)
        self.assertIn(("__CHAR_INFOFIELDS", "FLD_LOGINID"), self.fields)
        self.assertEqual(len(self.rows), 175)

    def test_ignores_commented_out_field_declarations(self) -> None:
        self.assertNotIn("FLD_RESERVED1", {r["field"] for r in self.rows})
