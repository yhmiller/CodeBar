import AppKit
import CodeCore
import SwiftUI

private let PANEL_WIDTH: CGFloat = 560
private let RESULT_LIST_MAX_HEIGHT: CGFloat = 340

struct SearchPanelView: View {
    let repository: (any CodeRepository)?
    var onDismiss: () -> Void

    @State private var query: String = ""
    @State private var results: [SearchResult] = []
    @State private var selectedIndex: Int = 0
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "stethoscope")
                    .foregroundStyle(.secondary)
                TextField("Search ICD-10, LOINC, SNOMED, CPT…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18))
                    .focused($isFocused)
                    .onChange(of: query) { _, newValue in runSearch(newValue) }
            }
            .padding(14)

            Divider()

            if query.isEmpty {
                emptyState
            } else if results.isEmpty {
                Text("No matches")
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                resultList
            }
        }
        .frame(width: PANEL_WIDTH)
        .background(.ultraThinMaterial)
        .onAppear { isFocused = true }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.return) { copySelected(); return .handled }
    }

    private var resultList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        ResultRow(code: result.code, isSelected: index == selectedIndex)
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture { copy(result.code) }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: RESULT_LIST_MAX_HEIGHT)
            .onChange(of: selectedIndex) { _, newValue in
                withAnimation(.easeOut(duration: 0.1)) {
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

    /// Cancelling the in-flight task is what stops a slow query for "dia"
    /// landing after a faster one for "diabetes".
    ///
    /// TODO(yhmiller): move to a debounced SearchViewModel in phase 2.
    private func runSearch(_ text: String) {
        searchTask?.cancel()
        selectedIndex = 0

        guard let repository, !text.isEmpty else {
            results = []
            return
        }

        searchTask = Task {
            let found = (try? await repository.search(SearchQuery(raw: text))) ?? []
            guard !Task.isCancelled else { return }
            results = found
        }
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, min(results.count - 1, selectedIndex + delta))
    }

    private func copySelected() {
        guard results.indices.contains(selectedIndex) else { return }
        copy(results[selectedIndex].code)
    }

    private func copy(_ item: ClinicalCode) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.code, forType: .string)
        onDismiss()
    }
}
