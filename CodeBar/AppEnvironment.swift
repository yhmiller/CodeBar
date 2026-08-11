import CodeCore
import CodeLibrary
import CodePlatform
import CodeStore
import Foundation

private let SEED_RESOURCE_NAME = "seed_icd10_sample"

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

        do {
            repository = try SQLiteCodeStore()
        } catch {
            repository = nil
            failures.append("Code index: \(error)")
        }

        do {
            library = try SQLiteCodeLibrary()
        } catch {
            library = nil
            failures.append("Library: \(error)")
        }

        startupFailure = failures.isEmpty ? nil : failures.joined(separator: "\n")
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
