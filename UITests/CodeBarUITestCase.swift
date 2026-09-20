import AppKit
import XCTest

@MainActor
class CodeBarUITestCase: XCTestCase {

    private static let storeVariable = "CODEBAR_STORE_SUBDIRECTORY"
    private static let bundleIdentifier = "com.princemiller.CodeBar"

    var app: XCUIApplication!

    private var storeName = ""

    override func setUp() async throws {
        try await super.setUp()
        continueAfterFailure = false

        storeName = "uitest-\(UUID().uuidString)"
        app = XCUIApplication()
        app.launchEnvironment[Self.storeVariable] = storeName
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

    private func terminateOtherInstances() {
        let underTest = Self.appUnderTestURL
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: Self.bundleIdentifier)
            .filter { $0.bundleURL != underTest }
        let pids = others.map(\.processIdentifier)

        others.forEach { $0.terminate() }
        waitForExit(of: pids, timeout: 3)

        pids.filter(isAlive).forEach { kill($0, SIGKILL) }
        waitForExit(of: pids, timeout: 3)

        XCTAssertFalse(
            pids.contains(where: isAlive),
            """
            Another CodeBar is still running and would make this run \
            non-deterministic. An instance held by a debugger cannot be killed: \
            stop the running scheme in Xcode, then try again.
            """
        )
    }

    private func isAlive(_ pid: pid_t) -> Bool {
        kill(pid, 0) == 0
    }

    private func waitForExit(of pids: [pid_t], timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, pids.contains(where: isAlive) {
            usleep(100_000)
        }
    }

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

    var browseWindows: [XCUIElement] {
        app.windows.allElementsBoundByIndex.filter {
            $0.identifier.hasPrefix("browse-")
        }
    }

    var searchPanel: XCUIElement {
        app.dialogs["search-panel"]
    }

    func reopen() {
        guard let url = Self.appUnderTestURL else {
            XCTFail("could not locate the built CodeBar.app next to the test bundle")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.createsNewApplicationInstance = false
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    static var appUnderTestURL: URL? {
        var directory = Bundle(for: CodeBarUITestCase.self).bundleURL
        while directory.pathComponents.count > 1 {
            directory = directory.deletingLastPathComponent()
            let candidate = directory.appendingPathComponent("CodeBar.app")
            if FileManager.default.fileExists(atPath: candidate.path) { return candidate }
        }
        return nil
    }

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
