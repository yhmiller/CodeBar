#!/usr/bin/env python3
"""
Converts a LOINC CSV export (Loinc.csv, from the full table download at
loinc.org — requires a free account and accepting the LOINC license, which
does permit redistribution within applications like this one) into the JSON
format CodeBar's "Import Code Set…" menu item expects.

Usage:
    python3 import_loinc_csv.py Loinc.csv loinc_full.json

Expects the standard LOINC table columns, in particular LOINC_NUM,
LONG_COMMON_NAME, and SHORTNAME. If your export uses different column
headers, adjust the .get(...) keys below.
"""
import csv
import json
import sys


def parse_loinc_csv(path):
    codes = []
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            code = (row.get("LOINC_NUM") or "").strip()
            display = (row.get("LONG_COMMON_NAME") or "").strip()
            short = (row.get("SHORTNAME") or "").strip()
            if not code or not display:
                continue
            codes.append({
                "code": code,
                "display": display,
                "system": "LOINC",
                "synonyms": [short] if short and short != display else [],
            })
    return codes


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 import_loinc_csv.py <Loinc.csv> [output.json]")
        sys.exit(1)

    src = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else "loinc_full.json"

    codes = parse_loinc_csv(src)
    with open(out, "w", encoding="utf-8") as f:
        json.dump(codes, f, indent=2)

    print(f"Wrote {len(codes)} codes to {out}")
    print("In CodeBar: click the menu bar icon → Import Code Set… → select this file.")
