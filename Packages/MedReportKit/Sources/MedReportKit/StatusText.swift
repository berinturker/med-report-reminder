import Foundation

/// The status badge text (spec 6.6). The badge shows the state with text, not only with color.
public enum StatusText {

    public static func text(daysRemaining: Int, isHandled: Bool, language: AppLanguage) -> String {
        switch language {
        case .en: english(daysRemaining: daysRemaining, isHandled: isHandled)
        case .tr: turkish(daysRemaining: daysRemaining, isHandled: isHandled)
        }
    }

    private static func english(daysRemaining: Int, isHandled: Bool) -> String {
        if isHandled { return "Waiting for new date" }
        switch daysRemaining {
        case -1: return "1 day overdue"
        case ..<0: return "\(-daysRemaining) days overdue"
        case 0: return "Ends today"
        case 1: return "Ends tomorrow"
        default: return "\(daysRemaining) days left"
        }
    }

    private static func turkish(daysRemaining: Int, isHandled: Bool) -> String {
        if isHandled { return "Yeni tarih bekleniyor" }
        switch daysRemaining {
        case ..<0: return "\(-daysRemaining) gün geçti"
        case 0: return "Bugün bitiyor"
        case 1: return "Yarın bitiyor"
        default: return "\(daysRemaining) gün kaldı"
        }
    }
}
