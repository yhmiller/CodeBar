/// Normalizes clinical codes into the form used for prefix search.
///
/// Clinicians type codes inconsistently — `E11.9`, `e119`, `E11-9` all mean the
/// same code — so both stored codes and incoming queries are folded to a single
/// uppercase alphanumeric form before comparison.
public enum CodeNormalizer {

    public static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isLetter || $0.isNumber })
    }

    /// The exclusive upper bound of the range containing every string with
    /// `normalized` as a prefix.
    ///
    /// This is what makes the code-prefix pass an index range scan
    /// (`code_norm >= 'E11' AND code_norm < 'E12'`) rather than a full table
    /// scan. `LIKE 'E11%'` is only index-optimized under specific collation and
    /// pragma conditions, so the range form is used instead.
    ///
    /// Returns `nil` when no bound exists — an empty string, or a final scalar
    /// at the top of its range.
    public static func prefixUpperBound(_ normalized: String) -> String? {
        guard let last = normalized.unicodeScalars.last,
              let incremented = Unicode.Scalar(last.value + 1)
        else { return nil }

        var scalars = normalized.unicodeScalars
        scalars.removeLast()
        scalars.append(incremented)
        return String(scalars)
    }
}
