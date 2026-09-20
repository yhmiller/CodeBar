import XCTest

@MainActor
final class AboutPanelTests: CodeBarUITestCase {

    private var appMenu: XCUIElement {
        app.menuBars.element(boundBy: 0).menuBarItems.element(boundBy: 1)
    }

    func testTheAppMenuAboutShowsCodeBarsOwnPanel() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        app.activate()
        waitFor("the app menu to be clickable") { self.appMenu.isHittable }

        XCTAssertEqual(appMenu.title, "CodeBar", "expected the app menu beside the Apple menu")
        appMenu.click()
        appMenu.menuItems["About CodeBar"].click()

        waitFor("the About panel") { self.app.links["www.princemiller.com"].exists }
    }
}
