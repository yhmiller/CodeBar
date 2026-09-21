import AppKit
import CodeCore

@MainActor
enum BrowseWindow {

    static let id = "browse"

    static var openAction: (() -> Void)?

    static var existing: NSWindow? {
        NSApp.windows.first { $0.identifier?.rawValue.hasPrefix("\(id)-") == true }
    }

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

    static func show(code: ClinicalCode? = nil) {
        if let code, let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.browseModel.selectedCode = code
        }
        if !focusExisting() {
            openAction?()
        }
    }
}
