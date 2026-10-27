import Foundation
import SwiftData
import MedReportKit

/// A medication report. For CloudKit compatibility: all fields have a default value,
/// the relationship is optional, and there is no `@Attribute(.unique)`.
@Model
final class Report {
    var id: UUID = UUID()
    var title: String = ""
    var personName: String = ""
    /// The end date on the report. The user enters it directly.
    var endDate: Date = Date()
    var leadDays: Int = 18
    var isHandled: Bool = false
    var handledAt: Date? = nil
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \Medication.report)
    var medications: [Medication]? = []

    init(
        title: String,
        personName: String = "",
        endDate: Date,
        leadDays: Int = 18,
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.personName = personName
        self.endDate = endDate
        self.leadDays = leadDays
        self.notes = notes
        self.createdAt = Date()
    }

    // MARK: - Calculated values

    func daysRemaining(now: Date = .now, calendar: Calendar = .current) -> Int {
        ReminderLogic.daysRemaining(until: endDate, now: now, calendar: calendar)
    }

    func reminderState(now: Date = .now, calendar: Calendar = .current) -> ReminderState {
        ReminderLogic.state(endDate: endDate, leadDays: leadDays, isHandled: isHandled, now: now, calendar: calendar)
    }

    // MARK: - Renewal cycle

    /// "Renewed": the reminders stop and the app waits for the new date.
    func markHandled(at date: Date = .now) {
        isHandled = true
        handledAt = date
    }

    /// The user entered the new end date: a new cycle starts.
    func renew(newEndDate: Date) {
        endDate = newEndDate
        isHandled = false
        handledAt = nil
    }
}
