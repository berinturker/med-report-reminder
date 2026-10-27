import Foundation

/// Title, body and category of one notification.
public struct NotificationContent: Sendable, Equatable {
    public let title: String
    public let body: String
    public let category: PlannedNotification.Category

    public init(title: String, body: String, category: PlannedNotification.Category) {
        self.title = title
        self.body = body
        self.category = category
    }
}

/// Notification copy from spec 7.3.
public enum NotificationText {

    /// Text for `item` on `fireDate`. Days are calculated from `fireDate`, not from now.
    public static func content(for item: ReminderItem, fireDate: Date, calendar: Calendar) -> NotificationContent {
        let days = item.daysRemaining(now: fireDate, calendar: calendar)
        switch item.kind {
        case .report: return reportContent(item, days: days)
        case .medication: return medicationContent(item, days: days)
        }
    }

    public static let backup = NotificationContent(
        title: "Hatırlatmalar devam etsin",
        body: "Hatırlatmaların devam etmesi için uygulamayı bir kez aç.",
        category: .backup
    )

    // MARK: - Private

    private static func reportContent(_ item: ReminderItem, days: Int) -> NotificationContent {
        let title = item.title

        if item.isHandled {
            return NotificationContent(
                title: "\(title): yeni bitiş tarihini gir",
                body: "Rapor sisteme işlendiyse tarihi kaydet.",
                category: .renewalDate
            )
        }
        if days < 0 {
            return NotificationContent(
                title: "\(title): süresi doldu",
                body: "\(-days) gün önce bitti.",
                category: .reportReminder
            )
        }

        let person = PersonNameSuggester.normalize(item.personName)
        let body = (person.isEmpty ? "" : "\(person) için. ") + "Randevu almayı unutma."
        return NotificationContent(title: "\(title) \(whenText(days))", body: body, category: .reportReminder)
    }

    private static func medicationContent(_ item: ReminderItem, days: Int) -> NotificationContent {
        let name = item.title

        if days < 0 {
            return NotificationContent(
                title: "\(name) ilacın bitti",
                body: "\(-days) gün önce bitti.",
                category: .medReminder
            )
        }
        return NotificationContent(
            title: "\(name) ilacın \(whenText(days))",
            body: "Eczaneden yenisini almayı unutma.",
            category: .medReminder
        )
    }

    /// For days ≥ 0: "bugün bitiyor", "yarın bitiyor", "N gün sonra bitiyor".
    private static func whenText(_ days: Int) -> String {
        switch days {
        case 0: "bugün bitiyor"
        case 1: "yarın bitiyor"
        default: "\(days) gün sonra bitiyor"
        }
    }
}
