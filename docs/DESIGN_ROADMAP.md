# CodeBar — design roadmap

The execution plan for [DESIGN_REVIEW.md](DESIGN_REVIEW.md). The review says what
is wrong and why; this says what to do about it, in what order, and how to know
each step landed.

Written 2026-08-12 against `21cc17b`. Steps are sized for one sitting each and
are meant to be one commit each.

## How to use this

**Order matters more than it usually does.** Phase 0 is a token layer that every
later phase writes against. Doing Phase 1 first means writing the same values
twice and deleting them again — the review's §8 sequencing note, expanded here
into hard dependencies.

**Every step has a *Done when*.** It is not "it looks right"; it is a command or
an observation. `make check` is the gate throughout — 271 Swift tests, the
Python converter tests, a Swift 6 strict-concurrency typecheck, and the
module-boundary assertion.

**Snapshot references will churn.** Six of the Swift tests are rendered images,
and most of Phases 1–3 move pixels. Re-recording is expected, not a failure —
but *look at the new reference before accepting it*. That is the entire value of
having them. Procedure in [Appendix A](#appendix-a--re-recording-snapshots).

**Steps marked ⚠ change a public surface** — an exported symbol, a stored
preference, or a snapshot's meaning. Those deserve a second look.

## Progress

**Phase 0 — done** (`26838d4`). One step was attempted and reverted; see 0.1,
which is worth reading before trusting a resource bundle for anything.

**Phase 1 — done.** 1.4 was folded into 0.4, since retiring the hardcoded
`.system(size: 18)` was already what the typography roles were for.

**Phase 2 — done.** 2.2's "pin click also copies" was a misdiagnosis on my part:
SwiftUI gives a child `Button` precedence over a parent `.onTapGesture`, so the
pin already consumed its own click. The pin still moved to a hover-revealed,
dedicated hit region, as design work rather than as a fix.

2.5 turned up a real one. Selection was defined over `results`, which is empty
until something is typed — so `↵` in the empty state did nothing, and the
README's "⌥⌘C then Return, no typing" had never been true. Selection is now
defined over `selectableCodes`, which is the pins and recents before a query.

**Phase 3 — done**, except one part of 3.5. 3.6 landed early, inside 2.1: the
shared `CodeRow` made the detail pane's children real rows on its own.

3.1 gave "Copy Code" **⌘⇧C rather than ⌘C**. The coding notes and the note
editor are selectable text, and claiming ⌘C would break copying from them, which
in a clinical tool is a real thing to want.

3.5's per-list SF Symbol is **deferred**: `CodeList` has no symbol column, so it
needs a `library.sqlite` migration. That is schema work, not UI work, and it does
not belong in a design phase. The `.badge` half shipped.

**Phase 4 — done**, with two steps landing differently than written.

4.2 kept the code column and scaled it, rather than replacing it with a `Grid`.
Rows are independent views inside a `ScrollView`, each painting its own ground,
and a shared grid container would take that away. Note that macOS does not drive
`@ScaledMetric` from `\.dynamicTypeSize`, so this **cannot be snapshot-tested**;
a test that forces that environment value renders at the default size and
asserts nothing. The metric is still correct, and it is what keeps the column
honest if `CodeBarUI` is reused on iOS.

4.3 did not add `.focusable()` to `CodeRow`. Phase 2 gave the panel `⇥` for
autocomplete, and focus traversal would fight it — while the accessibility need
it was meant to serve, reaching a row's pin, is already met by `⌘P`. The real
gap was elsewhere: the detail pane's children were `.onTapGesture` only, so they
were reachable by pointer and nothing else. They are `Button`s now.

**5.2 — done**, ahead of the 5.0 gate and without touching the deployment
target. That is the whole point of the shim: macOS 26 gets Liquid Glass, 14 and
15 keep `.ultraThinMaterial`, and `project.yml` still says 14.0.

Two things landed differently from the step as written:

- **The footer does not get glass.** The step said to apply it to the panel root
  *and* the footer, but the footer sits inside the root, so that is glass on
  glass — named as a mistake in Adopting Liquid Glass.
- **The surface is applied by `SearchPanelController`, not inside
  `SearchPanelView`.** Both materials sample a live backdrop and an offscreen
  bitmap render has none. With the modifier on the view, the placeholder
  snapshot measured a luminance range of **23** across the hint text against
  **105** for the same view without it, and changing the text's foreground style
  moved that not at all — obscured, not dimmed. Moving the ground to the window
  keeps the references meaningful.

**Unverified, and the reason is worth keeping:** nothing available here can
render Liquid Glass faithfully. The snapshot harness cannot, and the interaction
tests check structure rather than pixels. The panel's ground on macOS 26 has to
be judged by running the app. If it reads badly, the revert is one modifier.

**5.0 is still open.** 5.1, 5.3 and 5.4 all need the deployment target raised.

## Step index

| # | Step | Phase | Effort | Blocks |
|---|---|---|---|---|
| 0.1 | Package resources for asset colours | Foundations | 30m | 0.3 |
| 0.2 | `Metric.swift` — the spacing and size scale | Foundations | 1h | almost everything |
| 0.3 | `Palette.swift` + `AccentColor` | Foundations | 2h | 1.2, 1.3, 3.3, 4.1 |
| 0.4 | `CodeTypography` — the six roles | Foundations | 1h | 1.4, 2.1 |
| 1.1 | Two-line descriptions, panel width 680 | Correctness | 2h | 2.1 |
| 1.2 | Conditional system badge | Correctness | 1h | — |
| 1.3 | One wording, one dash for billability | Correctness | 30m | — |
| 1.4 | `.title3` search field | Correctness | 15m | — |
| 1.5 | Copy confirmation HUD | Correctness | 3h | 4.4 |
| 1.6 | Row accessibility elements | Correctness | 2h | 4.3 |
| 1.7 | Honour Reduce Motion | Correctness | 30m | 2.6 |
| 2.1 | One shared `CodeRow` | Consolidation | 4h | 2.2, 2.3, 3.6 |
| 2.2 | Hover states and context menus | Consolidation | 2h | — |
| 2.3 | Selection style | Consolidation | 1h | — |
| 2.4 | Panel footer key map | Consolidation | 2h | 2.5 |
| 2.5 | The keyboard set | Consolidation | 4h | 6.1 |
| 2.6 | Panel appearance animation | Consolidation | 1h | — |
| 3.1 | The window toolbar | Window | 3h | 3.2, 5.2 |
| 3.2 | Detail pane reorder | Window | 1h | 3.3, 3.4 |
| 3.3 | `Excludes 1` container | Window | 1h | — |
| 3.4 | Collapsible note editor | Window | 2h | — |
| 3.5 | Sidebar refinements | Window | 2h | 5.4 |
| 3.6 | Children as real rows | Window | 1h | — |
| 4.1 | High-contrast colour variants | Accessibility | 3h | — |
| 4.2 | Dynamic Type and `@ScaledMetric` | Accessibility | 3h | — |
| 4.3 | Full Keyboard Access | Accessibility | 4h | — |
| 4.4 | VoiceOver announcements | Accessibility | 1h | — |
| 5.0 | **Decision gate:** raise the deployment target | Liquid Glass | — | 5.1–5.4 |
| 5.1 | Rebuild with Xcode 26 and audit | Liquid Glass | 2h | 5.2 |
| 5.2 | `panelSurface()` shim | Liquid Glass | 2h | — |
| 5.3 | Concentric radii | Liquid Glass | 1h | — |
| 5.4 | `safeAreaBar` for the sidebar bar | Liquid Glass | 1h | — |
| 6.1 | ⌘K action menu | Larger | 1d | — |
| 6.2 | Panel → window handoff | Larger | 1d | — |
| 6.3 | Draggable result rows | Larger | 2h | — |
| 6.4 | Menu bar extra additions | Larger | 3h | — |
| 6.5 | Feature-module split | Larger | 3d | — |

Phases 0–3 are the roadmap proper: about two weeks, and they deliver everything
the review scored High or Medium. Phase 4 is non-negotiable but can trail. Phase
5 is gated on a business decision. Phase 6 is optional.

---

# Phase 0 — Foundations

No user-visible change in this entire phase. That is the point: it is the
substrate the rest writes against, and it is cheap now and expensive later.

## 0.1 — ~~Package resources for asset colours~~ — **superseded, done**

**Attempted and reverted on 2026-08-12.** Recorded rather than deleted, because
the reason is a trap worth not walking into twice.

The plan was an `.xcassets` inside `CodeBarUI` with `resources: [.process(…)]`,
so the semantic colours could carry light, dark and high-contrast variants
without the app target owning the design system.

**It does not work.** `swift build` copies an asset catalogue into the resource
bundle **verbatim** — it never runs `actool`, so no `Assets.car` is produced and
`Color(_:bundle:)` resolves to nothing at runtime. `xcodebuild` *does* compile
it. The result is the worst possible split:

- the **app** — built by `xcodebuild` through the generated project — renders
  the colours correctly;
- **`make check`** — which builds with `swift build` — renders them as clear.

The "category - not billable" chip disappeared from the result row while still
occupying its width, and the re-recorded snapshot locked that in and passed. The
app's single most safety-critical label, invisible, with a green test suite.

**What shipped instead.** The colours are defined in code in
`DesignSystem/Palette.swift`, via `NSColor(name:dynamicProvider:)` resolving
against `.aqua`, `.darkAqua`, `.accessibilityHighContrastAqua` and
`.accessibilityHighContrastDarkAqua`. Identical under both build systems, all
four variants kept, and one AppKit import isolated to one file.

`AccentColor` **stays** in the app's `Assets.xcassets` — macOS reads the global
accent from the app bundle, which `xcodebuild` compiles, so it is unaffected.

**The guard.** `PaletteTests` asserts each colour resolves opaque under all four
appearances, and that light and dark actually differ. A colour that fails to
resolve is a colour that silently disappears.

## 0.2 — `Metric.swift`, the spacing and size scale

**Goal.** One place that owns every number in the layout.

**Touches.** New `Sources/CodeBarUI/DesignSystem/Metric.swift`.

**Why it matters more than it looks.** `560` is currently written in **eight
places across three files** — `PANEL_WIDTH` in `SearchPanelView` (which is
`private`), `PANEL_SIZE` in `SearchPanelController` in the *app target*, and six
hardcoded sizes in `SnapshotTests`. The panel and the window that hosts it agree
on their width by coincidence. Step 1.1 cannot be done safely until one of them
owns the number.

**Do.**

1. Write the enum. Public, because the app target needs `panelWidth`:

   ```swift
   /// Every spacing and sizing value in the app. A 4pt scale.
   ///
   /// `panelWidth` is public because the panel's NSPanel is built in the app
   /// target while its content is laid out here — the two used to declare the
   /// number independently and agreed only by coincidence.
   public enum Metric {
       public static let xs: CGFloat = 4
       public static let s: CGFloat = 8
       public static let m: CGFloat = 12
       public static let l: CGFloat = 16
       public static let xl: CGFloat = 24
       public static let xxl: CGFloat = 32

       public static let rowRadius: CGFloat = 6
       public static let cardRadius: CGFloat = 10

       public static let panelWidth: CGFloat = 560     // 1.1 raises this to 680
       public static let resultListMaxHeight: CGFloat = 340
       public static let codeColumn: CGFloat = 92
       public static let badgeColumn: CGFloat = 72
   }
   ```

2. Replace every literal in the five view files with the nearest token. Where a
   literal does not map cleanly — the `9` in `ResultRow`'s vertical padding, the
   `18` between detail-pane sections — round to the scale rather than adding a
   token. Rounding `9 → 8` and `18 → 16` is a deliberate, visible change and is
   the whole point.
3. Delete `PANEL_WIDTH` and `RESULT_LIST_MAX_HEIGHT` from `SearchPanelView`.
4. In `SearchPanelController`, replace `PANEL_SIZE` with
   `NSSize(width: Metric.panelWidth, height: 420)`.

**Done when.** `make check` passes, and `grep -rn "padding(\([0-9]" Packages/CodeBarUI/Sources`
returns nothing.

**Expect.** Snapshot diffs from the rounding. Inspect each one — this is the
step where you find out whether the scale reads better or worse than the ad-hoc
values. If a specific row looks visibly tighter, that is information; adjust the
token, not the call site.

## 0.3 — `Palette.swift` and `AccentColor` ⚠

**Goal.** Four semantic colours with one owner each, and an accent the app
controls.

**Touches.** `Resources/Media.xcassets`, new `DesignSystem/Palette.swift`,
`CodeBar/Assets.xcassets`.

**Do.**

1. Write `DesignSystem/Palette.swift` with the three semantic colours defined in
   code — see 0.1 for why not in a catalogue — each resolving against all four
   appearances through `NSColor(name:dynamicProvider:)`. Pass components as
   `Int`s, not `NSColor`s: the provider closure escapes and `NSColor` is not
   `Sendable`, so built colours will not survive Swift 6 strict concurrency.
2. In the **app**'s catalogue add `AccentColor` with four wells, and set
   `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor` in
   `project.yml` — without the build setting the colour set is inert.
3. Replace `Color.orange` → `.warning`, `Color.red` (in `CodeDetailView`'s
   `excludes1` label) → `.prohibition`, `Color.green` → `.confirmed`.
4. **Break the collision.** Delete `ResultRow.badgeColor` entirely. All four
   systems use one neutral; the label already distinguishes them.
5. Add `PaletteTests` asserting each colour resolves opaque under every
   appearance.

**Done when.** `grep -rn "Color.orange\|Color.red\|Color.green" Packages/CodeBarUI/Sources`
returns nothing, `PaletteTests` passes, and the `result-rows` and `detail-pane`
snapshots re-record with the badge neutral **and the warning chip still visible**.

**Watch for.** The chip's horizontal padding competes with the description at
560pt. Landing it at `Metric.s` pushed the description from "…mellitus" to
"…melli…"; `Metric.xs` is tighter than the original 6pt and buys space back.
Step 1.1 settles it properly.

**Starting values** — tune in the catalogue, not in code:

| Colour | Light | Dark | Notes |
|---|---|---|---|
| `AccentColor` | `#0A5FC4` | `#4C9AFF` | Distinct from the warning amber at a glance |
| `Warning` | `#8A4E00` | `#E0A44E` | Foreground on an 18% fill of itself |
| `Prohibition` | `#A31D24` | `#F0868E` | Reserved for `Excludes 1` alone |
| `Confirmed` | `#15603F` | `#5EC099` | Reserved for billable alone |

High-contrast variants get their real treatment in 4.1; for now, fill them with
a darker/lighter step of the same hue so the wells are not empty.

## 0.4 — `CodeTypography`, the six roles

**Goal.** Stop views choosing fonts.

**Touches.** New `DesignSystem/CodeTypography.swift`, all five view files.

**Do.**

1. Define the six roles from the review's §3 table as `Font` statics — hero
   code, row code, description, search field, section label, metadata.
2. Apply them. Two substantive changes fall out and are the reason this step
   exists: `CodeRowLabel`'s description moves from `.secondary` to `.primary`,
   and the search field's `.font(.system(size: 18))` becomes `.title3`.
3. Add `.monospacedDigit()` to both code styles.

**Done when.** `grep -rn "\.font(\.system(size:" Packages/CodeBarUI/Sources` is
empty. Snapshots re-record; the window's rows should read noticeably stronger.

---

# Phase 1 — Correctness and feedback

The user-visible payoff. Everything here is independently shippable.

## 1.1 — Two-line descriptions and panel width 680 ⚠

**The most important step in this document.**

**Touches.** `ResultRow.swift`, `Metric.swift`, `SnapshotTests.swift`, six
reference images.

**Do.**

1. `Metric.panelWidth` → `680`.
2. In `ResultRow`, `.lineLimit(1)` → `.lineLimit(2)`, and add
   `.fixedSize(horizontal: false, vertical: true)` so the row grows rather than
   compressing the text.
3. Change the row's `HStack` alignment to `.firstTextBaseline` — with two-line
   descriptions, centre alignment floats the code away from the first line.
4. Update the six hardcoded `560`s in `SnapshotTests` to `Metric.panelWidth`,
   and raise the heights so two-line rows are not clipped.
5. Add a regression test — the fixture that would have caught this:

   ```swift
   @Test("a long description should wrap rather than truncate")
   func longDescriptionWraps() {
       let rows = VStack(spacing: Metric.xs) {
           ResultRow(code: Samples.longDescription.code, isSelected: true,
                     isPinned: false, onTogglePin: {})
       }
       assertImage(rows, size: CGSize(width: Metric.panelWidth, height: 80),
                   named: "result-row-long-description")
   }
   ```

   Add `Samples.longDescription` using a real one — `S72.001A`, "Fracture of
   unspecified part of neck of right femur, initial encounter for closed
   fracture", is 88 characters and is the honest worst case.

**Done when.** The new reference shows the full string with no ellipsis, *and*
`RESULT_LIST_MAX_HEIGHT` still holds about five rows — if two-line rows mean
only three fit, raise `resultListMaxHeight` to 420 in the same commit.

**Watch for.** The panel grows to content via `preferredContentSize`. Taller
rows mean a taller panel; re-check `PanelPlacement.origin` still lands it
sensibly on a 13" display. `PanelPlacementTests` covers the maths but not the
new height — add a case.

## 1.2 — Conditional system badge

**Touches.** `ResultRow.swift`, `SearchPanelView.swift`, `SearchViewModel.swift`.

**Do.**

1. `SearchViewModel` already reads `preferences.enabledSystems`. Expose
   `var showsSystemBadge: Bool { preferences.enabledSystems.count > 1 }`.
2. Pass it into `ResultRow` as a parameter with a `true` default, so the window
   and the tests are unaffected.
3. When false, omit the badge and its 72pt column entirely — do not hide it with
   opacity, which keeps the width.
4. When true, move it to the trailing edge before the pin, and drop it to
   `.caption2` in the neutral from 0.3.

**Done when.** With one system installed the description starts at the code
column + 12pt. With two, the badge is at the trailing edge.

**Note.** `EmptyStateView` builds `ResultRow`s too. Thread the flag through, or
the empty state and the results list will disagree.

## 1.3 — One wording, one dash

**Touches.** `ResultRow.swift`, `CodeDetailView.swift`.

**Do.** Pick the detail pane's wording — "Category — not valid for submission" —
and use it in both, as a shared constant so it cannot drift again:

```swift
/// The one phrasing for a non-billable code. Spelled once because two spellings
/// of the app's most safety-critical label is how a reader learns to distrust it.
public let NOT_BILLABLE_LABEL = "Category — not valid for submission"
```

Keep `ResultRow`'s existing `.accessibilityLabel` — it says "Category header,
not valid for submission", which is better spoken.

**Done when.** `grep -rn "not billable" Packages/` returns nothing.

## 1.4 — `.title3` search field

Folded into 0.4 if you did that step properly. If not: `SearchPanelView.swift`,
one line, `.font(.system(size: 18))` → `.font(.title3)`. Re-record
`search-panel-placeholder`.

## 1.5 — Copy confirmation HUD ⚠

**Goal.** Close the app's largest feedback gap: today a copy is silent.

**Touches.** New `Search/CopyConfirmation.swift`, `SearchPanelView.swift`,
`SearchViewModel.swift`, `LibraryActions.swift`.

**Design.** A small capsule at the panel's centre showing `Copied E11.9` or the
truncated long form. Fades in 100ms, holds 1000ms, fades out 200ms. **Not** a
system notification — this is a foreground user-initiated action and a
Notification Center banner would outlive its usefulness by four seconds.

**The sequencing problem worth thinking about.** The panel dismisses on copy.
Three options:

| Approach | Cost |
|---|---|
| HUD inside the panel, delay the dismiss by ~900ms | The panel lingering after Return contradicts "gone in two seconds" |
| Separate borderless `NSPanel` at the same position, panel dismisses immediately | One more window to own, but preserves the tempo |
| Menu bar icon flashes | Cheapest, but off-screen from where the user is looking |

**Take the second.** The promise is that the panel gets out of the way; the
confirmation should outlive it, not delay it. **[Call]**

**Do.**

1. `SearchViewModel` gains `private(set) var lastCopied: (text: String, id: UUID)?`,
   set in `copy(_:format:)`.
2. Build the HUD as a tiny `NSPanel` owned by `SearchPanelController`, positioned
   with the same `PanelPlacement` logic, `.nonactivatingPanel`, ignoring mouse
   events, self-dismissing on a timer.
3. Show the *actual copied string*, truncated to ~60 characters — the point is
   confirming which format landed, so `⇧↵` must visibly differ from `↵`.
4. Fire it from `LibraryActions.copy` so the window's Copy buttons get it too.

**Done when.** `⌥⌘C`, type, `↵` — the panel goes, the confirmation appears and
leaves on its own. `⇧↵` shows the long form. Two copies in quick succession
replace rather than stack.

**Test.** View-model level: `copySelected(format: .codeAndDisplay)` sets
`lastCopied.text` to the long form. The HUD's rendering gets a snapshot.

## 1.6 — Row accessibility elements

**Touches.** `ResultRow.swift`, `CodeRowLabel` (until 2.1 merges them).

**Do.** Apply the review's §9 pattern. The critical line is the label using
`code.display` **in full** — truncation is a visual concern only, and this is
what guarantees a VoiceOver user never gets the shortened string.

```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel("\(code.system.shortLabel) \(code.code). \(code.display)")
.accessibilityValue(code.isBillable == false
                    ? "Category header, not valid for submission" : "")
.accessibilityHint("Press Return to copy")
.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
.accessibilityAction(named: "Pin") { onTogglePin?() }
```

Also mark the `↵ copy` hint `.accessibilityHidden(true)` and the stethoscope
glyph decorative.

**Done when.** Accessibility Inspector on a running panel reports one element
per row, with the full description, and both actions in its action list.

**Note.** This has to be re-applied after 2.1 merges the two row types. Doing it
now anyway is correct — it is high-severity, and the merge is a move not a
rewrite.

## 1.7 — Honour Reduce Motion

**Touches.** `SearchPanelView.swift`.

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion
...
withAnimation(reduceMotion ? nil : .easeOut(duration: SCROLL_ANIMATION_DURATION)) {
    proxy.scrollTo(newValue, anchor: .center)
}
```

**Done when.** With Reduce Motion on, arrowing through a long result list jumps
rather than glides.

---

# Phase 2 — Consolidation

Where the two surfaces become one app.

## 2.1 — One shared `CodeRow` ⚠

**Goal.** Kill the duplication between `ResultRow` and `CodeRowLabel`.

**Touches.** New `DesignSystem/CodeRow.swift`; delete `ResultRow.swift`; remove
`CodeRowLabel` from `MainWindowView.swift`; update `EmptyStateView`,
`CodeDetailView`, `SnapshotTests`.

**Design.**

```swift
public struct CodeRow: View {
    public enum Density {
        case panel    // search results, empty state — 2-line, pin, copy hint
        case list     // window content column — 1-line, no pin
        case compact  // children in the detail pane — 1-line, tighter
    }
}
```

Anatomy is fixed across all three; only spacing, line limit, and which trailing
affordances appear vary. That is the review's principle 7 made mechanical:
*density may change, anatomy may not*.

**Do.**

1. Write `CodeRow` with `Density`, carrying over everything from `ResultRow`
   including the 1.6 accessibility block.
2. Migrate call sites: `SearchPanelView` and `EmptyStateView` → `.panel`;
   `MainWindowView`'s three lists → `.list`; `CodeDetailView.children` →
   `.compact`.
3. Delete the old types.
4. Update snapshot tests to construct `CodeRow`, and add a `code-row-densities`
   reference showing all three stacked — the regression test for the whole point
   of the step.

**Done when.** `make check` passes, `grep -rn "ResultRow\|CodeRowLabel" Packages/`
returns nothing, and the new densities reference shows three visibly related rows.

**Watch for.** `BrowseNodeRow` puts `CodeRowLabel` inside a `DisclosureGroup`
label. `.compact` needs to survive that without fighting the disclosure triangle's
own padding.

## 2.2 — Hover states and context menus

**Touches.** `CodeRow.swift`.

**Do.**

1. `@State private var isHovering = false` + `.onHover { isHovering = $0 }`.
2. Background: hovering and not selected → `Color.primary.opacity(0.06)`.
3. Pin visibility → `isPinned || isHovering`. **Make it not also copy** — the pin
   `Button` currently sits inside the row's `.onTapGesture` area; give the pin
   its own hit region so a pin click does not dismiss the panel. This is a live
   bug, not a refinement.
4. `.contextMenu` on `.panel` and `.list`: Copy, Copy with description, Pin,
   Open in window *(stub until 6.2)*, Add to List.

**Done when.** Hovering a row lights it and reveals the pin; clicking the pin
pins without copying or dismissing.

## 2.3 — Selection style

**Touches.** `CodeRow.swift`.

**Do.** Replace `Color.accentColor.opacity(0.15)` with a fill that reads at a
glance and dims when the window is not key:

```swift
@Environment(\.controlActiveState) private var controlState
...
.background(
    isSelected
        ? Color.accentColor.opacity(controlState == .key ? 0.28 : 0.12)
        : (isHovering ? Color.primary.opacity(0.06) : .clear)
)
.overlay {
    if isSelected {
        RoundedRectangle(cornerRadius: Metric.rowRadius)
            .strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1)
    }
}
```

**Done when.** The selected row is unmistakable at arm's length, and a panel
behind another app's window visibly shows an inactive selection.

## 2.4 — Panel footer key map

**Touches.** New `Search/PanelFooter.swift`, `SearchPanelView.swift`.

**Do.** A bar below the result list: `↵ Copy · ⇧↵ With description · ⌘↵ Open`
left, `⌘K Actions` right. `.caption2` on `.secondary`, `Divider` above,
`.background(.bar)`. Contents change with context — the empty state shows
`↵ Copy · ⌘P Pin`.

Then **delete the per-row `↵ copy` hint**, which is what this replaces.

**Done when.** The footer is present in all three panel states and the row-level
hint is gone. Note this is where Liquid Glass will eventually land (5.2) — keep
it a separate view so the surface is swappable.

## 2.5 — The keyboard set ⚠

**Touches.** New `Search/PanelKeyHandler.swift`, `SearchPanelView.swift`,
`SearchViewModel.swift`.

**Refactor first.** `.onKeyPress` modifiers are stacked on the root `VStack` with
implicit precedence. Adding six more makes that unreadable. Replace with one
handler:

```swift
/// One place that decides what a key does, because stacked `.onKeyPress`
/// modifiers resolve in an order that is not visible at the call site.
func handle(_ press: KeyPress) -> KeyPress.Result
```

**Then add**, in this order — each is independently testable:

| Key | Behaviour | Note |
|---|---|---|
| `⌘1`–`⌘9` | Copy the *n*th result | Also drives the footer's index hints |
| `⌘P` | Pin/unpin the selection | Pinning is mouse-only today |
| `⇥` | Autocomplete the field to the selected code | Refine rather than commit |
| `⌘↵` | Open in the window | Stub until 6.2 — do not ship a dead key |
| `⎋` | Clear field; dismiss only if already empty | ⚠ behaviour change |

**On `⎋`.** Today it dismisses immediately, losing a typed query with no undo.
Two-stage is better but it is a habit change for an existing user. Ship it, and
mention it in the release notes.

**Done when.** `SearchViewModelTests` covers each new action, and the `⌘1`–`⌘9`
indices in the footer match what the keys actually do.

## 2.6 — Panel appearance animation

**Touches.** `SearchPanelController.swift`.

120ms opacity + scale from 0.98 on `show()`. Gate on
`NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.

