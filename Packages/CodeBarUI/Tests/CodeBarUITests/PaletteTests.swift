import AppKit
import SwiftUI
import Testing
@testable import CodeBarUI

@Suite("Palette")
struct PaletteTests {

    private static let appearances: [NSAppearance.Name] = [
        .aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua
    ]

    private func assertResolves(_ color: Color, _ label: String) {
        for name in Self.appearances {
            let appearance = NSAppearance(named: name)
            var resolved: NSColor?
            appearance?.performAsCurrentDrawingAppearance {
                resolved = NSColor(color).usingColorSpace(.sRGB)
            }

            #expect(resolved != nil, "\(label) did not resolve under \(name.rawValue)")
            #expect(resolved?.alphaComponent == 1,
                    "\(label) resolved transparent under \(name.rawValue)")
        }
    }

    @Test("the warning colour should resolve under every appearance")
    func warningResolves() {
        assertResolves(.warning, "warning")
    }

    @Test("the prohibition colour should resolve under every appearance")
    func prohibitionResolves() {
        assertResolves(.prohibition, "prohibition")
    }

    @Test("the confirmed colour should resolve under every appearance")
    func confirmedResolves() {
        assertResolves(.confirmed, "confirmed")
    }

    @Test("light and dark should be different colours")
    func lightAndDarkDiffer() {
        var light: NSColor?
        var dark: NSColor?
        NSAppearance(named: .aqua)?.performAsCurrentDrawingAppearance {
            light = NSColor(Color.warning).usingColorSpace(.sRGB)
        }
        NSAppearance(named: .darkAqua)?.performAsCurrentDrawingAppearance {
            dark = NSColor(Color.warning).usingColorSpace(.sRGB)
        }

        #expect(light?.redComponent != dark?.redComponent)
    }
}
