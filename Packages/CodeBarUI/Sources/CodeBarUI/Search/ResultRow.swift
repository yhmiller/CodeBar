import CodeCore
import SwiftUI

struct ResultRow: View {
    let code: ClinicalCode
    let isSelected: Bool
    var isPinned: Bool = false

    /// Defaults to `true` so a caller that has not thought about it gets the
    /// informative row rather than the silently ambiguous one.
    var showsSystemBadge: Bool = true

    var onTogglePin: (() -> Void)? = nil

    var body: some View {
        // Baseline-aligned, not centred: a description that wraps to two lines
        // would otherwise float the code away from the line it belongs to.
        HStack(alignment: .firstTextBaseline, spacing: Metric.m) {
            Text(code.code)
                .font(CodeTypography.codeRow)
                .frame(width: Metric.codeColumn, alignment: .leading)

            // Two lines, and the row grows to fit rather than the text
            // compressing. `S72.001A` — "Fracture of unspecified part of neck of
            // right femur, initial encounter for closed fracture" — is 88
            // characters, and every one of them changes which claim is correct.
            Text(code.display)
                .font(CodeTypography.description)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.primary)

            if code.isBillable == false {
                headerBadge
            }

            Spacer()

            // Trailing, not leading. The system is a qualifier on a row, not
            // its headline, and at the leading edge it took the position — and
            // the width — that belongs to the code and its description.
            if showsSystemBadge {
                Text(code.system.shortLabel)
                    .font(CodeTypography.metadata.weight(.semibold))
                    .padding(.horizontal, Metric.s)
                    .padding(.vertical, Metric.xxs)
                    .background(Color.systemBadge.opacity(0.15))
                    .foregroundStyle(Color.systemBadge)
                    .clipShape(Capsule())
                    .fixedSize()
            }

            if let onTogglePin {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.caption)
                        .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .help(isPinned ? "Unpin this code" : "Pin this code")
                .accessibilityLabel(isPinned ? "Unpin \(code.code)" : "Pin \(code.code)")
            }

            if isSelected {
                // Decorative: VoiceOver would pronounce the glyph awkwardly, and
                // the same fact is delivered better as the row's hint.
                Text("↵ copy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Metric.rowPadding)
        .padding(.vertical, Metric.s)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Metric.rowRadius))
        .padding(.horizontal, Metric.rowInset)
        .accessibilityElement(children: .ignore)
        // `code.display` in full, never the truncated string. Truncation is a
        // visual concern; a screen-reader user must always get the whole
        // description, since its tail is what distinguishes one code from the
        // next. Before this the row was four separate elements and VoiceOver
        // read out the ellipsis.
        .accessibilityLabel("\(code.system.shortLabel) \(code.code). \(code.display)")
        .accessibilityValue(code.isBillable == false ? NOT_BILLABLE_SPOKEN_LABEL : "")
        .accessibilityHint("Press Return to copy")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: isPinned ? "Unpin" : "Pin") { onTogglePin?() }
    }

    /// Marks a code the publisher says cannot go on a claim.
    ///
    /// Shown as text rather than colour alone: this is the one piece of
    /// information in the row that can turn a correct-looking lookup into a
    /// denied claim, so it must survive being glanced at, and must not depend on
    /// the reader distinguishing two shades of grey.
    private var headerBadge: some View {
        Text(NOT_BILLABLE_LABEL)
            .font(CodeTypography.metadata.weight(.medium))
            // Tighter than the rest of the row on purpose: every point this chip
            // takes comes off the description, and the description is where a
            // code's clinical distinction lives.
            .padding(.horizontal, Metric.xs)
            .padding(.vertical, Metric.xxs)
            .background(Color.warning.opacity(0.18))
            .foregroundStyle(Color.warning)
            .clipShape(RoundedRectangle(cornerRadius: Metric.chipRadius))
            .fixedSize()
            // Laid out before the description, not after it. In a row this
            // tight `fixedSize` alone is not enough: with the description
            // competing for the same space the chip was dropped from the row
            // entirely, which is the one element here that must never lose.
            .layoutPriority(1)
            .accessibilityLabel(NOT_BILLABLE_SPOKEN_LABEL)
    }
}