**Do not animate the result list.** The debounce is 120ms; a typist outruns any
transition, and the `ForEach` identity comment in `SearchPanelView` records that
this list has already cost one class of bug.

---

# Phase 3 — The window

## 3.1 — The window toolbar ⚠

**Goal.** Get the four detail-pane buttons out of scrolling content. Also the
prerequisite for CodeBar getting Liquid Glass for free in 5.1.

**Touches.** `MainWindowView.swift`, `CodeDetailView.swift`, `CodeBarApp.swift`.

**Do.**

1. Add `.toolbar { }` to `MainWindowView`, not to the detail view — the toolbar
   belongs to the window.
2. Layout, with semantic grouping per Apple's guidance:

   ```swift
   ToolbarItemGroup(placement: .primaryAction) {
       Button("Copy code") { … }.buttonStyle(.borderedProminent)
       Menu { Button("Copy with description") { … } } label: { … }
   }
   ToolbarSpacer()                       // separates copy from library actions
   ToolbarItemGroup {
       Button { … } label: { Label("Pin", systemImage: isPinned ? "pin.fill" : "pin") }
       Menu("Add to List") { … }
   }
   ```

3. Give each a `.keyboardShortcut` — `⌘C`, `⇧⌘C`, `⌘P` — matching the panel's.
4. Delete the `HStack` of buttons from `CodeDetailView.header`.
5. Disable the group when `model.detail == nil` rather than hiding it, so the
   toolbar does not reflow on selection.

