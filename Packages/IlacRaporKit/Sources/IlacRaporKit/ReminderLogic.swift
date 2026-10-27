import Foundation

/// Gün ve durum hesapları. Hepsi saf fonksiyon: aynı girdi her zaman aynı çıktıyı verir,
/// `now` ve `calendar` dışarıdan verilir, böylece testlerde zaman sabitlenebilir.
///
/// Tüm gün hesapları `Calendar.startOfDay` üzerinden yapılır; saat farkı ve
/// yaz saati geçişleri sonucu değiştirmez.
public enum ReminderLogic {

    // MARK: - Gün hesabı

    /// İki tarih arasındaki takvim günü farkı (saatler yok sayılır).
    /// `to`, `from`'dan sonraysa pozitif, önceyse negatif.
    public static func calendarDays(from: Date, to: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Bitiş tarihine kaç gün kaldı. 0 = bugün bitiyor, negatif = bitiş geçti.
    public static func daysRemaining(until endDate: Date, now: Date, calendar: Calendar) -> Int {
        calendarDays(from: now, to: endDate, calendar: calendar)
    }

    // MARK: - Durum

    public static func state(daysRemaining: Int, leadDays: Int, isHandled: Bool) -> ReminderState {
        if isHandled { return .handled }
        if daysRemaining < 0 { return .overdue }
        if daysRemaining <= max(leadDays, 0) { return .reminding }
        return .normal
    }

    public static func state(endDate: Date, leadDays: Int, isHandled: Bool, now: Date, calendar: Calendar) -> ReminderState {
        let remaining = daysRemaining(until: endDate, now: now, calendar: calendar)
        return state(daysRemaining: remaining, leadDays: leadDays, isHandled: isHandled)
    }

    // MARK: - Tarih türetme

    /// İlaç stoğunun bittiği gün: son alım günü + kaç günlük olduğu.
    public static func supplyEndDate(lastPickupDate: Date, supplyDays: Int, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: lastPickupDate)
        return calendar.date(byAdding: .day, value: supplyDays, to: start) ?? start
    }

    /// Hatırlatmaların başladığı gün: bitiş − leadDays.
    public static func reminderStartDate(endDate: Date, leadDays: Int, calendar: Calendar) -> Date {
        let end = calendar.startOfDay(for: endDate)
        return calendar.date(byAdding: .day, value: -max(leadDays, 0), to: end) ?? end
    }

    /// Rapor yenilenirken önerilen yeni bitiş tarihi: önceki bitiş + 1 yıl.
    /// 29 Şubat → bir sonraki yılın 28 Şubat'ı.
    public static func suggestedRenewalEndDate(previousEndDate: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: previousEndDate)
        return calendar.date(byAdding: .year, value: 1, to: start) ?? start
    }

    // MARK: - Metinler

    /// Satırdaki durum rozeti metni. Durum renkle birlikte metinle de gösterilir (erişilebilirlik).
    public static func statusText(daysRemaining: Int, isHandled: Bool) -> String {
        if isHandled { return "Yeni tarih bekleniyor" }
        switch daysRemaining {
        case ..<0: return "\(-daysRemaining) gün geçti"
        case 0: return "Bugün bitiyor"
        case 1: return "Yarın bitiyor"
        default: return "\(daysRemaining) gün kaldı"
        }
    }
}
