import AppKit

/// Switches CodeBar between menu-bar-only and a full app with a Dock icon.
///
/// The bundle deliberately omits `LSUIElement`, so the app launches as a normal
/// app and demotes itself here when the preference says menu-bar-only. The
/// reverse — launching as an accessory and promoting — costs nothing visually,
/// but SwiftUI never builds the `WindowGroup` window for an accessory app, so
/// opening CodeBar had no window to show and fell back to the search panel.
/// Demoting instead flashes a Dock icon at launch for menu-bar-only users, which
/// is the cheaper of the two prices.
///
/// See docs/ARCHITECTURE.md §11.
@MainActor
public enum ActivationPolicyController {

    public static var showsDockIcon: Bool {
        NSApp.activationPolicy() == .regular
    }

    /// Applies the policy. Returns whether the app ended up in the requested state.
    @discardableResult
    public static func setShowsDockIcon(_ shows: Bool) -> Bool {
        let target: NSApplication.ActivationPolicy = shows ? .regular : .accessory
        guard NSApp.activationPolicy() != target else { return true }

        let changed = NSApp.setActivationPolicy(target)

        // Promoting to .regular while the app is frontmost leaves it without a
        // key window and without focus in the menu bar; re-activating settles it.
        if changed && shows {
            NSApp.activate(ignoringOtherApps: true)
        }
        return changed
    }
}
