import Foundation
import SwiftData

extension SchemaV1 {
    /// A medication report (spec 6.2). For CloudKit compatibility: all fields have a default value,
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
        /// Set by "In 3 hours". The planner adds the snooze notification again from this field.
        var snoozeUntil: Date? = nil
        var isArchived: Bool = false
        var notes: String = ""
        var createdAt: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \Medication.report)
        var medications: [Medication]? = []

        init(title: String, personName: String = "", endDate: Date, leadDays: Int = 18, notes: String = "") {
            self.id = UUID()
            self.title = title
            self.personName = personName
            self.endDate = endDate
            self.leadDays = leadDays
            self.notes = notes
            self.createdAt = Date()
        }

        // MARK: - Renewal cycle

        /// "Renewed": the reminders stop and the app waits for the new date.
        func markHandled(at date: Date) {
            isHandled = true
            handledAt = date
        }

        /// The user entered the new end date: a new cycle starts (spec 8.5).
        func renew(newEndDate: Date) {
            endDate = newEndDate
            isHandled = false
            handledAt = nil
            snoozeUntil = nil
        }
    }
}
