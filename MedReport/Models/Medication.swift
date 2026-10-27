import Foundation
import SwiftData
import MedReportKit

extension SchemaV1 {
    /// A medication (spec 6.3). It can have a report or no report.
    @Model
    final class Medication {
        var id: UUID = UUID()
        var name: String = ""
        /// For example "1 in the morning, 1 in the evening". Information only.
        var dosageNote: String = ""
        /// Used only when the medication has no report.
        var personName: String = ""
        /// The last day the user got the medication from the pharmacy (start of day).
        var lastPickupDate: Date = Date()
        /// How many days the supply lasts (28/30/56/60/84/90…).
        var supplyDays: Int = 30
        var leadDays: Int = 7
        var snoozeUntil: Date? = nil
        var isArchived: Bool = false
        var createdAt: Date = Date()

        var report: Report? = nil

        init(
            name: String,
            dosageNote: String = "",
            personName: String = "",
            lastPickupDate: Date,
            supplyDays: Int,
            leadDays: Int,
            report: Report? = nil
        ) {
            self.id = UUID()
            self.name = name
            self.dosageNote = dosageNote
            self.personName = personName
            self.lastPickupDate = lastPickupDate
            self.supplyDays = supplyDays
            self.leadDays = leadDays
            self.report = report
            self.createdAt = Date()
        }

        // MARK: - Calculated values (spec 6.5)

        /// The person name of the report if there is one, else the medication's own person name.
        var effectivePersonName: String {
            report?.personName ?? personName
        }

        /// True if the medication or its report is archived. The medication record does not change.
        var isEffectivelyArchived: Bool {
            isArchived || report?.isArchived == true
        }

        func supplyEndDate(calendar: Calendar) -> Date {
            ReminderLogic.supplyEndDate(lastPickupDate: lastPickupDate, supplyDays: supplyDays, calendar: calendar)
        }

        // MARK: - Renewal cycle

        /// "Picked up": the pickup date becomes today and a new cycle starts.
        func markPickedUp(on date: Date, calendar: Calendar) {
            lastPickupDate = calendar.startOfDay(for: date)
            snoozeUntil = nil
        }
    }
}
