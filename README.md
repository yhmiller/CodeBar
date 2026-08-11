# CodeBar

A native macOS menu bar app for fast clinical code lookup — ICD-10-CM,
LOINC, SNOMED CT, CPT. Click the menu bar icon or press **⌥⌘C** from
anywhere to summon a Spotlight-style search panel, type a term or a code,
hit Return to copy it.

Ships with a 100-code ICD-10-CM starter set so it's useful immediately.
Import the full official code sets whenever you're ready (see below).

## Setup

```bash
make bootstrap        # installs XcodeGen if needed, generates CodeBar.xcodeproj
open CodeBar.xcodeproj
```

Then build and run (⌘R). Everything that used to be a manual Xcode step —
deployment target, `LSUIElement`, SQLite linking, bundle resources — lives in
[project.yml](project.yml), so the project file is generated and never
committed.

No permission prompts, and the app runs inside the App Sandbox. The global
shortcut is registered with `RegisterEventHotKey`, which needs no Accessibility
grant and does not observe anything except the one combination it claims.

Look for the stethoscope icon in your menu bar. Click it, or press **⌥⌘C**
from anywhere, to open search.

If another app already owns ⌥⌘C, CodeBar says so at launch rather than failing
silently, and the menu bar icon keeps working.

### Working on it

```bash
make check       # package tests + Swift 6 typecheck of the app target
make test        # 58 tests across CodeCore and CodeStore
```

## Using it

- Type a term ("diabetes") or a code prefix ("E11") — both search at once.
- ↑ / ↓ to move the selection, **Return** to copy the highlighted code,
  **Esc** to dismiss.
- Clicking a result also copies it.

## Importing full code sets

The bundled starter set is intentionally small (common outpatient codes)
so the app is useful the moment you build it. For real work you'll want
the full official sets:

| System | Source | License |
|---|---|---|
| **ICD-10-CM** | [CMS.gov](https://www.cms.gov/medicare/coding-billing/icd-10-codes) — free "order file" download | U.S. government work, public domain |
| **LOINC** | [loinc.org](https://loinc.org) — free account required | Free, but requires accepting the LOINC license before redistribution |
| **SNOMED CT** | Requires a [UMLS](https://www.nlm.nih.gov/research/umls/index.html) account / national release center | Licensed — check your institution's affiliate status |
| **CPT** | AMA | Proprietary, licensed separately — cannot be bundled or freely redistributed |

Two converter scripts are in `Scripts/`:

```bash
python3 Scripts/import_icd10_cms.py icd10cm_order_2026.txt icd10cm_full.json
python3 Scripts/import_loinc_csv.py Loinc.csv loinc_full.json
```

Then in CodeBar: menu bar icon → **Import Code Set…** → pick the generated
JSON file. Codes are merged into the existing index, keyed on system + code:
importing the same file twice is a no-op, and re-importing a newer release
updates the descriptions in place.

Note that merging never *removes* anything, so a code retired by the publisher
stays searchable. Replace semantics — which fix that — need the versioned file
format from [phase 7](docs/ROADMAP.md#phase-7--versioned-interchange-format);
the store already supports them.

For SNOMED CT, there's no script yet since RF2 release file structure
varies by distribution — you'd map the `sct2_Description` file's
`conceptId` and `term` columns (filtering to `active=1` and the fully
specified name or preferred synonym typeId) into the same JSON shape:
`{"code": ..., "display": ..., "system": "SNOMED CT", "synonyms": [...]}`.
Happy to write that converter once you've got a sample file in hand — the
exact columns depend on which release you're pulling from.

## Architecture

Full design in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md); progress in
[docs/ROADMAP.md](docs/ROADMAP.md).

- **`Packages/CodeCore`** — domain types and the `CodeRepository` protocol.
  No AppKit, no SQLite.
- **`Packages/CodeStore`** — `SQLiteCodeStore`, an actor over SQLite. Codes
  live in a real table with `UNIQUE(system, code)` and an index on the
  normalized code; an external-content FTS5 index is kept in sync by triggers.
  Search is one statement with explicit match tiers: exact code, then code
  prefix, then BM25 over display text and synonyms.
- **`Packages/CodeBarUI`** — the search panel view and its view model. Depends on
  `CodeCore` only, so it never sees the concrete store.
- **`Packages/CodePlatform`** — AppKit and Carbon glue: the global hotkey and the
  pasteboard.
- **`CodeBar/`** — what's left of the app: `MenuBarExtra`, the floating `NSPanel`,
  and the composition root.

Because the app is sandboxed, its database lives in
`~/Library/Containers/com.princemiller.CodeBar/Data/Library/Application Support/CodeBar/`.

Because storage sits behind `CodeRepository`, the search UI never imports
`CodeStore` — which is what makes both sides testable.

## Ideas for v2

Tracked as [phase 6](docs/ROADMAP.md#phase-6--settings-pins-copy-formats).

- Pinned/recent codes list at the top of empty-query state
- Cmd+Return to copy `"SYSTEM code — description"` instead of just the code
- Per-system toggle in a settings window (hide code systems you don't use)
- Configurable hotkey (currently hardcoded to ⌥⌘C)
- iCloud sync of pinned codes across machines
