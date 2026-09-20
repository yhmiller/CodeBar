import Foundation
import ServiceManagement

@MainActor
public enum LoginItem {

    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

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

    public static var needsUserApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }
}
