import Foundation
import Testing
@testable import IlacRapor

// MARK: - Yardımcılar

private func calendar(_ timeZone: String = "Europe/Istanbul") -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: timeZone)!
    return cal
}

private func date(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int = 12, _ minute: Int = 0,
    in cal: Calendar = calendar()
) -> Date {
    cal.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

// MARK: - Gün hesabı

@Suite("Gün hesabı")
struct DayCountTests {
    let cal = calendar()

    @Test("Aynı gün, farklı saat → 0")
    func sameDayDifferentHours() {
        let now = date(2026, 10, 27, 23, 50)
        let end = date(2026, 10, 27, 0, 5)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: cal) == 0)
    }

    @Test("Gece yarısı geçişi: 23:59 → ertesi gün 00:00 = 1 gün")
    func midnightCrossing() {
        let now = date(2026, 10, 27, 23, 59)
        let end = date(2026, 10, 28, 0, 0)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: cal) == 1)
    }

    @Test("Geçmiş tarih → negatif")
    func pastDateIsNegative() {
        let now = date(2026, 10, 27)
        let end = date(2026, 10, 24)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: cal) == -3)
    }

    @Test("Yaz saati geçişi sonucu bozmaz (Berlin, 29 Mart 2026)")
    func daylightSavingTransition() {
        let berlin = calendar("Europe/Berlin")
        let now = date(2026, 3, 28, 23, 30, in: berlin)
        let end = date(2026, 3, 30, 0, 30, in: berlin)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: berlin) == 2)
    }

    @Test("Yıl geçişi")
    func yearBoundary() {
        let now = date(2026, 12, 31)
        let end = date(2027, 1, 18)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: cal) == 18)
    }
}

// MARK: - Durum

@Suite("Hatırlatma durumu")
struct StateTests {

    @Test("Bitiş bugün → reminding")
    func endsToday() {
        #expect(ReminderLogic.state(daysRemaining: 0, leadDays: 18, isHandled: false) == .reminding)
    }

    @Test("Bitiş geçmiş → overdue")
    func pastEndIsOverdue() {
        #expect(ReminderLogic.state(daysRemaining: -1, leadDays: 18, isHandled: false) == .overdue)
    }

    @Test("Sınır: kalan == leadDays → reminding, leadDays+1 → normal")
    func leadDaysBoundary() {
        #expect(ReminderLogic.state(daysRemaining: 18, leadDays: 18, isHandled: false) == .reminding)
        #expect(ReminderLogic.state(daysRemaining: 19, leadDays: 18, isHandled: false) == .normal)
    }

    @Test("leadDays kalan günden büyük → kayıttan itibaren hatırlatır")
    func leadDaysLargerThanRemaining() {
        #expect(ReminderLogic.state(daysRemaining: 5, leadDays: 18, isHandled: false) == .reminding)
    }

    @Test("handled her şeyi ezer, gecikmiş olsa bile")
    func handledOverridesOverdue() {
        #expect(ReminderLogic.state(daysRemaining: -10, leadDays: 18, isHandled: true) == .handled)
        #expect(ReminderLogic.state(daysRemaining: 100, leadDays: 18, isHandled: true) == .handled)
    }

    @Test("Negatif leadDays sıfır gibi davranır")
    func negativeLeadDays() {
        #expect(ReminderLogic.state(daysRemaining: 0, leadDays: -5, isHandled: false) == .reminding)
        #expect(ReminderLogic.state(daysRemaining: 1, leadDays: -5, isHandled: false) == .normal)
    }

    @Test("Sıralama önceliği: overdue < reminding < handled < normal")
    func sortPriority() {
        let sorted = ReminderState.allCases.sorted { $0.sortPriority < $1.sortPriority }
        #expect(sorted == [.overdue, .reminding, .handled, .normal])
    }
}

// MARK: - Tarih türetme

@Suite("Tarih türetme")
struct DerivedDateTests {
    let cal = calendar()

    @Test("Stok bitişi = alım + gün sayısı, saat sıfırlanır")
    func supplyEnd() {
        let end = ReminderLogic.supplyEndDate(lastPickupDate: date(2026, 1, 1, 17, 45), supplyDays: 30, calendar: cal)
        #expect(end == date(2026, 1, 31, 0, 0))
    }

    @Test("Stok bitişi şubatı doğru geçer")
    func supplyEndAcrossFebruary() {
        let end = ReminderLogic.supplyEndDate(lastPickupDate: date(2027, 2, 1), supplyDays: 30, calendar: cal)
        #expect(end == date(2027, 3, 3, 0, 0))
    }

    @Test("Hatırlatma başlangıcı = bitiş − leadDays")
    func reminderStart() {
        let start = ReminderLogic.reminderStartDate(endDate: date(2026, 3, 20), leadDays: 18, calendar: cal)
        #expect(start == date(2026, 3, 2, 0, 0))
    }

    @Test("Yenileme önerisi: +1 yıl")
    func renewalSuggestion() {
        let next = ReminderLogic.suggestedRenewalEndDate(previousEndDate: date(2026, 11, 14), calendar: cal)
        #expect(next == date(2027, 11, 14, 0, 0))
    }

    @Test("Yenileme önerisi: 29 Şubat → 28 Şubat")
    func renewalSuggestionLeapDay() {
        let next = ReminderLogic.suggestedRenewalEndDate(previousEndDate: date(2028, 2, 29), calendar: cal)
        #expect(next == date(2029, 2, 28, 0, 0))
    }
}

// MARK: - Metinler

@Suite("Durum metni")
struct StatusTextTests {

    @Test(arguments: zip(
        [12, 2, 1, 0, -1, -3],
        ["12 gün kaldı", "2 gün kaldı", "Yarın bitiyor", "Bugün bitiyor", "1 gün geçti", "3 gün geçti"]
    ))
    func text(days: Int, expected: String) {
        #expect(ReminderLogic.statusText(daysRemaining: days, isHandled: false) == expected)
    }

    @Test("handled → Yeni tarih bekleniyor")
    func handledText() {
        #expect(ReminderLogic.statusText(daysRemaining: -5, isHandled: true) == "Yeni tarih bekleniyor")
    }
}
