import CodeCore
import SnapshotTesting
import SwiftUI
import Testing
@testable import CodeBarUI

/// Rendered-output tests, covering the class of defect the view-model tests
/// cannot see.
///
/// Every UI bug in this project's history was found by a human looking at the
/// screen: a query walking backwards while the field showed something else,
/// duplicated rows, a transparent toolbar with list content scrolling under it.
/// None of those change a view model's values, so none were catchable by
/// asserting on one. A reference image is.
///
/// These are inherently machine-dependent — fonts, appearance and OS version all
/// move the pixels. They earn their place on a single-developer project on one
/// Mac; a shared CI machine would need its own references or a tolerance.
@Suite("Snapshots")
@MainActor
struct SnapshotTests {

    private static let panelSize = CGSize(width: Metric.panelWidth, height: 180)
    private static let detailSize = CGSize(width: 620, height: 520)

    /// Rows are rendered at the panel's real width, not at a number that
    /// happened to match it. The two used to be spelled independently, so a
    /// change to one silently stopped testing the other.
    private static func panel(_ height: CGFloat) -> CGSize {
        CGSize(width: Metric.panelWidth, height: height)
    }

    /// Snapshots the SwiftUI view through the same hosting path the app uses.
    ///
    /// The appearance is pinned and a ground is painted deliberately. Without
    /// them the view renders dark-appearance text onto a transparent background,
    /// so anything using `.primary` came out white on white — the first recorded
    /// detail-pane reference was almost entirely blank, and would have passed
    /// forever while hiding regressions in everything invisible.
    ///
    /// Pinning also means the references do not change when the machine switches
    /// between light and dark mode.
    ///
    /// A failure reports this line rather than the calling test, so `named:`
    /// carries the identification instead.
    private func assertImage(_ view: some View, size: CGSize, named name: String) {
        let grounded = view
            .frame(width: size.width, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))

        let controller = NSHostingController(rootView: grounded)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.appearance = NSAppearance(named: .darkAqua)

