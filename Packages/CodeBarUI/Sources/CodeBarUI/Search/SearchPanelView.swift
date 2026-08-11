import CodeCore
import SwiftUI

private let PANEL_WIDTH: CGFloat = 560
private let RESULT_LIST_MAX_HEIGHT: CGFloat = 340
private let SCROLL_ANIMATION_DURATION: TimeInterval = 0.1

public struct SearchPanelView: View {
    @State private var model: SearchViewModel
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
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.downArrow) { model.moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { model.moveSelection(-1); return .handled }
        .onKeyPress(.return) { copySelected(); return .handled }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "stethoscope")
                .foregroundStyle(.secondary)
            TextField(
                "Search ICD-10, LOINC, SNOMED, CPT…",
                text: Binding(get: { model.query }, set: { model.setQuery($0) })
            )
            .textFieldStyle(.plain)
            .font(.system(size: 18))
            .focused($isFocused)
        }
        .padding(14)
    }

    @ViewBuilder
    private var content: some View {
        if model.query.isEmpty {
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
                LazyVStack(spacing: 2) {
                    ForEach(Array(model.results.enumerated()), id: \.element.id) { index, result in
                        ResultRow(code: result.code, isSelected: model.isSelected(index))
                            .id(index)
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
            .onChange(of: model.selectedIndex) { _, newValue in
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
