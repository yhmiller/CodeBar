#!/usr/bin/env python3
"""
Converts the official CMS ICD-10-CM "order file" (a public domain, fixed-width
text file CMS publishes each year, e.g. icd10cm_order_2026.txt) into the JSON
format CodeBar's "Import Code Set…" menu item expects.

Download the current year's file from the CMS ICD-10-CM site:
https://www.cms.gov/medicare/coding-billing/icd-10-codes

Usage:
    python3 import_icd10_cms.py icd10cm_order_2026.txt icd10cm_full.json

NOTE: CMS's fixed-width column positions have been stable for several years
but can shift slightly release to release. If the parsed descriptions look
truncated or offset, open the source file in a text editor, check the byte
offsets against the layout described in the file's own header/readme, and
adjust CODE_START/CODE_END/etc. below accordingly.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from codebar_import import (  # noqa: E402
    CodeSetWriter, infer_missing_parents, parse_index, parse_tabular
)

ORDER_END = 5
CODE_START = 6
CODE_END = 13
BILLABLE_COL = 14
SHORT_DESC_START = 16
SHORT_DESC_END = 77


def parse_icd10_order_file(path):
    codes = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip():
                continue
            code_raw = line[CODE_START:CODE_END].strip()
            if not code_raw:
                continue
            short_desc = line[SHORT_DESC_START:SHORT_DESC_END].strip()
            long_desc = line[SHORT_DESC_END:].strip() or short_desc

            # Column 14 is CMS's "valid for submission" flag: 1 for a billable
            # code, 0 for a category header such as E11, which requires a further
            # character before it can go on a claim. Carrying this through is a
            # safety matter — the code text alone does not reveal it, and a
            # header submitted on a claim is a denial.
            billable = line[BILLABLE_COL:BILLABLE_COL + 1].strip() == "1"

            # Re-insert the decimal point after the 3rd character, per
            # ICD-10-CM convention (raw file stores codes without the dot).
            code = code_raw if len(code_raw) <= 3 else f"{code_raw[:3]}.{code_raw[3:]}"

            synonyms = short_desc.split() if short_desc and short_desc != long_desc else []
            codes.append({
                "code": code,
                "display": long_desc,
                "system": "ICD-10-CM",
                "synonyms": synonyms,
                "billable": billable,
            })
    return codes


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("order_file", help="icd10cm_order_YYYY.txt from CMS")
    parser.add_argument("output", nargs="?", default="icd10cm_full.json")
    parser.add_argument("--release", help="release year, e.g. 2026")
    # A CMS order file is the complete code set for its year, so replacing is
    # the correct default: codes retired that year should stop being searchable.
    parser.add_argument("--mode", default="replace", choices=["merge", "replace"])
    parser.add_argument(
        "--index",
        help="icd10cm_index_YYYY.xml — adds the phrasings clinicians look codes "
             "up by, which the descriptions do not contain",
    )
    parser.add_argument(
        "--tabular",
        help="icd10cm_tabular_YYYY.xml — adds the code hierarchy and the "
             "includes/excludes notes, which the order file does not carry",
    )
    parser.add_argument(
        "--enrich-unspecified",
        action="store_true",
        help="Run a TypeSafe Noul enrichment pass to badge catch-all codes "
             "(requires TYPESAFE_API_KEY; see Scripts/enrich_unspecified.py)",
    )
    args = parser.parse_args()

    # Both files describe the same release, and importing them together avoids
    # a second replace-mode import wiping the billability the first established.
    entries = parse_icd10_order_file(args.order_file)

    tabular = {}
    if args.tabular:
        tabular = parse_tabular(args.tabular)
        tabular = infer_missing_parents(tabular, [e["code"] for e in entries])

    index = parse_index(args.index) if args.index else {}

    # Optional TypeSafe enrichment pass: annotate catch-all/unspecified codes.
    # Runs before writing so the enrichment is part of the final file.
    unspecified_map = {}
    if args.enrich_unspecified:
        from enrich_unspecified import enrich_entries
        unspecified_map = enrich_entries(entries, verbose=True)

    writer = CodeSetWriter("ICD-10-CM", release=args.release, mode=args.mode)
    for entry in entries:
        extra = tabular.get(entry["code"], {})
        writer.add(entry["code"], entry["display"],
                   synonyms=entry["synonyms"] + index.get(entry["code"], []),
                   billable=entry["billable"],
                   parent=extra.get("parent"), chapter=extra.get("chapter"),
                   notes=extra.get("notes"),
                   unspecified=unspecified_map.get(entry["code"]))

    print(writer.write(args.output))


if __name__ == "__main__":
    main()

