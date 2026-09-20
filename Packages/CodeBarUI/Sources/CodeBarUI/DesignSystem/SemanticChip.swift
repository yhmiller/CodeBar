import SwiftUI

private let CHIP_FILL_OPACITY: Double = 0.18

extension View {
    func semanticChip(_ color: Color, in shape: some Shape) -> some View {
        modifier(SemanticChip(color: color, shape: shape))
    }
}

private struct SemanticChip<S: Shape>: ViewModifier {
    let color: Color
    let shape: S

    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .foregroundStyle(color)
            .background {
                if contrast == .increased {
                    shape.stroke(color, lineWidth: 1)
                } else {
                    shape.fill(color.opacity(CHIP_FILL_OPACITY))
                }
            }
    }
}
