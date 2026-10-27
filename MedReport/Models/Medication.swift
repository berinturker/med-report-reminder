import Foundation
import SwiftData
import MedReportKit

/// A medication. It can have a report or no report.
@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    /// For example "1 in the morning, 1 in the evening". Information only.
    var dosageNote: String = ""
    /// Used only when the medication has no report. Else the report's person name is used.
    var personName: String = ""
    /// The last day the user got the medication from the pharmacy.
    var lastPickupDate: Date = Date()
    /// How many days the supply lasts (28/30/56/60/84/90…).
    var supplyDays: Int = 30
    var leadDays: Int = 7
    var isHandled: Bool = false
    var createdAt: Date = Date()

    var report: Report? = nil

    init(
        name: String,
        dosageNote: String = "",
        personName: String = "",
        lastPickupDate: Date = .now,
        supplyDays: Int = 30,
        leadDays: Int = 7,
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

    // MARK: - Calculated values

    /// The person name of the report if there is one, else the medication's own person name.
    var effectivePersonName: String {
        report?.personName ?? personName
    }

    func supplyEndDate(calendar: Calendar = .current) -> Date {
        ReminderLogic.supplyEndDate(lastPickupDate: lastPickupDate, supplyDays: supplyDays, calendar: calendar)
    }

    func daysRemaining(now: Date = .now, calendar: Calendar = .current) -> Int {
        ReminderLogic.daysRemaining(until: supplyEndDate(calendar: calendar), now: now, calendar: calendar)
    }

    func reminderState(now: Date = .now, calendar: Calendar = .current) -> ReminderState {
        ReminderLogic.state(
            endDate: supplyEndDate(calendar: calendar),
            leadDays: leadDays,
            isHandled: isHandled,
            now: now,
            calendar: calendar
        )
    }

    // MARK: - Renewal cycle

    /// "Picked up": the pickup date becomes today and a new cycle starts.
    func markPickedUp(on date: Date = .now, calendar: Calendar = .current) {
        lastPickupDate = calendar.startOfDay(for: date)
        isHandled = false
    }
}
