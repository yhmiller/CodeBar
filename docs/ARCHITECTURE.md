# CodeBar — Architecture & Restructure Proposal

Scope: the whole repo — build system, module layout, storage schema, concurrency,
hotkey mechanism, and the JSON interchange format.

Status: phases 0–4 and 7 are implemented, 5 was skipped, 6 is in progress.
**[ROADMAP.md](ROADMAP.md) tracks what has actually landed** and logs every
deviation from this document. Sections below describe the target design, not
necessarily today's code.

**§11 supersedes the scope of §3–4**: CodeBar is now a full native app that keeps
the menu bar panel. Read it before making structural decisions.

**The module list in §3–4 is also superseded.** Six packages exist, not four:
`SQLiteKit` (the SQL layer both stores share) and `CodeLibrary` (the user's own
data, on the opposite lifecycle to the code index) were added afterwards. §11 has
the current shape; `make layering` has the enforced rules.

---

## 1. Current state

7 Swift files, ~400 LOC, 2 Python scripts, a 100-code seed file. No Xcode project,
no tests, no version control.

```
CodeBar/
├── README.md
├── Scripts/
│   ├── import_icd10_cms.py            fixed-width CMS order file → JSON
│   └── import_loinc_csv.py            Loinc.csv → JSON
└── CodeBar/
    ├── CodeBarApp.swift               @main, MenuBarExtra, wires singletons in init()
    ├── Models/ClinicalCode.swift      struct + CodeSystem enum
    ├── Data/CodeDatabase.swift        singleton, raw SQLite3, FTS5 table, 2-pass search
    ├── Support/
    │   ├── HotkeyManager.swift        NSEvent global monitor, hardcoded ⌥⌘C
    │   ├── PanelController.swift      NSPanel + NSHostingView   ← type is SearchPanelController
    │   └── CodeImporter.swift         NSOpenPanel → JSONDecoder → CodeDatabase
    ├── Views/
    │   ├── SearchPanelView.swift      calls CodeDatabase.shared directly
    │   └── ResultRow.swift
    └── Resources/seed_icd10_sample.json   100 codes, all ICD-10-CM
```

Two corrections to the README while we're here:

- The seed set is **100 codes**, not ~150.
- `Support/PanelController.swift` declares `SearchPanelController`. File name and type
  should match (your own naming rule: PascalCase file per class).

The design instincts are right — FTS5 for search, AppKit for the panel, SwiftUI for
content. The problems are all in the layer below that.

---

## 2. What's actually wrong

### Bugs live today

| # | Issue | Where | Impact |
|---|---|---|---|
| 1 | **Re-importing a file duplicates every row.** `codes_fts` has no unique constraint and import is a bare `INSERT`. Import the 2026 ICD file twice → 148k rows, every result doubled. | `CodeDatabase.importCodes` | Silent data corruption |
| 2 | **Every SQLite return code is ignored.** `prepare_v2`, `step`, `bind` results are all discarded; failures `print()` at best. A failed open leaves `db == nil` and every later call no-ops. | `CodeDatabase` throughout | Silent failure |
| 3 | **`BEGIN`/`COMMIT` with no rollback path.** A mid-import failure leaves a partial code set committed. | `importCodes:74-87` | Partial data |
| 4 | **Search runs synchronously on the main thread on every keystroke**, with no debounce and no cancellation. | `SearchPanelView.runSearch:83` | Beachball at real scale |
| 5 | **Multi-word synonyms are destroyed on round-trip.** Stored space-joined, split on space when read: `["type 2 diabetes"]` → `["type","2","diabetes"]`. | `importCodes:82` / `rowToCode:167` | Model lies about its data |
| 6 | **`E119` doesn't find `E11.9`.** Prefix pass matches the literal stored string, dots included. | `search:109` | Real usability gap — people type codes without dots |
| 7 | **The global monitor doesn't consume the event.** ⌥⌘C fires CodeBar *and* passes through to the frontmost app. | `HotkeyManager:20` | Fires unrelated shortcuts |
| 8 | **Panel state resets and re-centers on every open**, and `hidesOnDeactivate = false` means clicking away leaves it floating. | `SearchPanelController.show` | Not Spotlight-like |
| 9 | **Retired codes never disappear.** Import is merge-only, so a code deleted in the 2026 release stays searchable forever. | design | Clinical hazard, see §5.5 |

