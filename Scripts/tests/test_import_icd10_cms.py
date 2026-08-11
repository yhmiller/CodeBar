#!/usr/bin/env python3
"""Tests for the CMS ICD-10-CM order file parser.

The order file is fixed-width, so every field depends on byte offsets that are
easy to get subtly wrong and hard to notice: a one-column slip yields plausible
looking output with the billable flag read from the wrong place.
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS))

from import_icd10_cms import parse_icd10_order_file  # noqa: E402


def order_line(order_no, code, billable, short_desc, long_desc):
    """Builds one line in the CMS order file's fixed-width layout."""
    return (
        f"{order_no:>5}"          # 0-4   order number
        f" "                      # 5
        f"{code:<7}"              # 6-12  code, no decimal point
        f" "                      # 13
        f"{1 if billable else 0}" # 14    valid for submission
        f" "                      # 15
        f"{short_desc:<61}"       # 16-76 short description
        f"{long_desc}"            # 77+   long description
    )


class ParseOrderFileTests(unittest.TestCase):
    def parse(self, lines):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
            path = handle.name
        try:
            return parse_icd10_order_file(path)
        finally:
            Path(path).unlink()

    def test_should_mark_a_category_header_as_not_billable(self):
        codes = self.parse([order_line(1, "E11", False, "Type 2 diabetes mellitus",
                                       "Type 2 diabetes mellitus")])
        self.assertFalse(codes[0]["billable"])

    def test_should_mark_a_submittable_code_as_billable(self):
        codes = self.parse([order_line(2, "E119", True, "Type 2 diab w/o cmp",
                                       "Type 2 diabetes mellitus without complications")])
        self.assertTrue(codes[0]["billable"])

    def test_should_reinsert_the_decimal_point_after_three_characters(self):
        codes = self.parse([order_line(2, "E119", True, "Type 2 diab w/o cmp",
                                       "Type 2 diabetes mellitus without complications")])
        self.assertEqual(codes[0]["code"], "E11.9")

    def test_should_leave_a_three_character_code_undotted(self):
        codes = self.parse([order_line(1, "E11", False, "Type 2 diabetes mellitus",
                                       "Type 2 diabetes mellitus")])
        self.assertEqual(codes[0]["code"], "E11")

    def test_should_use_the_long_description_for_display(self):
        codes = self.parse([order_line(2, "E119", True, "Type 2 diab w/o cmp",
                                       "Type 2 diabetes mellitus without complications")])
        self.assertEqual(codes[0]["display"], "Type 2 diabetes mellitus without complications")

    def test_should_keep_short_description_words_as_synonyms(self):
        codes = self.parse([order_line(2, "E119", True, "Type 2 diab w/o cmp",
                                       "Type 2 diabetes mellitus without complications")])
        self.assertIn("diab", codes[0]["synonyms"])

    def test_should_skip_blank_lines(self):
        codes = self.parse([
            order_line(1, "E11", False, "Type 2 diabetes mellitus", "Type 2 diabetes mellitus"),
            "",
        ])
        self.assertEqual(len(codes), 1)

    def test_should_produce_json_serialisable_output(self):
        codes = self.parse([order_line(1, "E11", False, "Type 2 diabetes mellitus",
                                       "Type 2 diabetes mellitus")])
        self.assertEqual(json.loads(json.dumps(codes))[0]["code"], "E11")

    def test_should_tag_every_code_with_the_icd10_system(self):
        codes = self.parse([order_line(1, "E11", False, "Type 2 diabetes mellitus",
                                       "Type 2 diabetes mellitus")])
        self.assertEqual(codes[0]["system"], "ICD-10-CM")


class EndToEndTests(unittest.TestCase):
    def test_should_report_the_billable_and_header_split(self):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "order.txt"
            output = Path(directory) / "out.json"
            source.write_text(
                order_line(1, "E11", False, "Type 2 diabetes mellitus", "Type 2 diabetes mellitus")
                + "\n"
                + order_line(2, "E119", True, "Type 2 diab w/o cmp",
                             "Type 2 diabetes mellitus without complications")
                + "\n",
                encoding="utf-8",
            )

            result = subprocess.run(
                [sys.executable, str(SCRIPTS / "import_icd10_cms.py"), str(source), str(output)],
                capture_output=True, text=True, check=True,
            )

            self.assertIn("1 billable, 1 category headers", result.stdout)


if __name__ == "__main__":
    unittest.main()
