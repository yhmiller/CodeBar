/// Schema for `library.sqlite` — the user's own data.
///
/// The hub is `saved_codes`: one row per code the user has touched, keyed on
/// `(system, code)` exactly as the index is. Everything else hangs off it, which
/// is what lets later features arrive as new tables rather than as a reshape.
///
/// v2 added lists and notes, hanging off `saved_codes` exactly as planned when
/// the hub was designed — new tables rather than a reshape.
enum LibrarySchema {

    static let version: Int32 = 3

    /// Everything a fresh database needs, in version order.
    static let create = createV1 + createV2 + createV3

    /// The original schema: the hub, pins and usage.
    ///
    /// Named rather than left as "`create` minus the later pieces" so that a test
    /// building a v1 database can ask for it directly. Deriving it by stripping
    /// strings out of `create` broke the moment v3 was added.
    static let createV1 = """
    CREATE TABLE saved_codes (
        id            INTEGER PRIMARY KEY,
        system        TEXT NOT NULL,
        code          TEXT NOT NULL,
        -- Snapshot of the description as it was when the user saved it. If the
        -- publisher later retires the code, the pin still reads sensibly instead
        -- of becoming an opaque identifier. The UI can then mark it retired,
        -- which is exactly what a clinician needs to see.
        display       TEXT NOT NULL,
        synonyms_json TEXT NOT NULL DEFAULT '[]',
        is_billable   INTEGER,
        first_seen_at INTEGER NOT NULL,
        UNIQUE(system, code)
    );

    CREATE TABLE pins (
        saved_code_id INTEGER PRIMARY KEY REFERENCES saved_codes(id) ON DELETE CASCADE,
        pinned_at     INTEGER NOT NULL,
        -- Fractional so a future drag-to-reorder can insert between two rows
        -- without renumbering the table.
        sort_order    REAL NOT NULL
    );

    -- One row per use, not a capped list. Keeping the full history is what makes
    -- ranking by personal frequency possible later; the previous UserDefaults
    -- version discarded everything past the last eight, which threw away exactly
    -- the data that would help.
    CREATE TABLE usage_events (
        id            INTEGER PRIMARY KEY,
        saved_code_id INTEGER NOT NULL REFERENCES saved_codes(id) ON DELETE CASCADE,
        used_at       INTEGER NOT NULL,
        copy_format   TEXT
    );

    CREATE INDEX idx_usage_used_at ON usage_events(used_at DESC);
    CREATE INDEX idx_usage_code    ON usage_events(saved_code_id);
    """

    /// The clinician's own shorthand. Split out for the same reason as `createV2`.
    ///
    /// The term is the key, so adding `PCN` after `pcn` replaces it rather than
    /// storing a second row that could never be found — lookup lowercases the
    /// query token, so only one of the two would ever win. No `COLLATE NOCASE`
    /// is needed for that: `Abbreviation` lowercases on construction and every
    /// write goes through it, which a mutation test confirmed by removing the
    /// collation and changing nothing.
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

    /// Lists and notes. Split out so it can be run both on a fresh database and
    /// as the v1 -> v2 migration, from one definition.
    static let createV2 = """
    -- A named collection: a problem list, an encounter template, a personal
    -- favourites set.
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

    -- One note per code. What a clinician knows that the publisher does not:
    -- which code their department actually uses for a given presentation.
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

    /// Recents exclude pinned codes: a pin is already shown above, and repeating
    /// it wastes the few rows the empty state has.
    static let selectRecent = """
    SELECT c.system, c.code, c.display, c.synonyms_json, c.is_billable,
           MAX(u.used_at) AS last_used
      FROM usage_events u
      JOIN saved_codes c ON c.id = u.saved_code_id
     WHERE c.id NOT IN (SELECT saved_code_id FROM pins)
     GROUP BY c.id
     -- Tie-broken on the event id, which is strictly increasing. `used_at` has
     -- second resolution, so two codes copied in the same second would otherwise
     -- come back in an arbitrary order.
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

    /// A saved code with no pin, no usage, no list membership and no note is a
    /// leftover. Every reason to keep a row has to be checked, or unpinning a
    /// code would silently delete the note attached to it.
    static let pruneOrphans = """
    DELETE FROM saved_codes
     WHERE id NOT IN (SELECT saved_code_id FROM pins)
       AND id NOT IN (SELECT saved_code_id FROM usage_events)
       AND id NOT IN (SELECT saved_code_id FROM list_members)
       AND id NOT IN (SELECT saved_code_id FROM notes);
    """
}
