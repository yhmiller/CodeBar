import CodeCore
import Foundation

private let PINNED_KEY = "CodeBar.pinnedCodes"
private let RECENT_KEY = "CodeBar.recentCodes"

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

    public func clear() {
        pinnedCodes = []
        recentCodes = []
        defaults.removeObject(forKey: PINNED_KEY)
        defaults.removeObject(forKey: RECENT_KEY)
    }

    // MARK: - Persistence

    private static func load(_ key: String, from defaults: UserDefaults) -> [ClinicalCode] {
        guard let data = defaults.data(forKey: key),
              let codes = try? JSONDecoder().decode([ClinicalCode].self, from: data)
        else { return [] }
        return codes
    }

}
