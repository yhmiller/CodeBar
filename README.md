# CodeBar

A native macOS menu bar app for fast clinical code lookup — ICD-10-CM,
LOINC, SNOMED CT, CPT. Click the menu bar icon or press **⌥⌘C** from
anywhere to summon a Spotlight-style search panel, type a term or a code,
hit Return to copy it.

Ships with a 100-code ICD-10-CM starter set so it's useful immediately.
Import the full official code sets whenever you're ready (see below) — the real
CMS FY2026 release is 98,186 codes and imports in well under a second.

Codes that CMS marks as category headers rather than billable — `E11` "Type 2
diabetes mellitus", for instance, which needs a further character before it can
go on a claim — are labelled as such and ranked below their billable children.
Almost a quarter of the official file is these.

## Install it

```bash
make install
```

That builds a Release copy, puts it in `/Applications`, and launches it. First
run takes a minute or two; after that it's seconds.

You'll need [Homebrew](https://brew.sh). If [XcodeGen](https://github.com/yonaskolb/XcodeGen)
isn't installed yet, run `make bootstrap` once first — it installs XcodeGen and
generates the Xcode project.

Then:

1. Look for the **stethoscope icon** in your menu bar.
2. Open the menu and tick **Open at Login**, so it's there after a restart.
3. Press **⌥⌘C** from any app.

No permission prompts, and it runs inside the App Sandbox. The shortcut uses
`RegisterEventHotKey`, which needs no Accessibility grant and watches nothing
except the one combination it claims. If another app already owns ⌥⌘C, CodeBar
says so at launch instead of failing silently — the menu bar icon still works.

`make uninstall` removes it. Your codes and pins are kept.

## Working on it

```bash
make            # list every command
make run        # build a Debug copy and launch it, without installing
make check      # tests, typecheck, and module-boundary checks
```

`make check` is the gate: 144 Swift tests, 32 Python tests, a Swift 6
strict-concurrency typecheck of the app target, and an assertion that the module
boundaries hold. It does **not** cover the SwiftUI layer — see
[the roadmap](docs/ROADMAP.md#known-gaps) for why that matters.

## Using it

- Type a term ("diabetes") or a code prefix ("E11") — both search at once.
- ↑ / ↓ to move the selection, **Return** to copy the highlighted code,
  **Esc** to dismiss.
- **Shift+Return** copies `ICD-10-CM E11.9 — Type 2 diabetes mellitus without
  complications` instead of just the code, for pasting into a note.
- Clicking a result also copies it. The pin icon keeps a code in the empty state.

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

The converters are in `Scripts/`:

```bash
python3 Scripts/import_icd10_cms.py icd10cm_order_2026.txt out.json --release 2026
python3 Scripts/import_loinc_csv.py Loinc.csv out.json --release 2.78
python3 Scripts/import_snomed_rf2.py sct2_Description_Snapshot-en_*.txt out.json
```

The output format, including why `billable` is three-state and why a yearly
release should replace rather than merge, is documented in
[docs/CODE_SET_FORMAT.md](docs/CODE_SET_FORMAT.md).

Then in CodeBar: menu bar icon → **Import Code Set…** → pick the generated
JSON file. Codes are keyed on system + code, so importing the same file twice
is a no-op and re-importing a newer release updates descriptions in place.

The converters write `"mode": "replace"`, because an official release is the
complete set for its year — anything the publisher retired should stop being
searchable. CodeBar asks for confirmation before acting on that, showing how
many codes are installed against how many the file contains.

The SNOMED converter is written against the published RF2 layout but has only
been exercised against constructed rows, not a real distribution. Column
positions vary between releases, so check its output on your first real file.

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

## Pinned and recent codes

Pin a code from any result row, and it waits for you in the empty state next
time you open the panel — ⌥⌘C then Return, no typing.

This is more than a shortcut. Full-text relevance ranks by how well the text
matches, which is not the same as how often a code is used: typing "diabetes"
against the real 98k-code set surfaces obscure specific codes above E11.9. No
structural property of the data fixes that, and
[the alternatives were measured and rejected](docs/ROADMAP.md#open-ranking-does-not-match-clinical-frequency).
Your own pins are the one signal that reflects what you actually mean.

Pins and recents are stored outside the code database, so re-importing a code
set never costs you them.

## Still to come

Tracked as [phase 6](docs/ROADMAP.md#phase-6--settings-pins-copy-formats).

- Per-system toggle in a settings window (hide code systems you don't use)
- Code-set management: see installed releases, remove a set
- Configurable hotkey (currently fixed at ⌥⌘C)
- iCloud sync of pinned codes across machines
