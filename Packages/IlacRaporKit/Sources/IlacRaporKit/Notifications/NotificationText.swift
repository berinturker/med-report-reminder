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

/// Notification copy from spec 7.3, in English and Turkish.
public enum NotificationText {

    /// Text for `item` on `fireDate`. Days are calculated from `fireDate`, not from now.
    public static func content(
        for item: ReminderItem, fireDate: Date, calendar: Calendar, language: AppLanguage
    ) -> NotificationContent {
        let days = item.daysRemaining(now: fireDate, calendar: calendar)
        let person = PersonNameSuggester.normalize(item.personName)
        let table = strings(for: language)

        switch item.kind {
        case .report:
            if item.isHandled {
                return NotificationContent(title: table.reportHandledTitle(item.title),
                                           body: table.reportHandledBody, category: .renewalDate)
            }
            if days < 0 {
                return NotificationContent(title: table.reportOverdueTitle(item.title),
                                           body: table.reportOverdueBody(-days), category: .reportReminder)
            }
            return NotificationContent(title: table.reportTitle(item.title, days),
                                       body: table.reportBody(person), category: .reportReminder)

        case .medication:
            if days < 0 {
                return NotificationContent(title: table.medicationOverdueTitle(item.title),
                                           body: table.medicationOverdueBody(-days), category: .medReminder)
            }
            return NotificationContent(title: table.medicationTitle(item.title, days),
                                       body: table.medicationBody, category: .medReminder)
        }
    }

    public static func backup(language: AppLanguage) -> NotificationContent {
        let table = strings(for: language)
        return NotificationContent(title: table.backupTitle, body: table.backupBody, category: .backup)
    }

    // MARK: - Tables

    /// One language's copy. `days` is always ≥ 0 for the non-overdue texts and > 0 for the overdue texts.
    private struct Strings: Sendable {
        let reportTitle: @Sendable (_ title: String, _ days: Int) -> String
        let reportBody: @Sendable (_ person: String) -> String
        let reportOverdueTitle: @Sendable (_ title: String) -> String
        let reportOverdueBody: @Sendable (_ daysAgo: Int) -> String
        let reportHandledTitle: @Sendable (_ title: String) -> String
        let reportHandledBody: String
        let medicationTitle: @Sendable (_ name: String, _ days: Int) -> String
        let medicationBody: String
        let medicationOverdueTitle: @Sendable (_ name: String) -> String
        let medicationOverdueBody: @Sendable (_ daysAgo: Int) -> String
        let backupTitle: String
        let backupBody: String
    }

    private static func strings(for language: AppLanguage) -> Strings {
        switch language {
        case .en: english
        case .tr: turkish
        }
    }

    private static let english = Strings(
        reportTitle: { title, days in
            switch days {
            case 0: "\(title) ends today"
            case 1: "\(title) ends tomorrow"
            default: "\(title) ends in \(days) days"
            }
        },
        reportBody: { person in
            (person.isEmpty ? "" : "For \(person). ") + "Remember to book an appointment."
        },
        reportOverdueTitle: { title in "\(title): expired" },
        reportOverdueBody: { n in n == 1 ? "Ended 1 day ago." : "Ended \(n) days ago." },
        reportHandledTitle: { title in "\(title): enter the new end date" },
        reportHandledBody: "If the report is in the system, save the date.",
        medicationTitle: { name, days in
            switch days {
            case 0: "Your \(name) runs out today"
            case 1: "Your \(name) runs out tomorrow"
            default: "Your \(name) runs out in \(days) days"
            }
        },
        medicationBody: "Remember to get a new box from the pharmacy.",
        medicationOverdueTitle: { name in "Your \(name) has run out" },
        medicationOverdueBody: { n in n == 1 ? "Ran out 1 day ago." : "Ran out \(n) days ago." },
        backupTitle: "Keep your reminders going",
        backupBody: "Open the app once to keep your reminders going."
    )

    private static let turkish = Strings(
        reportTitle: { title, days in
            switch days {
            case 0: "\(title) bugün bitiyor"
            case 1: "\(title) yarın bitiyor"
            default: "\(title) \(days) gün sonra bitiyor"
            }
        },
        reportBody: { person in
            (person.isEmpty ? "" : "\(person) için. ") + "Randevu almayı unutma."
        },
        reportOverdueTitle: { title in "\(title): süresi doldu" },
        reportOverdueBody: { n in "\(n) gün önce bitti." },
        reportHandledTitle: { title in "\(title): yeni bitiş tarihini gir" },
        reportHandledBody: "Rapor sisteme işlendiyse tarihi kaydet.",
        medicationTitle: { name, days in
            switch days {
            case 0: "\(name) ilacın bugün bitiyor"
            case 1: "\(name) ilacın yarın bitiyor"
            default: "\(name) ilacın \(days) gün sonra bitiyor"
            }
        },
        medicationBody: "Eczaneden yenisini almayı unutma.",
        medicationOverdueTitle: { name in "\(name) ilacın bitti" },
        medicationOverdueBody: { n in "\(n) gün önce bitti." },
        backupTitle: "Hatırlatmalar devam etsin",
        backupBody: "Hatırlatmaların devam etmesi için uygulamayı bir kez aç."
    )
}
