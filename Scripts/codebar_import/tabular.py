"""Reads the CMS ICD-10-CM tabular XML: hierarchy and clinical notes.

The order file gives codes, descriptions and billability. It does not give the
tree, and it does not give the includes/excludes notes — and those notes are
often the difference between the right code and a denial.

`excludes1` and `excludes2` are not the same thing and must not be flattened
together: excludes1 means the two conditions cannot occur together and must
never both be coded, while excludes2 means the condition is separate and both
may legitimately be coded.
"""
import xml.etree.ElementTree as ET

# Order matters: it is the order they are shown in.
NOTE_KINDS = [
    "includes",
    "inclusionTerm",
    "excludes1",
    "excludes2",
    "codeFirst",
    "useAdditionalCode",
    "codeAlso",
    "notes",
]

# `notes` is the XML's catch-all; `note` reads better in our own format.
KIND_NAMES = {"notes": "note"}


def _notes_for(diag):
    for kind in NOTE_KINDS:
        for group in diag.findall(kind):
            for note in group.findall("note"):
                text = (note.text or "").strip()
                if text:
                    yield {"kind": KIND_NAMES.get(kind, kind), "text": text}


def _walk(element, chapter, parent=None):
    """Yields every <diag> under `element`, depth first, with its parent code."""
    for diag in element.findall("diag"):
        code = (diag.findtext("name") or "").strip()
        if not code:
            continue

        yield {
            "code": code,
            "display": (diag.findtext("desc") or "").strip(),
            "parent": parent,
            "chapter": chapter,
            "notes": list(_notes_for(diag)),
        }
        # Nesting goes up to five deep in the real file, and the parent is not
        # always the code minus its last character: E11.21's parent is E11.2.
        yield from _walk(diag, chapter, parent=code)


def infer_missing_parents(entries, all_codes):
    """Fills in parents the tabular does not state, using the longest code that
    is a proper prefix of this one.

    The tabular defines seventh-character extensions (S72.001A and friends) by
    rule rather than listing them, so roughly half the order file has no stated
    parent. Without this, those codes all look like top-level categories: 53,223
    apparent roots against the ~1,900 ICD-10-CM actually has.

    Only ever a fallback. Where the publisher states a parent it is used as
    given, because the tree is not always what trimming characters would suggest.
    """
    known = set(all_codes)

    for code in all_codes:
        entry = entries.setdefault(code, {"parent": None, "chapter": None, "notes": []})
        if entry.get("parent"):
            continue

        for cut in range(len(code) - 1, 2, -1):
            candidate = code[:cut].rstrip(".")
            if candidate != code and candidate in known:
                entry["parent"] = candidate
                # Inherit the chapter too, since the same gap leaves it unset.
                if not entry.get("chapter"):
                    entry["chapter"] = entries.get(candidate, {}).get("chapter")
                break

    return entries


def parse_tabular(path):
    """Returns {code: {"parent", "chapter", "notes"}} for every code in the file."""
    root = ET.parse(path).getroot()
    entries = {}

    for chapter in root.findall("chapter"):
        chapter_name = (chapter.findtext("desc") or chapter.findtext("name") or "").strip()
        for section in chapter.findall("section"):
            for entry in _walk(section, chapter_name):
                entries[entry["code"]] = {
                    "parent": entry["parent"],
                    "chapter": entry["chapter"],
                    "notes": entry["notes"],
                }
    return entries