**Done when.** The buttons stay put while the detail pane scrolls, `⌘C` copies
the selected code, and the `detail-pane` snapshot re-records without them.

**Watch for.** `ToolbarSpacer` is macOS 26. Below that, `ToolbarItem(placement:
.automatic)` with a `Spacer` is the fallback — or accept one undifferentiated
group until 5.0 and note it in the code.

## 3.2 — Detail pane reorder

**Touches.** `CodeDetailView.swift`.

Move `noteEditor` below `children`. Order becomes: breadcrumb → code →
description → status chip → publisher notes → children → your note.

Three lines moved, and it fixes the review's fourth High finding: the personal
reminder no longer outranks the `Excludes 1` rules.

**Done when.** The `detail-pane` reference shows `Excludes 1` above the fold at
620×520, which is roughly the real pane at default window size.

## 3.3 — `Excludes 1` container

**Touches.** `CodeDetailView.swift`.

Give it a left rule in `.prohibition` and a tinted ground — it is the only
content in the app that means "this combination will be rejected", and red label
text alone does not survive skimming. Leave the other note kinds as they are;
that contrast is the point.

Set the container's `.accessibilityLabel` to "Excludes 1. Never code together
with…" so the rule is spoken as a rule.

## 3.4 — Collapsible note editor

**Touches.** `CodeDetailView.swift`.

