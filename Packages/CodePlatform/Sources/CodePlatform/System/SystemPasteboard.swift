import AppKit
import CodeCore

@MainActor
public struct SystemPasteboard: PasteboardWriting {
    public init() {}

    public func write(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
