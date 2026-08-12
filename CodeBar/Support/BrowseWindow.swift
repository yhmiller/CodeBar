import AppKit

/// The browse window, found and focused rather than reopened.
///
/// Everything that wants to show the window goes through here: the Dock icon,
/// opening the app, and the menu bar's Browse Codes…. They previously did
/// different things, which is how one of them ended up showing the search panel
/// instead.
///
/// The distinction that matters is between a window that is *closed* and one that
/// is merely put away. `openWindow` on a `WindowGroup` builds a new window on
/// every call — verified: three calls produced `browse-AppWindow-1`, `-2` and
/// `-3` — so asking SwiftUI to open a window that already exists quietly clones
/// it. The group stays a `WindowGroup` rather than a single `Window` so that
/// deliberate multi-window work later is still open; it is only these paths that
/// mean "show me the one I had".
@MainActor
enum BrowseWindow {

    /// Matches `WindowGroup(id:)` in `CodeBarApp`.
    static let id = "browse"

    /// SwiftUI names the window `<scene id>-AppWindow-<n>`.
    ///
    /// That format is SwiftUI's rather than a documented contract, so it is worth
    /// knowing how this fails: an unrecognised window reads as "none open" and a
    /// fresh one is built. A spare window is a far better failure than focusing
    /// the wrong one — which is what matching on `canBecomeMain` alone would risk
    /// once Settings or an About panel is on screen.
    static var existing: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("\(id)-") == true }
    }

    /// Brings the window forward, returning false when there is none to bring.
    ///
    /// `makeKeyAndOrderFront` does not restore a miniaturised window — it
    /// activates the app and leaves the window in the Dock, which is exactly what
    /// clicking the Dock icon of a minimised CodeBar used to do.
    @discardableResult
    static func focusExisting() -> Bool {
        guard let window = existing else { return false }

        NSApp.activate(ignoringOtherApps: true)
        if window.isMiniaturized {
            window.deminiaturize(nil)
        }
        window.makeKeyAndOrderFront(nil)
        return true
    }
}
