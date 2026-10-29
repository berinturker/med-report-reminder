import Foundation
import SwiftData
import MedReportKit

/// The draft of the medication form. The medication itself changes only in `apply(to:calendar:)`,
/// so a failed save (which rolls back) never loses what the user typed.
@MainActor @Observable
final class MedicationFormModel {
    static let supplyDaysRange = 1...365
    static let quickSupplyDays = [30, 60, 90]
    static let leadDaysRange = 0...90

    let original: Medication?
    var name: String
    var dosageNote: String
    /// `nil` means "None".
    var report: Report?
    var personName: String
    var lastPickupDate: Date
    var supplyDays: Int
    var leadDays: Int

    init(medication: Medication?, preselectedReport: Report?, defaultLeadDays: Int, now: Date, calendar: Calendar) {
        original = medication
        name = medication?.name ?? ""
        dosageNote = medication?.dosageNote ?? ""
        report = medication == nil ? preselectedReport : medication?.report
        personName = medication?.personName ?? ""
        lastPickupDate = medication?.lastPickupDate ?? calendar.startOfDay(for: now)
        supplyDays = medication?.supplyDays ?? 30
        leadDays = medication?.leadDays ?? defaultLeadDays
    }

    /// The person field is shown only for a medication without a report.
    var showsPersonField: Bool { report == nil }

    var isValid: Bool {
        !PersonNameSuggester.normalize(name).isEmpty
            && Self.supplyDaysRange.contains(supplyDays)
            && Self.leadDaysRange.contains(leadDays)
    }

    func previewEndDate(calendar: Calendar) -> Date {
        ReminderLogic.supplyEndDate(lastPickupDate: lastPickupDate, supplyDays: supplyDays, calendar: calendar)
    }

    func suggestions(from usages: [NameUsage]) -> [String] {
        PersonNameSuggester.suggestions(for: personName, from: usages)
    }

    /// Writes the trimmed values into `original`, or inserts a new Medication into `context`. Does not save.
    @discardableResult
    func apply(to context: ModelContext, calendar: Calendar) -> Medication {
        let name = PersonNameSuggester.normalize(name)
        let person = report == nil ? PersonNameSuggester.normalize(personName) : ""
        let pickup = calendar.startOfDay(for: lastPickupDate)
        if let medication = original {
            medication.name = name
            medication.dosageNote = dosageNote
            medication.personName = person
            medication.report = report
            medication.lastPickupDate = pickup
            medication.supplyDays = supplyDays
            medication.leadDays = leadDays
            return medication
        }
        let medication = Medication(name: name, dosageNote: dosageNote, personName: person, lastPickupDate: pickup,
                                    supplyDays: supplyDays, leadDays: leadDays, report: report)
        context.insert(medication)
        return medication
    }
}