Empty and unfocused → a single `＋ Add a note` button. Tapping expands and
focuses. Non-empty → renders as now.

Also replace the appearing/disappearing "Save note" button with a transient
"Saved" label; the commit-on-focus-loss already works and the button is noise.

**Done when.** A code with no note shows one button; the ~140pt of always-present
chrome is gone.

## 3.5 — Sidebar refinements

**Touches.** `MainWindowView.swift`.

1. Count labels → `.badge(list.count)`, the native affordance, which handles
   selection-state colour itself.
2. Per-list SF Symbol, chosen at creation, replacing the uniform
   `list.bullet.rectangle`.
3. Leave the hand-built bottom bar alone for now — 5.4 replaces it with
   `safeAreaBar`. Add a `NOTE:` marker pointing at that step.

## 3.6 — Children as real rows

**Touches.** `CodeDetailView.swift`.

Swap the bare `Button`/`CodeRowLabel` pairs for `CodeRow(density: .compact)`,
which brings hover and accessibility with it from 2.1 and 2.2. These are the
fastest path from a category to its billable child, so they deserve the row
treatment.

---

# Phase 4 — Accessibility completion

Non-negotiable, but it can trail Phase 3 without blocking it.

## 4.1 — High-contrast colour variants

The four appearance variants already exist as of 0.3 — tune the two contrast
values in `Palette.swift`, then read the environment and swap tinted fills for
bordered ones:

