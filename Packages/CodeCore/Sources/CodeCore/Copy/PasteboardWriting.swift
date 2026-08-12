/// Writing text to the system pasteboard.
///
/// Abstracted so the search view model can be tested without AppKit. The real
/// implementation is `SystemPasteboard` in `CodePlatform`.
@MainActor
public protocol PasteboardWriting {
    func write(_ string: String)
}
