# CodeBar — UI/UX review

Written 2026-08-12 against the working tree at `21cc17b`. A snapshot: the code
changes daily, and Apple's guidance moves on its own schedule. Re-check before
acting on anything dated here.

The audit came from reading every view in
[`Packages/CodeBarUI`](../Packages/CodeBarUI) and the six rendered snapshot
references under `CodeBarUITests/__Snapshots__/` — so it describes the UI as it
draws, not as the source reads. The design guidance came from web research.

Claims are marked so they can be weighed differently:

| Mark | Means |
|---|---|
| **[Apple]** | Documented in the HIG, Technology Overviews, or a WWDC session. Linked at the end. |
| **[Field]** | Observed convention in shipping apps. Not Apple guidance. |
| **[Call]** | A recommendation for CodeBar specifically. Arguable, and argue with it. |

## The short version

**CodeBar's search panel truncates the end of a code's description** — the exact
part that separates `E11.9` *without complications* from `E11.65` *with
hyperglycemia*. In a clinical coding tool that is not cosmetic; it is the
interface withholding the information the user opened it for. Fix the row and
most of the app's perceived quality moves with it.

Three things are true at once and should be held separately:

- **The product thinking is sound.** Panel-as-fast-path, window-as-depth, pins
  as the answer to a ranking problem that no structural fix solved. These are
  good decisions, documented honestly in the code.
- **The visual execution has no system.** Spacing values run 2, 4, 6, 8, 9, 10,
  12, 14, 18, 24 with no scale behind them. The panel and the window render the
  same object — a code — with two unrelated row designs. There is no
  `AccentColor` asset, so the app has no colour of its own.
- **Liquid Glass is mostly not the problem.** `deploymentTarget.macOS` is
  `"14.0"`; `.glassEffect` is macOS 26. More to the point, Apple puts glass on
  the *navigation* layer and warns against it behind dense text — which is
  nearly all of CodeBar. There is a real Liquid Glass win here and it is smaller
  and less interesting than it sounds.

---

## 1. Audit

Severity is scored on user harm, not on how wrong it looks.

### What works — keep it and build on it

**Two surfaces with genuinely different jobs.** The panel copies a code and
leaves; the window is for hierarchy, coding notes and lists. They are reached
deliberately differently, and `applicationShouldHandleReopen` enforces it. A
clearer separation than most menu bar apps manage, and worth protecting as the
app grows.

**Billability is text, not colour.** The comment on `headerBadge` gets this
exactly right: the one fact that can turn a correct-looking lookup into a denied
claim must not depend on distinguishing two shades. It reads "category - not
billable" in words. Most apps would have shipped an orange dot. **[Apple]** also
requires it — colour must never be the sole carrier of meaning.

**Panel placement, sizing and dismissal.** Re-placed on every show rather than
autosaved (avoiding the documented downward drift), positioned on the display
under the pointer, grows downward via `NSHostingController.preferredContentSize`,
and `hidesOnDeactivate`. That is the correct Spotlight-class behaviour set, and
it is not trivially arrived at.

**Native components where native is right.** `ContentUnavailableView`,
`.formStyle(.grouped)`, a `TabView` settings shell, `NavigationSplitView`,
`confirmationDialog`. Nothing re-implemented that the system already does —
which is also what makes the eventual Liquid Glass adoption nearly free.

### What doesn't work

#### High — descriptions truncate at one line, in a fixed 560pt panel

`ResultRow` sets `.lineLimit(1)`; the snapshot shows "Type 2 diabetes mellitus
without com…". ICD-10 descriptions carry their clinical distinction in the tail
— *without complications*, *with hyperglycemia*, *unspecified laterality*.
Truncating the tail hides precisely the differentiator between adjacent codes.

**Fix:** `.lineLimit(2)`, widen the panel to ~680pt, and reclaim the width
currently spent on the system badge. **[Call]**

#### High — the system badge burns 15% of the panel on a constant

`BADGE_COLUMN_WIDTH` is 72pt plus a 12pt gap: 84 of 560 points, at the row's
most valuable position, on a label that reads "ICD-10" for every row for anyone
who has installed one code set. Which is most users, and the default out of the
box.

**Fix:** show the badge only when more than one system is enabled, and when
shown, move it to the trailing edge as a small tinted glyph. **[Call]**

#### High — copying gives no confirmation at all

Press Return; the panel disappears. Nothing tells you *what* landed on the
clipboard, or whether Shift was held and you got the long form instead of the
bare code. In a tool whose entire purpose is putting the right string on the
clipboard, the terminal action is unacknowledged. This is the gap most likely to
make a careful user re-check by pasting somewhere first — which erases the
two-second promise.

**Fix:** a brief non-blocking HUD showing the copied string, dismissing itself
in ~1.2s. See §4. **[Call]**

#### High — the detail pane puts your note above the publisher's exclusion rules

`CodeDetailView` orders header → **note editor** → publisher notes → children.
The `TextEditor` has a 56pt minimum plus padding and a conditional save button,
so roughly 100–140pt of always-present chrome sits between the code and the
`Excludes 1` rules that mean *never code these together*. The personal reminder
outranks the authoritative safety rule.