```swift
@Environment(\.colorSchemeContrast) private var contrast
...
.background(contrast == .increased ? Color.clear : Color.warning.opacity(0.18))
.overlay { if contrast == .increased { Capsule().strokeBorder(Color.warning, lineWidth: 1) } }
```

**Done when.** With Increase Contrast on, every chip has a visible boundary, and
a snapshot with the trait forced is recorded as the regression test.

## 4.2 — Dynamic Type and `@ScaledMetric`

`Metric.codeColumn` and `badgeColumn` are absolute — at larger text the code
clips inside its 92pt column.

```swift
@ScaledMetric(relativeTo: .body) private var codeColumn = Metric.codeColumn
```

Or drop the fixed columns for a `Grid` with `.gridColumnAlignment(.leading)`,
which is more work and survives every text size. **Prefer the `Grid`** if 2.1
has already centralised the row — one change, one place. **[Call]**

**Done when.** At the largest non-accessibility text size no code clips, and the
panel is still usable at the smallest accessibility size.

## 4.3 — Full Keyboard Access

Rows are gesture-driven with no focusable representation, so a keyboard-only
user cannot reach a row's pin at all. Add `.focusable()` and a `@FocusState` ring
to `CodeRow`, with a visible focus indicator distinct from selection.

**Done when.** With Full Keyboard Access on, `⇥` walks field → rows → pin →
footer, and every action is reachable.

