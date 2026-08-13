import SwiftUI

/// How the tinted fill compares to the surface behind it. Comfortable in normal
/// contrast, and the app's weakest pairing once Increase Contrast is on — which
/// is why that case gets a border instead.
private let CHIP_FILL_OPACITY: Double = 0.18

extension View {
    /// A chip carrying one of the semantic colours.
    ///
    /// Under Increase Contrast the tinted ground is replaced by a border. An
    /// 18%-opacity fill barely separates from the surface once the system
    /// raises contrast, so the chips that matter most — not billable, billable —
    /// were the first things to stop reading. A border survives it.
    ///
    /// The colour still comes from the palette, which carries its own
    /// increased-contrast variants; this handles the *shape*, which an asset
    /// catalogue cannot.
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
