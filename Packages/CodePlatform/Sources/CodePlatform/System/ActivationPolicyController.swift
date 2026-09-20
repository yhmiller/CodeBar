import AppKit

@MainActor
public enum ActivationPolicyController {

    public static var showsDockIcon: Bool {
        NSApp.activationPolicy() == .regular
    }

    @discardableResult
    public static func setShowsDockIcon(_ shows: Bool) -> Bool {
        let target: NSApplication.ActivationPolicy = shows ? .regular : .accessory
        guard NSApp.activationPolicy() != target else { return true }

        let changed = NSApp.setActivationPolicy(target)

        if changed && shows {
            NSApp.activate(ignoringOtherApps: true)
        }
        return changed
    }
}