## 4.4 — VoiceOver announcements

The panel vanishing on copy is a silent outcome. Post
`AccessibilityNotification.Announcement(“Copied E11.9”)` alongside the 1.5 HUD —
same trigger, two channels.

---

# Phase 5 — Liquid Glass

## 5.0 — Decision gate: raise the deployment target

**Not an engineering step.** `project.yml` sets `macOS: "14.0"`. Everything
below needs 26.

The review's position stands: treat Liquid Glass as **a compilation-time
upgrade, not a design project**. Nothing in Phases 0–4 depends on this, and
nothing here is worth doing before them.

**Decide on:** what fraction of users are on 26, and whether dropping 14/15 is
acceptable. If it is not, do 5.2 alone — a gated shim — and skip the rest until
it is.

## 5.1 — Rebuild with Xcode 26 and audit

Raise the target, rebuild, then **look at every surface before changing
anything**. Toolbar, sidebar, menu bar and window shape adopt Liquid Glass with
no code. Most of the value is in this step.

Then find what fights it: the hand-built sidebar bar (5.4), any `.background`
on a navigation element, the panel's `.ultraThinMaterial` under a glass toolbar.

**Done when.** Every snapshot reference is re-recorded on 26 and reviewed. This
will be the single largest reference churn in the roadmap — budget an hour just
for looking.

