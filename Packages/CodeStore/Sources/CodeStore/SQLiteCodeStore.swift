import CodeCore
import SQLiteKit
import Foundation

private let MAX_HIERARCHY_DEPTH = 16

public actor SQLiteCodeStore: CodeRepository {

    public enum Location: Sendable {
        case inMemory
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
        let preferred = Array(query.preferredCodes.sorted().prefix(SearchSQL.preferredLimit))
        let statement = try database.prepare(
            SearchSQL.build(codePass: hasCodePass, textPass: hasTextPass,
                            systemCount: systems.count, preferredCount: preferred.count)
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
        for (offset, id) in preferred.enumerated() {
            try statement.bind(id, to: ":pref\(offset)")
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
                        isBillable: statement.optionalBool(at: 4),
                        isUnspecified: statement.optionalBool(at: 8)
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

    // MARK: - Hierarchy

    public func detail(for code: ClinicalCode) throws -> CodeDetail? {
        guard let stored = try readCode(code.code, in: code.system) else { return nil }

        return CodeDetail(
            code: stored,
            ancestors: try ancestors(of: stored),
            children: try children(of: stored.code, in: stored.system),
            notes: try notes(for: stored)
        )
    }

    public func children(of parent: String?, in system: CodeSystem) throws -> [ClinicalCode] {
        let statement = try database.prepare(Schema.selectChildren)
        try statement.bind(system.rawValue, to: ":system")
        try statement.bind(parent, to: ":parent")

        var codes: [ClinicalCode] = []
        while try statement.step() {
            if let code = readCode(from: statement) { codes.append(code) }
        }
        return codes
    }

    public func chapters(in system: CodeSystem) throws -> [String] {
        let statement = try database.prepare(Schema.selectChapters)
        try statement.bind(system.rawValue, to: ":system")

        var chapters: [String] = []
        while try statement.step() {
            if let chapter = statement.string(at: 0) { chapters.append(chapter) }
        }
        return chapters
    }

    public func roots(inChapter chapter: String, of system: CodeSystem) throws -> [ClinicalCode] {
        let statement = try database.prepare(Schema.selectChapterRoots)
        try statement.bind(system.rawValue, to: ":system")
        try statement.bind(chapter, to: ":chapter")

        var codes: [ClinicalCode] = []
        while try statement.step() {
            if let code = readCode(from: statement) { codes.append(code) }
        }
        return codes
    }

    private func ancestors(of code: ClinicalCode) throws -> [ClinicalCode] {
        var ancestors: [ClinicalCode] = []
        var seen: Set<String> = [code.code]
        var next = code.parent

        while let parent = next, !seen.contains(parent), ancestors.count < MAX_HIERARCHY_DEPTH {
            guard let found = try readCode(parent, in: code.system) else { break }
            ancestors.append(found)
            seen.insert(parent)
            next = found.parent
        }
        return ancestors
    }

    private func notes(for code: ClinicalCode) throws -> [CodeNote] {
        let statement = try database.prepare(Schema.selectNotes)
        try statement.bind(code.system.rawValue, to: ":system")
        try statement.bind(code.code, to: ":code")

        var notes: [CodeNote] = []
        while try statement.step() {
            guard let rawKind = statement.string(at: 0),
                  let kind = CodeNote.Kind(rawValue: rawKind),
                  let text = statement.string(at: 1)
            else { continue }
            notes.append(CodeNote(kind: kind, text: text))
        }
        return notes
    }

    private func readCode(_ code: String, in system: CodeSystem) throws -> ClinicalCode? {
        let statement = try database.prepare(Schema.selectCode)
        try statement.bind(system.rawValue, to: ":system")
        try statement.bind(code, to: ":code")
        guard try statement.step() else { return nil }
        return readCode(from: statement)
    }

    private func readCode(from statement: Statement) -> ClinicalCode? {
        guard let systemRaw = statement.string(at: 0),
              let system = CodeSystem(rawValue: systemRaw),
              let code = statement.string(at: 1),
              let display = statement.string(at: 2)
        else { return nil }

        return ClinicalCode(
            code: code,
            display: display,
            system: system,
            synonyms: CodeBinder.decodeSynonyms(statement.string(at: 3)),
            isBillable: statement.optionalBool(at: 4),
            parent: statement.string(at: 5),
            chapter: statement.string(at: 6),
            isUnspecified: statement.optionalBool(at: 7)
        )
    }

    // MARK: - Mutating

    @discardableResult
    public func ingest(_ codeSet: CodeSetImport) throws -> IngestSummary {
        let systems = codeSet.systems
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

            try replaceNotes(from: codeSet, systems: systems)
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
        let deleted = database.changeCount

        let notes = try database.prepare(Schema.deleteNotes)
        try notes.bind(system.rawValue, to: ":system")
        try notes.step()

        return deleted
    }

    private func replaceNotes(from codeSet: CodeSetImport, systems: Set<CodeSystem>) throws {
        guard !codeSet.notes.isEmpty else { return }

        for system in systems.sorted(by: { $0.rawValue < $1.rawValue }) {
            let delete = try database.prepare(Schema.deleteNotes)
            try delete.bind(system.rawValue, to: ":system")
            try delete.step()
        }

        let insert = try database.prepare(Schema.insertNote)
        for code in codeSet.codes {
            guard let notes = codeSet.notes[code.id] else { continue }
            for (offset, note) in notes.enumerated() {
                insert.reset()
                try insert.bind(code.system.rawValue, to: ":system")
                try insert.bind(code.code, to: ":code")
                try insert.bind(note.kind.rawValue, to: ":kind")
                try insert.bind(note.text, to: ":text")
                try insert.bind(offset, to: ":sort_order")
                try insert.step()
            }
        }
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
