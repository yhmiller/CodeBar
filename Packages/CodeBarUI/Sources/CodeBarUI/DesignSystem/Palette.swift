import AppKit
import SwiftUI

/// The app's semantic colours. Each has exactly one owner.
///
/// Before these existed the palette carried two collisions: orange meant *CPT*
/// as a system badge and *not billable* as a warning, and green meant *SNOMED*
/// and *billable*. On a CPT row the two orange chips sat inches apart meaning
/// unrelated things. Spending the palette on taxonomy also left nothing reserved
/// for state, which is the one thing colour is load-bearing for here.
///
/// System identity is now carried by `systemBadge` — a neutral, distinguished by
/// its label rather than its hue. There is no colour that means "ICD-10".
///
/// ## Why these are in code rather than an asset catalogue
///
/// They were in one first. `swift build` copies an `.xcassets` into the resource
/// bundle **verbatim** — it never runs `actool`, so no `Assets.car` is produced
/// and `Color(_:bundle:)` finds nothing at runtime. `xcodebuild` *does* compile
/// it. The app would therefore have rendered the colours correctly while
/// `make check` rendered them as nothing: the "not billable" chip vanished from
/// the result row, and the snapshot references would have locked that in.
///
/// Defining them here resolves identically under both build systems, keeps all
/// four appearance variants, and costs one AppKit import in a module that
/// otherwise has none — see the note on `dynamicColor`.
public extension ShapeStyle where Self == Color {

    /// `Excludes 1` — never code these together. Never a destructive-button tint.
    static var prohibition: Color {
        dynamicColor(name: "Prohibition",
                     light: (0xA3, 0x1D, 0x24), dark: (0xF0, 0x86, 0x8E),
                     lightContrast: (0x85, 0x16, 0x1C), darkContrast: (0xFF, 0xA3, 0xA9))
    }

    /// A code the publisher says cannot go on a claim. Never a system badge.
    static var warning: Color {
        dynamicColor(name: "Warning",
                     light: (0x8A, 0x4E, 0x00), dark: (0xE0, 0xA4, 0x4E),
                     lightContrast: (0x6E, 0x3D, 0x00), darkContrast: (0xF2, 0xBC, 0x72))
    }

    /// A code valid for submission. Never a system badge.
    static var confirmed: Color {
        dynamicColor(name: "Confirmed",
                     light: (0x15, 0x60, 0x3F), dark: (0x5E, 0xC0, 0x99),
                     lightContrast: (0x0F, 0x4A, 0x31), darkContrast: (0x7F, 0xD4, 0xB4))
    }
}

extension Color {
    /// Which code system a row belongs to.
    ///
    /// Deliberately one neutral for all four systems. The label already says
    /// which one it is, and giving each a hue spends the palette on taxonomy
    /// while colliding with the billability signals.
    static let systemBadge = Color.secondary
}

/// One colour resolved against the four appearances CodeBar supports.
///
/// The components are passed as integers rather than as `NSColor`s because the
/// provider closure escapes and `NSColor` is not `Sendable` — capturing built
/// colours would not survive Swift 6 strict concurrency.
///
/// This is the module's only AppKit dependency that exists by choice. It is
/// isolated here so that porting `CodeBarUI` off AppKit is one file, not a
/// search — see docs/DESIGN_REVIEW.md §11.
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
