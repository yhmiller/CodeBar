import CodeCore
import SwiftUI

struct CodeRow: View {

    enum Density {
        case panel
        case list
        case compact
    }

    let code: ClinicalCode
    let density: Density
    var isSelected: Bool = false
    var isPinned: Bool = false
    var isPeeking: Bool = false

    var showsSystemBadge: Bool = true

    var onTogglePin: (() -> Void)? = nil
    var onTogglePeek: (() -> Void)? = nil

    @State private var isHovering = false
    @Environment(\.controlActiveState) private var controlState
    @Environment(\.colorSchemeContrast) private var contrast

    private var selectionFillOpacity: Double {
        guard controlState == .key else { return 0.12 }
        return contrast == .increased ? 0.18 : 0.28
    }

    var highlightQuery: String? = nil

    @ScaledMetric(relativeTo: .body) private var codeColumn: CGFloat = Metric.codeColumn

    private var codeColumnWidth: CGFloat {
        if code.code.count > 7 {
            let extra = CGFloat(code.code.count - 7) * 9.5
            return codeColumn + extra
        }
        return codeColumn
    }

    private var attributedDisplay: AttributedString {
        guard let highlight = highlightQuery?.trimmingCharacters(in: .whitespacesAndNewlines),
              !highlight.isEmpty else {
            return AttributedString(code.display)
        }
        var attributed = AttributedString(code.display)
        let terms = highlight.split(separator: " ").map(String.init).filter { !$0.isEmpty }
        let lowerDisplay = code.display.lowercased()

        for term in terms {
            let lowerTerm = term.lowercased()
            var searchStartIndex = lowerDisplay.startIndex

            while searchStartIndex < lowerDisplay.endIndex,
                  let matchRange = lowerDisplay.range(of: lowerTerm, range: searchStartIndex..<lowerDisplay.endIndex) {
                if let attrRange = Range(matchRange, in: attributed) {
                    attributed[attrRange].inlinePresentationIntent = .stronglyEmphasized
                    if !isSelected {
                        attributed[attrRange].foregroundColor = Color.accentColor
                    }
                }
                searchStartIndex = matchRange.upperBound
            }
        }
        return attributed
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metric.m) {
            Text(code.code)
                .font(CodeTypography.codeRow)
                .foregroundStyle(dimsCode ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .frame(width: density.usesFixedCodeColumn ? codeColumnWidth : nil,
                       alignment: .leading)

            Text(attributedDisplay)
                .font(CodeTypography.description)
                .lineLimit(density.descriptionLines)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)

            if showsUnspecifiedChip { unspecifiedChip }
            if showsBillabilityChip { billabilityChip }

            Spacer(minLength: Metric.s)

            trailingAffordances
        }
        .padding(.horizontal, density.horizontalPadding)
        .padding(.vertical, density.verticalPadding)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: Metric.rowRadius))
        .padding(.horizontal, density.inset)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
        .draggable(code.code)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(code.system.shortLabel) \(code.code). \(code.display)")
        .accessibilityValue(accessibilityValueString)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: isPinned ? "Unpin" : "Pin") { onTogglePin?() }
    }

    // MARK: - Trailing edge

    @ViewBuilder
    private var trailingAffordances: some View {
        if showsSystemBadge {
            Text(code.system.shortLabel)
                .font(CodeTypography.metadata.weight(.semibold))
                .padding(.horizontal, Metric.s)
                .padding(.vertical, Metric.xxs)
                .semanticChip(Color.systemBadge, in: Capsule())
                .fixedSize()
        }

        if let onTogglePeek, density == .panel, isHovering || isSelected {
            Button(action: onTogglePeek) {
                Image(systemName: isPeeking ? "eye.fill" : "eye")
                    .font(.caption)
                    .foregroundStyle(isPeeking ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(isPeeking ? "Close peek (Space)" : "Peek details (Space)")
            .accessibilityHidden(true)
        }

        if let onTogglePin, density == .panel, isPinned || isHovering {
            Button(action: onTogglePin) {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.caption)
                    .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
            }
            .buttonStyle(.plain)
            .help(isPinned ? "Unpin this code" : "Pin this code")
            .accessibilityHidden(true)
        }

        if isSelected && density == .panel {
            Text("↵")
                .font(CodeTypography.metadata)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(x: 4)), removal: .opacity))
        }
    }

    private var unspecifiedChip: some View {
        Text(UNSPECIFIED_LABEL)
            .font(CodeTypography.metadata.weight(.medium))
            .padding(.horizontal, Metric.xs)
            .padding(.vertical, Metric.xxs)
            .semanticChip(Color.warning, in: RoundedRectangle(cornerRadius: Metric.chipRadius))
            .fixedSize()
            .layoutPriority(1)
            .accessibilityHidden(true)
    }

    private var billabilityChip: some View {
        Text(NOT_BILLABLE_LABEL)
            .font(CodeTypography.metadata.weight(.medium))
            .padding(.horizontal, Metric.xs)
            .padding(.vertical, Metric.xxs)
            .semanticChip(Color.warning, in: RoundedRectangle(cornerRadius: Metric.chipRadius))
            .fixedSize()
            .layoutPriority(1)
            .accessibilityHidden(true)
    }

    // MARK: - Ground

    @ViewBuilder
    private var background: some View {
        if density == .list {
            Color.clear
        } else if isSelected {
            Color.accentColor.opacity(selectionFillOpacity)
                .overlay {
                    RoundedRectangle(cornerRadius: Metric.rowRadius)
                        .strokeBorder(Color.accentColor,
                                      lineWidth: contrast == .increased ? 2 : 1)
                        .opacity(contrast == .increased ? 1 : 0.45)
                }
        } else if isHovering {
            Color.primary.opacity(0.06)
        } else {
            Color.clear
        }
    }

    private var showsBillabilityChip: Bool {
        code.isBillable == false && density == .panel
    }

    private var showsUnspecifiedChip: Bool {
        code.isUnspecified == true && density == .panel
    }

    private var dimsCode: Bool {
        code.isBillable == false && density != .panel
    }

    private var accessibilityValueString: String {
        if code.isBillable == false { return NOT_BILLABLE_SPOKEN_LABEL }
        if code.isUnspecified == true { return UNSPECIFIED_SPOKEN_LABEL }
        return ""
    }
}

private extension CodeRow.Density {
    var descriptionLines: Int {
        self == .panel ? 2 : 1
    }

    var usesFixedCodeColumn: Bool {
        self == .panel
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .panel: Metric.rowPadding
        case .list: 0
        case .compact: Metric.s
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .panel: Metric.s
        case .list: 0
        case .compact: Metric.xs
        }
    }

    var inset: CGFloat {
        self == .panel ? Metric.rowInset : 0
    }
}
