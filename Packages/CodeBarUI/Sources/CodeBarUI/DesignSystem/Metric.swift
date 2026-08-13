import CoreGraphics

/// Every spacing and sizing value in the app.
///
/// A 4pt scale. Before this existed the five view files between them used
/// padding of 1, 2, 3, 4, 6, 8, 9, 10, 12, 14, 18, 20 and 24 — each locally
/// reasonable, collectively no rule, so nothing lined up across the panel and
/// the window and every new view was a fresh negotiation.
///
/// `xxs` is deliberately below the scale. It is for optical separation *inside*
/// a text block — the second line of a two-line label — where a 4pt gap reads as
/// two separate things rather than one.
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

    /// Public because the panel's `NSPanel` is built in the app target while its
    /// content is laid out here. The two used to declare this number
    /// independently — `PANEL_WIDTH` here and `PANEL_SIZE` there — and agreed
    /// only by coincidence.
    ///
    /// 680 rather than 560. ICD-10 descriptions carry their clinical
    /// distinction in the tail — *without complications*, *with hyperglycemia*,
    /// *initial encounter for closed fracture* — so a row that runs out of width
    /// truncates precisely the thing that separates one code from the next.
    /// Spotlight is 680; this is not a coincidence either.
    public static let panelWidth: CGFloat = 680

    public static let resultListMaxHeight: CGFloat = 340

    /// Wide enough for `ICD-10-CM E11.9 — Type 2 diabetes mellitus without
    /// complications`, narrow enough not to read as a second window.
    public static let copyConfirmationMaxWidth: CGFloat = 460

    // MARK: - Rows
    //
    // A row's leading text starts at `rowInset + rowPadding`. Any section header
    // that has to align with it — the empty state's PINNED and RECENT — must use
    // that sum, not a number that happens to match today.

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

    public static let settingsWidth: CGFloat = 540
    public static let settingsHeight: CGFloat = 380
    public static let abbreviationTermColumn: CGFloat = 100
    public static let abbreviationTermField: CGFloat = 110
}
