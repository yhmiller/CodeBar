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

    def add(self, code, display, synonyms=None, billable=None,
            parent=None, chapter=None, notes=None, unspecified=None):
        """Adds one code. Optional fields stay absent when the source is silent,
        so "unknown" is never confused with "none".

        unspecified: when True, marks this code as an unspecified/catch-all entry
            (e.g. flagged by TypeSafe Noul during an enrichment pass). When None
            (default), the field is omitted and no badge is shown in CodeBar.
        """
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
        if parent:
            entry["parent"] = parent
        if chapter:
            entry["chapter"] = chapter
        if notes:
            entry["notes"] = notes
        if unspecified is not None:
            entry["unspecified"] = bool(unspecified)
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

        synonym_count = sum(len(c.get("synonyms", [])) for c in self.codes)
        if synonym_count:
            lines.append(f"  {synonym_count} search synonyms")

        with_parent = sum(1 for c in self.codes if c.get("parent"))
        note_count = sum(len(c.get("notes", [])) for c in self.codes)
        if with_parent or note_count:
            lines.append(f"  {with_parent} codes have a parent, "
                         f"{note_count} clinical notes")
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