**Fix:** notes → children → your note. Collapse an empty note to a single "Add a
note" row. **[Call]**

#### Medium — two semantic collisions in the colour system

Orange means *CPT* as a system badge and *not billable* as a warning. Green
means *SNOMED* and *Billable*. On a row showing a CPT code the two orange chips
sit inches apart meaning unrelated things. The system palette is also being
spent decoratively on taxonomy, leaving nothing reserved for state.

**Fix:** reserve amber and red exclusively for billability and exclusion rules.
Render system identity in a neutral, distinguished by its label rather than by
hue. **[Call]**

#### Medium — the same object has two unrelated row designs

The panel uses `ResultRow`: badge, fixed-width mono code, primary-coloured
description, pin, copy hint. The window uses `CodeRowLabel`: mono code,
*secondary*-coloured description, no badge, no pin, no fixed columns. Move
between the two surfaces and codes stop looking like the same kind of thing —
and the window's version reads as the weaker one.

**Fix:** one `CodeRow` with a density parameter (`.panel` / `.list` /
`.compact`). **[Call]**

#### Medium — the window has no toolbar, so actions live inside scrolling content

`MainWindowView` declares `.navigationTitle` and `.searchable(placement:
.toolbar)` and no `.toolbar { }`. Consequently Copy, Copy with description, Pin
and Add to List are four equal-weight bordered buttons rendered inline in the
detail pane's `ScrollView` — they scroll away, they have no keyboard shortcuts,
and none of them is the primary.

**Fix:** a real toolbar with one primary Copy button and a menu for the
variants. This is also the change that earns CodeBar its Liquid Glass toolbar
for free on macOS 26. **[Apple] [Call]**

#### Medium — custom selection fill instead of the system's

`Color.accentColor.opacity(0.15)` at radius 6. Three costs: it does not dim when
the window loses key focus, so a background panel looks active; it does not pick
up the system's selection vibrancy over a material background; and at 15% over
`.ultraThinMaterial` the contrast against an unselected row is slight — visible
in the snapshot as a dim navy a fast scanner can miss.

**Fix:** either raise the fill and add a hairline inset stroke, or move to a real
`List` with `selection:` and let AppKit own it. **[Call]**

#### Medium — no accent colour asset, so the app has no colour of its own

`Assets.xcassets` contains only `AppIcon`. Every `Color.accentColor` resolves to
whatever the user picked in System Settings, so CodeBar's selection highlight,
pin state and link colour change identity per machine — and can land on the same
orange the app uses for "not billable."

**Fix:** ship an `AccentColor` with light, dark and high-contrast variants.
**[Apple]** asks for exactly those three per custom colour.

#### Medium — no hover states anywhere in the panel

Rows have `.contentShape(Rectangle())` and `.onTapGesture` but no `.onHover`.
Nothing indicates a row is clickable, and the pin button — a caption-sized glyph
sitting *inside* the row's tap target — is invisible as an affordance until you
already know it exists. On a pointer-driven platform that is a missing layer of
the interaction model.

#### Low — no spacing or type scale

Across five view files: padding of 2, 3, 4, 6, 8, 9, 10, 12, 14, 18, 20, 24;
corner radii of 4 and 6; fixed widths of 72, 92, 240, 280, 300, 360, 540; one
hardcoded `.font(.system(size: 18))`. Each was locally reasonable; collectively
there is no rule, so every new view is a fresh negotiation and nothing lines up
across surfaces.

#### Low — hardcoded point size in the search field

`.font(.system(size: 18))` will not scale with the user's text-size preference
and is not semantic, so it cannot inherit future metric changes. `.font(.title3)`
lands close and stays adaptive.

#### Low — tertiary text over a translucent background

The empty-state hint's second line is `.tertiary` over `.ultraThinMaterial` —
visible in the snapshot as a very low-contrast grey. Tertiary is intended for
text on an opaque surface; over a material whose luminance depends on the
desktop behind it, the effective contrast is unpredictable. Same issue on the
sidebar's list-count labels.

#### Low — AppKit types leaked into the shared UI module

`CodeDetailView` uses `Color(nsColor: .textBackgroundColor)`, and
`AbbreviationsSettingsView` uses it twice more. `CodeBarUI` is otherwise clean of
AppKit and is the module an iOS target would reuse wholesale. Three lines, worth
fixing before it becomes ten. See §11.

#### Low — inconsistent dashes in user-facing strings

The row says "category - not billable" (hyphen); the detail pane says "Category
— not valid for submission" (em dash). Two spellings of the same fact, in the
app's most safety-critical label. Pick one wording and one dash, use it in both.

---

## 2. Liquid Glass assessment

### Apple's rules, stated plainly

**[Apple]** The guidance is more restrictive than the marketing suggests:

- Liquid Glass belongs to **the navigation layer that floats above content** —
  toolbars, sidebars, tab bars, floating panels. Content stays at the base level.
- **Never glass on glass.** Overlapping glass surfaces are called out explicitly
  as a mistake.
