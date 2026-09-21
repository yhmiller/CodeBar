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
        if abs(panel.frame.width - Metric.panelWidth) > 1 {
            let targetSize = CGSize(width: Metric.panelWidth, height: panel.frame.height)
            let pointer = NSEvent.mouseLocation
            let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? .main
            if let visibleFrame = screen?.visibleFrame {
                let newOrigin = PanelPlacement.origin(for: targetSize, in: visibleFrame)
                panel.setFrame(NSRect(origin: newOrigin, size: targetSize), display: false)
            }
        }
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

    func setPeeking(_ isPeeking: Bool) {
        guard let panel else { return }
        let targetWidth = isPeeking ? Metric.peekPanelWidth : Metric.panelWidth
        guard abs(panel.frame.width - targetWidth) > 1 else { return }

        let screen = panel.screen ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        let targetSize = CGSize(width: targetWidth, height: panel.frame.height)
        let newOrigin = PanelPlacement.origin(for: targetSize, in: visibleFrame)
        let newFrame = NSRect(origin: newOrigin, size: targetSize)

        let animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if animates {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(newFrame, display: true)
            }
        } else {
            panel.setFrame(newFrame, display: true)
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
        Task {
            await (NSApp.delegate as? AppDelegate)?.actions.refresh()
        }
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
                onDismiss: { [weak self] in self?.hide() },
                onOpenInWindow: { [weak self] code in
                    self?.hide()
                    (NSApp.delegate as? AppDelegate)?.handoffToBrowseWindow(code)
                },
                onTogglePeek: { [weak self] isPeeking in
                    self?.setPeeking(isPeeking)
                }
            )
            .panelSurface()
            .ignoresSafeArea()
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
        panel.titlebarSeparatorStyle = .none
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
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
