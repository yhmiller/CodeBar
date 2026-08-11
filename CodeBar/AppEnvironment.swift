import CodeCore
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
    let startupFailure: String?

    init() {
        do {
            repository = try SQLiteCodeStore()
            startupFailure = nil
        } catch {
            repository = nil
            startupFailure = String(describing: error)
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
