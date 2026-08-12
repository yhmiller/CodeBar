import XCTest

/// The window and panel behaviour that six defects hid in on 2026-08-12.
///
/// Each test here corresponds to one of them. None was catchable by a view model
/// test, because none of them changes a value — they are about which window
/// exists, how many, and whether it is on screen.
@MainActor
final class WindowBehaviourTests: CodeBarUITestCase {

    /// Opening the app used to show the floating search panel, because the
    /// bundle was `LSUIElement` and SwiftUI never built the window.
    func testLaunchOpensTheBrowseWindowAndNotTheSearchPanel() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        XCTAssertFalse(searchPanel.exists, "the panel should stay closed until asked for")
    }

    /// The complaint that started this: opening CodeBar while it was already
    /// running threw the search panel on screen.
    ///
    /// A fresh launch does not reproduce it — the panel was opened from the
    /// *reopen* path — so this reopens a running app with its window already
    /// open, which is exactly what double-clicking the app in Finder does.
    func testReopeningDoesNotOpenTheSearchPanel() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        reopen()

        // Held long enough for the panel to appear if it were going to.
        Thread.sleep(forTimeInterval: 2)
        XCTAssertFalse(searchPanel.exists, "reopening should not summon the search panel")
        XCTAssertEqual(browseWindows.count, 1)
    }

    /// Reopening with the window *closed* rather than minimised is a different
    /// path, and the one where the meaning of the delegate's return value was
    /// backwards. It did nothing at all.
    func testReopeningRebuildsAClosedWindow() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        app.typeKey("w", modifierFlags: .command)
        waitFor("the window to close") { self.browseWindows.isEmpty }

        reopen()

        waitFor("a window to be rebuilt") { self.browseWindows.count == 1 }
    }

    /// Exactly one, not two. `openWindow` on a `WindowGroup` builds a new window
    /// on every call, so the reopen path can easily add one beside the window
    /// AppKit is already restoring.
    func testReopeningNeverLeavesTwoWindows() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        app.typeKey("w", modifierFlags: .command)
        waitFor("the window to close") { self.browseWindows.isEmpty }

        reopen()
        waitFor("a window to be rebuilt") { self.browseWindows.count == 1 }
        reopen()

        // Held for a moment: a duplicate arrives a beat after the first window,
        // so checking immediately would pass while the bug was present.
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertEqual(browseWindows.count, 1, "reopening should not add a second window")
    }

    /// CodeBar is a menu bar app first. Closing the window must not quit it, or
    /// ⌥⌘C silently stops working with nothing to explain why.
    func testClosingTheWindowLeavesTheAppRunning() {
        waitFor("the browse window") { self.browseWindows.count == 1 }

        app.typeKey("w", modifierFlags: .command)
        waitFor("the window to close") { self.browseWindows.isEmpty }

        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertNotEqual(app.state, .notRunning, "closing the window should not quit CodeBar")
    }
}
