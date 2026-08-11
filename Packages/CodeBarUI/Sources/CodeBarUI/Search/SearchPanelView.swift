import CodeCore
import SwiftUI

private let PANEL_WIDTH: CGFloat = 560
private let RESULT_LIST_MAX_HEIGHT: CGFloat = 340
private let SCROLL_ANIMATION_DURATION: TimeInterval = 0.1

public struct SearchPanelView: View {
    @State private var model: SearchViewModel

    /// The field owns its own text.
    ///
    /// Binding the TextField straight at `model.query` deadlocks the two against
    /// each other: assigning `results` when a search lands re-renders the view,
    /// which pushes a stale `query` back into the field, which writes back
    /// through the binding — and the text walks backwards one character per
    /// render. Keeping the text here means the model can never drive the field.
    @State private var text: String = ""

    @FocusState private var isFocused: Bool

    private let onDismiss: () -> Void

    public init(model: SearchViewModel, onDismiss: @escaping () -> Void) {
        _model = State(initialValue: model)
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
        }
        .frame(width: PANEL_WIDTH)
        .background(.ultraThinMaterial)
        .onAppear { isFocused = true }
        .onChange(of: model.displaySessionID) { _, _ in
            // The view survives between showings now, so each appearance has to
            // clear the field and reclaim focus explicitly.
            text = ""
            isFocused = true
        }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.downArrow) { model.moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { model.moveSelection(-1); return .handled }
        .onKeyPress(.return) { copySelected(); return .handled }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "stethoscope")
                .foregroundStyle(.secondary)
            TextField("Search ICD-10, LOINC, SNOMED, CPT…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .focused($isFocused)
                .onChange(of: text) { _, newValue in model.setQuery(newValue) }
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        if text.isEmpty {
            emptyState
        } else if model.results.isEmpty {
            Text("No matches")
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity)
        } else {
            resultList
        }
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                // Rows are keyed on the result's own identity. An explicit
                // .id(index) here fights ForEach's identity: when the result set
                // changes, a row that merely moved position is torn down and
                // rebuilt, and LazyVStack can leave the old one on screen —
                // which showed up as stale and duplicated rows.
                LazyVStack(spacing: 2) {
                    ForEach(model.results) { result in
                        ResultRow(code: result.code, isSelected: model.isSelected(result))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.copy(result)
                                onDismiss()
                            }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: RESULT_LIST_MAX_HEIGHT)
            .onChange(of: model.selectedResultID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: SCROLL_ANIMATION_DURATION)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 4) {
            Text("Start typing a term or a code")
                .foregroundStyle(.secondary)
            Text("e.g. \"type 2 diabetes\" or \"E11\"")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private func copySelected() {
        guard model.copySelected() else { return }
        onDismiss()
    }
}
