import CodeCore
import Foundation

private let PINNED_KEY = "CodeBar.pinnedCodes"
private let RECENT_KEY = "CodeBar.recentCodes"

/// How many recently-copied codes to remember. Long enough to cover a clinic
/// session, short enough that the empty state stays scannable.
private let RECENT_LIMIT = 8

/// Pins and recents, persisted in `UserDefaults`.
///
/// Deliberately not in `codes.sqlite`: that file is a rebuildable index, and
/// re-importing a code set must never cost someone their pins.
@MainActor
public final class UserDefaultsCodeUsageStore: CodeUsageTracking {
    private let defaults: UserDefaults

    public private(set) var pinnedCodes: [ClinicalCode]
    public private(set) var recentCodes: [ClinicalCode]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        pinnedCodes = Self.load(PINNED_KEY, from: defaults)
        recentCodes = Self.load(RECENT_KEY, from: defaults)
    }

    public func isPinned(_ code: ClinicalCode) -> Bool {
        pinnedCodes.contains { $0.id == code.id }
    }

    public func togglePin(_ code: ClinicalCode) {
        if let index = pinnedCodes.firstIndex(where: { $0.id == code.id }) {
            pinnedCodes.remove(at: index)
        } else {
            pinnedCodes.insert(code, at: 0)
        }
        save(pinnedCodes, to: PINNED_KEY)
    }

    public func recordUse(of code: ClinicalCode) {
        recentCodes.removeAll { $0.id == code.id }
        recentCodes.insert(code, at: 0)
        if recentCodes.count > RECENT_LIMIT {
            recentCodes.removeLast(recentCodes.count - RECENT_LIMIT)
        }
        save(recentCodes, to: RECENT_KEY)
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

    private func save(_ codes: [ClinicalCode], to key: String) {
        guard let data = try? JSONEncoder().encode(codes) else { return }
        defaults.set(data, forKey: key)
    }
}
