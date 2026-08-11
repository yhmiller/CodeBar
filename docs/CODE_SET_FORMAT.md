# CodeBar code-set format

What `Scripts/import_*.py` produces and what **Import Code Set…** reads.
The commands that generate it are in the [README](../README.md#importing-full-code-sets).

## Envelope

```json
{
  "formatVersion": 1,
  "system": "ICD-10-CM",
  "release": "2026",
  "mode": "replace",
  "codes": [
    {
      "code": "E11.9",
      "display": "Type 2 diabetes mellitus without complications",
      "system": "ICD-10-CM",
      "synonyms": ["T2DM", "Diabetes, diabetic type 2"],
      "billable": true,
      "parent": "E11",
      "chapter": "Endocrine, nutritional and metabolic diseases (E00-E89)"
    },
    {
      "code": "E11",
      "display": "Type 2 diabetes mellitus",
      "system": "ICD-10-CM",
      "synonyms": [],
      "billable": false,
      "chapter": "Endocrine, nutritional and metabolic diseases (E00-E89)",
      "notes": [
        { "kind": "includes",  "text": "diabetes NOS" },
        { "kind": "excludes1", "text": "type 1 diabetes mellitus (E10.-)" },
        { "kind": "useAdditionalCode", "text": "insulin (Z79.4)" }
      ]
    }
  ]
}
```

| Field | Required | Meaning |
|---|---|---|
| `formatVersion` | yes | Currently `1`. A file declaring a higher version is refused rather than half-read. |
| `system` | no | `ICD-10-CM`, `LOINC`, `SNOMED CT`, or `CPT`. Checked against the codes: a file claiming to be LOINC while containing ICD-10 codes is rejected, because under `replace` it would delete the wrong set. |
| `release` | no | The publisher's release identifier, e.g. `2026` or `20260101`. Shown so a stale code set is visible rather than silent. |
| `mode` | no | `replace` or `merge`. Defaults to `merge`. |
| `codes` | yes | Must be non-empty. |

### Code entries

| Field | Required | Meaning |
|---|---|---|
| `code` | yes | Display form including punctuation: `E11.9`, `2160-0`. CodeBar also indexes a normalized form, so `E119` finds `E11.9`. |
| `display` | yes | Full description shown in results. |
| `system` | yes | Must match the envelope's `system` when both are present. |
| `synonyms` | no | Additional search terms. Multi-word entries are preserved intact. Defaults to `[]`. |
| `billable` | no | See below. **Absent means unknown, which is not the same as `false`.** |
| `parent` | no | The code one level up. Absent for a top-level code, or when the source carried no hierarchy. |
| `chapter` | no | Grouping label, used when browsing. |
| `notes` | no | The publisher's coding notes, in the order given. |

## `notes`

Each entry is `{ "kind": …, "text": … }`.

| Kind | Meaning |
|---|---|
| `includes` | Terms this code covers |
| `inclusionTerm` | Alternative wordings that map here |
| `excludes1` | **Never code together with this code** |
| `excludes2` | Separate condition; both may be coded |
| `codeFirst` | Sequence the underlying condition first |
| `useAdditionalCode` | Add a further code for detail |
| `codeAlso` | A related code that may also apply |
| `note` | Anything else the publisher attached |

`excludes1` and `excludes2` look alike and mean opposite things. Collapsing them
would be a coding error waiting to happen, so they stay distinct through the
converter, the schema and the UI — which colours `excludes1` apart from every
other kind.

Notes are **replaced** per system on each import rather than merged. They are
publisher content, so the incoming file is the authority; merging would
accumulate notes from superseded releases.

## `parent`

Read from the publisher, never derived. `E11.21`'s parent is `E11.2`, not `E11`,
so trimming characters would build a wrong tree.

The CMS tabular file does not enumerate everything, though. Seventh-character
extensions like `S72.001A` are defined by rule rather than listed, which left
53,223 of 98,186 codes with no stated parent — and every one of them looking like
a top-level category. `infer_missing_parents` fills those with the longest code
that is a proper prefix, strictly as a fallback where the publisher is silent and
never overriding a stated parent. Root count goes from 53,223 to 1,918, which
matches ICD-10-CM's three-character categories.

## `mode`: why `replace` matters

`merge` adds and updates, and never removes. That is right for a partial batch —
a handful of hand-written codes, or a supplementary set.

It is wrong for a yearly release. Each year a publisher retires codes, and a
merge-only import leaves those retired codes searchable forever. A retired code
copied onto a claim is a denial, so a full release should be written with
`"mode": "replace"`, which deletes anything absent from the file.

The converter scripts default to `replace`, since they consume complete official
releases. CodeBar confirms before acting on it, showing how many codes are
installed versus how many the file contains.

Legacy bare-array files (a top-level JSON array, which earlier versions of the
scripts emitted) are still accepted, but always merge — such a file cannot
declare itself complete, so treating it as complete would be unsafe.

## `billable`: why it is three-state

ICD-10-CM contains category headers that must not be submitted on a claim.
`E11` "Type 2 diabetes mellitus" is one: it requires a further character
(`E11.9`) before it is valid. CMS marks this in column 14 of the order file.

Nothing about the code text reveals it. `A09`, `I10` and `R42` are three
characters and perfectly billable, so length is not a shortcut.

The three states are meaningful:

| Value | Meaning | Shown as |
|---|---|---|
| `true` | Publisher says it is valid for submission | nothing |
| `false` | Category header, not valid for submission | orange "category — not billable" badge |
| absent | The source does not say | nothing |

LOINC and SNOMED CT have no billability concept, so their converters omit the
field rather than guessing. Codes imported before this field existed also report
absent. Within a match tier, `false` sorts last; absent ranks with `true` rather
than being penalised for an unknown.

## Size

Measured on the real CMS ICD-10-CM FY2026 order file — 98,186 codes, of which
74,719 are billable and 23,467 are category headers:

| Step | Order file only | With `--tabular --index` |
|---|---|---|
| `import_icd10_cms.py` | 0.9 s, 28 MB of JSON | 1.7 s, 44 MB |
| Decode | 382 ms, 112 MB peak | 569 ms, 159 MB peak |
| Ingest | 218 ms | 331 ms |
| Database on disk | 33 MB | **57 MB** |
| Search | 0.1–64 ms | 0.1–47 ms |

The extra 24 MB buys the hierarchy, 23,910 coding notes, and 63,138 index
phrasings — without which `chalasia` and `childhood asthma` match nothing.

The whole file is held in memory during import, which is comfortable at this
scale and at LOINC's. SNOMED CT is several times larger and would push peak
memory well past this, which is the point at which streaming the file rather
than decoding it whole starts to be worth building. Measure before assuming it
is needed — an earlier estimate built on synthetic data was out by a factor of
two in both code count and memory.
