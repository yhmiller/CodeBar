import CoreGraphics

public enum Metric {

    // MARK: - Spacing scale

    public static let xxs: CGFloat = 2
    public static let xs: CGFloat = 4
    public static let s: CGFloat = 8
    public static let m: CGFloat = 12
    public static let l: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32

    // MARK: - Radii

    public static let chipRadius: CGFloat = 4
    public static let rowRadius: CGFloat = 6
    public static let cardRadius: CGFloat = 10

    // MARK: - The search panel

    public static let panelWidth: CGFloat = 680
    public static let resultListMaxHeight: CGFloat = 340
    public static let copyConfirmationMaxWidth: CGFloat = 460

    // MARK: - Spacebar Peek

    public static let peekPanelWidth: CGFloat = 940
    public static let peekListWidth: CGFloat = 520
    public static let peekInspectorWidth: CGFloat = 420

    // MARK: - Rows

    public static let rowInset: CGFloat = s
    public static let rowPadding: CGFloat = l
    public static let rowLeading: CGFloat = rowInset + rowPadding

    public static let codeColumn: CGFloat = 92

    // MARK: - The detail pane

    public static let noteEditorMinHeight: CGFloat = 56

    // MARK: - The browse window

    public static let sidebarMinWidth: CGFloat = 240
    public static let sidebarIdealWidth: CGFloat = 300
    public static let contentMinWidth: CGFloat = 280
    public static let contentIdealWidth: CGFloat = 360

    // MARK: - Settings

    public static let settingsWidth: CGFloat = 560
    public static let settingsHeight: CGFloat = 460
    public static let settingsIconSize: CGFloat = 28
    public static let settingsIconRadius: CGFloat = 7
    public static let keycapRadius: CGFloat = 4
    public static let abbreviationTermColumn: CGFloat = 100
    public static let abbreviationTermField: CGFloat = 110
}
