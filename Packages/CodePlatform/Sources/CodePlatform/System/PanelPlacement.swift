import CoreGraphics

/// Where the search panel opens.
///
/// Spotlight-style: horizontally centred, high on the screen, in the same place
/// every time. A panel summoned by a global shortcut is aimed at blind — the
/// user is already typing — so it has to be somewhere predictable rather than
/// wherever it was last left.
///
/// Kept apart from AppKit because it is the part that can be wrong. Screen
/// coordinates run upwards, so an inset from the top edge is a subtraction from
/// `maxY`; getting that sign wrong puts the panel below the screen, which is the
/// least recoverable direction to be wrong in.
public enum PanelPlacement {

    /// Share of the usable height left above the panel. Roughly Spotlight's.
    private static let topFraction = 0.18

    /// On a tall display the fraction alone would strand the panel mid-screen.
    private static let maxTopInset = 220.0

    /// Bottom-left origin, in screen coordinates, for a panel of `size`.
    ///
    /// Positions by the panel's *top* edge, so the result is independent of the
    /// panel's current height. That matters because the panel grows downwards as
    /// results arrive: anchoring the bottom would make it climb the screen as
    /// the user types.
    public static func origin(for size: CGSize, in visibleFrame: CGRect) -> CGPoint {
        let inset = min(visibleFrame.height * topFraction, maxTopInset)
        let topEdge = visibleFrame.maxY - inset

        return CGPoint(
            x: visibleFrame.midX - size.width / 2,
            // A panel taller than the room beneath the inset would otherwise
            // hang off the bottom, putting the search field out of reach.
            y: max(visibleFrame.minY, topEdge - size.height)
        )
    }
}
