# CodeBar

A native macOS menu bar app for fast clinical code lookup — ICD-10-CM,
LOINC, SNOMED CT, CPT. Click the menu bar icon or press **⌥⌘C** from
anywhere to summon a Spotlight-style search panel, type a term or a code,
hit Return to copy it.

Ships with a ~150-code ICD-10-CM starter set so it's useful immediately.
Import the full official code sets whenever you're ready (see below).

## Setup (Xcode)

1. **File → New → Project → macOS → App.** Name it `CodeBar`, interface:
   SwiftUI, language: Swift. Uncheck "Use Core Data" / "Include Tests"
   (not needed).
2. Delete the auto-generated `ContentView.swift` — this project doesn't use it.
3. Drag the `CodeBar/` folder from this download into your Xcode project
   (into the group with the same name Xcode created). Check **"Copy items
   if needed"** and make sure the target checkbox is ticked.
4. Confirm `Resources/seed_icd10_sample.json` is included in **Target →
   Build Phases → Copy Bundle Resources**. If it's missing, drag it in.
5. **Link SQLite:** select the project → your target → **Build Phases →
   Link Binary With Libraries → +** → add `libsqlite3.tbd`.
6. **Deployment target:** set to **macOS 14.0** or later (uses
   `MenuBarExtra` and `.onKeyPress`, both 14+ APIs).
7. **Menu-bar-only app (optional but recommended):** Target → Info tab →
   add key `Application is agent (UIElement)` (raw key `LSUIElement`) =
   `YES`. This hides the Dock icon and Cmd-Tab entry, so CodeBar behaves
   like a pure menu bar utility.
8. **App Sandbox:** if Xcode enabled it by default (Signing & Capabilities),
   remove it for now. The global hotkey (`NSEvent.addGlobalMonitorForEvents`)
   needs Accessibility permission, which is much simpler to reason about
   outside the sandbox for a personal tool. (If you later want to
   distribute this via the App Store, this is the part that'll need
   rework — sandboxed apps have real restrictions on global event
   monitoring.)
9. Build & run (⌘R). On first launch, macOS will prompt you to grant
   **Accessibility** permission (System Settings → Privacy & Security →
   Accessibility) — this is what lets the global hotkey work from any app.
10. Look for the stethoscope icon in your menu bar. Click it, or press
    **⌥⌘C** from anywhere, to open search.

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
JSON file. Codes are merged into the existing search index (nothing is
overwritten).

For SNOMED CT, there's no script yet since RF2 release file structure
varies by distribution — you'd map the `sct2_Description` file's
`conceptId` and `term` columns (filtering to `active=1` and the fully
specified name or preferred synonym typeId) into the same JSON shape:
`{"code": ..., "display": ..., "system": "SNOMED CT", "synonyms": [...]}`.
Happy to write that converter once you've got a sample file in hand — the
exact columns depend on which release you're pulling from.

## Architecture notes

- **Search:** SQLite FTS5 (`CodeDatabase.swift`), so it scales from the
  ~150-code starter set up to the full ICD-10-CM set (~70k rows) or LOINC
  (~100k+) without changing any query code. Search does a code-prefix
  pass first (typing "E11" surfaces E11.x immediately), then a full-text
  prefix pass over display text and synonyms, deduplicated.
- **Menu bar icon:** SwiftUI `MenuBarExtra` (`CodeBarApp.swift`).
- **Global hotkey + floating panel:** `HotkeyManager.swift` +
  `PanelController.swift`, plain AppKit (`NSEvent` global monitor +
  `NSPanel`), hosting the SwiftUI search view via `NSHostingView`.

## Known limitation to fix if you scale to SNOMED-sized datasets

The code-prefix search pass (`WHERE code LIKE ?`) does a full scan over
the FTS5 table since it's a virtual table without a real column index.
Fine at ICD-10-CM/LOINC scale (tens of thousands of rows, low
single-digit milliseconds). If you add SNOMED CT (350k+ concepts) and
notice lag on code-prefix queries, add a plain (non-FTS5) companion
table indexed on `code` and query that instead for the prefix pass.

## Ideas for v2

- Pinned/recent codes list at the top of empty-query state
- Cmd+Return to copy `"SYSTEM code — description"` instead of just the code
- Per-system toggle in a settings window (hide code systems you don't use)
- Configurable hotkey (currently hardcoded to ⌥⌘C in `HotkeyManager.swift`)
- iCloud sync of pinned codes across machines
