import Foundation
import MedReportKit

/// What the Home screen shows, computed from the stored reports and medications.
struct HomeSections {
    let summary: HomeSummary
    /// Not archived, by end date, then title, then creation date.
    let reports: [Report]
    /// No report, not archived, by supply end, then name, then creation date.
    let unlinkedMedications: [Medication]
    let archivedReports: [Report]
    /// No report and archived, by supply end.
    let archivedMedications: [Medication]

    var archiveCount: Int { archivedReports.count + archivedMedications.count }

    static func make(reports: [Report], medications: [Medication], now: Date, calendar: Calendar) -> HomeSections {
        let items = ReminderItem.active(reports: reports, medications: medications, calendar: calendar)
        let supplyEnd = { (m: Medication) in m.supplyEndDate(calendar: calendar) }
        let unlinked = medications.filter { $0.report == nil }
        return HomeSections(
            summary: HomeSummary.make(items: items, now: now, calendar: calendar),
            reports: reports.filter { !$0.isArchived }.sorted {
                ($0.endDate, $0.title, $0.createdAt) < ($1.endDate, $1.title, $1.createdAt)
            },
            unlinkedMedications: unlinked.filter { !$0.isArchived }.sorted {
                (supplyEnd($0), $0.name, $0.createdAt) < (supplyEnd($1), $1.name, $1.createdAt)
            },
            archivedReports: reports.filter(\.isArchived).sorted { $0.endDate < $1.endDate },
            archivedMedications: unlinked.filter(\.isArchived).sorted { supplyEnd($0) < supplyEnd($1) })
    }
}