### Structural

- **No project file.** README steps 1–8 are manual Xcode clicking. The build isn't
  reproducible and nothing about the target config is reviewable.
- **No version control.** Not a git repo.
- **No seam for tests.** Views call `CodeDatabase.shared` directly. Four singletons,
  zero injection points.
- **FTS5 used as primary storage.** This is the root cause of #1, #3, #6, and the
  "known limitation" the README documents. A virtual table can't carry a unique
  constraint or a B-tree index — so you get no dedup and a full scan on code prefix.
- **`Support/` is a junk drawer** holding three unrelated concerns.
- **Not Swift 6 ready.** A raw `OpaquePointer` on a singleton, main-thread-only by
  accident. Strict concurrency will reject it.

---

## 3. Target architecture

Four local SPM packages plus a thin app target. Dependencies point one way only.

```
                    ┌──────────────────┐
                    │  CodeBar (app)   │   @main, DI wiring, Info.plist, assets
                    └────────┬─────────┘
                             │ composes
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
      ┌──────────────┐ ┌───────────┐ ┌──────────────┐
      │  CodeBarUI   │ │ CodeStore │ │ CodePlatform │
      │ SwiftUI +    │ │ SQLite +  │ │ AppKit glue: │
      │ view models  │ │ FTS5      │ │ hotkey,panel │
      └───────┬──────┘ └─────┬─────┘ └──────┬───────┘
              └──────────────┼──────────────┘
                             ▼
                     ┌──────────────┐
                     │   CodeCore   │   pure Swift. No AppKit. No SQLite.
                     └──────────────┘
```

**The one rule that matters: `CodeBarUI` never imports `CodeStore`.** The UI sees only
the `CodeRepository` protocol declared in `CodeCore`. That single seam is what makes the
view model testable, and it's what lets you swap the storage implementation (see §9)
without touching a view.

| Module | Owns | Depends on |
|---|---|---|
| `CodeCore` | `ClinicalCode`, `CodeSystem`, `SearchResult`, `CopyFormat`, `Preferences`, and the `CodeRepository` / `HotkeyRegistering` / `PasteboardWriting` protocols | nothing |
| `CodeStore` | `SQLiteCodeStore` (actor), schema + migrations, SQL statement wrapper, bulk importer | `CodeCore`, `libsqlite3` |
| `CodePlatform` | Carbon hotkey registration, `SearchPanel: NSPanel`, panel presenter, pasteboard, Accessibility/permission checks | `CodeCore`, AppKit |
| `CodeBarUI` | `SearchPanelView`, `SearchViewModel`, `ResultRow`, settings UI, design tokens | `CodeCore` |
| `CodeBar` (app) | `@main`, `AppEnvironment` composition root, Info.plist, entitlements, assets, seed resource | all of the above |

For a ~400-line app, four modules is a lot — and your own rule says no premature
abstraction. The honest minimum is **two**: `CodeCore` (domain + protocols) and everything
else in the app target. If you only ever want the testability win, do that. I'm proposing
four because `CodePlatform` and `CodeStore` are the two places that *can't* be tested
without isolation, and splitting them is what makes the compiler enforce the rule rather
than your discipline.

---

## 4. Directory layout

