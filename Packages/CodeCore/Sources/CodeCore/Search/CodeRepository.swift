/// The seam between the UI and storage.
///
/// `CodeBarUI` depends on this protocol and never imports `CodeStore`, so the
/// view layer can be tested against an in-memory fake and the SQLite
/// implementation can be replaced without touching a view.
///
/// Every member is `async` because the concrete store is an actor: search moves
/// off the main thread, which is what keeps typing responsive at full code-set
/// scale.
public protocol CodeRepository: Sendable {

    /// Ranked matches, best first, capped at `query.limit`.
    /// Returns an empty array for an empty query rather than throwing.
    func search(_ query: SearchQuery) async throws -> [SearchResult]

    /// One entry per installed code set, ordered by system.
    func manifests() async throws -> [CodeSetManifest]

    /// Total stored codes across all systems.
    func codeCount() async throws -> Int

    /// Loads a batch, honouring its `mode`. Idempotent for `.merge`:
    /// re-importing the same batch leaves the row count unchanged.
    @discardableResult
    func ingest(_ codeSet: CodeSetImport) async throws -> IngestSummary

    /// Removes every code belonging to `system`, and its manifest entry.
    /// Returns the number of rows deleted.
    @discardableResult
    func removeCodeSet(_ system: CodeSystem) async throws -> Int
}
