/// Builds the ranked search statement.
///
/// v1 ran two separate queries with different limits and orderings and stitched
/// the arrays together in Swift, so relative ranking between a code hit and a
/// text hit was an accident of iteration order. Here both passes feed one
/// statement and ordering is explicit: tier first, then BM25, then code length.
enum SearchSQL {

    /// Caps applied inside each pass before the passes are merged. Both are
    /// larger than a typical result limit so that merging and de-duplication
    /// have material to work with.
    static let codePassLimit = 25
    static let textPassLimit = 50

    /// A hit in the display text outranks a hit in a synonym.
    private static let displayWeight = 2.0
    private static let synonymWeight = 1.0

    static func build(codePass: Bool, textPass: Bool, systemCount: Int) -> String {
        var commonTables: [String] = []
        var unions: [String] = []

        if codePass {
            // The half-open range is what lets SQLite use idx_codes_code_norm.
            // LIKE 'E11%' is only index-optimized under specific collation and
            // pragma conditions; the range form always is.
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

        let systemFilter = systemCount > 0
            ? "WHERE c.system IN (\((0..<systemCount).map { ":sys\($0)" }.joined(separator: ", ")))"
            : ""

        // GROUP BY collapses a code that matched both passes onto its best tier,
        // which is what de-duplicates the merged result set.
        return """
        WITH \(commonTables.joined(separator: ",\n")),
        hits AS (\(unions.joined(separator: "\n UNION ALL ")))
        SELECT c.system, c.code, c.display, c.synonyms_json, MIN(h.tier) AS tier
          FROM hits h
          JOIN codes c ON c.id = h.id
        \(systemFilter)
         GROUP BY c.id
         ORDER BY tier, MIN(h.score), LENGTH(c.code), c.code
         LIMIT :limit;
        """
    }
}
