import SwiftUI

public extension View {
    /// The search panel's own ground.
    ///
    /// The one place in CodeBar where Liquid Glass is conditional, and the only
    /// custom use of it anywhere. A floating panel summoned over whatever app
    /// the user was in is the textbook navigation-layer case: it sits above
    /// content it does not own, which is exactly what Apple reserves the
    /// material for.
    ///
    /// Deliberately not applied to the footer, though the roadmap originally
    /// said to. The footer lives *inside* this surface, so giving it its own
    /// glass would be glass on glass — called out by name as a mistake in
    /// Adopting Liquid Glass, and the reason the footer keeps `.bar`.
    ///
    /// Also deliberately not applied to result rows, the detail pane, or any
    /// chip. Those are the content layer, and dense text is the case Apple says
    /// translucency muddies.
    ///
    /// `.ultraThinMaterial` is the fallback rather than a hand-rolled
    /// approximation: stacked blurs cost GPU on every panel show and would look
    /// wrong beside the real thing on 26.
    ///
    /// ## Applied by the window, not by the content view
    ///
    /// Both materials sample a live backdrop, and there is no backdrop when
    /// SwiftUI is rendered offscreen into a bitmap. A snapshot of
    /// `SearchPanelView` carrying this modifier put the hint text at a luminance
    /// range of 23 where the same view without it measured 105 — the text was
    /// not dimmed but obscured, and changing its foreground style moved the
    /// numbers not at all.
    ///
    /// So the ground stays out of the content view: the panel controller applies
    /// it to the hosting root. The snapshot tests then cover what they can
    /// actually cover, and this surface is judged by running the app.
    func panelSurface() -> some View {
        modifier(PanelSurface())
    }
}

private struct PanelSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: Metric.cardRadius))
        } else {
            content.background(.ultraThinMaterial)
        }
    }
}
