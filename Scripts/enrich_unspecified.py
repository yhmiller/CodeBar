#!/usr/bin/env python3
"""
Annotates a CodeBar JSON file with TypeSafe Noul judgments that identify
"unspecified" or catch-all codes (NOS / NEC / "without further specification").

These codes are a leading cause of claim denials — payers flag them as
insufficient medical necessity. The annotation lets CodeBar show a warning
badge at lookup time with no network required.

Usage:
    python3 Scripts/enrich_unspecified.py icd10cm_full.json icd10cm_enriched.json

Requires:
    pip install typesafe-sdk
    export TYPESAFE_API_KEY=<your key>  # create at https://console.typesafe.ai/

The script batches codes into groups (--batch-size, default 50) and sends one
TypeSafe request per batch. Each question is one Noul: probability that the
code is a catch-all. Codes scoring >= --threshold get "unspecified": true;
codes in the ambiguous middle band (threshold_no, threshold_yes) are left
unannotated so no badge is shown.

The script is resume-safe: codes that already carry the "unspecified" field
are skipped. Re-run after a network failure without losing progress.
"""
import argparse
import json
import sys
from pathlib import Path

MODEL = "jev-latest"

# Noul thresholds. Adjust after evaluating on a real ICD-10-CM sample.
# Codes with noul >= THRESHOLD_YES  →  "unspecified": true   (badge shown)
# Codes with noul <= THRESHOLD_NO   →  "unspecified": false  (specific, no badge)
# Codes between the two             →  field absent          (uncertain, no badge)
DEFAULT_THRESHOLD_YES = 0.80
DEFAULT_THRESHOLD_NO = 0.35

# TypeSafe Noul question (same text for every code; the code data is the state)
NOUL_INSTRUCTIONS = {
    "question": (
        "Is `code.display` an 'unspecified', 'other', 'not elsewhere classified' (NEC), "
        "or 'not otherwise specified' (NOS) catch-all code — i.e. one that lacks the "
        "specificity payers require and that would typically be replaced by a more "
        "specific sibling code in a real encounter?"
    ),
    "criteria": {
        "true": (
            "The description contains words like 'unspecified', 'other', 'NOS', 'NEC', "
            "'without further specification', or is clearly the catch-all when multiple "
            "more-specific siblings exist for the same condition."
        ),
        "false": (
            "The description names a specific clinical presentation, laterality, severity, "
            "or complication rather than deferring to an unspecified category."
        ),
    },
}


def _typesafe_available():
    try:
        import typesafe_sdk  # noqa: F401
        return True
    except ImportError:
        return False


def _build_questions(batch):
    """
    Returns a dict of TypeSafe Noul questions, one per code in the batch.
    Question IDs encode the list index so we can look up results later.
    """
    try:
        from typesafe_sdk import Noul, NoulCriteria
    except ImportError:
        raise SystemExit(
            "typesafe-sdk is not installed. Run: pip install typesafe-sdk"
        )

    return {
        f"code_{i}": Noul(
            instructions={
                "code": {
                    "display": entry["display"],
                    "code": entry["code"],
                    "system": entry.get("system", ""),
                },
                "question": NOUL_INSTRUCTIONS["question"],
            },
            criteria=NoulCriteria(
                true=NOUL_INSTRUCTIONS["criteria"]["true"],
                false=NOUL_INSTRUCTIONS["criteria"]["false"],
            ),
        )
        for i, entry in enumerate(batch)
    }


def enrich_batch(client, batch, threshold_yes, threshold_no, dry_run=False):
    """
    Sends one TypeSafe request for the batch. Returns a parallel list of
    Optional[bool] — True/False/None for each code, in order.
    """
    questions = _build_questions(batch)

    if dry_run:
        # Print the first batch payload and exit
        import typesafe_sdk
        payload = {
            "model": MODEL,
            "state": None,
            "questions": {
                qid: {
                    "type": "noul",
                    "instructions": q.instructions,
                    "criteria": {
                        "true": q.criteria.true,
                        "false": q.criteria.false,
                    } if q.criteria else None,
                }
                for qid, q in questions.items()
            },
        }
        print(json.dumps(payload, indent=2, default=str))
        raise SystemExit(0)

    response = client.system_one(
        model=MODEL,
        state=None,  # All context is in the question instructions
        questions=questions,
    )

    results = []
    for i in range(len(batch)):
        answer = response.answers[f"code_{i}"]
        noul_value = answer.noul
        if noul_value >= threshold_yes:
            results.append(True)
        elif noul_value <= threshold_no:
            results.append(False)
        else:
            results.append(None)   # ambiguous — no badge
    return results


