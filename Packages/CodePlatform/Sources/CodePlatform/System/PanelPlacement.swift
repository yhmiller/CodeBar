import CoreGraphics

public enum PanelPlacement {

    private static let topFraction = 0.18
    private static let maxTopInset = 220.0

    public static func origin(for size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let inset = min(visibleFrame.height * topFraction, maxTopInset)
        let topEdge = visibleFrame.maxY - inset

        return CGPoint(
            x: visibleFrame.midX - size.width / 2,
            y: max(visibleFrame.minY, topEdge - size.height)
        )
    }
}
