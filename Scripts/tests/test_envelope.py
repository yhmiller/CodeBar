#!/usr/bin/env python3
"""Tests for the shared code-set envelope writer."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS))

from codebar_import import CodeSetWriter  # noqa: E402


class CodeSetWriterTests(unittest.TestCase):
    def test_should_reject_an_unknown_system(self):
        with self.assertRaises(ValueError):
            CodeSetWriter("ICD-11")

    def test_should_reject_an_unknown_mode(self):
        with self.assertRaises(ValueError):
            CodeSetWriter("LOINC", mode="overwrite")

    def test_should_default_to_replace_mode(self):
        self.assertEqual(CodeSetWriter("LOINC").envelope()["mode"], "replace")

    def test_should_stamp_the_current_format_version(self):
        self.assertEqual(CodeSetWriter("LOINC").envelope()["formatVersion"], 1)

    def test_should_omit_billable_when_the_source_cannot_say(self):
        writer = CodeSetWriter("LOINC")
        writer.add("2160-0", "Creatinine")
        self.assertNotIn("billable", writer.envelope()["codes"][0])

    def test_should_record_a_billable_flag_when_given_one(self):
        writer = CodeSetWriter("ICD-10-CM")
        writer.add("E11", "Type 2 diabetes mellitus", billable=False)
        self.assertIs(writer.envelope()["codes"][0]["billable"], False)

    def test_should_skip_entries_with_no_code(self):
        writer = CodeSetWriter("LOINC")
        writer.add("", "Creatinine")
        self.assertEqual(writer.envelope()["codes"], [])

    def test_should_skip_entries_with_no_display_text(self):
        writer = CodeSetWriter("LOINC")
        writer.add("2160-0", "")
        self.assertEqual(writer.envelope()["codes"], [])

    def test_should_deduplicate_synonyms(self):
        writer = CodeSetWriter("LOINC")
        writer.add("2160-0", "Creatinine", synonyms=["serum creatinine", "serum creatinine"])
        self.assertEqual(writer.envelope()["codes"][0]["synonyms"], ["serum creatinine"])

    def test_should_write_a_file_swift_can_parse_as_an_envelope(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "out.json"
            writer = CodeSetWriter("ICD-10-CM", release="2026")
            writer.add("E11", "Type 2 diabetes mellitus", billable=False)
            writer.write(path)

            payload = json.loads(path.read_text(encoding="utf-8"))

            self.assertEqual(
                [payload["formatVersion"], payload["system"], payload["release"], payload["mode"]],
                [1, "ICD-10-CM", "2026", "replace"],
            )

    def test_should_warn_in_the_summary_that_replace_removes_codes(self):
        writer = CodeSetWriter("ICD-10-CM", mode="replace")
        writer.add("E11", "Type 2 diabetes mellitus", billable=False)
        self.assertIn("will be removed on import", writer.summary("out.json"))

    def test_should_record_unspecified_flag_when_given_one(self):
        writer = CodeSetWriter("ICD-10-CM")
        writer.add("E11.9", "Type 2 diabetes mellitus without complications",
                   unspecified=True)
        self.assertIs(writer.envelope()["codes"][0]["unspecified"], True)

    def test_should_omit_unspecified_when_not_provided(self):
        """Backward compatibility: old code sets omit the field entirely."""
        writer = CodeSetWriter("ICD-10-CM")
        writer.add("E11.65", "Type 2 diabetes mellitus with hyperglycemia")
        self.assertNotIn("unspecified", writer.envelope()["codes"][0])


if __name__ == "__main__":
    unittest.main()
