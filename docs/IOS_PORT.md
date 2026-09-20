# CodeBar on iOS — audit and plan

Written 2026-08-26. Every number below was measured on this machine against the
current tree, not estimated. Where something is unverified it says so, and the
unverified items are the ones that decide whether the plan holds.

## The finding in one line

The code ports almost for free; the *product* does not port at all.

## 1. What was measured

The five library packages were copied out of the tree, given `.iOS(.v17)`, and
built and tested against an iPhone 16 Pro simulator.

| Package | Source changes to build for iOS | Tests on iOS |
|---|---|---|
| CodeCore | none | 45 / 45 pass |
| SQLiteKit | none | 13 / 13 pass |
| CodeStore | none | 95 / 95 pass |
| CodeLibrary | none | 52 / 52 pass |
| CodeBarUI | 5 files | 89 / 89 view-model tests pass |

**294 tests pass on iOS.** The four packages underneath the UI — the model, the
SQL layer, FTS5 search, the migration ladder, the whole user library — needed
nothing but the platform line in `Package.swift`. Their only imports are
`Foundation`, `SQLite3`, and each other.

The same patches were then run against macOS: **109 / 109 pass**, snapshots
included. The changes are non-regressive.

### The five files

| File | What is macOS-only | Fix |
|---|---|---|
| `DesignSystem/Palette.swift` | `NSColor` appearance provider | `UIColor` trait provider under `#if canImport(AppKit)` |
| `DesignSystem/PanelSurface.swift` | `if #available(macOS 26, *)` leaves `glassEffect` unguarded on iOS | `if #available(macOS 26, iOS 26, *)` |
| `DesignSystem/CodeRow.swift` | `controlActiveState` | `isWindowActive`, `true` on iOS |
| `Browse/CodeDetailView.swift` | `.buttonStyle(.link)`, `.textBackgroundColor` | `.borderless` + accent; semantic colour shim |
| `Settings/AbbreviationsSettingsView.swift` | `.textBackgroundColor`, `.separatorColor` | semantic colour shim |

The `Palette.swift` docblock already predicted this: *"porting `CodeBarUI` off
AppKit is one file, not a search."* It was very nearly right — one file, plus
four one-line substitutions.

The one-way dependency rule that `make layering` enforces is why. It was not
written for a port and it paid for one anyway.

### What does not come along

`CodePlatform` is 426 lines, of which **311 are macOS concepts that simply do
not exist on iOS** — `CarbonHotkeyRegistrar` (116), `KeyCombo` (77),
`PanelPlacement` (39), `LoginItem` (43), `ActivationPolicyController` (36).
`SystemPasteboard` (14) is a one-line swap to `UIPasteboard`. The two
`UserDefaults` stores (101) are pure Foundation and port as-is.

The app shell is 923 lines, roughly half of it window and panel machinery with
no iOS analogue: `SearchPanelController` (164), `CopyConfirmationPanel` (103),
`AboutPanel` (75), `BrowseWindow` (50), and the `MenuBarExtra` / `Settings`
scenes. `AppEnvironment` (120) is mostly portable — `applicationSupportDirectory`
resolves on iOS unchanged.

So roughly **5,000 of 6,000 lines port as-is**, and about 400–500 lines of new
iOS shell need writing.

## 2. Two measurements that shape the plan

### Size: 31.4 MB at full ICD-10-CM scale

74,000 synthetic codes — longer descriptions than the real ones, two synonyms
each — ingested through `SQLiteCodeStore` produce a **31.4 MB** file with the
FTS5 index, hierarchy and billability included. Real CMS data should land under
that.

31 MB is nothing for an app bundle. **The code set ships inside the app**, which
deletes the entire import problem on iOS and preserves the no-network constraint
completely.

### Search latency: fine for codes, unproven for words

Measured on this Mac against those 74,000 rows, worst of 20 runs:

| Query | Worst |
|---|---|
| `D42` | 0.61 ms |
| `D42.7` | 0.58 ms |
| `synthetic diagnosis 500` | 8.94 ms |
| `unspecified` | 200.95 ms |
| `respiratory` | 696.73 ms |

Code lookup — the dominant path, and the one the product promise is built on —
is **sub-millisecond at full scale**. Free-text is where the cost lives, and it
scales with how many rows the term matches.

The two slow numbers are pathological by construction: every synthetic
description contains both words, so those queries match all 74,000 rows. Real
ICD-10-CM has no term that broad — but it does have *`unspecified`*, which
appears in many thousands of real descriptions, and a phone is slower than this
Mac.

**This is the top technical risk and it is not yet measured on real data or real
hardware.** Do that in Phase 1, before committing to the iPhone form factor.
`SearchSQL` already applies `LIMIT`, so the cost is FTS5 ranking the match set,
not fetching it — which means the mitigations are known if it bites: require
three characters before running the text pass, tighten the debounce, or cap the
match set before ranking.

## 3. The actual problem

From `PRODUCT_RESEARCH.md`, the objective:

> Fast clinical code lookup as a system-wide reflex — ⌥⌘C, type, Return, the
> code is on the clipboard.

