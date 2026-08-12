import XCTest

/// The About panel reached from the app menu.
///
/// There are two routes to it — the menu bar icon and the app menu — and only
/// the first was ever wired to CodeBar's own panel. The app menu did not exist
/// while the app launched as an accessory, so when it gained one it came with
/// AppKit's stock About item: name, version, copyright, and none of the
/// installed code sets or the link.
@MainActor
final class AboutPanelTests: CodeBarUITestCase {

    /// The app menu, which sits immediately right of the Apple menu.
    ///
    /// Taken by position because matching on the title selects the Apple menu
    /// instead — a click on `menuBarItems["CodeBar"]` opened "About This Mac".
    /// The title is asserted first so a change in layout fails here rather than
    /// silently driving the wrong menu.
    private var appMenu: XCUIElement {
        app.menuBars.element(boundBy: 0).menuBarItems.element(boundBy: 1)
    }

    func testTheAppMenuAboutShowsCodeBarsOwnPanel() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        XCTAssertEqual(appMenu.title, "CodeBar", "expected the app menu beside the Apple menu")
        appMenu.click()
        appMenu.menuItems["About CodeBar"].click()

        // The link is the part that distinguishes CodeBar's panel from AppKit's:
        // the stock one has no credits at all, so it cannot carry one.
        waitFor("the About panel") { self.app.links["www.princemiller.com"].exists }
    }
}
