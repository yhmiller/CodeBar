#!/usr/bin/env python3
"""
Converts a SNOMED CT RF2 description file into CodeBar's import format.

SNOMED CT is licensed. In the United States it is free for use under the UMLS
licence via an NLM account; elsewhere it depends on whether your country has a
National Release Centre and whether your institution is an affiliate. Check
before redistributing anything you produce with this.

Usage:
    python3 import_snomed_rf2.py sct2_Description_Snapshot-en_INT_20260101.txt out.json
    python3 import_snomed_rf2.py <descriptions> <out.json> --release 20260101

The Description file is tab-separated with a header row:

    id  effectiveTime  active  moduleId  conceptId  languageCode  typeId  term
        caseSignificanceId

One concept has many description rows. This script keeps `active=1` rows and
collapses them per concept: the Fully Specified Name becomes the display text
(with its trailing semantic tag stripped, so "Asthma (disorder)" reads
"Asthma"), and the remaining synonym rows become searchable synonyms.

Prefer the *Snapshot* release over Full: Snapshot holds one current row per
description, whereas Full holds every historical version and will give you
superseded terms.
"""
import argparse
import csv
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from codebar_import import CodeSetWriter  # noqa: E402

FULLY_SPECIFIED_NAME = "900000000000003001"
SYNONYM = "900000000000013009"

# Trailing semantic tag, e.g. "Asthma (disorder)".
SEMANTIC_TAG = re.compile(r"\s*\([^()]*\)\s*$")


def strip_semantic_tag(term):
    return SEMANTIC_TAG.sub("", term).strip() or term


def parse_descriptions(path, language="en"):
    """Returns {conceptId: {"display": str, "synonyms": set}} for active rows."""
    concepts = {}

    with open(path, newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle, delimiter="\t")
        for row in reader:
            if row.get("active") != "1":
                continue
            if language and row.get("languageCode") not in (language, None):
                continue

            concept_id = (row.get("conceptId") or "").strip()
            term = (row.get("term") or "").strip()
            if not concept_id or not term:
                continue

            entry = concepts.setdefault(concept_id, {"display": None, "synonyms": set()})
            type_id = row.get("typeId")

            if type_id == FULLY_SPECIFIED_NAME:
                entry["display"] = strip_semantic_tag(term)
            elif type_id == SYNONYM:
                entry["synonyms"].add(term)

    # A concept with no FSN still deserves to be findable: promote its shortest
    # synonym to the display text rather than dropping the concept entirely.
    for entry in concepts.values():
        if entry["display"] is None and entry["synonyms"]:
            entry["display"] = min(entry["synonyms"], key=len)

    return {cid: e for cid, e in concepts.items() if e["display"]}


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("descriptions", help="sct2_Description_Snapshot-*.txt")
    parser.add_argument("output", nargs="?", default="snomed_full.json")
    parser.add_argument("--release", help="release identifier, e.g. 20260101")
    parser.add_argument("--language", default="en", help="languageCode to keep (default: en)")
    parser.add_argument("--mode", default="replace", choices=["merge", "replace"])
    args = parser.parse_args()

    concepts = parse_descriptions(args.descriptions, language=args.language)

    writer = CodeSetWriter("SNOMED CT", release=args.release, mode=args.mode)
    for concept_id, entry in concepts.items():
        # SNOMED has no billability concept, so the flag is deliberately omitted
        # rather than guessed at.
        writer.add(concept_id, entry["display"], synonyms=entry["synonyms"] - {entry["display"]})

    print(writer.write(args.output))


if __name__ == "__main__":
    main()