```
CodeBar/
├── .gitignore
├── project.yml                        XcodeGen — the project file becomes reviewable
├── Makefile                           bootstrap / build / test / lint
├── README.md
├── docs/
│   ├── ARCHITECTURE.md                this file
│   └── CODE_SET_FORMAT.md             the JSON interchange contract (§5.5)
│
├── App/
│   ├── CodeBarApp.swift               @main — scene declaration only
│   ├── AppEnvironment.swift           composition root: builds and holds the graph
│   ├── AppDelegate.swift              lifecycle, hotkey teardown
│   ├── Info.plist                     LSUIElement=YES lives here, not in an Xcode click
│   ├── CodeBar.entitlements           sandbox on (see §5.4)
│   ├── Assets.xcassets
│   └── Resources/
│       └── seed_icd10_sample.json
│
├── Packages/
│   ├── CodeCore/
│   │   ├── Package.swift
│   │   ├── Sources/CodeCore/
│   │   │   ├── Model/
│   │   │   │   ├── ClinicalCode.swift
│   │   │   │   ├── CodeSystem.swift
│   │   │   │   └── CodeSetManifest.swift      system + release + row count
│   │   │   ├── Search/
│   │   │   │   ├── SearchQuery.swift          normalization, tokenizing
│   │   │   │   ├── SearchResult.swift         code + match tier
│   │   │   │   └── CodeRepository.swift       ← the seam
│   │   │   ├── Copy/CopyFormat.swift          code-only / code+display / full
│   │   │   └── Preferences/Preferences.swift  enabled systems, hotkey, copy format
│   │   └── Tests/CodeCoreTests/
│   │
│   ├── CodeStore/
│   │   ├── Package.swift
│   │   ├── Sources/CodeStore/
│   │   │   ├── SQLiteCodeStore.swift          actor, conforms to CodeRepository
│   │   │   ├── SQL/
│   │   │   │   ├── Database.swift             open, pragmas, exec, transaction
│   │   │   │   ├── Statement.swift            typed bind/step/read, throwing
│   │   │   │   └── SQLiteError.swift
│   │   │   ├── Schema/
│   │   │   │   ├── Schema.swift               DDL, current version
│   │   │   │   └── Migrations.swift           PRAGMA user_version ladder
│   │   │   └── Import/
│   │   │       ├── CodeSetDecoder.swift       both JSON shapes, streaming
│   │   │       └── CodeSetIngestor.swift      chunked upsert + progress
│   │   └── Tests/CodeStoreTests/              against :memory:, no mocks
│   │
│   ├── CodePlatform/
│   │   ├── Package.swift
│   │   ├── Sources/CodePlatform/
│   │   │   ├── Hotkey/
│   │   │   │   ├── CarbonHotkeyRegistrar.swift
│   │   │   │   └── KeyCombo.swift
│   │   │   ├── Panel/
│   │   │   │   ├── SearchPanel.swift          NSPanel subclass
│   │   │   │   └── SearchPanelPresenter.swift show / hide / toggle / frame restore
│   │   │   └── System/
│   │   │       ├── Pasteboard.swift
│   │   │       └── FileImportPicker.swift
│   │   └── Tests/CodePlatformTests/
│   │
│   └── CodeBarUI/
│       ├── Package.swift
│       ├── Sources/CodeBarUI/
│       │   ├── Search/
│       │   │   ├── SearchPanelView.swift
│       │   │   ├── SearchViewModel.swift      @MainActor @Observable
│       │   │   ├── ResultRow.swift
│       │   │   └── EmptyStateView.swift       recents / pinned live here
│       │   ├── Settings/
│       │   │   ├── SettingsView.swift
│       │   │   ├── CodeSetsSettingsView.swift import, remove, show release
│       │   │   └── HotkeySettingsView.swift
│       │   └── DesignSystem/
│       │       ├── Tokens.swift               spacing, radii, type scale
│       │       └── SystemBadgeStyle.swift     the per-system colors
│       └── Tests/CodeBarUITests/              view model only, fake repository
│
├── Scripts/
│   ├── codebar_import/
│   │   ├── __init__.py
│   │   ├── envelope.py                 shared writer + schema validation
│   │   ├── icd10_cms.py
│   │   ├── loinc.py
│   │   └── snomed_rf2.py               currently missing
│   ├── import_icd10_cms.py             thin CLI shims, kept for compatibility
│   ├── import_loinc_csv.py
│   └── tests/
└── Tools/
    └── bootstrap.sh                    brew install xcodegen && xcodegen
```

---

## 5. Key designs

### 5.1 Storage schema (highest-value change)

Stop using FTS5 as the source of truth. Use a real table plus an **external-content**
FTS5 index kept in sync by triggers.

