import CodeCore
import SwiftUI

/// One code, rendered the same way everywhere it appears.
///
/// There used to be two of these: `ResultRow` in the panel and `CodeRowLabel` in
/// the window. They disagreed about almost everything — the window had no badge,
/// no pin, no fixed columns, and rendered the description `.secondary`, so the
/// surface with the most room to show a description showed it weakest. Moving
/// between the two made codes stop looking like the same kind of thing.
///
/// Density varies; anatomy does not. That is the rule this type exists to hold.
struct CodeRow: View {

    enum Density {
        /// Search results and the empty state. Two-line descriptions, a fixed
        /// code column so a flat list scans as a column, and the row paints its
        /// own selection.
        case panel
        /// The window's content column. Inside a `List`, which owns selection
        /// and insets, and often inside a `DisclosureGroup`, whose indentation a
        /// fixed code column would fight.
        case list
        /// Children in the detail pane. Like `.list` but tighter, and it paints
        /// its own hover because it is not in a `List`.
        case compact
    }

    let code: ClinicalCode
    let density: Density
    var isSelected: Bool = false
    var isPinned: Bool = false

    /// Defaults to `true` so a caller that has not thought about it gets the
    /// informative row rather than the silently ambiguous one.
    var showsSystemBadge: Bool = true

    var onTogglePin: (() -> Void)? = nil

    @State private var isHovering = false
    @Environment(\.controlActiveState) private var controlState
    @Environment(\.colorSchemeContrast) private var contrast

    /// The fill alone carries selection in normal contrast. Under Increase
    /// Contrast the border does the work, so the fill steps back rather than
    /// competing with it — and the inactive case stays visibly weaker either way.
    private var selectionFillOpacity: Double {
        guard controlState == .key else { return 0.12 }
        return contrast == .increased ? 0.18 : 0.28
    }

    /// Scales with the user's text size, so a large-text code cannot clip inside
    /// a column sized for the default. The column is kept rather than replaced
    /// by a `Grid`: rows are independent views inside a `ScrollView`, each
    /// painting its own ground, and a shared grid container would take that away.
    @ScaledMetric(relativeTo: .body) private var codeColumn: CGFloat = Metric.codeColumn

    var body: some View {
        // Baseline-aligned, not centred: a description that wraps to two lines
        // would otherwise float the code away from the line it belongs to.
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
        .accessibilityElement(children: .ignore)
        // `code.display` in full, never the truncated string. Truncation is a
        // visual concern; a screen-reader user must always get the whole
        // description, since its tail is what distinguishes one code from the
        // next.
        .accessibilityLabel("\(code.system.shortLabel) \(code.code). \(code.display)")
        .accessibilityValue(code.isBillable == false ? NOT_BILLABLE_SPOKEN_LABEL : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: isPinned ? "Unpin" : "Pin") { onTogglePin?() }
    }

    // MARK: - Trailing edge

    @ViewBuilder
    private var trailingAffordances: some View {
        // Trailing, not leading. The system is a qualifier on a row, not its
        // headline, and at the leading edge it took the position — and the
        // width — that belongs to the code and its description.
        if showsSystemBadge {
            Text(code.system.shortLabel)
                .font(CodeTypography.metadata.weight(.semibold))
                .padding(.horizontal, Metric.s)
                .padding(.vertical, Metric.xxs)
                .semanticChip(Color.systemBadge, in: Capsule())
                .fixedSize()
        }

        // Revealed on hover or when set. Its own button, so clicking it pins
        // rather than copying — the row's tap belongs to the row.
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
            // Decorative: VoiceOver would pronounce the glyph awkwardly, and the
            // same fact is delivered better as the panel's footer.
            Text("↵")
                .font(CodeTypography.metadata)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
    }

    /// Marks a code the publisher says cannot go on a claim.
    ///
    /// Shown as text rather than colour alone: this is the one piece of
    /// information in the row that can turn a correct-looking lookup into a
    /// denied claim, so it must survive being glanced at, and must not depend on
    /// the reader distinguishing two shades of grey.
    private var billabilityChip: some View {
        Text(NOT_BILLABLE_LABEL)
            .font(CodeTypography.metadata.weight(.medium))
            // Tighter than the rest of the row on purpose: every point this chip
            // takes comes off the description, and the description is where a
            // code's clinical distinction lives.
            .padding(.horizontal, Metric.xs)
            .padding(.vertical, Metric.xxs)
            .semanticChip(Color.warning, in: RoundedRectangle(cornerRadius: Metric.chipRadius))
            .fixedSize()
            // Laid out before the description, not after it. `fixedSize` alone
            // is not enough: with the description competing for the same space
            // the chip was dropped from the row entirely, which is the one
            // element here that must never lose.
            .layoutPriority(1)
            .accessibilityHidden(true)
    }

    // MARK: - Ground

    /// A `List` paints its own selection, and painting a second one inside it
    /// produces two disagreeing highlights.
    @ViewBuilder
    private var background: some View {
        if density == .list {
            Color.clear
        } else if isSelected {
            // Dimmed when the window is not key, so a panel sitting behind
            // another app does not advertise a live selection.
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

    /// The chip is worth its noise in a flat list of mixed results, where the
    /// next thing the user does is copy. In the browse tree most parent nodes
    /// are categories, so a chip on each would be wallpaper — there the dimmed
    /// code carries it, and the detail pane states it outright.
    private var showsBillabilityChip: Bool {
        code.isBillable == false && density == .panel
    }

    private var dimsCode: Bool {
        code.isBillable == false && density != .panel
    }
}

private extension CodeRow.Density {
    var descriptionLines: Int {
        self == .panel ? 2 : 1
    }

    /// Only the panel gets a column. It is a flat list of siblings, so aligned
    /// codes scan as a column; the window's rows sit at varying disclosure
    /// depths, where a fixed width fights the indentation.
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