## 5.2 — `panelSurface()` shim

The only place glass is conditional:

```swift
extension View {
    func panelSurface() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: Metric.cardRadius))
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}
```

**Do not build a general-purpose glass abstraction.** One gated surface, two
branches, one call site. A `GlassCompatible` protocol is the overengineering this
codebase has so far avoided.

Apply to the panel root and the 2.4 footer. **Nowhere else** — not rows, not the
detail pane, not chips. That is Apple's rule and the review's principle 6.

## 5.3 — Concentric radii

Replace `RoundedRectangle(cornerRadius:)` with `ConcentricRectangle` where a
shape is nested in a container, gated on 26. Cosmetic, cheap, and it makes
nested shapes track the window's own curvature.

## 5.4 — `safeAreaBar` for the sidebar bar

Replace the hand-built `Divider` + `.background(.bar)` from 3.5 with
`safeAreaBar(edge: .bottom)`, which gets the scroll edge effect and stops
fighting the sidebar's glass.

---

# Phase 6 — Larger

Optional. Each is a feature, not a fix.

- **6.1 ⌘K action menu** — the extension point for list-adding from the panel,
  export, and crosswalks. Depends on 2.5.
- **6.2 Panel → window handoff** — so a lookup that turns out to need context
  does not restart. Makes `⌘↵` from 2.5 real.
