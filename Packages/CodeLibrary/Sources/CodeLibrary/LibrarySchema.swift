enum LibrarySchema {

    static let version: Int32 = 3

    static let create = createV1 + createV2 + createV3

    static let createV1 = """
    CREATE TABLE saved_codes (
        id            INTEGER PRIMARY KEY,
        system        TEXT NOT NULL,
        code          TEXT NOT NULL,
        display       TEXT NOT NULL,
        synonyms_json TEXT NOT NULL DEFAULT '[]',
        is_billable   INTEGER,
        first_seen_at INTEGER NOT NULL,
        UNIQUE(system, code)
    );

    CREATE TABLE pins (
        saved_code_id INTEGER PRIMARY KEY REFERENCES saved_codes(id) ON DELETE CASCADE,
        pinned_at     INTEGER NOT NULL,
        sort_order    REAL NOT NULL
    );

    CREATE TABLE usage_events (
        id            INTEGER PRIMARY KEY,
        saved_code_id INTEGER NOT NULL REFERENCES saved_codes(id) ON DELETE CASCADE,
        used_at       INTEGER NOT NULL,
        copy_format   TEXT
    );

    CREATE INDEX idx_usage_used_at ON usage_events(used_at DESC);
    CREATE INDEX idx_usage_code    ON usage_events(saved_code_id);
    """

    static let createV3 = """
    CREATE TABLE abbreviations (
        term       TEXT PRIMARY KEY,
        expansion  TEXT NOT NULL,
        created_at INTEGER NOT NULL
    );
    """

    static let selectAbbreviations = """
    SELECT term, expansion FROM abbreviations ORDER BY term;
    """

    static let createV2 = """
    CREATE TABLE lists (
        id         INTEGER PRIMARY KEY,
        name       TEXT NOT NULL,
        detail     TEXT,
        created_at INTEGER NOT NULL,
        sort_order REAL NOT NULL
    );

    CREATE TABLE list_members (
        list_id       INTEGER NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
        saved_code_id INTEGER NOT NULL REFERENCES saved_codes(id) ON DELETE CASCADE,
        sort_order    REAL NOT NULL,
        PRIMARY KEY (list_id, saved_code_id)
    );

    CREATE INDEX idx_list_members ON list_members(list_id, sort_order);

    CREATE TABLE notes (
        saved_code_id INTEGER PRIMARY KEY REFERENCES saved_codes(id) ON DELETE CASCADE,
        body          TEXT NOT NULL,
        updated_at    INTEGER NOT NULL
    );
    """

    static let selectLists = """
    SELECT l.id, l.name, l.detail, l.created_at, COUNT(m.saved_code_id)
      FROM lists l LEFT JOIN list_members m ON m.list_id = l.id
     GROUP BY l.id
     ORDER BY l.sort_order, l.created_at;
    """

    static let selectListMembers = """
    SELECT c.system, c.code, c.display, c.synonyms_json, c.is_billable
      FROM list_members m JOIN saved_codes c ON c.id = m.saved_code_id
     WHERE m.list_id = :list_id
     ORDER BY m.sort_order;
    """

    static let selectNote = """
    SELECT n.body FROM notes n JOIN saved_codes c ON c.id = n.saved_code_id
     WHERE c.system = :system AND c.code = :code;
    """

    static let upsertNote = """
    INSERT INTO notes (saved_code_id, body, updated_at)
    VALUES (:id, :body, :now)
    ON CONFLICT(saved_code_id) DO UPDATE SET body = excluded.body,
                                             updated_at = excluded.updated_at;
    """

    static let upsertSavedCode = """
    INSERT INTO saved_codes (system, code, display, synonyms_json, is_billable, first_seen_at)
    VALUES (:system, :code, :display, :synonyms_json, :is_billable, :now)
    ON CONFLICT(system, code) DO UPDATE SET
        display       = excluded.display,
        synonyms_json = excluded.synonyms_json,
        is_billable   = COALESCE(excluded.is_billable, saved_codes.is_billable);
    """

    static let selectPinned = """
    SELECT c.system, c.code, c.display, c.synonyms_json, c.is_billable
      FROM pins p JOIN saved_codes c ON c.id = p.saved_code_id
     ORDER BY p.sort_order, p.pinned_at DESC;
    """

    static let selectRecent = """
    SELECT c.system, c.code, c.display, c.synonyms_json, c.is_billable,
           MAX(u.used_at) AS last_used
      FROM usage_events u
      JOIN saved_codes c ON c.id = u.saved_code_id
     WHERE c.id NOT IN (SELECT saved_code_id FROM pins)
     GROUP BY c.id
     ORDER BY last_used DESC, MAX(u.id) DESC
     LIMIT :limit;
    """

    static let selectMostUsed = """
    SELECT c.system, c.code, c.display, c.synonyms_json, c.is_billable,
           COUNT(u.id) AS uses, MAX(u.used_at) AS last_used
      FROM usage_events u
      JOIN saved_codes c ON c.id = u.saved_code_id
     GROUP BY c.id
     ORDER BY uses DESC, last_used DESC, MAX(u.id) DESC
     LIMIT :limit;
    """

    static let pruneOrphans = """
    DELETE FROM saved_codes
     WHERE id NOT IN (SELECT saved_code_id FROM pins)
       AND id NOT IN (SELECT saved_code_id FROM usage_events)
       AND id NOT IN (SELECT saved_code_id FROM list_members)
       AND id NOT IN (SELECT saved_code_id FROM notes);
    """
}
