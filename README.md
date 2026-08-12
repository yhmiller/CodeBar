# CodeBar

A native macOS app for fast clinical code lookup — ICD-10-CM, LOINC,
SNOMED CT, CPT — with a menu bar panel as the fast path. Press **⌥⌘C** from
anywhere, type a term or a code, hit Return to copy it. Or open the window to
browse the hierarchy, read the publisher's coding notes, and keep your own
lists and annotations.

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

`make check` is the gate: 271 Swift tests, 45 Python tests, a Swift 6
strict-concurrency typecheck of the app target, and an assertion that the module
boundaries hold. Six of the Swift tests are rendered-image snapshots, which cover
the class of bug a view model cannot see.

`make uitest` adds five interaction tests that drive the real app — which window
opens, what reopening does, whether the panel stays out of the way. They are kept
out of `make check` because they take about 25 seconds and quit a running CodeBar.
`make check-all` runs both.

## Using it

- Type a term ("diabetes") or a code prefix ("E11") — both search at once.
  Codes match without their dots, so `E119` finds `E11.9`.
- Clinical shorthand works: `uti`, `copd`, `t2dm`, `gerd` and 22 others expand to
  the words a description actually uses.
- ↑ / ↓ to move the selection, **Return** to copy the highlighted code,
  **Esc** to dismiss.
- **Shift+Return** copies `ICD-10-CM E11.9 — Type 2 diabetes mellitus without
  complications` instead of just the code, for pasting into a note.
- Clicking a result also copies it. The pin icon keeps a code in the empty state.

### The window

Open it from the Dock or the menu bar. Three columns: chapters, the code tree,
and a detail pane carrying the code's ancestry, the codes beneath it, whether it
is billable, and the publisher's own coding notes — including the `Excludes 1`
rules that mean *never code these together*.

Lists live in the sidebar: build a problem list or an encounter template, and add
codes to it from any detail pane.

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
# ICD-10-CM. All three files come from the same CMS download page.
python3 Scripts/import_icd10_cms.py icd10cm_order_2026.txt out.json \
    --release 2026 \
    --tabular icd10cm_tabular_2026.xml \
    --index   icd10cm_index_2026.xml

python3 Scripts/import_loinc_csv.py Loinc.csv out.json --release 2.78
python3 Scripts/import_snomed_rf2.py sct2_Description_Snapshot-en_*.txt out.json
```

The two optional ICD-10-CM files are worth the extra arguments:

- `--tabular` adds the **hierarchy** and the **includes/excludes notes**. Without
  it the window has nothing to browse, and the coding rules are absent.
- `--index` adds the alphabetic index as **search synonyms** — 63,138 phrasings
  clinicians look codes up by. Without it, `chalasia` and `childhood asthma`
  match nothing, because those words appear in no description.

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

Full design in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). What the outside
world offers that CodeBar does not yet use is in
[docs/PRODUCT_RESEARCH.md](docs/PRODUCT_RESEARCH.md).

- **`Packages/CodeCore`** — domain types and the `CodeRepository` protocol.
  No AppKit, no SQLite.
- **`Packages/CodeStore`** — `SQLiteCodeStore`, an actor over SQLite. Codes
  live in a real table with `UNIQUE(system, code)` and an index on the
  normalized code; an external-content FTS5 index is kept in sync by triggers.
  Search is one statement with explicit match tiers: exact code, then code
  prefix, then BM25 over display text and synonyms.
- **`Packages/CodeLibrary`** — your own data: pins, usage history, lists, notes.
  A separate database from the code index, because their lifecycles are opposite.
- **`Packages/SQLiteKit`** — the SQL layer both stores share.
- **`Packages/CodeBarUI`** — the search panel, the browse window and their view
  models. Depends on `CodeCore` only, so it never sees a concrete store.
- **`Packages/CodePlatform`** — AppKit and Carbon glue: the global hotkey, the
  pasteboard, login item, activation policy.
- **`CodeBar/`** — what's left of the app: scenes, the floating `NSPanel`, and
  the composition root.

Because the app is sandboxed, both databases live in
`~/Library/Containers/com.princemiller.CodeBar/Data/Library/Application Support/CodeBar/`:

```
codes.sqlite     the code index — rebuildable, replaced by each yearly release
library.sqlite   your pins, history, lists and notes — irreplaceable
```

Two files, not two tables, so importing a new release can never reach your own
data.

Because storage sits behind `CodeRepository`, the search UI never imports
`CodeStore` — which is what makes both sides testable.

## Your own shorthand

CodeBar expands about two dozen abbreviations nobody argues about — `uti`
searches as "urinary tract infection", which appears in no ICD-10-CM
description, so without it the search finds nothing however well it ranks.

Everything past that point is local, so **Settings → Abbreviations** takes your
own. Adding a term CodeBar already knows replaces its expansion, and the pane
says what it replaced: `RA` is rheumatoid arthritis on most wards and the right
atrium on some, and only the person typing it knows which.

This expands the **query**, never the code. `pcn` searching as "penicillin" is a
fact about vocabulary; pointing `pcn` at a particular code would be a clinical
judgement made on your behalf, and a wrong one reaches a claim. Your shorthand
lives in the library beside your pins, so re-importing a code set never costs
you it.

## Pinned and recent codes

Pin a code from any result row, and it waits for you in the empty state next
time you open the panel — ⌥⌘C then Return, no typing.

This is more than a shortcut. Full-text relevance ranks by how well the text
matches, which is not the same as how often a code is used: typing "diabetes"
against the real 98k-code set surfaces obscure specific codes above E11.9. No
structural property of the data fixes that: weighting descriptions, capping
synonyms and preferring shorter codes were each measured and each made results
worse. Your own pins are the one signal that reflects what you actually mean.

Pins and recents are stored outside the code database, so re-importing a code
set never costs you them.

## Still to come

- Configurable hotkey (currently fixed at ⌥⌘C)
- Export a list as CSV or paste-ready text
- Add to a list from the search panel, not only from the window
- iCloud sync of the library across machines
- Crosswalks between code systems — a separately licensed release, not a column

## Known limits

Worth reading before relying on it.

- **Ranking.** Searching a condition in general terms surfaces its variants
  before its catch-all — `chronic kidney disease` reaches N18.9 behind its
  staged siblings. Relevance cannot know which code a clinician means; the
  structural fixes were measured and made results worse. Pinning is the answer,
  and it ships.
- **The SNOMED converter** has only been exercised against constructed rows, not
  a real distribution. Column positions vary between releases, so check its
  output on your first real file.
- **Interaction coverage** stops at window and panel behaviour. Typing,
  expanding the tree, selecting and copying are still verified by opening the
  app. The one case that cannot be covered at all is restoring a *minimised*
  window from the Dock: a test has to post the reopen event itself, and every
  way of doing that either restores the window on its own or is refused to the
  test runner.
- **Snapshot references are machine-specific.** Fonts, appearance and OS version
  all move the pixels. Appearance is pinned to dark so they do not flip with the
  system setting, but another machine needs its own references or a tolerance.
- **No CI.** `make check` and `make uitest` are the whole gate, and they run by
  hand.
- **Migrations run synchronously on the main actor at launch.** Imperceptible at
  today's scale — 98,186 codes — but a schema change that rewrites rows rather
  than adding columns would block the app while it ran.
- **The bundled starter set reports unknown billability** rather than claiming to
  be billable, because that was never verified against the CMS file. Only
  imported sets carry the flag.
