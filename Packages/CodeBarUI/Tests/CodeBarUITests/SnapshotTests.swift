import CodeCore
import SnapshotTesting
import SwiftUI
import Testing
@testable import CodeBarUI

@Suite("Snapshots")
@MainActor
struct SnapshotTests {

    private static let panelSize = CGSize(width: Metric.panelWidth, height: 180)
    private static let detailSize = CGSize(width: 620, height: 520)

    private static func panel(_ height: CGFloat) -> CGSize {
        CGSize(width: Metric.panelWidth, height: height)
    }

    private func assertImage(
        _ view: some View,
        size: CGSize,
        named name: String,
        appearance: NSAppearance.Name = .darkAqua
    ) {
        let grounded = view
            .frame(width: size.width, alignment: .topLeading)
            .background(Color(nsColor: .windowBackgroundColor))

        let controller = NSHostingController(rootView: grounded)
        controller.view.frame = CGRect(origin: .zero, size: size)
        controller.view.appearance = NSAppearance(named: appearance)

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

    @Test("a long description should wrap rather than truncate")
    func longDescriptionWraps() {
        let rows = VStack(spacing: Metric.xxs) {
            CodeRow(code: Samples.longDescription.code, density: .panel, isSelected: true,
                      isPinned: false, onTogglePin: {})
        }
        .padding(.vertical, Metric.s)

        assertImage(rows, size: Self.panel(90), named: "result-row-long-description")
    }

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

    // MARK: - Accessibility

    @Test("chips should stay legible under increased contrast")
    func rowsUnderIncreasedContrast() {
        let rows = VStack(spacing: Metric.xxs) {
            CodeRow(code: Samples.diabetes.code, density: .panel, isSelected: true,
                    isPinned: false, onTogglePin: {})
            CodeRow(code: Samples.header.code, density: .panel,
                    isPinned: false, onTogglePin: {})
        }
        .padding(.vertical, Metric.s)

        assertImage(rows, size: Self.panel(110), named: "result-rows-increased-contrast",
                    appearance: .accessibilityHighContrastDarkAqua)
    }

    // MARK: - Footer

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
