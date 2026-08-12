import CodeCore
import CodeLibrary
import CodePlatform
import CodeStore
import Foundation

private let SEED_RESOURCE_NAME = "seed_icd10_sample"

/// Set by the UI tests to move both databases into a scratch folder.
///
/// A UI test drives the real app, so without this it would search, pin and take
/// notes in the user's own library. It names a *subdirectory* rather than a full
/// path because the app is sandboxed and can only write inside its container: an
/// absolute path from outside would fail to open, and the run would look like a
/// database failure rather than a sandbox denial.
private let STORE_SUBDIRECTORY_VARIABLE = "CODEBAR_STORE_SUBDIRECTORY"

/// Composition root: builds the object graph once and hands it to whoever needs it.
///
/// Nothing else in the app constructs a `SQLiteCodeStore`, so the concrete
/// storage type appears in exactly one place.
@MainActor
final class AppEnvironment {

    /// `nil` when the database could not be opened. Callers surface
    /// `startupFailure` rather than silently returning no results, which is what
    /// the previous implementation did on a failed open.
    let repository: (any CodeRepository)?

    /// The user's own data. Separate from the index on purpose: a yearly release
    /// replaces `codes.sqlite` wholesale, and none of this can be rebuilt from a
    /// downloaded file. See docs/ARCHITECTURE.md §11.
    let library: (any CodeLibraryStoring)?

    let startupFailure: String?

    init() {
        var failures: [String] = []
        let scratch = Self.scratchDirectory()

        do {
            repository = try SQLiteCodeStore(
                location: scratch.map { .file($0.appendingPathComponent("codes.sqlite")) }
                    ?? .applicationSupport
            )
        } catch {
            repository = nil
            failures.append("Code index: \(error)")
        }

        do {
            library = try SQLiteCodeLibrary(
                location: scratch.map { .file($0.appendingPathComponent("library.sqlite")) }
                    ?? .applicationSupport
            )
        } catch {
            library = nil
            failures.append("Library: \(error)")
        }

        startupFailure = failures.isEmpty ? nil : failures.joined(separator: "\n")
    }

    /// The throwaway folder a UI test asked for, or nil for the real thing.
    private static func scratchDirectory() -> URL? {
        guard let name = ProcessInfo.processInfo.environment[STORE_SUBDIRECTORY_VARIABLE],
              !name.isEmpty
        else { return nil }

        do {
            let directory = try FileManager.default
                .url(for: .applicationSupportDirectory, in: .userDomainMask,
                     appropriateFor: nil, create: true)
                .appendingPathComponent("CodeBar", isDirectory: true)
                .appendingPathComponent(name, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            // Falling back to the real library would have the tests quietly
            // writing into it, which is the one outcome worth crashing over.
            fatalError("could not create the UI test store directory: \(error)")
        }
    }

    /// Hands pins and recents from the old `UserDefaults` store to the library,
    /// once. Runs before the panel is first shown so nothing appears to vanish.
    func adoptLegacyLibraryData() async {
        guard let library else { return }
        let legacy = LegacyUserDefaultsUsageStore()
        guard !legacy.pinnedCodes.isEmpty || !legacy.recentCodes.isEmpty else { return }

        do {
            let adopted = try await library.adoptLegacyData(
                pinned: legacy.pinnedCodes,
                recent: legacy.recentCodes
            )
            if adopted { legacy.clear() }
        } catch {
            NSLog("CodeBar: could not adopt legacy pins — \(error)")
        }
    }

    /// Loads the bundled ICD-10-CM starter set the first time the app runs.
    ///
    /// Safe to call on every launch: ingest is keyed on `(system, code)`, so a
    /// repeat load would be a no-op even without the count check.
    func loadSeedIfNeeded() async {
        guard let repository else { return }
        do {
            guard try await repository.codeCount() == 0 else { return }
            guard let url = Bundle.main.url(forResource: SEED_RESOURCE_NAME, withExtension: "json") else {
                assertionFailure("\(SEED_RESOURCE_NAME).json missing from the app bundle")
                return
            }
            try await repository.ingest(CodeSetDecoder.decode(contentsOf: url))
        } catch {
            NSLog("CodeBar: failed to load seed code set — \(error)")
        }
    }
}
