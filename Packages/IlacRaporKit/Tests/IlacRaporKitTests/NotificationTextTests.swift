import Foundation
import Testing
@testable import IlacRaporKit

@Suite("NotificationText")
struct NotificationTextTests {
    let end = date(2026, 11, 5)

    private func text(_ item: ReminderItem, on d: Date) -> NotificationContent {
        NotificationText.content(for: item, fireDate: d, calendar: istanbul)
    }

    @Test func reportDaysUseFireDate() {
        let r = report(1, end: end)
        #expect(text(r, on: date(2026, 10, 28, 10)) ==
                NotificationContent(title: "Tansiyon raporu 8 gün sonra bitiyor",
                                    body: "Babam için. Randevu almayı unutma.", category: .reportReminder))
        #expect(text(r, on: date(2026, 11, 4, 10)).title == "Tansiyon raporu yarın bitiyor")
        #expect(text(r, on: date(2026, 11, 5, 10)).title == "Tansiyon raporu bugün bitiyor")
    }

    @Test func reportOverdue() {
        #expect(text(report(1, end: end), on: date(2026, 11, 8, 10)) ==
                NotificationContent(title: "Tansiyon raporu: süresi doldu",
                                    body: "3 gün önce bitti.", category: .reportReminder))
    }

    @Test func handledReport() {
        let r = report(1, end: end, handledAt: date(2026, 10, 27))
        #expect(text(r, on: date(2026, 10, 30, 10)) ==
                NotificationContent(title: "Tansiyon raporu: yeni bitiş tarihini gir",
                                    body: "Rapor sisteme işlendiyse tarihi kaydet.", category: .renewalDate))
    }

    @Test func medicationCases() {
        let m = medication(2, end: end)
        #expect(text(m, on: date(2026, 11, 1, 10)) ==
                NotificationContent(title: "Beloc ilacın 4 gün sonra bitiyor",
                                    body: "Eczaneden yenisini almayı unutma.", category: .medReminder))
        #expect(text(m, on: date(2026, 11, 4, 10)).title == "Beloc ilacın yarın bitiyor")
        #expect(text(m, on: date(2026, 11, 5, 10)).title == "Beloc ilacın bugün bitiyor")
        #expect(text(m, on: date(2026, 11, 7, 10)) ==
                NotificationContent(title: "Beloc ilacın bitti", body: "2 gün önce bitti.", category: .medReminder))
    }

    @Test func emptyPersonHasNoPersonPart() {
        #expect(text(report(1, person: "", end: end), on: date(2026, 10, 28, 10)).body == "Randevu almayı unutma.")
    }

    @Test func whitespacePersonIsEmpty() {
        #expect(text(report(1, person: "   ", end: end), on: date(2026, 10, 28, 10)).body == "Randevu almayı unutma.")
    }

    @Test func backupText() {
        #expect(NotificationText.backup ==
                NotificationContent(title: "Hatırlatmalar devam etsin",
                                    body: "Hatırlatmaların devam etmesi için uygulamayı bir kez aç.", category: .backup))
    }
}
