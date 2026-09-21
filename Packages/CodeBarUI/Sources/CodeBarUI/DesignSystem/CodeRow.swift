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

    var showsSystemBadge: Bool = true

    var onTogglePin: (() -> Void)? = nil

    @State private var isHovering = false
    @Environment(\.controlActiveState) private var controlState
    @Environment(\.colorSchemeContrast) private var contrast

    private var selectionFillOpacity: Double {
        guard controlState == .key else { return 0.12 }
        return contrast == .increased ? 0.18 : 0.28
    }

    @ScaledMetric(relativeTo: .body) private var codeColumn: CGFloat = Metric.codeColumn

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Metric.m) {
            Text(code.code)
                .font(CodeTypography.codeRow)
                .foregroundStyle(dimsCode ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
                .frame(width: density.usesFixedCodeColumn ? codeColumn : nil,
                       alignment: .leading)

            Text(code.display)
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
        .onHover { isHovering = $0 }
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
