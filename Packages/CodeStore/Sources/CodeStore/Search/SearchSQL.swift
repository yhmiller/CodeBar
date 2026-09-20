enum SearchSQL {

    static let codePassLimit = 25
    static let textPassLimit = 50

    static let displayWeight = 1.0
    static let synonymWeight = 1.0

    static let preferredLimit = 50

    static func build(codePass: Bool, textPass: Bool, systemCount: Int,
                      preferredCount: Int = 0) -> String {
        var commonTables: [String] = []
        var unions: [String] = []

        if codePass {
            commonTables.append("""
            code_hits AS (
                SELECT id,
                       CASE WHEN code_norm = :norm THEN 0 ELSE 1 END AS tier,
                       0.0 AS score
                  FROM codes
                 WHERE code_norm >= :norm AND code_norm < :norm_upper
                 LIMIT :code_limit
            )
            """)
            unions.append("SELECT id, tier, score FROM code_hits")
        }

        if textPass {
            commonTables.append("""
            text_hits AS (
                SELECT rowid AS id,
                       2 AS tier,
                       bm25(codes_fts, \(displayWeight), \(synonymWeight)) AS score
                  FROM codes_fts
                 WHERE codes_fts MATCH :match
                 ORDER BY bm25(codes_fts, \(displayWeight), \(synonymWeight))
                 LIMIT :text_limit
            )
            """)
            unions.append("SELECT id, tier, score FROM text_hits")
        }

        if textPass && preferredCount > 0 {
            let placeholders = (0..<preferredCount).map { ":pref\($0)" }.joined(separator: ", ")
            commonTables.append("""
            preferred_hits AS (
                SELECT c.id, 2 AS tier, 0.0 AS score
                  FROM codes c
                 WHERE (c.system || '-' || c.code) IN (\(placeholders))
                   AND c.id IN (SELECT rowid FROM codes_fts WHERE codes_fts MATCH :match)
            )
            """)
            unions.append("SELECT id, tier, score FROM preferred_hits")
        }

        let systemFilter = systemCount > 0
            ? "WHERE c.system IN (\((0..<systemCount).map { ":sys\($0)" }.joined(separator: ", ")))"
            : ""

        let preference = preferredCount > 0
            ? "CASE WHEN (c.system || '-' || c.code) IN "
              + "(\((0..<preferredCount).map { ":pref\($0)" }.joined(separator: ", ")))"
              + " THEN 0 ELSE 1 END"
            : "0"

        return """
        WITH \(commonTables.joined(separator: ",\n")),
        hits AS (\(unions.joined(separator: "\n UNION ALL ")))
        SELECT c.system, c.code, c.display, c.synonyms_json, c.is_billable,
               MIN(h.tier) AS tier,
               CASE WHEN c.is_billable = 0 THEN 1 ELSE 0 END AS header_last,
               \(preference) AS not_preferred,
               c.is_unspecified
          FROM hits h
          JOIN codes c ON c.id = h.id
        \(systemFilter)
         GROUP BY c.id
         ORDER BY tier, not_preferred, header_last, MIN(h.score), LENGTH(c.code), c.code
         LIMIT :limit;
        """
    }
}
