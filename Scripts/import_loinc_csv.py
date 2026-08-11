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
import argparse
import csv
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from codebar_import import CodeSetWriter  # noqa: E402


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


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("csv_file", help="Loinc.csv from the full table download")
    parser.add_argument("output", nargs="?", default="loinc_full.json")
    parser.add_argument("--release", help="LOINC version, e.g. 2.78")
    parser.add_argument("--mode", default="replace", choices=["merge", "replace"])
    args = parser.parse_args()

    # LOINC has no billability concept, so the flag is left absent rather than
    # guessed at — absent means "unknown", which is honest here.
    writer = CodeSetWriter("LOINC", release=args.release, mode=args.mode)
    for entry in parse_loinc_csv(args.csv_file):
        writer.add(entry["code"], entry["display"], synonyms=entry["synonyms"])

    print(writer.write(args.output))


if __name__ == "__main__":
    main()