- **Never glass in the content layer.** Putting it behind scrolling tables and
  lists "muddies visual hierarchy."
- **Don't overuse it.** "Limit these effects to the most important functional
  elements in your app."
- **Tint carries meaning, not decoration.** Tint the primary action; tinting
  everything means nothing stands out.
- **Two variants.** *Regular* adapts to what is behind it and guarantees
  legibility anywhere. *Clear* is permanently transparent, requires its own
  dimming layer, and is only correct over bold media-rich content. Never mix them.
- **Don't hardcode metrics.** Fixed frames prevent components from picking up
  the new sizes and shapes.

### The constraint that decides this

`project.yml` sets `deploymentTarget.macOS: "14.0"`. `.glassEffect()`,
`GlassEffectContainer`, `ConcentricRectangle`, `scrollEdgeEffectStyle` and
`safeAreaBar` are all macOS 26. Every one needs an `if #available` branch and a
maintained fallback path, on an app that currently has no design-token layer to
hang two branches off.

### Where it should and should not be used

| Surface | Verdict | Why |
|---|---|---|
| Window toolbar & sidebar | **Yes — free** | Standard components adopt it on recompile with Xcode 26. No code. This is the entire high-ROI story, and it requires first *having* a toolbar. |
| The search panel's chrome | **Yes — gated** | A floating panel over arbitrary other apps is the textbook navigation-layer case. Already `.ultraThinMaterial`; gate up to *regular* glass on 26, keep the material below. |
| A panel footer action bar | **Yes — if built** | If you add a bar showing ↵ / ⇧↵ / ⌘K, that bar is navigation and should float on glass with a scroll edge effect beneath it. |
| Result rows | **No** | Content layer. Dense text. Apple's stated anti-pattern, and it would put glass on glass inside the panel. |
| Detail pane, note editor | **No** | Reading surface. A text editor needs an opaque, predictable ground — `.textBackgroundColor` is correct here whatever else changes. |
| Badges, chips, pin buttons | **No** | "Limit these effects to the most important functional elements." A billability warning must be maximally legible, not translucent. |
| The *clear* variant, anywhere | **No** | Requires bold media-rich content beneath and a dimming layer. CodeBar has neither. |

### Recommendation

**[Call]** Treat Liquid Glass as a **compilation-time upgrade, not a design
project**. Build the toolbar, keep using standard components, raise the
deployment target when the user OS mix allows, rebuild with Xcode 26. Add
exactly one gated custom use — the panel chrome — and stop.

The reason is worth stating: on a tool measured in seconds-to-copy, translucency
behind a grid of small monospaced glyphs costs legibility and buys nothing.
CodeBar's distinctiveness should come from being *the fastest correct lookup on
the machine*, not from looking like the OS demo reel.

---

## 3. Design direction

One sentence: **a clinical reference instrument — dense, legible, unhurried in
the window and instantaneous in the panel — that spends its colour only on
things that can hurt you.**

Four rules the system follows from:

1. **The code and its description are the interface.** Every pixel not spent on
   them is justified individually.
2. **Colour is a safety channel.** Amber and red mean billability and exclusion.
   Nothing else may use them.
3. **Chrome recedes; the system provides it.** Toolbars, sidebars, selection,
   materials — all standard, so the app inherits every OS refinement including
   Liquid Glass at no cost.
4. **The panel is a different tempo, not a different app.** Same type, same
   colour, same row anatomy; tighter spacing, no scrolling chrome, no decoration.

### Colour roles

**[Call]** Roles, not a repaint. The point is that each role has exactly one owner.

| Role | Owns | Used for nothing else |
|---|---|---|
| `AccentColor` | Selection, links, pin-on | — |
| Warning (amber) | Not billable | Never a system badge |
| Prohibition (red) | `Excludes 1` | Never a destructive-button tint |
| Confirmed (green) | Billable | Never a system badge |
| Neutral | System identity | Distinguished by label, not hue |

Ship the accent as an asset rather than inheriting the user's system accent. The
four semantic colours are decided by meaning, so they get the same treatment:
light, dark and high-contrast variants each, defined once, in `CodeBarUI`.

### Type

Keep the current instinct — it is good. Codes in `.monospaced` so digits align;
descriptions in the system text face. Formalise it:

| Role | Style | Where |
|---|---|---|
| Code, hero | `.largeTitle` · monospaced · semibold | Detail pane header |
| Code, row | `.body` · monospaced · semibold | Every row, both surfaces |
| Description | `.body` · **primary** | Every row, both surfaces |
| Search field | `.title3` | Panel — replaces `size: 18` |
| Section label | `.caption` · semibold · secondary | PINNED, Includes, Excludes 1 |
| Metadata | `.caption2` · secondary | Chapter, counts, release |

Two changes of substance: descriptions are **primary** in both surfaces (the
window currently demotes them to secondary), and nothing below `.caption2` or
dimmer than `.secondary` appears over a translucent background.

### Space

A 4pt scale, named once, used everywhere: **2 · 4 · 8 · 12 · 16 · 24 · 32**. Row
vertical padding 8, horizontal 12. Section gaps 24. Detail pane margin 24.
Corner radii: 6 for rows, 10 for cards, and `ConcentricRectangle` where available
so nested shapes track their container.

