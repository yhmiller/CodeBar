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

from codebar_import import CodeSetWriter, infer_missing_parents, parse_tabular  # noqa: E402

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
        "--tabular",
        help="icd10cm_tabular_YYYY.xml — adds the code hierarchy and the "
             "includes/excludes notes, which the order file does not carry",
    )
    args = parser.parse_args()

    # Both files describe the same release, and importing them together avoids
    # a second replace-mode import wiping the billability the first established.
    entries = parse_icd10_order_file(args.order_file)

    tabular = {}
    if args.tabular:
        tabular = parse_tabular(args.tabular)
        tabular = infer_missing_parents(tabular, [e["code"] for e in entries])

    writer = CodeSetWriter("ICD-10-CM", release=args.release, mode=args.mode)
    for entry in entries:
        extra = tabular.get(entry["code"], {})
        writer.add(entry["code"], entry["display"],
                   synonyms=entry["synonyms"], billable=entry["billable"],
                   parent=extra.get("parent"), chapter=extra.get("chapter"),
                   notes=extra.get("notes"))

    print(writer.write(args.output))


if __name__ == "__main__":
    main()
