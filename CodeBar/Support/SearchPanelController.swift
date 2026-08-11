import AppKit
import CodeBarUI
import CodeCore
import SwiftUI

private let PANEL_SIZE = NSSize(width: 560, height: 420)

/// NSPanel subclass that overrides canBecomeKey. Without this, a
/// .nonactivatingPanel style window won't reliably accept keyboard focus,
/// which would make the search field untypeable.
private final class FocusablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the floating, Spotlight-style search panel: creates it lazily,
/// centers it, and toggles visibility from the global hotkey or the menu.
///
/// TODO(yhmiller): phase 4 replaces the rebuild-on-show with a persistent
/// hosting view, restores the user's saved frame instead of re-centering, and
/// hides the panel when it resigns key.
@MainActor
final class SearchPanelController {
    static let shared = SearchPanelController()

    /// Injected at launch by `AppDelegate`. `nil` when the database failed to open.
    var repository: (any CodeRepository)?

    private var panel: NSPanel?

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
            return
        }
        show()
    }

    func show() {
        let model = SearchViewModel(repository: repository, pasteboard: SystemPasteboard())
        let contentView = SearchPanelView(model: model) { [weak self] in
            self?.panel?.orderOut(nil)
        }

        let panel = self.panel ?? FocusablePanel(
            contentRect: NSRect(origin: .zero, size: PANEL_SIZE),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.standardWindowButtons.forEach { $0?.isHidden = true }

        // Lay the SwiftUI content out before the panel takes key focus. Ordering
        // front first leaves a window where the panel is key but the text field
        // has not yet become first responder, and keystrokes typed in that gap
        // are dropped — which is why the first character often went missing.
        let hosting = NSHostingView(rootView: contentView)
        panel.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        panel.center()

        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
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