---

## 4. Component recommendations

### Search panel

- **Width 680, not 560.** The single highest-leverage number in the app.
  Descriptions stop truncating and it still reads as a panel rather than a
  window. Spotlight is 680; Raycast is 750. **[Field]**
- **A persistent footer bar** showing the live key map: `↵` Copy · `⇧↵` Copy with
  description · `⌘↵` Open in window · `⌘K` Actions. This is how every
  keyboard-first launcher teaches its own shortcuts, and it replaces the per-row
  "↵ copy" hint that currently competes with the pin button. **[Field]**
- **Result count and system filter** in the field's trailing edge when more than
  one set is installed — a small segmented filter beats a badge on every row.
- **Keep** the placement logic, `hidesOnDeactivate`, and the content-driven
  height. Don't touch them.

### Result row

- Two-line description, primary colour, no ellipsis on the first line.
- Code column stays fixed and monospaced — it is what makes the list scannable.
  Add `.monospacedDigit()`.
- System badge only when more than one system is enabled; trailing edge; neutral.
- Billability chip keeps its wording and moves to the second line, so it never
  displaces description text.
- Pin appears on hover or when set, at the trailing edge, **outside** the row's
  copy target. A pin click must not also copy.
- Hover: raise the row background one step. Selection: system-strength fill plus
  a hairline inset stroke.

### Window toolbar

Build one. Primary `Copy` button (prominent, accent-tinted — the one place tint
is earned), a menu beside it for *Copy with description* and future formats,
then Pin, then Add to List. `ToolbarSpacer` between the copy group and the
library group so the two read as separate functions — **[Apple]** asks
specifically for semantic grouping with fixed spacers rather than one
undifferentiated bar.

### Sidebar

- Lists section is good. Give each list a symbol the user picks, not a uniform
  `list.bullet.rectangle` — a problem list and an encounter template should be
  distinguishable at a glance.
- Count badges: move from `.tertiary` caption to `.badge()`, the native
  affordance, which handles selection-state colour automatically.
- The bottom "New List" bar is hand-built with a `Divider` and
  `.background(.bar)`. On macOS 26 that will fight the sidebar's glass. Prefer a
  `+` in the toolbar's bottom bar, or gate to `safeAreaBar` where available.
  **[Apple]**

### Detail pane

Reorder to: *breadcrumb → code → description → status chip → publisher notes →
children → your note*. Then:

- **`Excludes 1` gets a container**, not just red label text: a left rule in the
  prohibition colour with a tinted ground, so it survives being skimmed. It is
  the only content in the app that means "this combination will be rejected."
- **Your note collapses when empty** to a single "Add a note" button. The
  permanently-open editor pays a fixed cost on every code for a feature used on
  a few.
- The "Save note" button that appears on change is honest but noisy — commit on
  focus loss (already implemented) and confirm with a brief "Saved" label.
- Breadcrumb: `.buttonStyle(.link)` at `.caption` is a small click target. Keep
  the size, add a hover underline and a ≥20pt hit area.
- Children list: currently `.plain` buttons with no hover. They are the fastest
  path to the billable child of a category, so they deserve the row treatment,
  not a bare label.

### Menu bar extra

`.menuBarExtraStyle(.menu)` with six items is correct, and correct to keep. Two
additions: a *Pinned codes* submenu so a pin is reachable without the panel, and
the installed-release summary as a disabled first item, since a stale code set
is invisible until it hurts. **[Call]**

### Settings

Structurally right already. Refinements: use `Toggle`'s own description slot
rather than a following `Text` in the same section (grouped form styles handle
that natively); render the fixed ⌥⌘C as a real disabled shortcut capsule rather
than a value string, so the eventual configurable version is a swap and not a
redesign.

### Feedback and notifications