        assertSnapshot(of: controller, as: .image(size: size), named: name, testName: "snapshot")
    }

    // MARK: - Result rows

    @Test("billable and header rows should stay visually distinct")
    func resultRowVariants() {
        let rows = VStack(spacing: Metric.xxs) {
            CodeRow(code: Samples.diabetes.code, density: .panel, isSelected: true,
                      isPinned: false, onTogglePin: {})
            CodeRow(code: Samples.header.code, density: .panel, isSelected: false,
                      isPinned: false, onTogglePin: {})
            CodeRow(code: Samples.asthma.code, density: .panel, isSelected: false,
                      isPinned: true, onTogglePin: {})
        }
        .padding(.vertical, Metric.s)

        assertImage(rows, size: Self.panel(140), named: "result-rows")
    }

    /// The regression test for the app's worst defect.
    ///
    /// `.lineLimit(1)` in a 560pt panel truncated "Type 2 diabetes mellitus
    /// without com…" — hiding the clause that separates E11.9 from E11.65. This
    /// asserts the widened, two-line row shows a real 88-character CMS
    /// description whole.
    @Test("a long description should wrap rather than truncate")
    func longDescriptionWraps() {
        let rows = VStack(spacing: Metric.xxs) {
            CodeRow(code: Samples.longDescription.code, density: .panel, isSelected: true,
                      isPinned: false, onTogglePin: {})
        }
        .padding(.vertical, Metric.s)

        assertImage(rows, size: Self.panel(90), named: "result-row-long-description")
    }

    /// The regression test for the merge itself.
    ///
    /// The panel and the window used to render a code with two unrelated row
    /// types, so moving between surfaces made codes stop looking like the same
    /// kind of thing. Density may change; anatomy may not — and that is only
    /// checkable by looking at the three side by side.
    @Test("the three row densities should stay visibly related")
    func rowDensities() {
        let rows = VStack(alignment: .leading, spacing: Metric.m) {
            CodeRow(code: Samples.diabetes.code, density: .panel, showsSystemBadge: false)
            CodeRow(code: Samples.diabetes.code, density: .list, showsSystemBadge: false)
            CodeRow(code: Samples.diabetes.code, density: .compact, showsSystemBadge: false)
        }
        .padding(Metric.m)

        assertImage(rows, size: Self.panel(150), named: "code-row-densities")
    }

    // MARK: - Footer

    /// The footer is the app's only statement of its own shortcuts, so what it
    /// claims has to stay true. Every key listed here must actually work in the
    /// state it is listed for — a shortcut that fails the first time it is tried
    /// is worse than one nobody knew about.
    @Test("the footer should list the keys that work on results")
    func footerForResults() {
        assertImage(PanelFooter(context: .results),
                    size: Self.panel(44), named: "panel-footer-results")
    }

    @Test("the footer should drop the description key when nothing is typed")
    func footerForSuggestions() {
        assertImage(PanelFooter(context: .suggestions),
                    size: Self.panel(44), named: "panel-footer-suggestions")
    }

    // MARK: - Copy confirmation

    /// The long form is the case worth locking. Confirming a copy is only
    /// useful if it distinguishes `↵` from `⇧↵`, which means the description has
    /// to survive into the confirmation.
    @Test("the copy confirmation should show the long form it copied")
    func copyConfirmationLongForm() {
        let view = CopyConfirmationView(
            copiedText: CopyFormat.codeAndDisplay.string(for: Samples.diabetes.code)
        )

        assertImage(view, size: CGSize(width: 520, height: 70),
                    named: "copy-confirmation-long")
    }

    @Test("the copy confirmation should show a bare code")
    func copyConfirmationCodeOnly() {
        let view = CopyConfirmationView(
            copiedText: CopyFormat.codeOnly.string(for: Samples.diabetes.code)
        )

        assertImage(view, size: CGSize(width: 260, height: 70),
                    named: "copy-confirmation-code")
    }

    // MARK: - Empty state

    @Test("the empty state should offer pins and recents")
    func emptyStateWithSuggestions() {
        let view = EmptyStateView(
            pinned: [Samples.diabetes.code],
            recent: [Samples.asthma.code, Samples.hypertension.code],
            onChoose: { _ in },
            onTogglePin: { _ in }
        )
        .frame(width: Metric.panelWidth)

        assertImage(view, size: Self.panel(220), named: "empty-state")
    }

    @Test("the empty state should explain itself before anything is pinned")
    func emptyStateHint() {
        let view = EmptyStateView(pinned: [], recent: [], onChoose: { _ in }, onTogglePin: { _ in })
            .frame(width: Metric.panelWidth)

        assertImage(view, size: Self.panel(120), named: "empty-state-hint")
    }

    // MARK: - Detail pane

    @Test("the detail pane should separate coding rules from the user's own note")
    func detailPane() {
        let detail = CodeDetail(
            code: Samples.header.code,
            ancestors: [],
            children: [Samples.diabetes.code],
            notes: [
                CodeNote(kind: .includes, text: "diabetes NOS"),
                CodeNote(kind: .excludes1, text: "type 1 diabetes mellitus (E10.-)"),
                CodeNote(kind: .useAdditionalCode, text: "insulin (Z79.4)")
            ]
        )

        let view = CodeDetailView(
            detail: detail,
            note: "Our clinic codes new diagnoses here",
            onSelectCode: { _ in },
            onSaveNote: { _ in }
        )

        assertImage(view, size: Self.detailSize, named: "detail-pane")
    }

    /// The ordering regression test.
    ///
    /// With no note, nothing at all should stand between the code and the
    /// publisher's rules. An always-open editor used to sit there and push
    /// `Excludes 1` — the rule that means *never code these together* — below
    /// the fold on every single code.
    @Test("the detail pane should show coding rules before the empty note")
    func detailPaneWithoutNote() {
        let detail = CodeDetail(
            code: Samples.header.code,
            ancestors: [],
            children: [Samples.diabetes.code],
            notes: [
                CodeNote(kind: .includes, text: "diabetes NOS"),
                CodeNote(kind: .excludes1, text: "type 1 diabetes mellitus (E10.-)"),
                CodeNote(kind: .useAdditionalCode, text: "insulin (Z79.4)")
            ]
        )

        let view = CodeDetailView(
            detail: detail, note: "", onSelectCode: { _ in }, onSaveNote: { _ in }
        )

        assertImage(view, size: Self.detailSize, named: "detail-pane-no-note")
    }

    @Test("the detail pane should say when nothing is selected")
    func detailPaneEmpty() {
        let view = CodeDetailView(
            detail: nil, note: "", onSelectCode: { _ in }, onSaveNote: { _ in }
        )

        assertImage(view, size: CGSize(width: 420, height: 260), named: "detail-pane-empty")
    }

    // MARK: - Abbreviations

    /// The override notice is the part worth locking: a silent replacement is how
    /// the wrong reading of a letter pair ends up in use.
    @Test("the abbreviations pane should name the built-in an entry replaces")
    func abbreviationsWithOverride() async {
        let library = FakeLibrary()
        await library.saveAbbreviation(Abbreviation(term: "pcn", expansion: "penicillin"))
        await library.saveAbbreviation(Abbreviation(term: "ra", expansion: "right atrium"))
        let model = AbbreviationsViewModel(library: library)
        await model.load()

        assertImage(AbbreviationsSettingsView(model: model),
                    size: CGSize(width: Metric.settingsWidth, height: 320), named: "abbreviations")
    }

    @Test("the abbreviations pane should show an example before anything is added")
    func abbreviationsEmpty() async {
        let model = AbbreviationsViewModel(library: FakeLibrary())
        await model.load()

        assertImage(AbbreviationsSettingsView(model: model),
                    size: CGSize(width: Metric.settingsWidth, height: 260), named: "abbreviations-empty")
    }

    // MARK: - Search panel

    /// Only the panel's opening state is reachable from here.
    ///
    /// `SearchPanelView` owns its text in `@State`, which nothing outside the
    /// view can set — deliberately, since letting the model drive the field
    /// makes the query walk backwards. Driving it would need a
    /// UI test that types. The rendered result rows are covered by the
    /// `result-rows` reference instead.
    @Test("the panel should open on its placeholder")
    func searchPanelPlaceholder() async {
        let model = SearchViewModel(repository: CountingRepository(),
                                    pasteboard: FakePasteboard(),
                                    library: FakeLibrary(), preferences: FakePreferences(),
                                    debounce: .milliseconds(1))

        assertImage(SearchPanelView(model: model, onDismiss: {}),
                    size: Self.panelSize, named: "search-panel-placeholder")
    }
}