def enrich(input_path, output_path, batch_size, threshold_yes, threshold_no,
           dry_run=False, verbose=False):
    data = json.loads(Path(input_path).read_text(encoding="utf-8"))

    # Support both raw list and envelope format
    if isinstance(data, list):
        codes = data
        envelope = None
    else:
        codes = data.get("codes", [])
        envelope = data

    # Identify codes that still need annotation
    pending_indices = [
        i for i, c in enumerate(codes)
        if "unspecified" not in c
    ]

    if not pending_indices:
        print(f"All {len(codes)} codes are already annotated. Nothing to do.")
        return

    print(f"{len(pending_indices)} of {len(codes)} codes need annotation "
          f"({len(codes) - len(pending_indices)} already done).")

    if not _typesafe_available():
        raise SystemExit(
            "typesafe-sdk is not installed. Run: pip install typesafe-sdk"
        )

    from typesafe_sdk import TypeSafeClient

    annotated = 0
    skipped = 0

    with TypeSafeClient() as client:
        for batch_start in range(0, len(pending_indices), batch_size):
            batch_idxs = pending_indices[batch_start:batch_start + batch_size]
            batch = [codes[i] for i in batch_idxs]

            if verbose:
                print(f"  Batch {batch_start // batch_size + 1}: "
                      f"{len(batch)} codes …", end=" ", flush=True)

            judgments = enrich_batch(
                client, batch, threshold_yes, threshold_no, dry_run=dry_run
            )

            for code_idx, judgment in zip(batch_idxs, judgments):
                if judgment is not None:
                    codes[code_idx]["unspecified"] = judgment
                    annotated += 1
                else:
                    skipped += 1

            if verbose:
                yes = sum(1 for j in judgments if j is True)
                no = sum(1 for j in judgments if j is False)
                unk = sum(1 for j in judgments if j is None)
                print(f"unspecified={yes}, specific={no}, uncertain={unk}")

    # Write output
    if envelope is not None:
        envelope["codes"] = codes
        output_data = envelope
    else:
        output_data = codes

    Path(output_path).write_text(
        json.dumps(output_data, indent=2, ensure_ascii=False),
        encoding="utf-8",
    )

    unspecified_total = sum(1 for c in codes if c.get("unspecified") is True)
    print(
        f"\nDone. {annotated} newly annotated, {skipped} left uncertain.\n"
        f"Total unspecified codes: {unspecified_total} of {len(codes)}.\n"
        f"Output: {output_path}"
    )


def enrich_entries(entries, batch_size=50, threshold_yes=DEFAULT_THRESHOLD_YES,
                   threshold_no=DEFAULT_THRESHOLD_NO, verbose=False):
    """
    Convenience API for import_icd10_cms.py (and other callers).

    Accepts a list of raw entry dicts (with at least 'code' and 'display' keys)
    and returns a dict mapping code → True/False/None. None means the Noul was
    ambiguous; callers should not write that to the JSON.
    """
    if not _typesafe_available():
        raise SystemExit(
            "typesafe-sdk is not installed. Run: pip install typesafe-sdk"
        )

    from typesafe_sdk import TypeSafeClient

    result = {}
    pending = [e for e in entries if "unspecified" not in e]

    with TypeSafeClient() as client:
        for batch_start in range(0, len(pending), batch_size):
            batch = pending[batch_start:batch_start + batch_size]

            if verbose:
                print(f"  Enriching batch {batch_start // batch_size + 1} "
                      f"({len(batch)} codes)…", end=" ", flush=True)

            judgments = enrich_batch(
                client, batch, threshold_yes, threshold_no
            )

            for entry, judgment in zip(batch, judgments):
                result[entry["code"]] = judgment

            if verbose:
                yes = sum(1 for j in judgments if j is True)
                no = sum(1 for j in judgments if j is False)
                unk = sum(1 for j in judgments if j is None)
                print(f"unspecified={yes}, specific={no}, uncertain={unk}")

    return result


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("input", help="CodeBar JSON file (envelope or raw list)")
    parser.add_argument("output", nargs="?", default=None,
                        help="Output path (default: overwrites input)")
    parser.add_argument(
        "--threshold-yes", type=float, default=DEFAULT_THRESHOLD_YES,
        help=f"Noul >= this → unspecified: true (default: {DEFAULT_THRESHOLD_YES})",
    )
    parser.add_argument(
        "--threshold-no", type=float, default=DEFAULT_THRESHOLD_NO,
        help=f"Noul <= this → unspecified: false (default: {DEFAULT_THRESHOLD_NO})",
    )
    parser.add_argument(
        "--batch-size", type=int, default=50,
        help="Codes per TypeSafe request (default: 50)",
    )
    parser.add_argument(
        "--dry-run", action="store_true",
        help="Print the first batch payload and exit without writing",
    )
    parser.add_argument(
        "--verbose", "-v", action="store_true",
        help="Print per-batch progress",
    )
    args = parser.parse_args()

    output = args.output or args.input

    enrich(
        input_path=args.input,
        output_path=output,
        batch_size=args.batch_size,
        threshold_yes=args.threshold_yes,
        threshold_no=args.threshold_no,
        dry_run=args.dry_run,
        verbose=args.verbose,
    )


if __name__ == "__main__":
    main()