CodeBar has no feedback layer at all. Add exactly one, and no more: a small HUD
at the panel's position showing `Copied E11.9` or `Copied ICD-10-CM E11.9 — Type
2 diabetes…`, auto-dismissing. **Never a system notification** — this is a
foreground, user-initiated action; a Notification Center banner would be
intrusive and would outlive its usefulness by four seconds.

### Empty states

The three `ContentUnavailableView` uses are right. One problem: "No hierarchy
installed" puts a Python command line in a description string. That is the right
information for the right person, but it should be selectable text at minimum,
and better as a "Show me how" button opening the docs. Also `Text("No matches")`
in the panel should be `ContentUnavailableView.search(text:)` for consistency
with the window.

---

## 5. Interaction improvements

### Keyboard — the highest-value area for a frequent user

| Key | Action | Status |
|---|---|---|
| `↑ ↓` | Move selection | Shipped |
| `↵` / `⇧↵` | Copy code / copy with description | Shipped, undiscoverable |
| `⌘1`–`⌘9` | Copy the *n*th result directly | Add — removes the arrow-key walk for the common case |
| `⌘↵` | Open this code in the browse window | Add — the panel cannot hand off to the window today |
| `⌘P` | Pin / unpin the selection | Add — pinning is mouse-only |
| `⌘K` | Action menu for the selection | Add — the extension point for future actions **[Field]** |
| `⇥` | Autocomplete to the selected code | Add — lets you refine rather than commit |
| `⌥↑ ⌥↓` | Jump between Pinned and Recent | Add — empty state only |
| `⎋` | Clear field, then dismiss on second press | Change — currently dismisses immediately, losing a typed query with no undo |

A structural note behind this: `.onKeyPress(keys: [.return])` is attached to the
panel's root `VStack`. As more keys are added that becomes an unreadable pile of
modifiers with implicit precedence. Move to a single key-handling function that
switches on key and modifiers, or to `commands` where the shortcut can also
appear in a menu.

### Motion

There is one animation in the whole app: a 0.1s `easeOut` scroll-to-selection.
That restraint is correct. What to add, and nothing beyond it:

- Panel appearance: 120ms opacity-and-scale from 0.98. It currently hard-cuts,
  which reads as a glitch rather than an arrival.
- Result set changes: **no animation**. Rows appearing and reflowing under a fast
  typist is worse than an instant swap. **[Call]**
- Copy confirmation: fade in 100ms, hold 1000ms, fade out 200ms.
- **All three gated on `@Environment(\.accessibilityReduceMotion)`** — including
  the existing scroll animation, which currently ignores it.

### Pointer

- Hover backgrounds on every clickable row, panel and window.
- Right-click context menu on result rows: Copy, Copy with description, Pin,
  Open in window, Add to List. The sidebar already has context menus; the panel
  has none.
- Drag a result row out of the panel to drop the code string into another app.
  Cheap with `.draggable()`, and for a copy-oriented tool it is the one gesture
  that genuinely earns its place. **[Call]**

---

## 6. Accessibility

Current state: two `accessibilityLabel` calls, two `.help` tooltips, one
`keyboardShortcut`, and no reference to any accessibility environment value in
the entire UI layer.

#### High — result rows are not accessibility elements

A row is an `HStack` of four to six independent `Text` views. VoiceOver reads
them as separate items — "ICD-10", "E11.9", "Type 2 diabetes mellitus without
com…", "pin" — so the user hears the **truncated** string, and the row is not a
single navigable unit.

**Fix:** `.accessibilityElement(children: .ignore)` with a composed label reading
the *full untruncated* description, plus `.accessibilityValue` for billability
and `.accessibilityAddTraits(.isSelected)`. Add `accessibilityAction`s for copy
and pin. Pattern in §9.

#### Medium — Reduce Motion is not honoured

The scroll-to-selection animation runs unconditionally. It is small, but it is
also the only animation, which makes it a one-line fix with no excuse.

#### Medium — semantic colours have no high-contrast variants

`Color.orange`, `.red` and `.green` at 0.15–0.18 background opacity carry the
billability and exclusion signals. **[Apple]** asks that custom colours define
light, dark *and* increased-contrast variants. Under Increase Contrast these
tinted grounds barely separate from the surface, and foreground text over an
18%-opacity fill is the app's weakest contrast pairing.

**Fix:** define the four semantic colours as asset colours with all three
variants, and read `\.colorSchemeContrast` to swap tinted fills for bordered ones.

#### Medium — nothing in the panel is reachable by Tab

Rows are gesture-driven with no focusable representation, so a keyboard-only
user can select and copy but cannot reach a row's pin button at all. Full
Keyboard Access users get less of the app than mouse users.

#### Low — one fixed font size, and fixed row column widths

`.font(.system(size: 18))` will not respond to text-size preferences, and
`BADGE_COLUMN_WIDTH` / `CODE_COLUMN_WIDTH` are absolute — at larger text the
code will clip inside its 92pt column. Use `@ScaledMetric` for both, or drop the
fixed columns for a `Grid` with alignment.

#### Low — the "↵ copy" hint is decorative to a screen reader

It renders a glyph VoiceOver will pronounce awkwardly, duplicating information
better delivered as a hint. Mark it `.accessibilityHidden(true)` and put "Press
Return to copy" on the row's `accessibilityHint`.

#### Also worth doing

- Announce the copy with `AccessibilityNotification.Announcement` — the panel
  vanishing is currently a silent outcome for a VoiceOver user.
- Label the search field's stethoscope glyph as decorative.
- Test with **Increase Contrast and Reduce Transparency both on**. That is what a
  low-vision clinician on a bright ward display will be running, and it is the
  combination the material-heavy panel is least tested against.

---

## 7. Before → After

Approximations at the app's real proportions.

### Result row — the panel's core unit

**Before** — 84 of 560 points on a constant label; both diabetes codes truncate
exactly where they differ; the warning chip pushes the description further;
selection is a dim navy wash.

```
┌──────────────────────────────────────────────────────────────────────┐
│ ▓ (ICD-10)  E11.9    Type 2 diabetes mellitus without com…  ⚲  ↵ copy│  ← selected
│   (ICD-10)  E11      Type 2 diabetes mellitus [category - n…] ⚲      │
│   (ICD-10)  E11.65   Type 2 diabetes mellitus with hyperg…    ⚲      │
└──────────────────────────────────────────────────────────────────────┘
   └─ 72pt ─┘└─92pt─┘└──────── whatever is left, 1 line ────────┘
