import AppKit

@MainActor
enum BrowseWindow {

    static let id = "browse"

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
}
