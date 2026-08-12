import AppKit
import XCTest

/// Shared launch and teardown for tests that drive the real app.
///
/// These are the only tests that exercise window and panel behaviour. Everything
/// they cover — which surface opens, whether reopening restores a minimised
/// window, whether a second window appears — is invisible to a view model, and
/// was previously verified by a person looking at the screen.
@MainActor
class CodeBarUITestCase: XCTestCase {

    private static let storeVariable = "CODEBAR_STORE_SUBDIRECTORY"
    private static let bundleIdentifier = "com.princemiller.CodeBar"

    var app: XCUIApplication!

    /// Named per test so a crashed run cannot leak state into the next one.
    private var storeName = ""

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        storeName = "uitest-\(UUID().uuidString)"
        app = XCUIApplication()
        // Without this the tests would search, pin and take notes in the real
        // library. The app creates the folder inside its own sandbox container.
        app.launchEnvironment[Self.storeVariable] = storeName
        // macOS restores which windows were open at the last quit. One test
        // closes the window, and without this every test after it launched to no
        // window at all — a failure caused entirely by test order.
        app.launchArguments += ["-NSQuitAlwaysKeepsWindows", "NO",
                                "-ApplePersistenceIgnoreState", "YES"]
        removeSavedWindowState()
        terminateOtherInstances()
        app.launch()
    }

    override func tearDown() async throws {
        app?.terminate()
        removeScratchStore()
        app = nil
        try await super.tearDown()
    }

    /// Quits any *other* copy of CodeBar — in practice the one in
    /// `/Applications`, which a developer running these tests almost certainly
    /// has open.
    ///
    /// Two processes sharing a bundle identifier make the run non-deterministic:
    /// the reopen event goes to whichever LaunchServices prefers, and XCUITest
    /// can attach to the installed copy rather than the build under test. With
    /// the installed copy running, three of these tests failed against an app
    /// that was working perfectly.
    private func terminateOtherInstances() {
        let underTest = Self.appUnderTestURL
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.bundleIdentifier)
            .filter { $0.bundleURL != underTest }
        let pids = others.map(\.processIdentifier)

        // `terminate()` alone is not enough: it sends a quit Apple Event, which
        // needs Automation permission the test runner does not have, so it fails
        // silently and the installed copy keeps running. Ask politely, then
        // insist. SQLite is crash-safe, so the abrupt exit costs nothing.
        others.forEach { $0.terminate() }
        waitForExit(of: pids, timeout: 3)

        // Then SIGKILL, directly. `forceTerminate()` can be refused, and an
        // instance blocked on a modal alert — which is what a second copy shows
        // when it cannot register the global shortcut — ignores everything
        // gentler.
        pids.filter(isAlive).forEach { kill($0, SIGKILL) }
        waitForExit(of: pids, timeout: 3)

        // Refusing to run is the right answer here. Two instances sharing a
        // bundle identifier make the result meaningless — XCUITest can attach to
        // the wrong one — so a loud failure beats a confident wrong answer.
        XCTAssertFalse(
            pids.contains(where: isAlive),
            """
            Another CodeBar is still running and would make this run \
            non-deterministic. An instance held by a debugger cannot be killed: \
            stop the running scheme in Xcode, then try again.
            """
        )
    }

    /// Asks the kernel rather than `NSRunningApplication.isTerminated`, which is
    /// KVO-backed and does not refresh while the run loop is blocked by polling —
    /// it reported a live process that had already exited.
    private func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    private func waitForExit(of pids: [pid_t], timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, pids.contains(where: isAlive) {
            usleep(100_000)
        }
    }

    /// Belt and braces alongside the launch arguments: state written by an
    /// earlier run, or by the installed copy, must not decide what these see.
    private func removeSavedWindowState() {
        let saved = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(Self.bundleIdentifier)")
            .appendingPathComponent("Data/Library/Saved Application State")
            .appendingPathComponent("\(Self.bundleIdentifier).savedState")
        try? FileManager.default.removeItem(at: saved)
    }

    private func removeScratchStore() {
        guard !storeName.isEmpty else { return }
        let container = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/\(Self.bundleIdentifier)")
            .appendingPathComponent("Data/Library/Application Support/CodeBar")
            .appendingPathComponent(storeName)
        try? FileManager.default.removeItem(at: container)
    }

    // MARK: - Windows

    /// The browse window, identified the way SwiftUI names it: `<scene id>-AppWindow-<n>`.
    var browseWindows: [XCUIElement] {
        app.windows.allElementsBoundByIndex.filter {
            $0.identifier.hasPrefix("browse-")
        }
    }

    /// The panel is an `NSPanel`, which the accessibility layer reports as a
    /// *dialog* rather than a window. Querying `app.windows` for it silently
    /// never matches, so a test asserting the panel had not appeared passed even
    /// when it had.
    var searchPanel: XCUIElement {
        app.dialogs["search-panel"]
    }

    /// Reopening the app, as clicking the Dock icon does.
    ///
    /// Deliberately not `XCUIApplication.activate()`, which only brings the app
    /// forward. A Dock click also posts a *reopen* event, and that event is the
    /// entire subject of these tests — with `activate()` the reopen tests failed
    /// against an app that works, because the delegate was never consulted.
    /// `NSWorkspace.openApplication` is what `open -a` does.
    func reopen() {
        guard let url = Self.appUnderTestURL else {
            XCTFail("could not locate the built CodeBar.app next to the test bundle")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        // Reopen the instance under test rather than starting a second copy.
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    /// The freshly built app, found by path rather than by bundle identifier.
    ///
    /// Looking it up with `runningApplications(withBundleIdentifier:)` finds the
    /// copy in `/Applications` when one is installed and running — so the reopen
    /// went to the user's app while the test watched the build under test, and
    /// three tests failed against an app that was working.
    static var appUnderTestURL: URL? {
        var directory = Bundle(for: CodeBarUITestCase.self).bundleURL
        while directory.pathComponents.count > 1 {
            directory = directory.deletingLastPathComponent()
            let candidate = directory.appendingPathComponent("CodeBar.app")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

    /// Polls rather than sleeping: window changes go through the app's run loop,
    /// so the state right after an action is not the state that settles.
    func waitFor(
        _ description: String,
        timeout: TimeInterval = 5,
        until condition: () -> Bool
    ) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            usleep(100_000)
        }
        XCTFail("timed out waiting for \(description)")
    }
}