- **6.3 Draggable rows** — `.draggable(code.code)`. For a copy-oriented tool this
  is the one gesture that earns its place.
- **6.4 Menu bar extra additions** — a *Pinned codes* submenu, and the installed
  release summary as a disabled first item.
- **6.5 Feature-module split** — SearchUI / BrowseUI / LibraryUI / SettingsUI
  over the shared design system, as [ARCHITECTURE.md](ARCHITECTURE.md) §11
  anticipates. Phase 0 is what makes this cheap; do not attempt it first.

---

## Appendix A — Re-recording snapshots

Most of Phases 1–3 moves pixels. The procedure:

1. Run `make test`. Failures print a diff path.
2. **Open the diff.** This is the only step that matters — the references exist
   to make a human look.
3. To accept: delete the stale `.png` under
   `Packages/CodeBarUI/Tests/CodeBarUITests/__Snapshots__/SnapshotTests/` and
   re-run. The test fails once on re-record, then passes.
4. Commit the new reference **in the same commit** as the code that changed it,
   so `git show` explains the pixels.

References are machine-specific — fonts, appearance and OS version all move them
— and appearance is pinned to dark so they do not flip with the system setting.
Already recorded as a known limit in [README.md](../README.md).

## Appendix B — What not to do

Carried from the review's §9, restated as prohibitions because a roadmap invites
scope creep:

- **Don't hand-roll glass on macOS 14/15.** Stacked blurs cost GPU on every
  panel show and will look wrong beside the real thing. `.ultraThinMaterial` is
  the correct fallback and is already there.
- **Don't animate the result list.** See 2.6.
- **Don't introduce a custom font.** The system faces plus `.monospaced` are
  correct here and free.
- **Don't build a theming system.** Light, dark and high-contrast via the asset
  catalogue is the whole requirement.
- **Don't replace `NavigationSplitView`.** It is the right container and it is
  what makes the sidebar adopt Liquid Glass for free in 5.1.
- **Don't skip Phase 0.** Every later step writes against it.

## Appendix C — Risks

| Risk | Where | Mitigation |
|---|---|---|
| Snapshot churn hides a real regression | Phases 1–3 | Appendix A step 2. Never bulk-accept. **This already happened once** — see 0.1. |
| `swift build` and `xcodebuild` disagree | Anything resource-backed | Keep design-system values in code. Assert they resolve, don't assume. |
| Panel height grows past a 13" screen | 1.1 | Extend `PanelPlacementTests` with the taller frame |
| Two-stage `⎋` breaks an existing habit | 2.5 | Release notes; it is still the right behaviour |
| `ToolbarSpacer` unavailable below 26 | 3.1 | Ship one group, add the spacer at 5.1 |
| Deployment-target decision stalls | 5.0 | Nothing in 0–4 depends on it. Ship those. |
| Module split attempted too early | 6.5 | It is last for a reason |

---

**See also.** [DESIGN_REVIEW.md](DESIGN_REVIEW.md) for the findings and their
reasoning, [codebar-design-review.html](codebar-design-review.html) for the same
review with rendered before/after mockups, and
[ARCHITECTURE.md](ARCHITECTURE.md) §11 for where the module shape is headed.
