import Foundation

/// The language of the user text (spec D10).
/// The app layer selects it; the Domain layer receives it as a parameter.
public enum AppLanguage: String, Sendable, CaseIterable {
    case en, tr

    /// `.tr` if the language code of the first preferred language is "tr" (any case), else `.en`.
    public static func current(preferredLanguages: [String]) -> AppLanguage {
        guard let first = preferredLanguages.first else { return .en }
        let code = first.split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? first
        return code.lowercased() == "tr" ? .tr : .en
    }

    /// Locale for formatting and case rules.
    public var locale: Locale {
        switch self {
        case .en: Locale(identifier: "en_US")
        case .tr: Locale(identifier: "tr_TR")
        }
    }
}
