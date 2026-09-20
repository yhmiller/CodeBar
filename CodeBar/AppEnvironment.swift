import CodeCore
import CodeLibrary
import CodePlatform
import CodeStore
import Foundation

private let SEED_RESOURCE_NAME = "seed_icd10_sample"

private let STORE_SUBDIRECTORY_VARIABLE = "CODEBAR_STORE_SUBDIRECTORY"

@MainActor
final class AppEnvironment {

    let repository: (any CodeRepository)?
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
            fatalError("could not create the UI test store directory: \(error)")
        }
    }

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
