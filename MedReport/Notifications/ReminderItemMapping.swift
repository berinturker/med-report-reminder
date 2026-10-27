import Foundation
import MedReportKit

/// Maps the SwiftData models to the Domain value type (spec 5.4 step 2).
extension ReminderItem {
    init(report: Report) {
        self.init(kind: .report, id: report.id, title: report.title, personName: report.personName,
                  endDate: report.endDate, leadDays: report.leadDays, isHandled: report.isHandled,
                  handledAt: report.handledAt, snoozeUntil: report.snoozeUntil)
    }

    init(medication: Medication, calendar: Calendar) {
        self.init(kind: .medication, id: medication.id, title: medication.name,
                  personName: medication.effectivePersonName,
                  endDate: medication.supplyEndDate(calendar: calendar), leadDays: medication.leadDays,
                  isHandled: false, handledAt: nil, snoozeUntil: medication.snoozeUntil)
    }

    /// Items that are not archived: reports with `isArchived` false and
    /// medications with `isEffectivelyArchived` false (spec 6.5).
    static func active(reports: [Report], medications: [Medication], calendar: Calendar) -> [ReminderItem] {
        reports.filter { !$0.isArchived }.map { ReminderItem(report: $0) }
            + medications.filter { !$0.isEffectivelyArchived }.map { ReminderItem(medication: $0, calendar: calendar) }
    }
}
