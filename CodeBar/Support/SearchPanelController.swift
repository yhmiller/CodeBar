import AppKit
import CodeBarUI
import CodeCore
import CodePlatform
import SwiftUI

private let PANEL_SIZE = NSSize(width: 560, height: 420)
private let PANEL_FRAME_AUTOSAVE_NAME = "CodeBarSearchPanel"

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
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let model = SearchViewModel(repository: repository, pasteboard: SystemPasteboard())
        viewModel = model

        let hosting = NSHostingView(
            rootView: SearchPanelView(model: model) { [weak self] in self?.hide() }
        )

        let panel = FocusablePanel(
            contentRect: NSRect(origin: .zero, size: PANEL_SIZE),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .resizable],
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

        panel.contentView = hosting
        hosting.layoutSubtreeIfNeeded()

        // Restore where the user last put it; centre only on the very first run.
        if !panel.setFrameUsingName(PANEL_FRAME_AUTOSAVE_NAME) {
            panel.center()
        }
        panel.setFrameAutosaveName(PANEL_FRAME_AUTOSAVE_NAME)

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
