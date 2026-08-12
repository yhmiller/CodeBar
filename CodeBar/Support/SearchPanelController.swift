import AppKit
import CodeBarUI
import CodeCore
import CodeLibrary
import CodePlatform
import SwiftUI

private let PANEL_SIZE = NSSize(width: 560, height: 420)

/// Also spelled in `UITests`; the two must agree.
let SEARCH_PANEL_ACCESSIBILITY_ID = "search-panel"

/// NSPanel subclass that overrides canBecomeKey. Without this, a
/// .nonactivatingPanel style window won't reliably accept keyboard focus,
/// which would make the search field untypeable.
private final class FocusablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the floating, Spotlight-style search panel.
///
/// The panel and its hosting view are built once and reused. Rebuilding them on
/// every show meant the SwiftUI content was laid out only after the panel had
/// taken key focus, which is how the first keystroke went missing.
@MainActor
final class SearchPanelController {
    static let shared = SearchPanelController()

    /// Injected at launch by `AppDelegate`. `nil` when the database failed to open.
    var repository: (any CodeRepository)?

    private var panel: NSPanel?
    private var viewModel: SearchViewModel?

    /// Injected at launch alongside the repository.
    var library: (any CodeLibraryStoring)?

    let preferences = UserDefaultsPreferences()

    func toggle() {
        if let panel, panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = self.panel ?? makePanel()
        viewModel?.prepareForDisplay()
        position(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    /// Re-placed on every show rather than remembered.
    ///
    /// The panel used to autosave its frame, which drifted: it grows downwards as
    /// results arrive, that taller frame was saved, and each search nudged it
    /// further down until it opened somewhere it had to be dragged back from. A
    /// panel aimed at blind — the user is already typing — is better off landing
    /// in the same place every time than remembering a position nobody chose.
    private func position(_ panel: NSPanel) {
        // The pointer is a better guess at which display the user is looking at
        // than the key window, which at this moment still belongs to whichever
        // app the shortcut was pressed over.
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? .main

        guard let visibleFrame = screen?.visibleFrame else { return }
        panel.setFrameOrigin(
            PanelPlacement.origin(for: panel.frame.size, in: visibleFrame)
        )
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let model = SearchViewModel(
            repository: repository,
            pasteboard: SystemPasteboard(),
            library: library ?? EmptyCodeLibrary(),
            preferences: preferences
        )
        viewModel = model

        // NSHostingController rather than NSHostingView: the window then tracks
        // the SwiftUI content's preferred size, and AppKit keeps the top-left
        // corner fixed while the height changes. That is what makes the panel
        // grow downwards as results arrive instead of sitting in a fixed box
        // with dead space underneath.
        let hosting = NSHostingController(
            rootView: SearchPanelView(model: model) { [weak self] in self?.hide() }
        )
        hosting.sizingOptions = [.preferredContentSize]

        // Not .resizable: a panel that sizes itself to its content would fight a
        // user-dragged height on every keystroke.
        let panel = FocusablePanel(
            contentRect: NSRect(origin: .zero, size: PANEL_SIZE),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isMovableByWindowBackground = true
        // Spotlight-like: clicking away puts the panel away, rather than leaving
        // it floating over everything until it is dismissed explicitly.
        panel.hidesOnDeactivate = true
        panel.standardWindowButtons.forEach { $0?.isHidden = true }

        // Lets a UI test tell the panel from the browse window. The panel has no
        // visible title to match on, deliberately.
        panel.setAccessibilityIdentifier(SEARCH_PANEL_ACCESSIBILITY_ID)

        panel.contentViewController = hosting
        // Still laid out before the panel takes key focus, so the first
        // keystroke has somewhere to land.
        hosting.view.layoutSubtreeIfNeeded()

        self.panel = panel
        return panel
    }
}

private extension NSWindow {
    var standardWindowButtons: [NSButton?] {
        [
            standardWindowButton(.closeButton),
            standardWindowButton(.miniaturizeButton),
            standardWindowButton(.zoomButton)
        ]
    }
}
