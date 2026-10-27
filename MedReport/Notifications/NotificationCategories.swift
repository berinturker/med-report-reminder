import Foundation
import UserNotifications
import MedReportKit

/// Notification button identifiers (spec 8.2).
enum NotificationAction: String, Sendable {
    case renewed = "RENEWED"
    case pickedUp = "PICKED_UP"
    case snooze = "SNOOZE"
}

/// Keys in `UNNotificationContent.userInfo` (spec 7.5).
enum NotificationUserInfoKey {
    static let kind = "itemKind"
    static let id = "itemID"
}

/// The four notification categories and their buttons (spec 7.6, 8.2).
/// The buttons have no options: the app does the action in the background,
/// and the user can press them on the lock screen.
enum NotificationCategories {
    static func all(language: AppLanguage) -> Set<UNNotificationCategory> {
        let renewed = action(.renewed, en: "Renewed", tr: "Yeniledim", language: language)
        let pickedUp = action(.pickedUp, en: "Picked up", tr: "Aldım", language: language)
        let snooze = action(.snooze, en: "In 3 hours", tr: "3 saat sonra", language: language)
        return [
            category(.reportReminder, actions: [renewed, snooze]),
            category(.medReminder, actions: [pickedUp, snooze]),
            category(.renewalDate, actions: []),
            category(.backup, actions: []),
        ]
    }

    private static func action(_ id: NotificationAction, en: String, tr: String,
                               language: AppLanguage) -> UNNotificationAction {
        UNNotificationAction(identifier: id.rawValue, title: language == .tr ? tr : en, options: [])
    }

    private static func category(_ id: PlannedNotification.Category,
                                 actions: [UNNotificationAction]) -> UNNotificationCategory {
        UNNotificationCategory(identifier: id.rawValue, actions: actions, intentIdentifiers: [], options: [])
    }
}
