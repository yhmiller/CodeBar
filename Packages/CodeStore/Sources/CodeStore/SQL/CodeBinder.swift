import CodeCore
import SQLiteKit
import Foundation

/// Translates a `ClinicalCode` to and from its stored column form.
///
/// Synonyms are stored twice on purpose: `synonyms_json` preserves them exactly,
/// including multi-word entries like "type 2 diabetes", while `synonyms_text` is
/// the flattened form the FTS5 index reads. v1 stored only the flattened form
/// and split it back apart on read, which silently shredded every multi-word
/// synonym into separate tokens.
enum CodeBinder {

    static func bind(_ code: ClinicalCode, to statement: Statement) throws {
        try statement.bind(code.system.rawValue, to: ":system")
        try statement.bind(code.code, to: ":code")
        try statement.bind(code.normalizedCode, to: ":code_norm")
        try statement.bind(code.display, to: ":display")
        try statement.bind(encodeSynonyms(code.synonyms), to: ":synonyms_json")
        try statement.bind(code.synonyms.joined(separator: " "), to: ":synonyms_text")
        try statement.bind(code.isBillable.map { $0 ? 1 : 0 }, to: ":is_billable")
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
