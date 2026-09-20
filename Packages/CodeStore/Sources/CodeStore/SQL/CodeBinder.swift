import CodeCore
import SQLiteKit
import Foundation

enum CodeBinder {

    static func bind(_ code: ClinicalCode, to statement: Statement) throws {
        try statement.bind(code.system.rawValue, to: ":system")
        try statement.bind(code.code, to: ":code")
        try statement.bind(code.normalizedCode, to: ":code_norm")
        try statement.bind(code.display, to: ":display")
        try statement.bind(encodeSynonyms(code.synonyms), to: ":synonyms_json")
        try statement.bind(code.synonyms.joined(separator: " "), to: ":synonyms_text")
        try statement.bind(code.isBillable.map { $0 ? 1 : 0 }, to: ":is_billable")
        try statement.bind(code.parent, to: ":parent_code")
        try statement.bind(code.chapter, to: ":chapter")
    }

    static func encodeSynonyms(_ synonyms: [String]) -> String {
        guard let data = try? JSONEncoder().encode(synonyms),
              let json = String(data: data, encoding: .utf8)
        else { return "[]" }
        return json
    }

    static func decodeSynonyms(_ json: String?) -> [String] {
        guard let json,
              let data = json.data(using: .utf8),
              let synonyms = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return synonyms
    }
}
