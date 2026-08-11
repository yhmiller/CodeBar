import CodeCore
import SQLiteKit
import Foundation

/// SQLite + FTS5 implementation of `CodeRepository`.
///
/// An actor rather than a shared singleton: search runs off the main thread, and
/// actor isolation is what serializes access to the non-`Sendable` connection.
public actor SQLiteCodeStore: CodeRepository {

    public enum Location: Sendable {
        case inMemory
        /// `~/Library/Application Support/CodeBar/codes.sqlite`.
        ///
        /// Treat this file as disposable: it is rebuildable from the bundled seed
        /// plus the user's import files. Pinned codes and preferences deliberately
        /// live elsewhere so that discarding the index is never destructive.
        case applicationSupport
        case file(URL)
    }

    private let database: Database

    public init(location: Location = .applicationSupport) throws {
        database = try Database(path: try location.path())
        try database.configure()
        try Migrations.migrate(database)
    }

    // MARK: - Search

    public func search(_ query: SearchQuery) throws -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        let upperBound = CodeNormalizer.prefixUpperBound(query.normalizedCode)
        let hasCodePass = !query.normalizedCode.isEmpty && upperBound != nil
        let hasTextPass = query.matchExpression != nil
        guard hasCodePass || hasTextPass else { return [] }

        let systems = query.systems.map(\.rawValue).sorted()
        let statement = try database.prepare(
            SearchSQL.build(codePass: hasCodePass, textPass: hasTextPass, systemCount: systems.count)
        )

        if hasCodePass, let upperBound {
            try statement.bind(query.normalizedCode, to: ":norm")
            try statement.bind(upperBound, to: ":norm_upper")
            try statement.bind(SearchSQL.codePassLimit, to: ":code_limit")
        }
        if let matchExpression = query.matchExpression {
            try statement.bind(matchExpression, to: ":match")
            try statement.bind(SearchSQL.textPassLimit, to: ":text_limit")
        }
        for (offset, system) in systems.enumerated() {
            try statement.bind(system, to: ":sys\(offset)")
        }
        try statement.bind(query.limit, to: ":limit")

        var results: [SearchResult] = []
        while try statement.step() {
            guard let systemRaw = statement.string(at: 0),
                  let system = CodeSystem(rawValue: systemRaw),
                  let code = statement.string(at: 1),
                  let display = statement.string(at: 2)
            else { continue }

            results.append(
                SearchResult(
                    code: ClinicalCode(
                        code: code,
                        display: display,
                        system: system,
                        synonyms: CodeBinder.decodeSynonyms(statement.string(at: 3)),
                        isBillable: statement.optionalBool(at: 4)
                    ),
                    matchTier: SearchResult.MatchTier(rawValue: statement.int(at: 5)) ?? .text
                )
            )
        }
        return results
    }

    // MARK: - Inspecting

    public func codeCount() throws -> Int {
        let statement = try database.prepare("SELECT COUNT(*) FROM codes;")
        guard try statement.step() else { return 0 }
        return statement.int(at: 0)
    }

    /// Codes installed for the given systems. An empty set counts everything.
    private func codeCount(in systems: Set<CodeSystem>) throws -> Int {
        guard !systems.isEmpty else { return try codeCount() }

        let placeholders = (0..<systems.count).map { ":sys\($0)" }.joined(separator: ", ")
        let statement = try database.prepare(
            "SELECT COUNT(*) FROM codes WHERE system IN (\(placeholders));"
        )
        for (offset, system) in systems.map(\.rawValue).sorted().enumerated() {
            try statement.bind(system, to: ":sys\(offset)")
        }
        guard try statement.step() else { return 0 }
        return statement.int(at: 0)
    }

    public func manifests() throws -> [CodeSetManifest] {
        let statement = try database.prepare(Schema.selectManifests)
        var manifests: [CodeSetManifest] = []

        while try statement.step() {
            guard let systemRaw = statement.string(at: 0),
                  let system = CodeSystem(rawValue: systemRaw)
            else { continue }

            manifests.append(
                CodeSetManifest(
                    system: system,
                    release: statement.string(at: 1),
                    importedAt: Date(timeIntervalSince1970: TimeInterval(statement.int(at: 2))),
                    rowCount: statement.int(at: 3)
                )
            )
        }
        return manifests
    }

    // MARK: - Mutating

    @discardableResult
    public func ingest(_ codeSet: CodeSetImport) throws -> IngestSummary {
        let systems = codeSet.systems
        // Scoped to the systems this file touches: importing LOINC should not
        // report a change in how many ICD-10 codes are installed.
        let installedBefore = try codeCount(in: systems)

        try database.transaction {
            if codeSet.mode == .replace {
                for system in systems.sorted(by: { $0.rawValue < $1.rawValue }) {
                    _ = try deleteCodes(in: system)
                }
            }

            let upsert = try database.prepare(Schema.upsertCode)
            for code in codeSet.codes {
                upsert.reset()
                try CodeBinder.bind(code, to: upsert)
                try upsert.step()
            }

            try recordManifests(for: systems, release: codeSet.release)
        }

        try optimize()

        return IngestSummary(
            processed: codeSet.codes.count,
            installedBefore: installedBefore,
            installedAfter: try codeCount(in: systems),
            systems: systems
        )
    }

    @discardableResult
    public func removeCodeSet(_ system: CodeSystem) throws -> Int {
        try database.transaction {
            let deleted = try deleteCodes(in: system)
            let statement = try database.prepare("DELETE FROM code_sets WHERE system = :system;")
            try statement.bind(system.rawValue, to: ":system")
            try statement.step()
            return deleted
        }
    }

    // MARK: - Private

    private func deleteCodes(in system: CodeSystem) throws -> Int {
        let statement = try database.prepare("DELETE FROM codes WHERE system = :system;")
        try statement.bind(system.rawValue, to: ":system")
        try statement.step()
        return database.changeCount
    }

    private func recordManifests(for systems: Set<CodeSystem>, release: String?) throws {
        let statement = try database.prepare(Schema.upsertCodeSet)
        let importedAt = Int(Date().timeIntervalSince1970)

        for system in systems.sorted(by: { $0.rawValue < $1.rawValue }) {
            statement.reset()
            try statement.bind(system.rawValue, to: ":system")
            try statement.bind(release, to: ":release")
            try statement.bind(importedAt, to: ":imported_at")
            try statement.step()
        }
    }

    /// Merges the FTS index's b-tree segments after a bulk write. Skipping this
    /// leaves a freshly imported set querying through hundreds of segments.
    private func optimize() throws {
        try database.execute("INSERT INTO codes_fts(codes_fts) VALUES('optimize');")
        try database.execute("PRAGMA optimize;")
    }
}

extension SQLiteCodeStore.Location {
    func path() throws -> String {
        switch self {
        case .inMemory:
            ":memory:"
        case .file(let url):
            url.path
        case .applicationSupport:
            try Self.applicationSupportPath()
        }
    }

    private static func applicationSupportPath() throws -> String {
        let directory = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("CodeBar", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("codes.sqlite").path
    }
}
