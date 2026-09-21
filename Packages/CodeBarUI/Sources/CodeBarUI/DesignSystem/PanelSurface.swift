import SwiftUI

public extension View {
    func panelSurface() -> some View {
        modifier(PanelSurface())
    }
}

private struct PanelSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: Metric.cardRadius))
        } else {
            content
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Metric.cardRadius))
        }
    }
}
