import SwiftUI
import AppKit

struct SearchPanelView: View {
    @State private var query: String = ""
    @State private var results: [ClinicalCode] = []
    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool

    var onDismiss: () -> Void

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
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                ResultRow(code: item, isSelected: index == selectedIndex)
                                    .id(index)
                                    .contentShape(Rectangle())
                                    .onTapGesture { copy(item) }
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .frame(maxHeight: 340)
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 560)
        .background(.ultraThinMaterial)
        .onAppear { isFocused = true }
        .onKeyPress(.escape) { onDismiss(); return .handled }
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.return) { copySelected(); return .handled }
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

    private func runSearch(_ text: String) {
        selectedIndex = 0
        guard !text.isEmpty else {
            results = []
            return
        }
        results = CodeDatabase.shared.search(text)
    }

    private func moveSelection(_ delta: Int) {
        guard !results.isEmpty else { return }
        selectedIndex = max(0, min(results.count - 1, selectedIndex + delta))
    }

    private func copySelected() {
        guard results.indices.contains(selectedIndex) else { return }
        copy(results[selectedIndex])
    }

    private func copy(_ item: ClinicalCode) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.code, forType: .string)
        onDismiss()
    }
}
