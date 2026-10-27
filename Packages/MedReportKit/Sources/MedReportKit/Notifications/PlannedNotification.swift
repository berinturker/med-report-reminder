import Foundation

/// One local notification that the scheduler adds to iOS.
public struct PlannedNotification: Sendable, Equatable {
    public enum Category: String, Sendable, CaseIterable {
        case reportReminder = "REPORT_REMINDER"
        case medReminder = "MED_REMINDER"
        case renewalDate = "RENEWAL_DATE"
        case backup = "BACKUP"
    }

    public let identifier: String
    public let fireDate: Date
    public let title: String
    public let body: String
    public let category: Category
    /// nil for the backup notification.
    public let itemKind: ReminderItem.Kind?
    /// nil for the backup notification.
    public let itemID: UUID?

    public init(
        identifier: String, fireDate: Date, title: String, body: String,
        category: Category, itemKind: ReminderItem.Kind?, itemID: UUID?
    ) {
        self.identifier = identifier
        self.fireDate = fireDate
        self.title = title
        self.body = body
        self.category = category
        self.itemKind = itemKind
        self.itemID = itemID
    }
}
