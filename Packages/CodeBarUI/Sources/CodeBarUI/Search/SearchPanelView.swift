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
    private let onOpenInWindow: ((ClinicalCode) -> Void)?

    public init(
        model: SearchViewModel,
        onCopied: @escaping (String) -> Void = { _ in },
        onDismiss: @escaping () -> Void,
        onOpenInWindow: ((ClinicalCode) -> Void)? = nil
    ) {
        _model = State(initialValue: model)
        self.onCopied = onCopied
        self.onDismiss = onDismiss
        self.onOpenInWindow = onOpenInWindow
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
            content
            if let footerContext {
                Divider()
                PanelFooter(context: footerContext)
            }
        }
        .frame(width: Metric.panelWidth)
        .ignoresSafeArea()
        .onAppear { isFocused = true }
        .onChange(of: model.displaySessionID) { _, _ in
            text = ""
            isFocused = true
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
                .onChange(of: text) { _, newValue in model.setQuery(newValue) }

            // Safe clear button: always present, opacity-animated rather than
            // inserted/removed, to avoid transition identity assertion crashes.
            Button(action: {
                text = ""
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
    private var content: some View {
        if model.cleanQuery.isEmpty {
            EmptyStateView(
                pinned: model.scopedPinnedCodes,
                recent: model.scopedRecentCodes,
                scopedSystem: model.activeSystemScope,
                showsSystemBadge: model.showsSystemBadge,
                isSelected: { model.isSelected($0) },
                onChoose: { code in
                    model.copy(code)
                    confirmAndDismiss()
                },
                onTogglePin: { model.togglePin($0) },
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
                            showsSystemBadge: model.showsSystemBadge,
                            onTogglePin: {
                                NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
                                model.togglePin(result.code)
                            },
                            highlightQuery: model.cleanQuery
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
            if !text.isEmpty {
                text = ""
            } else if model.activeSystemScope != nil {
                model.setSystemScope(nil)
            } else {
                onDismiss()
            }
            return .handled

        case .downArrow:
            model.moveSelection(1)
            return .handled

        case .upArrow:
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
