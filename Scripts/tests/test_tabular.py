#!/usr/bin/env python3
"""Tests for the ICD-10-CM tabular parser: hierarchy and clinical notes."""
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS))

from codebar_import import infer_missing_parents, parse_tabular  # noqa: E402

TABULAR = """<?xml version="1.0" encoding="UTF-8"?>
<ICD10CM.tabular>
  <chapter>
    <name>4</name>
    <desc>Endocrine diseases (E00-E89)</desc>
    <section id="E08-E13">
      <desc>Diabetes mellitus</desc>
      <diag>
        <name>E11</name>
        <desc>Type 2 diabetes mellitus</desc>
        <includes><note>diabetes NOS</note></includes>
        <excludes1><note>type 1 diabetes mellitus (E10.-)</note></excludes1>
        <useAdditionalCode><note>insulin (Z79.4)</note></useAdditionalCode>
        <diag>
          <name>E11.2</name>
          <desc>Type 2 diabetes with kidney complications</desc>
          <diag>
            <name>E11.21</name>
            <desc>Type 2 diabetes with diabetic nephropathy</desc>
            <excludes2><note>separate condition</note></excludes2>
          </diag>
        </diag>
      </diag>
    </section>
  </chapter>
</ICD10CM.tabular>
"""


class ParseTabularTests(unittest.TestCase):
    def setUp(self):
        handle = tempfile.NamedTemporaryFile("w", suffix=".xml", delete=False, encoding="utf-8")
        handle.write(TABULAR)
        handle.close()
        self.path = handle.name
        self.entries = parse_tabular(self.path)

    def tearDown(self):
        Path(self.path).unlink()

    def test_should_report_no_parent_for_a_top_level_code(self):
        self.assertIsNone(self.entries["E11"]["parent"])

    def test_should_record_the_immediate_parent_not_the_root(self):
        # The whole reason for reading the tabular: E11.21 belongs to E11.2.
        self.assertEqual(self.entries["E11.21"]["parent"], "E11.2")

    def test_should_record_the_chapter(self):
        self.assertEqual(self.entries["E11"]["chapter"], "Endocrine diseases (E00-E89)")

    def test_should_give_nested_codes_the_chapter_too(self):
        self.assertEqual(self.entries["E11.21"]["chapter"], "Endocrine diseases (E00-E89)")

    def test_should_keep_excludes1_distinct_from_excludes2(self):
        kinds = {n["kind"] for n in self.entries["E11"]["notes"]}
        self.assertIn("excludes1", kinds)
        self.assertNotIn("excludes2", kinds)

    def test_should_capture_excludes2_where_it_appears(self):
        kinds = {n["kind"] for n in self.entries["E11.21"]["notes"]}
        self.assertEqual(kinds, {"excludes2"})

    def test_should_preserve_the_publishers_note_order(self):
        kinds = [n["kind"] for n in self.entries["E11"]["notes"]]
        self.assertEqual(kinds, ["includes", "excludes1", "useAdditionalCode"])

    def test_should_keep_note_text_verbatim(self):
        texts = [n["text"] for n in self.entries["E11"]["notes"]]
        self.assertIn("type 1 diabetes mellitus (E10.-)", texts)


class InferMissingParentsTests(unittest.TestCase):
    def test_should_fill_a_parent_the_tabular_never_stated(self):
        # Seventh-character extensions are defined by rule, not listed.
        entries = {"S72.001": {"parent": None, "chapter": "Injury", "notes": []}}
        result = infer_missing_parents(entries, ["S72.001", "S72.001A"])
        self.assertEqual(result["S72.001A"]["parent"], "S72.001")

    def test_should_inherit_the_chapter_when_inferring(self):
        entries = {"S72.001": {"parent": None, "chapter": "Injury", "notes": []}}
        result = infer_missing_parents(entries, ["S72.001", "S72.001A"])
        self.assertEqual(result["S72.001A"]["chapter"], "Injury")

    def test_should_never_override_a_stated_parent(self):
        entries = {
            "E11": {"parent": None, "chapter": None, "notes": []},
            "E11.2": {"parent": "E11", "chapter": None, "notes": []},
            "E11.21": {"parent": "E11.2", "chapter": None, "notes": []},
        }
        result = infer_missing_parents(entries, list(entries))
        self.assertEqual(result["E11.21"]["parent"], "E11.2")

    def test_should_leave_a_genuine_root_without_a_parent(self):
        entries = {}
        result = infer_missing_parents(entries, ["A00"])
        self.assertIsNone(result["A00"]["parent"])

    def test_should_pick_the_longest_matching_prefix(self):
        entries = {}
        result = infer_missing_parents(entries, ["S72", "S72.0", "S72.001"])
        self.assertEqual(result["S72.001"]["parent"], "S72.0")


if __name__ == "__main__":
    unittest.main()
