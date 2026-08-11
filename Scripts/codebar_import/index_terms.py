"""Reads the CMS ICD-10-CM alphabetic index into per-code search synonyms.

The tabular file gives each code its official description. The index gives the
phrasings clinicians actually look codes up by — "Chalasia" for K21.9,
"Bronchitis allergic" for J45.909 — none of which appear in the description text
and so none of which are findable without this.

Entries are nested: a main term with sub-terms that narrow it. The full path is
kept as the phrase, so "Asthma, asthmatic childhood" matches a search for
"childhood asthma" as well as one for "asthma".
"""
import xml.etree.ElementTree as ET

# Some index entries point at another entry rather than a code ("see Diabetes").
# Those carry no code and are skipped rather than guessed at.
MAX_PHRASE_WORDS = 12


def _walk(node, prefix=()):
    title = (node.findtext("title") or "").strip()
    path = prefix + (title,) if title else prefix

    code = (node.findtext("code") or "").strip()
    if code and path:
        yield code, " ".join(path)

    for sub in node.findall("term"):
        yield from _walk(sub, path)


def parse_index(path):
    """Returns {code: [phrase, …]} for every indexed code."""
    root = ET.parse(path).getroot()
    synonyms = {}

    for main in root.iter("mainTerm"):
        for code, phrase in _walk(main):
            # A dagger/asterisk pair like "E10.9-" is a range marker, not a code.
            if code.endswith("-"):
                continue
            if len(phrase.split()) > MAX_PHRASE_WORDS:
                continue
            synonyms.setdefault(code, set()).add(phrase)

    return {code: sorted(phrases) for code, phrases in synonyms.items()}
