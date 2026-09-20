import AppKit
import CodeBarUI
import CodeCore
import CodeLibrary
import CodePlatform
import SwiftUI

private let PANEL_SIZE = NSSize(width: Metric.panelWidth, height: 420)

private let APPEARANCE_DURATION: TimeInterval = 0.12

let SEARCH_PANEL_ACCESSIBILITY_ID = "search-panel"

private final class FocusablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class SearchPanelController {
    static let shared = SearchPanelController()

    var repository: (any CodeRepository)?

    private var panel: NSPanel?
    private var viewModel: SearchViewModel?

    var library: (any CodeLibraryStoring)?

    let preferences = UserDefaultsPreferences()

    let confirmation = CopyConfirmationPanel()

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

        let animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        panel.alphaValue = animates ? 0 : 1
        panel.makeKeyAndOrderFront(nil)

        guard animates else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = APPEARANCE_DURATION
            panel.animator().alphaValue = 1
        }
    }

    private func position(_ panel: NSPanel) {
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

        let hosting = NSHostingController(
            rootView: SearchPanelView(
                model: model,
                onCopied: { [weak self] copied in self?.confirmation.show(copied) },
                onDismiss: { [weak self] in self?.hide() }
            )
            .panelSurface()
        )
        hosting.sizingOptions = [.preferredContentSize]

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
        panel.hidesOnDeactivate = true
        panel.standardWindowButtons.forEach { $0?.isHidden = true }

        panel.setAccessibilityIdentifier(SEARCH_PANEL_ACCESSIBILITY_ID)

        panel.contentViewController = hosting
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