```

**After** — badge dropped (one system installed); descriptions complete; the
warning gets its own line instead of stealing width; the category code is dimmed
rather than double-flagged; the footer teaches the shortcuts once, so the
per-row hint is not needed.

```
┌──────────────────────────────────────────────────────────────────────┐
│ ▓ E11.9    Type 2 diabetes mellitus without complications         ↵  │  ← selected
│   E11      Type 2 diabetes mellitus                                  │
│            [ Category — not valid for submission ]                   │
│   E11.65   Type 2 diabetes mellitus with hyperglycemia               │
├──────────────────────────────────────────────────────────────────────┤
│ ↵ Copy   ⇧↵ With description   ⌘↵ Open              ⌘K Actions       │
└──────────────────────────────────────────────────────────────────────┘
   └─92pt─┘└──────────── 2 lines, wraps, never truncates ──────────┘
```

### Detail pane header — where the actions live

**Before** — four equal buttons inside scrolling content, no primary, no
shortcuts, and they scroll away. An empty note editor sits between the code and
the exclusion rules that matter most.

```
E00-E89 › E08-E13 › E11
E11
Type 2 diabetes mellitus
[⚠ Category — not valid for submission]
[Copy code] [Copy with description] [Pin] [Add to List ⌄]
Your note
┌──────────────────────────────────────┐
│                                      │   ← ~140pt, always present
└──────────────────────────────────────┘
Includes · Excludes 1 · Use additional code    ← below the fold
```

**After** — actions promoted to a toolbar with one primary and a semantic gap
between the copy group and the library group; `Excludes 1` gets a container, not
just red text; children become real rows; the note collapses to a button.

```
┌─ toolbar ────────────────────────────────────────────────────────────┐
│ [ Copy code ] [⌄]      [Pin]  [Add to List ⌄]                        │
└──────────────────────────────────────────────────────────────────────┘
E00-E89 › E08-E13 › E11
E11
Type 2 diabetes mellitus
[ Category — not valid for submission ]

┃ Excludes 1 — never code together
┃ type 1 diabetes mellitus (E10.-)

Use additional code
insulin (Z79.4)

1 code beneath this
  ┌────────────────────────────────────────────────────────┐
  │ E11.9   Type 2 diabetes mellitus without complications │
  └────────────────────────────────────────────────────────┘

[ ＋ Add a note ]
```

### Panel empty state — the fastest path in the app

**Before** — no selection on open, so Return does nothing until you arrow down;
no keyboard route to a pin; badge repeated on every row.

```
🩺 Search ICD-10, LOINC, SNOMED, CPT…
──────────────────────────────────────────────────────────────
PINNED
   (ICD-10)  E11.9     Type 2 diabetes mellitus without compl…
RECENT
   (ICD-10)  J45.909   Unspecified asthma, uncomplicated
   (ICD-10)  I10       Essential (primary) hypertension
```

**After** — first pin pre-selected, so ⌥⌘C then Return is the two-keystroke path
the README already promises; direct `⌘1`–`⌘9` access; the placeholder states
what is installed, which is also the honest answer to "is my code set loaded?"

```
🩺 Search 98,186 codes…
──────────────────────────────────────────────────────────────
PINNED
 ▓ E11.9     Type 2 diabetes mellitus without complications  ⌘1
RECENT
   J45.909   Unspecified asthma, uncomplicated               ⌘2
   I10       Essential (primary) hypertension                ⌘3
──────────────────────────────────────────────────────────────
 ↵ Copy    ⌘P Pin                              ⌘K Actions
```

---

## 8. Priority roadmap

Ordered by user benefit per hour of work. The step-by-step execution plan —
dependencies, verification, and what to watch for in each step — is
[DESIGN_ROADMAP.md](DESIGN_ROADMAP.md).

### Quick wins — about a day

1. **Two-line descriptions** and panel width 680. Removes the correctness risk.
2. **Conditional system badge** — hide it when one system is installed.
3. **Ship an `AccentColor` asset** with three variants.
4. **Copy confirmation HUD.** Closes the biggest feedback gap.
5. **Row accessibility elements** with full untruncated labels.
6. **Honour Reduce Motion** on the scroll animation.
7. **One dash, one wording** for the billability label.
8. **`.title3` for the search field**, replacing `size: 18`.

### Medium — about a week

1. **A `DesignSystem` file** in `CodeBarUI`: spacing scale, radii, semantic
   colours, row metrics. Everything below depends on it.
2. **One shared `CodeRow`** with a density parameter, replacing `ResultRow` and
   `CodeRowLabel`.
3. **A real window toolbar**, moving the four detail-pane buttons into it.
4. **Reorder the detail pane**; container for `Excludes 1`; collapse the empty note.
5. **Keyboard set:** ⌘1–9, ⌘↵, ⌘P, ⇥, two-stage ⎋.
6. **Hover states and context menus** on every clickable row.
7. **Panel footer key map.**
8. **Semantic colours as asset colours** with high-contrast variants.

### Larger — two to four weeks

1. **Raise the deployment target** and rebuild with Xcode 26 — toolbar, sidebar
   and window shape adopt Liquid Glass with no code.
2. **Gated glass on the panel chrome**, with the current material as the fallback.
3. **⌘K action menu** in the panel, as the extension point for list-adding,
   export and crosswalks.
4. **Panel → window handoff**, so a lookup that turns out to need context does
   not restart.
5. **Full Keyboard Access** across both surfaces.
6. **Feature-module split** (SearchUI / BrowseUI / LibraryUI / SettingsUI over a
   shared design system) as [ARCHITECTURE.md](ARCHITECTURE.md) §11 anticipates.

**Sequencing.** Do the `DesignSystem` file before the shared `CodeRow`, and both
before the toolbar; the other order means writing the toolbar's spacing twice.
Everything in the Larger lane is optional. Nothing in the Quick lane is.

---

## 9. Implementation guidance

Sized to a codebase that values not overengineering. Each of these is one file
or one modifier.

### The token file — the whole thing

Resist a design-system package. One file in `CodeBarUI`, no protocols, no
theming layer:

```swift
// CodeBarUI/DesignSystem/Metric.swift

