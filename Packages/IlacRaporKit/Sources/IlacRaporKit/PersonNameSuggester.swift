import Foundation

/// One use of a person name, for example in a report.
public struct NameUsage: Sendable, Equatable {
    public let name: String
    public let usedAt: Date

    public init(name: String, usedAt: Date) {
        self.name = name
        self.usedAt = usedAt
    }
}

/// Uniform person names and suggestions for the "For whom" field (spec 10).
public enum PersonNameSuggester {
    private static let turkish = Locale(identifier: "tr_TR")

    /// Removes whitespace and newlines at the start and at the end.
    public static func normalize(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Unique names that start with `typed`, latest use first.
    /// Comparison uses a loose key (see `foldKey`). A name is hidden only when
    /// `typed` is already its exact saved spelling, so "sukru" still offers "Şükrü".
    public static func suggestions(for typed: String, from usages: [NameUsage]) -> [String] {
        let key = foldKey(typed)
        let typedName = normalize(typed)

        var latest: [String: NameUsage] = [:]
        for usage in usages {
            let name = normalize(usage.name)
            guard !name.isEmpty else { continue }
            let nameKey = foldKey(name)
            if let current = latest[nameKey], current.usedAt >= usage.usedAt { continue }
            latest[nameKey] = NameUsage(name: name, usedAt: usage.usedAt)
        }

        return latest
            .filter { nameKey, usage in nameKey.hasPrefix(key) && usage.name != typedName }
            .map(\.value)
            .sorted { $0.usedAt > $1.usedAt }
            .map(\.name)
    }

    /// Loose key (spec 10): lowercase with Turkish rules ("I" → "ı", "İ" → "i"),
    /// make "ı" the same as "i", then remove diacritics ("ş" → "s", "ü" → "u").
    /// It does not depend on the app language, because the language of a name is not known.
    private static func foldKey(_ text: String) -> String {
        normalize(text)
            .lowercased(with: turkish)
            .replacingOccurrences(of: "ı", with: "i")
            .folding(options: .diacriticInsensitive, locale: turkish)
    }
}
