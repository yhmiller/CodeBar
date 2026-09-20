import AppKit
import SwiftUI

public let NOT_BILLABLE_LABEL = "Category — not valid for submission"

public let NOT_BILLABLE_SPOKEN_LABEL = "Category header, not valid for submission"

public extension ShapeStyle where Self == Color {

    static var prohibition: Color {
        dynamicColor(name: "Prohibition",
                     light: (0xA3, 0x1D, 0x24), dark: (0xF0, 0x86, 0x8E),
                     lightContrast: (0x85, 0x16, 0x1C), darkContrast: (0xFF, 0xA3, 0xA9))
    }

    static var warning: Color {
        dynamicColor(name: "Warning",
                     light: (0x8A, 0x4E, 0x00), dark: (0xE0, 0xA4, 0x4E),
                     lightContrast: (0x6E, 0x3D, 0x00), darkContrast: (0xF2, 0xBC, 0x72))
    }

    static var confirmed: Color {
        dynamicColor(name: "Confirmed",
                     light: (0x15, 0x60, 0x3F), dark: (0x5E, 0xC0, 0x99),
                     lightContrast: (0x0F, 0x4A, 0x31), darkContrast: (0x7F, 0xD4, 0xB4))
    }
}

extension Color {
    static let systemBadge = Color.secondary
}

private func dynamicColor(
    name: String,
    light: (Int, Int, Int),
    dark: (Int, Int, Int),
    lightContrast: (Int, Int, Int),
    darkContrast: (Int, Int, Int)
) -> Color {
    Color(nsColor: NSColor(name: name) { appearance in
        let match = appearance.bestMatch(from: [
            .aqua, .darkAqua,
            .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua
        ])
        switch match {
        case .darkAqua: return NSColor(rgb: dark)
        case .accessibilityHighContrastAqua: return NSColor(rgb: lightContrast)
        case .accessibilityHighContrastDarkAqua: return NSColor(rgb: darkContrast)
        default: return NSColor(rgb: light)
        }
    })
}

private extension NSColor {
    convenience init(rgb: (Int, Int, Int)) {
        self.init(srgbRed: CGFloat(rgb.0) / 255,
                  green: CGFloat(rgb.1) / 255,
                  blue: CGFloat(rgb.2) / 255,
                  alpha: 1)
    }
}
