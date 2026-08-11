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
import json
import sys

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

            # Re-insert the decimal point after the 3rd character, per
            # ICD-10-CM convention (raw file stores codes without the dot).
            code = code_raw if len(code_raw) <= 3 else f"{code_raw[:3]}.{code_raw[3:]}"

            synonyms = short_desc.split() if short_desc and short_desc != long_desc else []
            codes.append({
                "code": code,
                "display": long_desc,
                "system": "ICD-10-CM",
                "synonyms": synonyms,
            })
    return codes


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 import_icd10_cms.py <order_file.txt> [output.json]")
        sys.exit(1)

    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "icd10cm_full.json"

    codes = parse_icd10_order_file(src)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(codes, f, indent=2)

    print(f"Wrote {len(codes)} codes to {out}")
    print("In CodeBar: click the menu bar icon → Import Code Set… → select this file.")
