import CodeCore
import SwiftUI

private let SCROLL_ANIMATION_DURATION: TimeInterval = 0.1

public struct SearchPanelView: View {
    @State private var model: SearchViewModel

    @State private var text: String = ""
    @State private var listHeight: CGFloat = 0

    @FocusState private var isFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let onDismiss: () -> Void
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
            if let footerContext {
                Divider()
                PanelFooter(context: footerContext)
            }
        }
        .frame(width: Metric.panelWidth)
        .onAppear { isFocused = true }
        .onChange(of: model.displaySessionID) { _, _ in
            text = ""
            isFocused = true
        }
        .onKeyPress { press in handle(press) }
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

    private var footerContext: PanelFooter.Context? {
        if model.selectableCodes.isEmpty { return nil }
        return text.isEmpty ? .suggestions : .results
    }

    @ViewBuilder
    private var content: some View {
        if text.isEmpty {
            EmptyStateView(
                pinned: model.pinnedCodes,
                recent: model.recentCodes,
                showsSystemBadge: model.showsSystemBadge,
                isSelected: { model.isSelected($0) },
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
                VStack(spacing: Metric.xxs) {
                    ForEach(model.results) { result in
                        CodeRow(
                            code: result.code,
                            density: .panel,
                            isSelected: model.isSelected(result),
                            isPinned: model.isPinned(result.code),
                            showsSystemBadge: model.showsSystemBadge,
                            onTogglePin: { model.togglePin(result.code) }
                        )
                        .onTapGesture {
                            model.copy(result)
                            confirmAndDismiss()
                        }
                        .accessibilityHint("Press Return to copy")
                        .contextMenu {
                            Button("Copy Code") {
                                model.copy(result)
                                confirmAndDismiss()
                            }
                            Button("Copy with Description") {
                                model.copy(result, format: .codeAndDisplay)
                                confirmAndDismiss()
                            }
                            Divider()
                            Button(model.isPinned(result.code) ? "Unpin" : "Pin") {
                                model.togglePin(result.code)
                            }
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
                withAnimation(reduceMotion ? nil : .easeOut(duration: SCROLL_ANIMATION_DURATION)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .escape:
            if text.isEmpty {
                onDismiss()
            } else {
                text = ""
            }
            return .handled

        case .downArrow:
            model.moveSelection(1)
            return .handled

        case .upArrow:
            model.moveSelection(-1)
            return .handled

        case .return:
            copySelected(format: press.modifiers.contains(.shift) ? .codeAndDisplay : .codeOnly)
            return .handled

        case .tab:
            guard let completion = model.selectedCodeText else { return .ignored }
            text = completion
            return .handled

        default:
            return handleCharacter(press)
        }
    }

    private func handleCharacter(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.contains(.command) else { return .ignored }

        if press.characters == "p" {
            return model.togglePinOnSelection() ? .handled : .ignored
        }

        guard let digit = Int(press.characters), (1...9).contains(digit) else {
            return .ignored
        }
        guard model.copy(at: digit - 1) else { return .ignored }
        confirmAndDismiss()
        return .handled
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