```sql
PRAGMA user_version = 2;

-- Row counts are deliberately absent here and computed from `codes` at read
-- time: a cached count drifts after a partial delete, and the indexed `system`
-- column makes computing it free.
CREATE TABLE code_sets (
    system      TEXT PRIMARY KEY,        -- 'ICD-10-CM'
    release     TEXT,                    -- '2026'
    imported_at INTEGER NOT NULL
);

CREATE TABLE codes (
    id            INTEGER PRIMARY KEY,
    system        TEXT NOT NULL,
    code          TEXT NOT NULL,         -- 'E11.9' as displayed
    code_norm     TEXT NOT NULL,         -- 'E119'  uppercased, punctuation stripped
    display       TEXT NOT NULL,
    synonyms_json TEXT NOT NULL DEFAULT '[]',  -- fidelity: multi-word synonyms survive
    synonyms_text TEXT NOT NULL DEFAULT '',    -- flattened, this is what FTS indexes
    UNIQUE(system, code)
);

CREATE INDEX idx_codes_code_norm ON codes(code_norm);
CREATE INDEX idx_codes_system    ON codes(system);

CREATE VIRTUAL TABLE codes_fts USING fts5(
    display, synonyms_text,
    content = 'codes', content_rowid = 'id',
    tokenize = 'porter unicode61'
);

CREATE TRIGGER codes_ai AFTER INSERT ON codes BEGIN
    INSERT INTO codes_fts(rowid, display, synonyms_text)
    VALUES (new.id, new.display, new.synonyms_text);
END;
CREATE TRIGGER codes_ad AFTER DELETE ON codes BEGIN
    INSERT INTO codes_fts(codes_fts, rowid, display, synonyms_text)
    VALUES ('delete', old.id, old.display, old.synonyms_text);
END;
CREATE TRIGGER codes_au AFTER UPDATE ON codes BEGIN
    INSERT INTO codes_fts(codes_fts, rowid, display, synonyms_text)
    VALUES ('delete', old.id, old.display, old.synonyms_text);
    INSERT INTO codes_fts(rowid, display, synonyms_text)
    VALUES (new.id, new.display, new.synonyms_text);
END;
```

What this buys, per bug in §2:

