import CodeCore
import SwiftUI

struct ResultRow: View {
    let code: ClinicalCode
    let isSelected: Bool
    var isPinned: Bool = false
    var onTogglePin: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: Metric.m) {
            Text(code.system.shortLabel)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, Metric.s)
                .padding(.vertical, Metric.xs)
                .background(Color.systemBadge.opacity(0.15))
                .foregroundStyle(Color.systemBadge)
                .clipShape(Capsule())
                .frame(width: Metric.badgeColumn, alignment: .leading)

            Text(code.code)
                .font(CodeTypography.codeRow)
                .frame(width: Metric.codeColumn, alignment: .leading)

            Text(code.display)
                .font(CodeTypography.description)
                .lineLimit(1)
                .foregroundStyle(.primary)

            if code.isBillable == false {
                headerBadge
            }

            Spacer()

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
                Text("↵ copy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, Metric.rowPadding)
        .padding(.vertical, Metric.s)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: Metric.rowRadius))
        .padding(.horizontal, Metric.rowInset)
    }

    /// Marks a code the publisher says cannot go on a claim.
    ///
    /// Shown as text rather than colour alone: this is the one piece of
    /// information in the row that can turn a correct-looking lookup into a
    /// denied claim, so it must survive being glanced at, and must not depend on
    /// the reader distinguishing two shades of grey.
    private var headerBadge: some View {
        Text("category - not billable")
            .font(.caption2.weight(.medium))
            // Tighter than the rest of the row on purpose: at 560pt every point
            // this chip takes comes off the description, and the description is
            // where a code's clinical distinction lives. Step 1.1 settles this
            // properly by widening the panel and giving the chip its own line.
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
            .accessibilityLabel("Category header, not valid for submission")
    }
}
