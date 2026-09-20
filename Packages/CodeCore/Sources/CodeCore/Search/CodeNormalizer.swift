public enum CodeNormalizer {

    public static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isLetter || $0.isNumber })
    }

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
