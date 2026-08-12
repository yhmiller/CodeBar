import CodeCore
import SwiftUI

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let onDismiss: () -> Void

    /// Called with the string that reached the pasteboard, just before the panel
    /// goes away. The panel cannot show its own confirmation — it is dismissing.
    private let onCopied: (String) -> Void

    public init(
        model: SearchViewModel,
        onCopied: @escaping (String) -> Void = { _ in },
        onDismiss: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.onCopied = onCopied
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()
            content
        }
        .frame(width: Metric.panelWidth)
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
        HStack(spacing: Metric.m) {
            Image(systemName: "stethoscope")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("Search ICD-10, LOINC, SNOMED, CPT…", text: $text)
                .textFieldStyle(.plain)
                .font(CodeTypography.searchField)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in model.setQuery(newValue) }
        }
        .padding(Metric.l)
    }

    @ViewBuilder
    private var content: some View {
        if text.isEmpty {
            EmptyStateView(
                pinned: model.pinnedCodes,
                recent: model.recentCodes,
                showsSystemBadge: model.showsSystemBadge,
                onChoose: { code in
                    model.copy(code)
                    confirmAndDismiss()
                },
                onTogglePin: { model.togglePin($0) }
            )
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
                VStack(spacing: Metric.xxs) {
                    ForEach(model.results) { result in
                        ResultRow(
                            code: result.code,
                            isSelected: model.isSelected(result),
                            isPinned: model.isPinned(result.code),
                            showsSystemBadge: model.showsSystemBadge,
                            onTogglePin: { model.togglePin(result.code) }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.copy(result)
                            confirmAndDismiss()
                        }
                    }
                }
                .padding(.vertical, Metric.s)
                .measuringHeight()
            }
            .frame(height: min(listHeight, Metric.resultListMaxHeight))
            .onPreferenceChange(ContentHeightPreferenceKey.self) { listHeight = $0 }
            .onChange(of: model.selectedResultID) { _, newValue in
                guard let newValue else { return }
                // The app's only animation, so honouring Reduce Motion is one
                // line and there is no excuse for skipping it.
                withAnimation(reduceMotion ? nil : .easeOut(duration: SCROLL_ANIMATION_DURATION)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }


    private func copySelected(format: CopyFormat) {
        guard model.copySelected(format: format) else { return }
        confirmAndDismiss()
    }

    private func confirmAndDismiss() {
        if let copied = model.lastCopiedText { onCopied(copied) }
        onDismiss()
    }
}
