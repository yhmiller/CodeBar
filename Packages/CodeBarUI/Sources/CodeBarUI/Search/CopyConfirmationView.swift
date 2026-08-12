import SwiftUI

/// Confirms what actually reached the pasteboard.
///
/// The panel disappears the instant Return is pressed, so until this existed the
/// app's terminal action was unacknowledged: nothing said *which* string had
/// been copied, or whether Shift had been held and the long form taken instead
/// of the bare code. A careful user's only recourse was to paste somewhere and
/// look — which costs more than the confirmation does.
///
/// Deliberately not a system notification. This is a foreground, user-initiated
/// action; a Notification Center banner would be intrusive and would outlive its
/// usefulness by about four seconds.
public struct CopyConfirmationView: View {
    private let copiedText: String

    public init(copiedText: String) {
        self.copiedText = copiedText
    }

    public var body: some View {
        HStack(spacing: Metric.s) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.confirmed)
                .accessibilityHidden(true)

            // Middle truncation, not tail: with the long form the code sits at
            // the front and the description's distinguishing tail at the back,
            // and dropping the tail would confirm the wrong thing.
            Text(copiedText)
                .font(CodeTypography.description)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, Metric.l)
        .padding(.vertical, Metric.m)
        .frame(maxWidth: Metric.copyConfirmationMaxWidth)
        .fixedSize()
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.08)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Copied \(copiedText)")
    }
}
