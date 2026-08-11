import CodeCore
import SwiftUI

private let PANEL_WIDTH: CGFloat = 560
let RESULT_LIST_MAX_HEIGHT: CGFloat = 340
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

    /// Measured height of the result rows, so the panel can size to them.
    @State private var listHeight: CGFloat = 0

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
        .onKeyPress(keys: [.return]) { press in
            // ⇧↵ copies the code with its description, for pasting into prose
            // rather than into a code field.
            copySelected(format: press.modifiers.contains(.shift) ? .codeAndDisplay : .codeOnly)
            return .handled
        }
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
            EmptyStateView(
                pinned: model.pinnedCodes,
                recent: model.recentCodes,
                onChoose: { code in
                    model.copy(code)
                    onDismiss()
                },
                onTogglePin: { model.togglePin($0) }
            )
            .id(model.pinRevision)
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
                // rebuilt, and the stack can leave the old one on screen —
                // which showed up as stale and duplicated rows.
                //
                // Eager rather than lazy: results are capped at 30, and a lazy
                // stack only measures what it has laid out, which is useless to
                // a panel trying to size itself to its content.
                VStack(spacing: 2) {
                    ForEach(model.results) { result in
                        ResultRow(
                            code: result.code,
                            isSelected: model.isSelected(result),
                            isPinned: model.isPinned(result.code),
                            onTogglePin: { model.togglePin(result.code) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.copy(result)
                            onDismiss()
                        }
                    }
                }
                .padding(.vertical, 6)
                .measuringHeight()
            }
            .frame(height: min(listHeight, RESULT_LIST_MAX_HEIGHT))
            .onPreferenceChange(ContentHeightPreferenceKey.self) { listHeight = $0 }
            .onChange(of: model.selectedResultID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: SCROLL_ANIMATION_DURATION)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }


    private func copySelected(format: CopyFormat) {
        guard model.copySelected(format: format) else { return }
        onDismiss()
    }
}
