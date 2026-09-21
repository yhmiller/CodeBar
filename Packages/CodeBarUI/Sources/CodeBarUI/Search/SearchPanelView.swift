import CodeCore
import SwiftUI

private let SCROLL_ANIMATION_DURATION: TimeInterval = 0.1

public struct SearchPanelView: View {
    @State private var model: SearchViewModel

    @State private var text: String = ""
    @State private var listHeight: CGFloat = 0
    @State private var isNavigatingList: Bool = false

    @FocusState private var isFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let onDismiss: () -> Void
    private let onCopied: (String) -> Void
    private let onOpenInWindow: ((ClinicalCode) -> Void)?
    private let onTogglePeek: ((Bool) -> Void)?

    public init(
        model: SearchViewModel,
        onCopied: @escaping (String) -> Void = { _ in },
        onDismiss: @escaping () -> Void,
        onOpenInWindow: ((ClinicalCode) -> Void)? = nil,
        onTogglePeek: ((Bool) -> Void)? = nil
    ) {
        _model = State(initialValue: model)
        self.onCopied = onCopied
        self.onDismiss = onDismiss
        self.onOpenInWindow = onOpenInWindow
        self.onTogglePeek = onTogglePeek
    }

    public var body: some View {
        VStack(spacing: 0) {
            searchField
            SystemScopeFilterBar(
                availableSystems: model.availableSystems,
                activeScope: model.activeSystemScope,
                onSelectScope: { system in
                    model.setSystemScope(system)
                }
            )
            scopeAccentDivider
            mainContent
            if let footerContext {
                Divider()
                PanelFooter(context: footerContext, isPeeking: model.isPeeking, showsPeek: true)
            }
        }
        .frame(width: model.isPeeking ? Metric.peekPanelWidth : Metric.panelWidth)
        .ignoresSafeArea()
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: model.isPeeking)
        .onAppear { isFocused = true }
        .onChange(of: model.displaySessionID) { _, _ in
            text = ""
            isNavigatingList = false
            isFocused = true
        }
        .onChange(of: model.isPeeking) { _, peeking in
            onTogglePeek?(peeking)
        }
        .onKeyPress { press in handle(press) }
    }

    private var searchField: some View {
        HStack(spacing: Metric.m) {
            // Safe icon: single persistent view that swaps symbol name/color via direct property
            // animation, avoiding structural branch swaps inside Group that can collide.
            Image(systemName: model.activeSystemScope?.iconName ?? "stethoscope")
                .font(.system(
                    size: 16,
                    weight: model.activeSystemScope != nil ? .semibold : .regular
                ))
                .foregroundStyle(model.activeSystemScope?.themeColor ?? .secondary)
                .frame(width: 20, height: 20)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: model.activeSystemScope)
                .accessibilityHidden(true)

            TextField("Search ICD-10, LOINC, SNOMED, CPT…", text: $text)
                .textFieldStyle(.plain)
                .font(CodeTypography.searchField)
                .focused($isFocused)
                .onChange(of: text) { _, newValue in
                    isNavigatingList = false
                    model.setQuery(newValue)
                }

            // Safe clear button: always present, opacity-animated rather than
            // inserted/removed, to avoid transition identity assertion crashes.
            Button(action: {
                text = ""
                isNavigatingList = false
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(text.isEmpty ? 0 : 1)
            .scaleEffect(text.isEmpty ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.15), value: text.isEmpty)
            .allowsHitTesting(!text.isEmpty)
        }
        .padding(Metric.l)
    }

    private var scopeAccentDivider: some View {
        Divider()
            .overlay(alignment: .leading) {
                if let scope = model.activeSystemScope {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [scope.themeColor.opacity(0.55), scope.themeColor.opacity(0.12), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 1.5)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.activeSystemScope)
    }

    private var footerContext: PanelFooter.Context? {
        if model.selectableCodes.isEmpty { return nil }
        return model.cleanQuery.isEmpty ? .suggestions : .results
    }

    @ViewBuilder
    private var mainContent: some View {
        if model.isPeeking, let selectedCode = model.selectedCode {
            HStack(alignment: .top, spacing: 0) {
                content
                    .frame(width: Metric.peekListWidth)

                Divider()

                PeekInspectorView(
                    code: selectedCode,
                    detail: model.peekDetail,
                    note: model.peekNote,
                    isLoading: model.isPeekLoading,
                    isPinned: model.isPinned(selectedCode),
                    onCopy: { format in
                        model.copy(selectedCode, format: format)
                        confirmAndDismiss()
                    },
                    onTogglePin: {
                        model.togglePin(selectedCode)
                    },
                    onOpenInWindow: onOpenInWindow == nil ? nil : {
                        onOpenInWindow?(selectedCode)
                        onDismiss()
                    },
                    onDismiss: {
                        model.dismissPeek()
                    }
                )
                .frame(width: Metric.peekInspectorWidth)
            }
        } else {
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.cleanQuery.isEmpty {
            EmptyStateView(
                pinned: model.scopedPinnedCodes,
                recent: model.scopedRecentCodes,
                scopedSystem: model.activeSystemScope,
                showsSystemBadge: model.showsSystemBadge,
                isSelected: { model.isSelected($0) },
                isPeeking: { model.isPeeking && model.isSelected($0) },
                onChoose: { code in
                    model.copy(code)
                    confirmAndDismiss()
                },
                onTogglePin: { model.togglePin($0) },
                onTogglePeek: { code in
                    if !model.isSelected(code) {
                        let selectable = model.selectableCodes
                        if let idx = selectable.firstIndex(where: { $0.id == code.id }) {
                            model.moveSelection(idx - model.selectedIndex)
                        }
                    }
                    model.togglePeek()
                },
                onSearchExample: { exampleTerm in
                    if let parsedSystem = QueryScoper.parse(exampleTerm).scopedSystem {
                        model.setSystemScope(parsedSystem)
                        text = ""
                    } else {
                        if let active = model.activeSystemScope {
                            model.setSystemScope(active)
                        }
                        text = exampleTerm
                    }
                }
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
                            isPeeking: model.isPeeking && model.isSelected(result),
                            showsSystemBadge: model.showsSystemBadge,
                            onTogglePin: {
                                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                                model.togglePin(result.code)
                            },
                            onTogglePeek: {
                                if !model.isSelected(result) {
                                    if let idx = model.results.firstIndex(where: { $0.id == result.id }) {
                                        model.moveSelection(idx - model.selectedIndex)
                                    }
                                }
                                model.togglePeek()
                            },
                            highlightQuery: model.cleanQuery
                        )
                        .onTapGesture {
                            model.copy(result)
                            confirmAndDismiss()
                        }
                        .accessibilityHint("Press Return to copy")
                        .contextMenu {
                            Button(model.isPeeking && model.isSelected(result) ? "Close Peek (Space)" : "Peek Details (Space)") {
                                if !model.isSelected(result) {
                                    if let idx = model.results.firstIndex(where: { $0.id == result.id }) {
                                        model.moveSelection(idx - model.selectedIndex)
                                    }
                                }
                                model.togglePeek()
                            }
                            Divider()
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
            if model.isPeeking {
                model.dismissPeek()
                return .handled
            }
            if !text.isEmpty {
                text = ""
            } else if model.activeSystemScope != nil {
                model.setSystemScope(nil)
            } else {
                onDismiss()
            }
            return .handled

        case .space:
            if press.modifiers.contains(.command) || press.modifiers.contains(.control) {
                model.togglePeek()
                return .handled
            }
            if model.isPeeking {
                model.dismissPeek()
                return .handled
            }
            if isNavigatingList || text.isEmpty {
                model.togglePeek()
                return .handled
            }
            return .ignored

        case .downArrow:
            isNavigatingList = true
            model.moveSelection(1)
            return .handled

        case .upArrow:
            isNavigatingList = true
            model.moveSelection(-1)
            return .handled

        case .return:
            if press.modifiers.contains(.command) {
                guard let code = model.selectedCode else { return .ignored }
                onOpenInWindow?(code)
                onDismiss()
                return .handled
            }
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

        if press.characters == "y" {
            model.togglePeek()
            return .handled
        }

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
