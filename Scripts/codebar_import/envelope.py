"""Writes CodeBar's versioned code-set interchange format.

The format is documented in docs/CODE_SET_FORMAT.md. The important field is
`mode`: a yearly release should be written as "replace" so that codes the
publisher retired stop being searchable. Merging a new release leaves retired
codes in place forever, and a retired code copied onto a claim is a denial.
"""
import json

FORMAT_VERSION = 1
VALID_SYSTEMS = {"ICD-10-CM", "LOINC", "SNOMED CT", "CPT"}
VALID_MODES = {"merge", "replace"}


class CodeSetWriter:
    """Accumulates codes for one system and writes the envelope."""

    def __init__(self, system, release=None, mode="replace"):
        if system not in VALID_SYSTEMS:
            raise ValueError(f"unknown system {system!r}; expected one of {sorted(VALID_SYSTEMS)}")
        if mode not in VALID_MODES:
            raise ValueError(f"unknown mode {mode!r}; expected one of {sorted(VALID_MODES)}")

        self.system = system
        self.release = release
        self.mode = mode
        self.codes = []

    def add(self, code, display, synonyms=None, billable=None):
        """Adds one code. `billable` stays absent when the source cannot say."""
        if not code or not display:
            return

        entry = {
            "code": code,
            "display": display,
            "system": self.system,
            "synonyms": sorted(set(synonyms or [])),
        }
        if billable is not None:
            entry["billable"] = bool(billable)
        self.codes.append(entry)

    def envelope(self):
        return {
            "formatVersion": FORMAT_VERSION,
            "system": self.system,
            "release": self.release,
            "mode": self.mode,
            "codes": self.codes,
        }

    def write(self, path):
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(self.envelope(), handle, indent=2)
        return self.summary(path)

    def summary(self, path):
        lines = [f"Wrote {len(self.codes)} {self.system} codes to {path}"]

        known = [c for c in self.codes if "billable" in c]
        if known:
            billable = sum(1 for c in known if c["billable"])
            lines.append(f"  {billable} billable, {len(known) - billable} category headers "
                         f"(not valid for submission)")
        if self.release:
            lines.append(f"  release {self.release}")
        if self.mode == "replace":
            lines.append("  mode: replace — codes missing from this file will be removed on import")
        lines.append("In CodeBar: menu bar icon → Import Code Set… → select this file.")
        return "\n".join(lines)


def write_code_set(path, system, codes, release=None, mode="replace"):
    """Convenience wrapper for callers that already have a list of dicts."""
    writer = CodeSetWriter(system, release=release, mode=mode)
    for entry in codes:
        writer.add(
            entry["code"],
            entry["display"],
            synonyms=entry.get("synonyms"),
            billable=entry.get("billable"),
        )
    return writer.write(path)
