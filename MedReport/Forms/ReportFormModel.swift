import Foundation
import SwiftData
import MedReportKit

/// The draft of the report form. The report itself changes only in `apply(to:)`,
/// so a failed save (which rolls back) never loses what the user typed.
@MainActor @Observable
final class ReportFormModel {
    static let leadDaysRange = 0...90

    let original: Report?
    var title: String
    var personName: String
    var endDate: Date
    var leadDays: Int
    var notes: String

    init(report: Report?, defaultLeadDays: Int, now: Date, calendar: Calendar) {
        original = report
        title = report?.title ?? ""
        personName = report?.personName ?? ""
        endDate = report?.endDate ?? calendar.startOfDay(for: now)
        leadDays = report?.leadDays ?? defaultLeadDays
        notes = report?.notes ?? ""
    }

    var isValid: Bool {
        !PersonNameSuggester.normalize(title).isEmpty && Self.leadDaysRange.contains(leadDays)
    }

    func endDateIsPast(now: Date, calendar: Calendar) -> Bool {
        ReminderLogic.daysRemaining(until: endDate, now: now, calendar: calendar) < 0
    }

    func suggestions(from usages: [NameUsage]) -> [String] {
        PersonNameSuggester.suggestions(for: personName, from: usages)
    }

    /// Writes the trimmed values into `original`, or inserts a new Report into `context`. Does not save.
    @discardableResult
    func apply(to context: ModelContext) -> Report {
        let title = PersonNameSuggester.normalize(title)
        let person = PersonNameSuggester.normalize(personName)
        if let report = original {
            report.title = title
            report.personName = person
            if report.isHandled && report.endDate != endDate {
                // A new end date on a handled report is the renewal: a new cycle starts (spec 8.5).
                report.renew(newEndDate: endDate)
            } else {
                report.endDate = endDate
            }
            report.leadDays = leadDays
            report.notes = notes
            return report
        }
        let report = Report(title: title, personName: person, endDate: endDate, leadDays: leadDays, notes: notes)
        context.insert(report)
        return report
    }
}