/// 4pt scale. Every spacing value in the app comes from here.
enum Metric {
    static let xs: CGFloat = 4,  s: CGFloat = 8,   m: CGFloat = 12
    static let l:  CGFloat = 16, xl: CGFloat = 24, xxl: CGFloat = 32

    static let rowRadius: CGFloat = 6
    static let cardRadius: CGFloat = 10
    static let panelWidth: CGFloat = 680
    static let codeColumn: CGFloat = 92
}
```

```swift
// CodeBarUI/DesignSystem/Palette.swift — asset colours, three variants each

extension ShapeStyle where Self == Color {
    /// Excludes 1. Never a destructive-button tint.
    static var prohibition: Color { .init("Prohibition", bundle: .module) }
    /// Not billable. Never a system badge.
    static var warning: Color { .init("Warning", bundle: .module) }
    /// Billable. Never a system badge.
    static var confirmed: Color { .init("Confirmed", bundle: .module) }
}
```

### The availability shim — one modifier, not a framework

```swift
extension View {
    /// The only place glass is conditional. Applied to the panel's root.
    func panelSurface() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: Metric.cardRadius))
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}
```

Do **not** build a general-purpose glass abstraction. There is exactly one gated
surface; a shim with two branches at one call site is honest, and a
`GlassCompatible` protocol would be the overengineering this codebase has so far
avoided.

### Row accessibility — the pattern to apply once and reuse

```swift
.accessibilityElement(children: .ignore)
.accessibilityLabel("\(code.system.shortLabel) \(code.code). \(code.display)")
.accessibilityValue(code.isBillable == false
                    ? "Category header, not valid for submission" : "")
