import Foundation
import ServiceManagement

/// Whether CodeBar starts with the Mac.
///
/// A menu bar utility that is not running is not merely inconvenient — the
/// hotkey silently does nothing, which reads as the app being broken. Worth
/// offering prominently rather than burying.
///
/// `SMAppService` is the sandbox-safe replacement for the old login-item APIs;
/// it needs no helper bundle for the main app.
@MainActor
public enum LoginItem {

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns whether the change took effect.
    ///
    /// Registration can fail — most often because the user has denied login
    /// items for this app in System Settings, which the app cannot override.
    @discardableResult
    public static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            NSLog("CodeBar: could not \(enabled ? "enable" : "disable") open at login — \(error)")
            return false
        }
    }

    /// True when macOS is holding the request for the user to approve in
    /// System Settings › General › Login Items.
    public static var needsUserApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }
}
