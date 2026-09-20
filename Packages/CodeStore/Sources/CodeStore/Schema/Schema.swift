enum Schema {
    static let version: Int32 = 4

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
        is_billable   INTEGER,
        parent_code   TEXT,
        chapter       TEXT,
        UNIQUE(system, code)
    );

    CREATE INDEX idx_codes_code_norm ON codes(code_norm);
    CREATE INDEX idx_codes_system    ON codes(system);
    CREATE INDEX idx_codes_parent    ON codes(system, parent_code);

    CREATE TABLE code_notes (
        id         INTEGER PRIMARY KEY,
        system     TEXT NOT NULL,
        code       TEXT NOT NULL,
        kind       TEXT NOT NULL,
        text       TEXT NOT NULL,
        sort_order INTEGER NOT NULL
    );

    CREATE INDEX idx_code_notes ON code_notes(system, code, sort_order);

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

    static let upsertCode = """
    INSERT INTO codes (system, code, code_norm, display, synonyms_json, synonyms_text,
                       is_billable, parent_code, chapter)
    VALUES (:system, :code, :code_norm, :display, :synonyms_json, :synonyms_text,
             :is_billable, :parent_code, :chapter)
    ON CONFLICT(system, code) DO UPDATE SET
        code_norm     = excluded.code_norm,
        display       = excluded.display,
        synonyms_json = excluded.synonyms_json,
        synonyms_text = excluded.synonyms_text,
        is_billable   = COALESCE(excluded.is_billable, codes.is_billable),
        parent_code   = COALESCE(excluded.parent_code, codes.parent_code),
        chapter       = COALESCE(excluded.chapter, codes.chapter);
    """

    static let migrateV2ToV3 = "ALTER TABLE codes ADD COLUMN is_billable INTEGER;"

    static let migrateV3ToV4 = """
    ALTER TABLE codes ADD COLUMN parent_code TEXT;
    ALTER TABLE codes ADD COLUMN chapter TEXT;

    CREATE INDEX idx_codes_parent ON codes(system, parent_code);

    CREATE TABLE code_notes (
        id         INTEGER PRIMARY KEY,
        system     TEXT NOT NULL,
        code       TEXT NOT NULL,
        kind       TEXT NOT NULL,
        text       TEXT NOT NULL,
        sort_order INTEGER NOT NULL
    );

    CREATE INDEX idx_code_notes ON code_notes(system, code, sort_order);
    """

    static let selectChildren = """
    SELECT system, code, display, synonyms_json, is_billable, parent_code, chapter
      FROM codes
     WHERE system = :system AND parent_code IS :parent
     ORDER BY LENGTH(code), code;
    """

    static let selectNotes = """
    SELECT kind, text FROM code_notes
     WHERE system = :system AND code = :code
     ORDER BY sort_order;
    """

    static let selectCode = """
    SELECT system, code, display, synonyms_json, is_billable, parent_code, chapter
      FROM codes WHERE system = :system AND code = :code;
    """

    static let insertNote = """
    INSERT INTO code_notes (system, code, kind, text, sort_order)
    VALUES (:system, :code, :kind, :text, :sort_order);
    """

    static let deleteNotes = "DELETE FROM code_notes WHERE system = :system;"

    static let selectChapters = """
    SELECT chapter FROM codes
     WHERE system = :system AND chapter IS NOT NULL
     GROUP BY chapter
     ORDER BY MIN(code);
    """

    static let selectChapterRoots = """
    SELECT system, code, display, synonyms_json, is_billable, parent_code, chapter
      FROM codes
     WHERE system = :system AND chapter = :chapter AND parent_code IS NULL
     ORDER BY code;
    """

    static let upsertCodeSet = """
    INSERT INTO code_sets (system, release, imported_at)
    VALUES (:system, :release, :imported_at)
    ON CONFLICT(system) DO UPDATE SET
        release     = COALESCE(excluded.release, code_sets.release),
        imported_at = excluded.imported_at;
    """

    static let selectManifests = """
    SELECT s.system, s.release, s.imported_at, COUNT(c.id) AS row_count
      FROM code_sets s
      LEFT JOIN codes c ON c.system = s.system
     GROUP BY s.system
     ORDER BY s.system;
    """
}
