/// The user's own data: what they pinned, what they have used, and in time what
/// they have collected and annotated.
///
/// Deliberately a separate store from `CodeRepository`, because the two have
/// opposite lifecycles. The code index is derived and disposable — a yearly
/// release replaces it wholesale. This is irreplaceable: nothing here can be
/// rebuilt from a downloaded file. A `DELETE FROM codes` must never be able to
/// reach any of it. See docs/ARCHITECTURE.md §11.
public protocol CodeLibraryStoring: Sendable {

    // MARK: - Pins

    func pinnedCodes() async throws -> [ClinicalCode]
    func isPinned(_ code: ClinicalCode) async throws -> Bool
    /// Returns whether the code is pinned afterwards.
    @discardableResult
    func togglePin(_ code: ClinicalCode) async throws -> Bool

    // MARK: - Usage

    /// Records that a code was copied.
    ///
    /// Every use is kept, not just the last handful. That history is what makes
    /// ranking by personal frequency possible, which is the one sound answer to
    /// the gap recorded in phase 7: relevance ranking cannot know that E11.9 is
    /// the diabetes code a given clinician reaches for daily.
    func recordUse(of code: ClinicalCode, format: CopyFormat) async throws

    /// Most recently used first.
    func recentCodes(limit: Int) async throws -> [ClinicalCode]
    /// Most frequently used first, then most recent.
    func mostUsedCodes(limit: Int) async throws -> [ClinicalCode]
    func usageCount(for code: ClinicalCode) async throws -> Int

    // MARK: - Lists

    func lists() async throws -> [CodeList]
    @discardableResult
    func createList(named name: String, detail: String?) async throws -> CodeList
    func renameList(_ id: Int, to name: String) async throws
    func deleteList(_ id: Int) async throws
    func codes(inList id: Int) async throws -> [ClinicalCode]
    func addCode(_ code: ClinicalCode, toList id: Int) async throws
    func removeCode(_ code: ClinicalCode, fromList id: Int) async throws

    // MARK: - Notes

    /// What the user knows that the publisher does not — which code their
    /// department actually uses for a given presentation, for instance.
    /// `nil` when there is no note.
    func note(for code: ClinicalCode) async throws -> String?
    /// An empty or whitespace-only body removes the note.
    func setNote(_ body: String, for code: ClinicalCode) async throws

    // MARK: - Migration

    /// One-time adoption of data held before the library existed.
    /// Returns whether anything was taken across.
    @discardableResult
    func adoptLegacyData(pinned: [ClinicalCode], recent: [ClinicalCode]) async throws -> Bool
}
