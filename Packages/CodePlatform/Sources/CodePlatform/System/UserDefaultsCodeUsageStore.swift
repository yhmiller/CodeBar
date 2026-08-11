import CodeCore
import Foundation

private let PINNED_KEY = "CodeBar.pinnedCodes"
private let RECENT_KEY = "CodeBar.recentCodes"

/// The pre-`CodeLibrary` home for pins and recents.
///
/// Superseded by `library.sqlite`, and kept only so an existing install's data
/// can be handed across on first launch. `UserDefaults` was fine for a capped
/// list of pins; it cannot carry lists, notes or a full usage history, and its
/// eight-item recents cap discarded exactly the data personal-frequency ranking
/// needs. See docs/ARCHITECTURE.md §11.
///
/// TODO(yhmiller): delete once enough time has passed that no install is still
/// carrying data here.
@MainActor
public final class LegacyUserDefaultsUsageStore {
    private let defaults: UserDefaults

    public private(set) var pinnedCodes: [ClinicalCode]
    public private(set) var recentCodes: [ClinicalCode]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pinnedCodes = Self.load(PINNED_KEY, from: defaults)
        recentCodes = Self.load(RECENT_KEY, from: defaults)
    }

    /// Clears what was handed over, so the old keys do not linger.
    public func clear() {
        pinnedCodes = []
        recentCodes = []
        defaults.removeObject(forKey: PINNED_KEY)
        defaults.removeObject(forKey: RECENT_KEY)
    }

    // MARK: - Persistence

    /// Decoding failures are swallowed on purpose: a corrupt or
    /// forward-incompatible list should cost the user their history, not the
    /// ability to launch.
    private static func load(_ key: String, from defaults: UserDefaults) -> [ClinicalCode] {
        guard let data = defaults.data(forKey: key),
              let codes = try? JSONDecoder().decode([ClinicalCode].self, from: data)
        else { return [] }
        return codes
    }

}
