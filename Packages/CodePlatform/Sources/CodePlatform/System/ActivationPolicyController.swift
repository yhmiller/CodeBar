import AppKit

/// Switches CodeBar between menu-bar-only and a full app with a Dock icon.
///
/// The bundle keeps `LSUIElement = true`, so the app always launches as an
/// accessory and promotes itself when the preference says so. The reverse —
/// launching `.regular` and demoting — flashes a Dock icon on every launch for
/// people who only want the menu bar, which is the majority case today.
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
