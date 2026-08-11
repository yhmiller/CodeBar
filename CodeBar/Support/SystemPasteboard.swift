import AppKit
import CodeCore

/// Writes to the real system pasteboard.
///
/// TODO(yhmiller): moves to CodePlatform in phase 5.
@MainActor
struct SystemPasteboard: PasteboardWriting {
    func write(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
