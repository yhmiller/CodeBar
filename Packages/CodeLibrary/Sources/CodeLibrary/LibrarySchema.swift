/// Schema for `library.sqlite` — the user's own data.
///
/// The hub is `saved_codes`: one row per code the user has touched, keyed on
/// `(system, code)` exactly as the index is. Everything else hangs off it, which
/// is what lets later features arrive as new tables rather than as a reshape.
///
/// Planned, deliberately **not** created until a feature needs them, because a
/// migration ladder is cheap here and speculative empty tables are not:
///
///   lists(id, name, detail, created_at, sort_order)
///   list_members(list_id, saved_code_id, sort_order)
///   notes(saved_code_id, body, updated_at)
///
/// Each would reference `saved_codes(id)` with `ON DELETE CASCADE`, so the shape
/// above is the actual forward planning — not the tables themselves.
enum LibrarySchema {

    static let version: Int32 = 1

    static let create = """
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

    /// A saved code with neither a pin nor any usage is a leftover.
    static let pruneOrphans = """
    DELETE FROM saved_codes
     WHERE id NOT IN (SELECT saved_code_id FROM pins)
       AND id NOT IN (SELECT saved_code_id FROM usage_events);
    """
}
