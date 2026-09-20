import SwiftUI

public enum CodeTypography {
    public static let codeHero = Font.system(.largeTitle, design: .monospaced)
        .weight(.semibold)
        .monospacedDigit()

    public static let codeRow = Font.system(.body, design: .monospaced)
        .weight(.semibold)
        .monospacedDigit()

    public static let description = Font.body
    public static let searchField = Font.title3
    public static let sectionLabel = Font.caption.weight(.semibold)
    public static let metadata = Font.caption2
}
