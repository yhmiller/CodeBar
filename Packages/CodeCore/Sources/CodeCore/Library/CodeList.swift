import Foundation

/// A named collection of codes: a problem list, an encounter template, a
/// personal favourites set.
public struct CodeList: Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let detail: String?
    public let createdAt: Date
    public let count: Int

    public init(id: Int, name: String, detail: String?, createdAt: Date, count: Int) {
        self.id = id
        self.name = name
        self.detail = detail
        self.createdAt = createdAt
        self.count = count
    }
}
