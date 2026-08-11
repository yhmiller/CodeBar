/// Writing text to the system pasteboard.
///
/// Abstracted so the search view model can be tested without AppKit. The real
/// implementation lives in the app target today and moves to `CodePlatform` in
/// phase 5.
@MainActor
public protocol PasteboardWriting {
    func write(_ string: String)
}