That is a *system-wide* reflex, performed **without leaving the app you are
working in**. iOS has no global hotkey, no menu bar, and no way for an app to
overlay another app. The port is easy. The premise is what does not survive.

An iOS CodeBar has to answer one question first: *what replaces ⌥⌘C?*

| Shape | What the reflex becomes | Cost | Keeps the soul? |
|---|---|---|---|
| **Custom keyboard** | Switch keyboards, type, tap — the code is typed **into the app you are already in**. No app switch, no clipboard. | High | Yes |
| **Standalone app** + Shortcuts / Spotlight / Share | Leave your app, look up, copy, come back. | Low | Partly |
| **iPad-first** | Same as above, but Split View makes leaving cheap. | Lowest | Partly |

**Recommendation: build the standalone app first, then the keyboard.** Not as a
compromise — a keyboard extension *requires* a host app, so this is the only
possible order. The host app is genuinely useful on iPad on its own, and it is
what makes the keyboard shippable.

## 4. Plan

### Phase 0 — Make the shared core cross-platform · ~1 day

Everything here is already verified working.

1. Add `.iOS(.v17)` to the five package manifests.
2. Apply the five source fixes in the table above.
3. Give `CodePlatform` an iOS platform, wrap the 311 macOS-only lines in
   `#if os(macOS)`, and add the `UIPasteboard` branch to `SystemPasteboard`.
4. Port the 20 rendering-dependent tests — `PaletteTests` (4) asserts colours
   *resolve*, and needs a `UIColor` trait-collection equivalent; `SnapshotTests`
   (16) needs its own iOS reference set. The other 89 already pass untouched.
5. Check `Tools/check-layering.sh` still holds with the new platform.

### Phase 1 — Data delivery · ~2 days

1. Make the build produce `codes.sqlite` instead of shipping JSON: a `Make`
   target runs the existing `Scripts/import_*.py`, ingests through `CodeStore`,
   and emits the file as a bundle resource.
2. **`SQLiteKit` hardcodes `SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE`**
   ([Database.swift:15](../Packages/SQLiteKit/Sources/SQLiteKit/Database.swift#L15)).
   Add a read-only open mode so the bundled index can be opened in place. The
   alternative — copying 31 MB into Application Support on first launch — costs
   the user storage for nothing.
   This maps cleanly onto the split the architecture already has: the derived
   index is read-only and ships with the app; `library.sqlite` stays writable in
   Application Support.
3. **Measure real search latency** — real CMS file, real device. This is the
   gate on Phase 2's form factor.
4. No import UI on iOS. A new code set is an app update, which also removes the
   "which release am I on?" ambiguity for iOS users.

### Phase 2 — iOS host app · ~1.5 weeks

Reused as-is, all verified: `SearchViewModel`, `BrowseViewModel`,
`AbbreviationsViewModel`, `CodeRow`, `SemanticChip`, `CodeDetailView`,
`MainWindowView`.

Written new: a search screen replacing `SearchPanelController`, a copy toast
replacing `CopyConfirmationPanel`, a settings screen, an About row. Dropped
entirely: menu bar, hotkey, login item, activation policy, panel placement.

Then the iOS-native affordances that earn their place: swipe-to-pin, the share
sheet, haptics on copy, App Intents so Siri and Shortcuts can look a code up,
and a Lock Screen / Control Center entry point.

`NavigationSplitView` already collapses correctly on iPhone, so iPad is close to
free and should be the first thing on TestFlight.

### Phase 3 — Keyboard extension · ~2–3 weeks

**Prototype the memory budget before writing anything else.** Keyboard
extensions are killed for exceeding it, and that risk decides the phase.

Ship the read-only `codes.sqlite` *inside the keyboard's own bundle* rather than
in a shared App Group container. An App Group would force "Allow Full Access" —
a frightening prompt for a clinical tool, and one that flatly contradicts the
"nothing about a patient leaves the machine" promise the app is built on. Two
copies of a 31 MB file is the cheaper price by a wide margin.

### Phase 4 — Ship

Privacy nutrition label is the easy part: nothing is collected, nothing leaves
the device. Worth noting for review that CodeBar is a reference tool and makes
no clinical judgement — the same constraint that already governs abbreviations
expanding to words rather than codes.

## 5. Effort

| Milestone | Elapsed |
|---|---|
| Shared core iOS-ready, data ships | ~3 days |
| iPad/iPhone app on TestFlight | ~2 weeks |
| Keyboard extension — the reflex, preserved | ~5–6 weeks total |

## 6. Risks, ranked

1. **Free-text search latency on device at full scale.** Unmeasured. Gate on it
   in Phase 1. Mitigations are known and cheap.
2. **Keyboard extension memory budget.** Prototype first; it decides Phase 3.
3. **Snapshot suite doubles.** 16 references per platform, maintained forever.
4. **App Store review** for a clinical reference app.

## 7. What was not verified

- No run on physical hardware — simulator only.
- Search latency was measured against synthetic data whose match distribution is
  deliberately worst-case, on a Mac rather than a phone.
- The 20 rendering-dependent tests were set aside on iOS, not ported; the iOS
  colour and snapshot behaviour is therefore untested.
- Nothing about the keyboard extension has been prototyped.
