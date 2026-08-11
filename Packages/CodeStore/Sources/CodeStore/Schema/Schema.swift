/// Schema v2 DDL and the statements shared across the store.
///
/// The central change from v1: FTS5 is no longer the source of truth. Codes live
/// in a real table that can carry a uniqueness constraint and a B-tree index,
/// with an external-content FTS5 index kept in sync by triggers. That is what
/// makes imports idempotent and turns code-prefix search into an index range
/// scan. See docs/ARCHITECTURE.md §5.1.
enum Schema {

    static let version: Int32 = 3

    static let createSchema = """
    CREATE TABLE code_sets (
        system      TEXT PRIMARY KEY,
        release     TEXT,
        imported_at INTEGER NOT NULL
    );

    CREATE TABLE codes (
        id            INTEGER PRIMARY KEY,
        system        TEXT NOT NULL,
        code          TEXT NOT NULL,
        code_norm     TEXT NOT NULL,
        display       TEXT NOT NULL,
        synonyms_json TEXT NOT NULL DEFAULT '[]',
        synonyms_text TEXT NOT NULL DEFAULT '',
        -- NULL when the source does not say. 0 marks a category header that
        -- must not be submitted on a claim.
        is_billable   INTEGER,
        UNIQUE(system, code)
    );

    CREATE INDEX idx_codes_code_norm ON codes(code_norm);
    CREATE INDEX idx_codes_system    ON codes(system);

    CREATE VIRTUAL TABLE codes_fts USING fts5(
        display,
        synonyms_text,
        content = 'codes',
        content_rowid = 'id',
        tokenize = 'porter unicode61'
    );

    CREATE TRIGGER codes_ai AFTER INSERT ON codes BEGIN
        INSERT INTO codes_fts(rowid, display, synonyms_text)
        VALUES (new.id, new.display, new.synonyms_text);
    END;

    CREATE TRIGGER codes_ad AFTER DELETE ON codes BEGIN
        INSERT INTO codes_fts(codes_fts, rowid, display, synonyms_text)
        VALUES ('delete', old.id, old.display, old.synonyms_text);
    END;

    CREATE TRIGGER codes_au AFTER UPDATE ON codes BEGIN
        INSERT INTO codes_fts(codes_fts, rowid, display, synonyms_text)
        VALUES ('delete', old.id, old.display, old.synonyms_text);
        INSERT INTO codes_fts(rowid, display, synonyms_text)
        VALUES (new.id, new.display, new.synonyms_text);
    END;
    """

    /// Upsert keyed on `(system, code)`. This is what makes importing the same
    /// file twice a no-op instead of doubling every row.
    static let upsertCode = """
    INSERT INTO codes (system, code, code_norm, display, synonyms_json, synonyms_text, is_billable)
    VALUES (:system, :code, :code_norm, :display, :synonyms_json, :synonyms_text, :is_billable)
    ON CONFLICT(system, code) DO UPDATE SET
        code_norm     = excluded.code_norm,
        display       = excluded.display,
        synonyms_json = excluded.synonyms_json,
        synonyms_text = excluded.synonyms_text,
        -- COALESCE so re-importing from a source that omits billability does
        -- not erase a flag an earlier, richer import established.
        is_billable   = COALESCE(excluded.is_billable, codes.is_billable);
    """

    /// v2 -> v3. A nullable column needs no table rebuild, so existing rows keep
    /// their data and simply report "unknown" until they are re-imported.
    static let migrateV2ToV3 = "ALTER TABLE codes ADD COLUMN is_billable INTEGER;"

    /// `COALESCE` keeps a previously recorded release when a later merge import
    /// carries no release stamp of its own.
    static let upsertCodeSet = """
    INSERT INTO code_sets (system, release, imported_at)
    VALUES (:system, :release, :imported_at)
    ON CONFLICT(system) DO UPDATE SET
        release     = COALESCE(excluded.release, code_sets.release),
        imported_at = excluded.imported_at;
    """

    /// Row counts are computed from `codes` rather than cached on `code_sets`,
    /// so a manifest can never drift out of step with what is actually stored.
    static let selectManifests = """
    SELECT s.system, s.release, s.imported_at, COUNT(c.id) AS row_count
      FROM code_sets s
      LEFT JOIN codes c ON c.system = s.system
     GROUP BY s.system
     ORDER BY s.system;
    """
}
