import Foundation
import SwiftData

/// İlaç raporu. CloudKit uyumu için: tüm alanların varsayılan değeri var,
/// ilişki optional, `@Attribute(.unique)` yok.
@Model
final class Report {
    var id: UUID = UUID()
    var title: String = ""
    var personName: String = ""
    /// Raporun üzerindeki bitiş tarihi, kullanıcı doğrudan girer.
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

    // MARK: - Hesaplananlar

    func daysRemaining(now: Date = .now, calendar: Calendar = .current) -> Int {
        ReminderLogic.daysRemaining(until: endDate, now: now, calendar: calendar)
    }

    func reminderState(now: Date = .now, calendar: Calendar = .current) -> ReminderState {
        ReminderLogic.state(endDate: endDate, leadDays: leadDays, isHandled: isHandled, now: now, calendar: calendar)
    }

    // MARK: - Yenileme döngüsü

    /// "Yeniledim": hatırlatmalar durur, yeni tarih beklenir.
    func markHandled(at date: Date = .now) {
        isHandled = true
        handledAt = date
    }

    /// Yeni bitiş tarihi girildi: yeni döngü başlar.
    func renew(newEndDate: Date) {
        endDate = newEndDate
        isHandled = false
        handledAt = nil
    }
}