.accessibilityHint("Press Return to copy")
.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
.accessibilityAction(named: "Pin") { onTogglePin?() }
```

The label uses `code.display` in full — truncation is a visual concern only, and
this is the line that guarantees a VoiceOver user never gets the short string.

### What not to do

- **Don't hand-roll glass on macOS 14/15.** Stacked blurs approximating Liquid
  Glass cost GPU time on every panel show and will look wrong beside the real
  thing on 26. `.ultraThinMaterial` is the correct fallback and is already there.
- **Don't animate the result list.** The debounce is 120ms; a typist outruns any
  transition, and the existing `ForEach` identity comment shows this list has
  already cost one class of bug.
- **Don't introduce a custom font.** The system faces plus `.monospaced` are
  correct here and free.
- **Don't build a theming system.** Light, dark and high-contrast via the asset
  catalogue is the whole requirement.
- **Don't replace `NavigationSplitView`.** It is the right container and it is
  what makes the sidebar adopt Liquid Glass for free.

### Testing the visual work

The six snapshot references are the right tool for most of this, and the known
limit is already recorded in [README.md](../README.md) — machine-specific, pinned
to dark. Two additions worth making alongside these changes: a snapshot of a
long-description row at panel width (the regression test for the truncation
fix), and one with Increase Contrast enabled (the regression test for the
semantic-colour work). One line each in `SnapshotTests`.

---

## 10. Design principles

Eight rules. If a future change fails one of them, it is the change that is wrong.

1. **Never truncate a code's meaning.** Wrap, widen, or reflow. The end of a
   description is where the clinical distinction lives. Nothing in the layout
   outranks it.
2. **Colour is a safety channel.** Amber, red and green mean billability and
   exclusion. They are never spent on taxonomy, decoration, or brand.
3. **Every action confirms itself.** A copy that vanishes silently is a copy the
   user will verify by hand, which costs more than the confirmation would.
4. **The keyboard is the primary input.** Every action reachable by mouse gets a
   shortcut, and the panel states what its shortcuts are rather than assuming
   they are known.
5. **Use the system's component or build none.** Standard controls inherit every
   OS refinement, Liquid Glass included, for free. A custom control has to earn
   its maintenance.
6. **Glass floats, content doesn't.** Translucency belongs to chrome above
   content. It never goes behind text you have to read carefully.
7. **Both surfaces, one vocabulary.** A code looks like a code in the panel and
   in the window. Density may change; anatomy may not.
8. **The publisher outranks the user's note.** Authoritative coding rules come
   first on screen. A personal reminder is valuable, but it is not the thing
   that gets a claim denied.

---

## 11. On iOS

Stated plainly: **CodeBar has no iOS target.** `project.yml` declares one macOS
application and one macOS UI-test bundle. Nothing in this section is a live
recommendation; it is what would be needed, plus the two cheap things worth
doing now.

### What already ports, and what doesn't

| Module | Portability | Note |
|---|---|---|
| `CodeCore` | Clean | Domain types and protocols, no AppKit, no SQLite. Ports unchanged. |
| `SQLiteKit`, `CodeStore`, `CodeLibrary` | Clean | SQLite is on both platforms. FTS5 and the trigger-maintained index work identically. |
| `CodeBarUI` | Four references | `Color(nsColor:)` in `CodeDetailView` and twice in `AbbreviationsSettingsView`, plus `NSColor(name:dynamicProvider:)` in `DesignSystem/Palette.swift`. The first three are incidental and should go; the fourth is deliberate and isolated to one file — see [DESIGN_ROADMAP.md](DESIGN_ROADMAP.md) 0.1. Everything else is portable SwiftUI. |
| `CodePlatform` | macOS-only by design | Carbon hotkey, `NSPasteboard`, login item, activation policy. Would need an iOS sibling — and the hotkey has no iOS equivalent at all. |

### What an iOS CodeBar would have to become

- **The fast path changes shape entirely.** There is no global hotkey. The
  equivalents are a **keyboard extension** (type a term, insert the code into any
  app's text field — closest to the panel's actual job), a Share/Action
  extension, a Shortcuts action via App Intents, and Spotlight indexing of
  pinned codes. The keyboard extension is the one that preserves the product's
  promise. **[Call]**
- **Three columns become a stack.** `NavigationSplitView` adapts on iPad; on
  iPhone it collapses to push navigation, which is correct — chapters → codes →
  detail.
- **Touch targets.** The pin glyph is caption-sized today. On iOS it needs
  44×44pt, which means moving it out of the row and into a swipe action — the
  native pattern, and better than the Mac version.
- **Dynamic Type is mandatory, not optional.** Which retires the fixed column
  widths entirely; a `Grid` or an adaptive two-line row is the only layout that
  survives Accessibility text sizes.
- **Sheets and detents.** The detail pane on iPhone is a sheet with `.medium` /
  `.large` detents, so the code list stays visible behind it.
- **Liquid Glass matters more here.** On iOS 26 the tab bar and navigation bar
  are glass by default, and floating controls over scrolling content are the
  canonical case. The one thing that stays true: not behind the code list.

### The two cheap things to do now

1. Replace the `NSColor` reference so `CodeBarUI` stays platform-neutral. Five
   minutes, and it keeps the option open.
2. Build the design-token file (§9) as platform-neutral `CGFloat`s and asset
   colours from the start. A token layer written macOS-first is the thing that
   is expensive to port later.

---

## Sources

**Apple, documented guidance**

- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass)
  — the layer model, grouping with fixed spacers, tinting rules, scroll edge
  effect, concentric radii, and the explicit do-nots.
- [Liquid Glass — Technology Overviews](https://developer.apple.com/documentation/technologyoverviews/liquid-glass)
- [Meet Liquid Glass (WWDC25 · 219)](https://developer.apple.com/videos/play/wwdc2025/219/)
  — regular vs clear, lensing, adaptivity, and the accessibility behaviours under
  Reduce Transparency, Increase Contrast and Reduce Motion.
- [Build a SwiftUI app with the new design (WWDC25 · 323)](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines)
- [Apple introduces a delightful and elegant new software design](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
  — the macOS Tahoe / Liquid Glass announcement.

**Field patterns**

- [Raycast](https://www.raycast.com/faq) and
  [Raycast vs Alfred](https://www.raycast.com/raycast-vs-alfred) — the
  keyboard-first launcher conventions cited above: the standardised ⌘K action
  menu, the persistent footer key map, and list/detail result rows.
- [Command palette conventions (⌘K)](https://www.techinterview.org/post/3233475212/build-command-palette-cmd-k/)
  as they have settled across Linear, Vercel, GitHub and Slack.

**CodeBar itself** — read directly: `SearchPanelView`, `ResultRow`,
`EmptyStateView`, `MainWindowView`, `CodeDetailView`, `SettingsView`,
`CodeSetsSettingsView`, `SearchPanelController`, `CodeBarApp`, `AppDelegate`,
`AboutPanel`, `project.yml`, [README.md](../README.md),
[ARCHITECTURE.md](ARCHITECTURE.md) §11, and the six snapshot references under
`Packages/CodeBarUI/Tests/CodeBarUITests/__Snapshots__/`.
