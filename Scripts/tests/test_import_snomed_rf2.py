#!/usr/bin/env python3
"""Tests for the SNOMED CT RF2 description-file converter."""
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(SCRIPTS))

from import_snomed_rf2 import parse_descriptions, strip_semantic_tag  # noqa: E402

HEADER = ("id\teffectiveTime\tactive\tmoduleId\tconceptId\tlanguageCode\t"
          "typeId\tterm\tcaseSignificanceId")
FSN = "900000000000003001"
SYNONYM = "900000000000013009"


def row(concept_id, type_id, term, active="1", language="en", description_id="1"):
    return (f"{description_id}\t20260101\t{active}\t900000000000207008\t{concept_id}\t"
            f"{language}\t{type_id}\t{term}\t900000000000448009")


class StripSemanticTagTests(unittest.TestCase):
    def test_should_strip_a_trailing_semantic_tag(self):
        self.assertEqual(strip_semantic_tag("Asthma (disorder)"), "Asthma")

    def test_should_leave_a_term_without_a_tag_alone(self):
        self.assertEqual(strip_semantic_tag("Asthma"), "Asthma")

    def test_should_keep_meaningful_parentheses_inside_a_term(self):
        self.assertEqual(
            strip_semantic_tag("Essential (primary) hypertension (disorder)"),
            "Essential (primary) hypertension",
        )

    def test_should_not_reduce_a_term_to_nothing(self):
        self.assertEqual(strip_semantic_tag("(disorder)"), "(disorder)")


class ParseDescriptionsTests(unittest.TestCase):
    def parse(self, rows, **kwargs):
        with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False, encoding="utf-8") as handle:
            handle.write("\n".join([HEADER] + rows) + "\n")
            path = handle.name
        try:
            return parse_descriptions(path, **kwargs)
        finally:
            Path(path).unlink()

    def test_should_use_the_fully_specified_name_as_display_text(self):
        concepts = self.parse([row("195967001", FSN, "Asthma (disorder)")])
        self.assertEqual(concepts["195967001"]["display"], "Asthma")

    def test_should_collect_synonyms_for_a_concept(self):
        concepts = self.parse([
            row("195967001", FSN, "Asthma (disorder)", description_id="1"),
            row("195967001", SYNONYM, "Bronchial asthma", description_id="2"),
        ])
        self.assertIn("Bronchial asthma", concepts["195967001"]["synonyms"])

    def test_should_ignore_inactive_rows(self):
        concepts = self.parse([row("195967001", FSN, "Asthma (disorder)", active="0")])
        self.assertEqual(concepts, {})

    def test_should_ignore_other_languages(self):
        concepts = self.parse([row("195967001", FSN, "Asma (trastorno)", language="es")])
        self.assertEqual(concepts, {})

    def test_should_promote_a_synonym_when_a_concept_has_no_fully_specified_name(self):
        concepts = self.parse([
            row("195967001", SYNONYM, "Bronchial asthma", description_id="1"),
            row("195967001", SYNONYM, "Asthma", description_id="2"),
        ])
        self.assertEqual(concepts["195967001"]["display"], "Asthma")

    def test_should_group_many_description_rows_onto_one_concept(self):
        concepts = self.parse([
            row("195967001", FSN, "Asthma (disorder)", description_id="1"),
            row("195967001", SYNONYM, "Bronchial asthma", description_id="2"),
            row("73211009", FSN, "Diabetes mellitus (disorder)", description_id="3"),
        ])
        self.assertEqual(sorted(concepts), ["195967001", "73211009"])

    def test_should_skip_rows_with_an_empty_term(self):
        concepts = self.parse([row("195967001", FSN, "")])
        self.assertEqual(concepts, {})


if __name__ == "__main__":
    unittest.main()
