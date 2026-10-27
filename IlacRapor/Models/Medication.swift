import Foundation
import SwiftData

/// İlaç. Bir rapora bağlı olabilir ya da raporsuz olabilir.
@Model
final class Medication {
    var id: UUID = UUID()
    var name: String = ""
    /// "Sabah 1, akşam 1" gibi, sadece bilgi amaçlı.
    var dosageNote: String = ""
    /// Raporsuz ilaçlar için. Rapora bağlıysa raporunki kullanılır.
    var personName: String = ""
    /// Eczaneden en son alındığı gün.
    var lastPickupDate: Date = Date()
    /// Alınan ilaç kaç gün yetiyor (28/30/56/60/84/90…).
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

    // MARK: - Hesaplananlar

    /// Rapora bağlıysa raporun kişisi, değilse ilacın kendi kişisi.
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

    // MARK: - Yenileme döngüsü

    /// "Aldım": alım tarihi bugün olur, döngü kendiliğinden yeniden başlar.
    func markPickedUp(on date: Date = .now, calendar: Calendar = .current) {
        lastPickupDate = calendar.startOfDay(for: date)
        isHandled = false
    }
}
