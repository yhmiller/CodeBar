import SwiftUI

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
