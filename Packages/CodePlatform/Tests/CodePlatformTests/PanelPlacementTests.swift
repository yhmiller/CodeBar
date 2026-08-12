import CoreGraphics
import Testing
@testable import CodePlatform

/// A 16-inch MacBook Pro's usable area, menu bar excluded.
private let LAPTOP = CGRect(x: 0, y: 0, width: 1728, height: 1051)
private let PANEL = CGSize(width: 560, height: 420)

@Suite("Panel placement")
struct PanelPlacementTests {

    private func topEdge(of size: CGSize, in frame: CGRect) -> CGFloat {
        PanelPlacement.origin(for: size, in: frame).y + size.height
    }

    @Test("should centre the panel horizontally")
    func centresHorizontally() {
        let origin = PanelPlacement.origin(for: PANEL, in: LAPTOP)

        #expect(origin.x + PANEL.width / 2 == LAPTOP.midX)
    }

    @Test("should open the panel in the upper part of the screen")
    func opensHigh() {
        let origin = PanelPlacement.origin(for: PANEL, in: LAPTOP)

        #expect(origin.y + PANEL.height > LAPTOP.midY)
    }

    /// The panel grows downwards as results arrive. Anchoring anything but the
    /// top edge would make the search field move while the user is typing into it.
    @Test("should put the top edge in the same place whatever the panel height")
    func topEdgeIsIndependentOfHeight() {
        let empty = CGSize(width: PANEL.width, height: 92)

        #expect(topEdge(of: empty, in: LAPTOP) == topEdge(of: PANEL, in: LAPTOP))
    }

    /// Guards the sign of the inset: `+` instead of `-` puts the panel above the
    /// top of the screen, where it cannot be dragged back.
    @Test("should keep the whole panel on screen")
    func staysOnScreen() {
        let origin = PanelPlacement.origin(for: PANEL, in: LAPTOP)

        #expect(origin.y >= LAPTOP.minY)
        #expect(origin.y + PANEL.height <= LAPTOP.maxY)
    }

    /// A second display sits at a non-zero origin in the global coordinate space.
    /// Placement must therefore depend on the frame's *edges*, never on its size
    /// alone — `height - inset` reads identically to `maxY - inset` on the main
    /// screen and puts the panel on the wrong display everywhere else.
    ///
    /// Stated as translation invariance rather than as bounds: merely landing
    /// inside the external frame is satisfied by the wrong answer too, which is
    /// how an earlier version of this test passed against that exact mistake.
    @Test("should place the panel the same way on a screen that is not at the origin")
    func isTranslationInvariant() {
        let atOrigin = CGRect(x: 0, y: 0, width: 2560, height: 1415)
        let offset = CGPoint(x: 1728, y: 300)
        let external = atOrigin.offsetBy(dx: offset.x, dy: offset.y)

        let here = PanelPlacement.origin(for: PANEL, in: atOrigin)
        let there = PanelPlacement.origin(for: PANEL, in: external)

        #expect(there.x - here.x == offset.x)
        #expect(there.y - here.y == offset.y)
    }

    /// A panel taller than the room beneath the inset would hang off the bottom,
    /// putting the search field out of reach — the failure being fixed here.
    @Test("should not push a tall panel below the bottom of the screen")
    func clampsTallPanel() {
        let short = CGRect(x: 0, y: 0, width: 1440, height: 500)
        let tall = CGSize(width: 560, height: 460)

        #expect(PanelPlacement.origin(for: tall, in: short).y >= short.minY)
    }
}
