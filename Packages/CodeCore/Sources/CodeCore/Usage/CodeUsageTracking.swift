/// Records which codes this person actually uses.
///
/// This is user data, not derived data: it lives outside `codes.sqlite`, which is
/// a disposable index rebuildable from the seed plus imported files. Nuking and
/// re-importing a code set must never cost someone their pins.
/// See docs/ARCHITECTURE.md §5.6.
///
/// It also does real work for search quality. BM25 ranks by textual relevance,
/// which is not the same as clinical frequency — typing "diabetes" surfaces
/// obscure specific codes above E11.9, and no structural signal in the data fixes
/// that. Personal usage is the one signal that genuinely reflects what a given
/// clinician means.
@MainActor
public protocol CodeUsageTracking {
    /// Codes the user pinned, most recently pinned first.
    var pinnedCodes: [ClinicalCode] { get }
    /// Codes the user recently copied, most recent first, excluding pinned ones.
    var recentCodes: [ClinicalCode] { get }

    func isPinned(_ code: ClinicalCode) -> Bool
    func togglePin(_ code: ClinicalCode)
    /// Called when a code is copied.
    func recordUse(of code: ClinicalCode)
}
