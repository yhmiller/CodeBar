import XCTest

@MainActor
final class WindowBehaviourTests: CodeBarUITestCase {

    func testLaunchOpensTheBrowseWindowAndNotTheSearchPanel() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        XCTAssertFalse(searchPanel.exists, "the panel should stay closed until asked for")
    }

    func testReopeningDoesNotOpenTheSearchPanel() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        reopen()

        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(searchPanel.exists, "reopening should not summon the search panel")
        XCTAssertEqual(browseWindows.count, 1)
    }

    func testReopeningRebuildsAClosedWindow() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        app.typeKey("w", modifierFlags: .command)
        waitFor("the window to close") { self.browseWindows.isEmpty }

        reopen()

        waitFor("a window to be rebuilt") { self.browseWindows.count == 1 }
    }

    func testReopeningNeverLeavesTwoWindows() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        app.typeKey("w", modifierFlags: .command)
        waitFor("the window to close") { self.browseWindows.isEmpty }

        reopen()
        waitFor("a window to be rebuilt") { self.browseWindows.count == 1 }
        reopen()

        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertEqual(browseWindows.count, 1, "reopening should not add a second window")
    }

    func testClosingTheWindowLeavesTheAppRunning() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        app.typeKey("w", modifierFlags: .command)
        waitFor("the window to close") { self.browseWindows.isEmpty }

        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertNotEqual(app.state, .notRunning, "closing the window should not quit CodeBar")
    }
}
