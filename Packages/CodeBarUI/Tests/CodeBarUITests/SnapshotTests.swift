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

    private static let panelSize = CGSize(width: 560, height: 180)
    private static let detailSize = CGSize(width: 620, height: 520)

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
        let rows = VStack(spacing: 2) {
            ResultRow(code: Samples.diabetes.code, isSelected: true,
                      isPinned: false, onTogglePin: {})
            ResultRow(code: Samples.header.code, isSelected: false,
                      isPinned: false, onTogglePin: {})
            ResultRow(code: Samples.asthma.code, isSelected: false,
                      isPinned: true, onTogglePin: {})
        }
        .padding(.vertical, 6)

        assertImage(rows, size: CGSize(width: 560, height: 140), named: "result-rows")
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
        .frame(width: 560)

        assertImage(view, size: CGSize(width: 560, height: 220), named: "empty-state")
    }

    @Test("the empty state should explain itself before anything is pinned")
    func emptyStateHint() {
        let view = EmptyStateView(pinned: [], recent: [], onChoose: { _ in }, onTogglePin: { _ in })
            .frame(width: 560)

        assertImage(view, size: CGSize(width: 560, height: 120), named: "empty-state-hint")
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
            isPinned: false,
            note: "Our clinic codes new diagnoses here",
            lists: [CodeList(id: 1, name: "Clinic", detail: nil, createdAt: .distantPast, count: 3)],
            currentList: nil,
            onCopy: { _, _ in },
            onTogglePin: { _ in },
            onSelectCode: { _ in },
            onSaveNote: { _ in },
            onAddToList: { _ in },
            onRemoveFromList: {}
        )

        assertImage(view, size: Self.detailSize, named: "detail-pane")
    }

    @Test("the detail pane should say when nothing is selected")
    func detailPaneEmpty() {
        let view = CodeDetailView(
            detail: nil, isPinned: false, note: "", lists: [], currentList: nil,
            onCopy: { _, _ in }, onTogglePin: { _ in }, onSelectCode: { _ in },
            onSaveNote: { _ in }, onAddToList: { _ in }, onRemoveFromList: {}
        )

        assertImage(view, size: CGSize(width: 420, height: 260), named: "detail-pane-empty")
    }

    // MARK: - Search panel

    /// Only the panel's opening state is reachable from here.
    ///
    /// `SearchPanelView` owns its text in `@State`, which nothing outside the
    /// view can set — deliberately, since letting the model drive the field is
    /// what made the query walk backwards in phase 2. Driving it would need a
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