- `UNIQUE(system, code)` + upsert → **import becomes idempotent** (fixes #1).
- `idx_codes_code_norm` → prefix search becomes an **index range scan** instead of a full
  table scan. This resolves the README's "known limitation" outright, at every scale, not
  just SNOMED's (fixes the scan).
- `code_norm` → typing `E119` finds `E11.9` (fixes #6).
- `synonyms_json` → multi-word synonyms survive the round trip (fixes #5).
- External content → FTS stops storing a second copy of every display string;
  roughly halves the database file.
- `code_sets` → you can show "ICD-10-CM · 2026 · 74,260 codes" and offer per-system
  replace/remove (addresses #9).

Import becomes:

```sql
INSERT INTO codes (system, code, code_norm, display, synonyms_json, synonyms_text)
VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(system, code) DO UPDATE SET
    code_norm     = excluded.code_norm,
    display       = excluded.display,
    synonyms_json = excluded.synonyms_json,
    synonyms_text = excluded.synonyms_text;
```

Connection pragmas at open: `journal_mode = WAL`, `synchronous = NORMAL`,
`foreign_keys = ON`. After a bulk import: `INSERT INTO codes_fts(codes_fts) VALUES('optimize')`
then `PRAGMA optimize`.

**Migration from v1.** `user_version` is currently 0 with a bare `codes_fts` table.
The migration reads existing rows out, creates the v2 schema, and re-inserts through the
upsert — which incidentally de-duplicates anyone already bitten by bug #1. Roughly 20
lines, one transaction. Don't drop and re-seed; people have imported files you can't
re-fetch (SNOMED and CPT aren't redistributable).

### 5.2 Search

One statement instead of two stitched-together passes with incompatible limits and
orderings. Explicit match tiers make ranking deterministic and testable.

```sql
WITH code_hits AS (
    SELECT id,
           CASE WHEN code_norm = :norm THEN 0 ELSE 1 END AS tier,
           0.0 AS rank
    FROM codes
    WHERE code_norm >= :norm AND code_norm < :norm_upper   -- index range scan
    LIMIT 25
),
text_hits AS (
    SELECT rowid AS id, 2 AS tier, bm25(codes_fts, 2.0, 1.0) AS rank
    FROM codes_fts
    WHERE codes_fts MATCH :match
    ORDER BY rank
    LIMIT 50
),
hits AS (SELECT * FROM code_hits UNION ALL SELECT * FROM text_hits)
SELECT c.system, c.code, c.display, c.synonyms_json, MIN(h.tier) AS tier
FROM hits h JOIN codes c ON c.id = h.id
WHERE c.system IN (/* enabled systems */)
GROUP BY c.id
ORDER BY tier, MIN(h.rank), LENGTH(c.code)
LIMIT 30;
```

Two things worth calling out:

- `code_norm >= :norm AND code_norm < :norm_upper` (norm with the last character
  incremented) is the formulation that reliably uses the index. `LIKE 'E11%'` only gets
  optimized under specific collation/pragma conditions — don't rely on it.
- `bm25(codes_fts, 2.0, 1.0)` weights a display-text match above a synonym match. The
  current code takes default weights.

Tier 0/1/2 exposed as `SearchResult.matchTier` also lets the UI show *why* something
matched, and gives tests something concrete to assert on ("exact code ranks above
text match") instead of asserting on array positions.

### 5.3 Concurrency

`SQLiteCodeStore` becomes an `actor`. `CodeRepository` is async:

```swift
public protocol CodeRepository: Sendable {
    func search(_ query: SearchQuery) async throws -> [SearchResult]
    func manifests() async throws -> [CodeSetManifest]
    func ingest(_ source: CodeSetSource, progress: @Sendable (Double) -> Void) async throws
    func removeCodeSet(_ system: CodeSystem) async throws
}
```

The view model debounces and cancels, which is what fixes bug #4:

```swift
@MainActor @Observable
public final class SearchViewModel {
    public private(set) var results: [SearchResult] = []
    public var query = "" { didSet { scheduleSearch() } }

    private let repository: CodeRepository
    private var searchTask: Task<Void, Never>?

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query
        searchTask = Task { [repository] in
            try? await Task.sleep(for: .milliseconds(SEARCH_DEBOUNCE))
            guard !Task.isCancelled else { return }
            let found = (try? await repository.search(.init(raw: text))) ?? []
            guard !Task.isCancelled else { return }
            results = found
        }
    }
}
```

The double cancellation check is the part that matters — it's what stops a slow query for
"dia" from landing after a fast one for "diabetes".

### 5.4 Hotkey — replace the global monitor

`NSEvent.addGlobalMonitorForEvents` is the wrong API here, and it's the reason the README
has to tell people to turn off the sandbox and grant Accessibility.

Use Carbon `RegisterEventHotKey` (`import Carbon.HIToolbox`) instead. It is still the
supported mechanism for system-wide hotkeys and it changes four things at once:

| | Global monitor (now) | `RegisterEventHotKey` |
|---|---|---|
| Accessibility permission | required | **not required** |
| App Sandbox | must be off | **works sandboxed** |
| Event consumed | no — leaks to frontmost app (bug #7) | **yes** |
| Rebindable at runtime | awkward | unregister + re-register |

This deletes README steps 8 and 9, removes the scary first-launch permission prompt, makes
the "configurable hotkey" v2 idea a small feature instead of a redesign, and puts App Store
distribution back on the table. If you'd rather not hand-roll the Carbon bridge, Sindre
Sorhus's `KeyboardShortcuts` package wraps exactly this and ships a recorder control.

Sandbox note: `NSOpenPanel` still works sandboxed — Powerbox grants read access to the file
the user picks. Import needs no entitlement beyond `com.apple.security.files.user-selected.read-only`.

### 5.5 Interchange format — version it

Current format is a bare JSON array, which can't express "this is the 2026 ICD-10-CM
release, replace what you have." Move to an envelope, accept both shapes:

```json
{
  "formatVersion": 1,
  "system": "ICD-10-CM",
  "release": "2026",
  "mode": "replace",
  "codes": [
    { "code": "E11.9", "display": "Type 2 diabetes mellitus without complications",
      "synonyms": ["type 2 diabetes", "T2DM"] }
  ]
}
```

`mode: "replace"` is the clinically important part. Merge-only import means a code retired
in the 2026 release stays searchable forever, and a stale ICD code copied into a chart is a
denial. Replace semantics per system, plus the release stamp shown in settings, closes that.

Decode this **streaming**, not with `JSONDecoder.decode([ClinicalCode].self, from: data)`.
350k SNOMED concepts fully materialized as Swift structs is several hundred MB resident.
Chunk it — decode N thousand, upsert in a transaction, report progress, repeat.

### 5.6 Data ownership — one boundary worth drawing

Split derived data from user data:

- `~/Library/Application Support/CodeBar/codes.sqlite` — **disposable**. Rebuildable from
  the seed plus the user's import files. Safe to delete and re-create on a corrupt migration.
- Pinned codes, recents, enabled systems, hotkey, copy format — **user data**. `UserDefaults`,
  or `NSUbiquitousKeyValueStore` when you want the iCloud sync from the v2 list.

Keeping pins out of the SQLite file means "nuke and rebuild the index" is never a
destructive operation. If pins lived in `codes.sqlite`, every schema migration would put
them at risk.

---

## 6. Testing

Per your testing rules — real implementations, mock only at boundaries.

| Target | Approach | Representative cases |
|---|---|---|
| `CodeCoreTests` | pure | code normalization (`e11.9` → `E119`), FTS token escaping for quotes/hyphens, copy formatting per `CopyFormat` |
| `CodeStoreTests` | **real SQLite at `:memory:`** | importing the same set twice leaves row count unchanged; exact code outranks text match; `E119` finds `E11.9`; multi-word synonym survives round trip; v1→v2 migration preserves row count and de-duplicates; replace mode removes retired codes |
| `CodeBarUITests` | fake `CodeRepository` | rapid typing issues one search, not one per character; a stale slow result never overwrites a newer fast one; arrow keys clamp at both ends |
| `CodePlatformTests` | thin | `KeyCombo` ↔ Carbon modifier mask round trip |

No mocking of SQLite. The FTS ranking behavior *is* the thing under test — an in-memory
database is the real implementation, and it's fast.

---

## 7. Build

Replace README steps 1–8 with a checked-in `project.yml` and XcodeGen:

```yaml
name: CodeBar
options:
  deploymentTarget: { macOS: "14.0" }
  createIntermediateGroups: true
packages:
  CodeCore:     { path: Packages/CodeCore }
  CodeStore:    { path: Packages/CodeStore }
  CodePlatform: { path: Packages/CodePlatform }
  CodeBarUI:    { path: Packages/CodeBarUI }
targets:
  CodeBar:
    type: application
    platform: macOS
    sources: [App]
    info:
      path: App/Info.plist
      properties:
        LSUIElement: true
    entitlements:
      path: App/CodeBar.entitlements
      properties:
        com.apple.security.app-sandbox: true
        com.apple.security.files.user-selected.read-only: true
    dependencies:
      - package: CodeCore
      - package: CodeStore
      - package: CodePlatform
      - package: CodeBarUI
```

Setup collapses to `make bootstrap && open CodeBar.xcodeproj`. Every setting that was a
README instruction ("tick this box", "add this key") becomes a reviewable line of YAML.

`libsqlite3.tbd` linking disappears too — in `CodeStore/Package.swift` it's
`linkerSettings: [.linkedLibrary("sqlite3")]`.

Also, before any of this: `git init` and a `.gitignore` (`.DS_Store`, `*.xcodeproj`,
`.build/`, `DerivedData/`). There's currently no version control and two `.DS_Store` files
sitting in the tree.

---

## 8. Migration path

Each phase is independently shippable. Deliberately, the file-moving phase comes *after*
the substance — reorganizing directories first would be busywork that makes the real fixes
harder to review.

Live status and per-task detail live in [ROADMAP.md](ROADMAP.md); this table is
the shape of the plan.

| Phase | Work | Fixes |
|---|---|---|
| **0** ✅ | `git init`, `.gitignore`, `project.yml`, `Makefile`, test target scaffold | reproducible build, reviewable config |
| **1** ✅ | Schema v2 + migration + throwing SQL wrapper + `CodeStoreTests` | bugs 1, 2, 3, 5, 6, 9 and the README's known limitation |
| **2** | Debounce + cancel in a `SearchViewModel` (the actor and async `CodeRepository` landed early, in phase 1) | bug 4 |
| **3** | Carbon hotkey, sandbox on, entitlements | bug 7, removes Accessibility prompt, unblocks App Store |
| **4** | Panel presenter: persistent hosting view, frame autosave, hide on resign-key | bug 8 |
| **5** | Split into the four SPM packages, move tests alongside | enforces the layering |
| **6** | Settings scene, per-system toggles, pins/recents, `Shift+Return` copy formats | the v2 list |
| **7** | Envelope format + `snomed_rf2.py` + shared `codebar_import` package | §5.5 |

Phases 1 and 2 are where nearly all the value is. If you stop after those, you've fixed
every live bug except the hotkey behavior and the app is genuinely production-shaped.

---

## 9. Two forks in the road

**Raw SQLite3 vs GRDB.** The proposal above hand-rolls ~150 lines of statement wrapper and
a migration ladder. [GRDB](https://github.com/groue/GRDB.swift) gives you both, plus FTS5
support and typed records, and it's the best-maintained SQLite layer in Swift. The tradeoff
is your first dependency in a tool that currently has zero — which has some appeal for a
personal clinical utility you want to still build in five years.

Either way the layout is identical: it's all behind `CodeRepository` in `CodeStore`, and no
other module can tell the difference. That's the payoff from the seam in §3 — this decision
stays reversible.

My lean was **GRDB**, on the grounds that migrations are exactly the code you don't want
subtly wrong on someone's imported SNOMED set.

**Decided: raw SQLite3.** Chosen in phase 1 for zero dependencies and because it is fully
verifiable offline — the migration ladder is covered by eight tests against real databases
in the v1 shape. The seam holds: swapping in GRDB later touches only `CodeStore`.

**Four modules vs two.** Covered in §3 — two (`CodeCore` + app) gets you the testability
win. Four gets the compiler to enforce it. Start with two if phase 5 feels like a lot.

---

## 10. Explicitly not proposing

- **SwiftData / Core Data.** Neither has full-text search. FTS5 is the correct choice here
  and the current instinct was right.
- **Auto-downloading code sets.** CPT is proprietary and SNOMED needs a UMLS affiliate
  license. That's a legal problem, not an engineering one — keep import manual.
- **A view model for `ResultRow`.** It's a pure function of its inputs. Leave it.
- **An abstraction over `CodeSystem`.** Four cases, stable for decades. A protocol here
  would be abstraction for its own sake.
- **Touching the search UX.** The two-pass ranking instinct, the ⌥⌘C panel, the badge/code/
  display row are all good. This proposal changes what's underneath them, not what they do.

---

## 11. Growing into a full app

**Direction (2026-08-11):** CodeBar becomes a full native macOS app with a real
main window, *keeping* the menu bar panel, and gains a substantial feature set.

The menu bar panel stays the fast path — hotkey, type, copy, gone in two seconds.
The window is for everything that does not fit that: browsing a hierarchy,
reading a code's full context, curating lists. Two front doors onto one domain.

### What today's design cannot carry

| Today | Why it breaks | What it becomes |
|---|---|---|
| `LSUIElement: true` | No Dock icon, no app menu, no main window | `.regular` activation with `MenuBarExtra` alongside `WindowGroup`. The Dock icon can still be hidden as a *preference*, rather than being baked into the bundle |
| `SearchPanelController.shared` | A singleton owns the one panel; multi-window and multi-scene fight it | Environment-injected controller. Scenes get what they need; nothing reaches for a global |
| `AppEnvironment` built in `AppDelegate` | Fine for one panel; SwiftUI scenes cannot see it | Composition root injected through `@Environment`, so any scene resolves its dependencies |
| Everything user-owned in `UserDefaults` | Pins fit. Notes, lists, annotations and history do not | A second **user database**, see below |
| `CodeBarUI` as one module | Will accumulate search, browse, detail, settings, lists | Feature modules under a shared design system |
| `CodeRepository` as the only service | It is search + ingest. Browsing, crosswalks and lists are different concerns | Additional protocols in `CodeCore`, each narrow |

### The decision worth making now: two databases, not one

[§5.6](#56-data-ownership--one-boundary-worth-drawing) drew a line between
derived and user data, and so far `UserDefaults` has held the user side. That
stops working the moment features accumulate — notes, saved lists, encounter
templates, usage history and annotations are relational, queryable, and worth
far more than the code index itself.

```
~/Library/…/CodeBar/
├── codes.sqlite       DERIVED. Rebuildable from seed + imports. Safe to delete.
│                      Schema owned by CodeStore. Replaced wholesale on import.
└── library.sqlite     USER. Irreplaceable. Backed up, and eventually synced.
                       Pins, lists, notes, history. Never touched by an import.
```

Two stores rather than two tables in one file, because their lifecycles are
opposite: the index is disposable and gets replaced by a yearly release, while
the library must survive every one of those replacements untouched. A
`DELETE FROM codes` must never be able to reach a note.

The library references codes by `(system, code)` rather than by row id — the
same key the index is unique on. A code retired by the publisher then leaves a
note pointing at something no longer in the index, which is **correct**: the
note should survive, and the UI should mark it as referring to a retired code.
That is exactly the situation a clinician needs to see, not one to hide.

Doing this before features land is cheap. Retrofitting it after notes and lists
have been written into `UserDefaults` blobs is not.

### Module shape

```
                    ┌──────────────────────────┐
                    │      CodeBar (app)       │  scenes, composition root
                    └────────────┬─────────────┘
        ┌──────────────┬─────────┴───────┬──────────────┐
        ▼              ▼                 ▼              ▼
  ┌───────────┐  ┌───────────┐   ┌────────────┐  ┌────────────┐
  │ SearchUI  │  │ BrowseUI  │   │ LibraryUI  │  │ SettingsUI │   feature modules
  └─────┬─────┘  └─────┬─────┘   └─────┬──────┘  └─────┬──────┘
        └──────────────┴────────┬──────┴───────────────┘
                                ▼
                       ┌─────────────────┐
                       │  CodeBarKit     │  shared design system + view helpers
                       └────────┬────────┘
                                ▼
        ┌──────────────┬────────┴────────┬──────────────┐
        ▼              ▼                 ▼              ▼
  ┌──────────┐  ┌────────────┐  ┌──────────────┐  ┌──────────┐
  │ CodeCore │  │ CodeStore  │  │ CodeLibrary  │  │CodePlatform│
  │ domain   │  │ the index  │  │ user data    │  │ AppKit    │
  └──────────┘  └────────────┘  └──────────────┘  └──────────┘
```

`CodeLibrary` is new and mirrors `CodeStore`: same actor-over-SQLite shape, same
migration discipline, opposite lifecycle. Feature modules never import either —
they see protocols in `CodeCore`, exactly as `CodeBarUI` does today, and
`make layering` keeps it that way.

**Do not create these modules until a feature needs one.** Every package so far
was created at the moment a phase needed a test target, and that timing worked;
inventing four empty modules now would be the premature abstraction this
document has argued against throughout.

### Schema implications worth knowing early

- **Hierarchy is not stored.** `E11.9` is a child of `E11`, but nothing records
  that; the code-prefix search only makes it look that way. Real browsing needs
  parent/child edges, which come from the CMS *tabular* file, not the order file
  currently imported. New import path, new table, same converter discipline.
- **Includes/excludes notes are not stored.** Clinically these are the difference
  between the right code and a denial, and they live only in the tabular file.
- **No crosswalks.** ICD-10 ↔ SNOMED mappings are separate licensed releases with
  their own cardinality rules; that is a code set of its own, not a column.

None of these block the current app. All three change what `ingest` means, so
they are worth knowing before the import path is treated as settled.

### Order of work

1. **Settings scene** — the first real window, and the shell later panes plug into
2. **Activation policy** — `.regular` plus `MenuBarExtra`, Dock icon as a preference
3. **`CodeLibrary`** — before any feature writes user data that is not a pin
4. **Main window** — browse and detail, once hierarchy import exists
5. **Feature modules** — split when a module gets uncomfortable, not before

