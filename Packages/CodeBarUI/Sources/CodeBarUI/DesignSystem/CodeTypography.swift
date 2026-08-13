import SwiftUI

/// The six type roles. Views pick a role, never a font.
///
/// Codes are monospaced so digits line up in a column, which is what makes a
/// list of them scannable — and `.monospacedDigit()` on top so a proportional
/// fallback cannot break the alignment.
public enum CodeTypography {

    /// The code itself, in the detail pane header.
    public static let codeHero = Font.system(.largeTitle, design: .monospaced)
        .weight(.semibold)
        .monospacedDigit()

    /// The code in a row, on both surfaces.
    public static let codeRow = Font.system(.body, design: .monospaced)
        .weight(.semibold)
        .monospacedDigit()

    /// A code's description.
    ///
    /// Rendered `.primary` everywhere. The window used to demote it to
    /// `.secondary`, which made the same object read as weaker in the surface
    /// with more room to show it.
    public static let description = Font.body

    /// The search field. Was a hardcoded `.system(size: 18)`, which neither
    /// scaled with the user's text-size preference nor inherited future metrics.
    public static let searchField = Font.title3

    /// PINNED, RECENT, Includes, Excludes 1.
    public static let sectionLabel = Font.caption.weight(.semibold)

    /// Chapter, counts, release — anything qualifying the thing above it.
    public static let metadata = Font.caption2
}
