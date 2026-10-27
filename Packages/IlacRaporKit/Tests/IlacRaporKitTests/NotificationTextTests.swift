import Foundation
import Testing
@testable import IlacRaporKit

@Suite("NotificationText — Turkish")
struct NotificationTextTests {
    let end = date(2026, 11, 5)

    private func text(_ item: ReminderItem, on d: Date) -> NotificationContent {
        NotificationText.content(for: item, fireDate: d, calendar: istanbul, language: .tr)
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
        #expect(NotificationText.backup(language: .tr) ==
                NotificationContent(title: "Hatırlatmalar devam etsin",
                                    body: "Hatırlatmaların devam etmesi için uygulamayı bir kez aç.", category: .backup))
    }
}

@Suite("NotificationText — English")
struct NotificationTextEnglishTests {
    let end = date(2026, 11, 5)

    private func text(_ item: ReminderItem, on d: Date) -> NotificationContent {
        NotificationText.content(for: item, fireDate: d, calendar: istanbul, language: .en)
    }

    @Test func reportCases() {
        let r = report(1, title: "Blood pressure report", person: "Dad", end: end)
        #expect(text(r, on: date(2026, 10, 28, 10)) ==
                NotificationContent(title: "Blood pressure report ends in 8 days",
                                    body: "For Dad. Remember to book an appointment.", category: .reportReminder))
        #expect(text(r, on: date(2026, 11, 4, 10)).title == "Blood pressure report ends tomorrow")
        #expect(text(r, on: date(2026, 11, 5, 10)).title == "Blood pressure report ends today")
        #expect(text(r, on: date(2026, 11, 8, 10)) ==
                NotificationContent(title: "Blood pressure report: expired",
                                    body: "Ended 3 days ago.", category: .reportReminder))
    }

    @Test func englishSingular() {
        #expect(text(report(1, end: end), on: date(2026, 11, 6, 10)).body == "Ended 1 day ago.")
        #expect(text(medication(2, end: end), on: date(2026, 11, 6, 10)).body == "Ran out 1 day ago.")
    }

    @Test func handledReport() {
        let r = report(1, title: "Blood pressure report", end: end, handledAt: date(2026, 10, 27))
        #expect(text(r, on: date(2026, 10, 30, 10)) ==
                NotificationContent(title: "Blood pressure report: enter the new end date",
                                    body: "If the report is in the system, save the date.", category: .renewalDate))
    }

    @Test func medicationCases() {
        let m = medication(2, end: end)
        #expect(text(m, on: date(2026, 11, 1, 10)) ==
                NotificationContent(title: "Your Beloc runs out in 4 days",
                                    body: "Remember to get a new box from the pharmacy.", category: .medReminder))
        #expect(text(m, on: date(2026, 11, 4, 10)).title == "Your Beloc runs out tomorrow")
        #expect(text(m, on: date(2026, 11, 5, 10)).title == "Your Beloc runs out today")
        #expect(text(m, on: date(2026, 11, 7, 10)) ==
                NotificationContent(title: "Your Beloc has run out", body: "Ran out 2 days ago.", category: .medReminder))
    }

    @Test func emptyPersonHasNoPersonPart() {
        #expect(text(report(1, person: "  ", end: end), on: date(2026, 10, 28, 10)).body
                == "Remember to book an appointment.")
    }

    @Test func backupText() {
        #expect(NotificationText.backup(language: .en) ==
                NotificationContent(title: "Keep your reminders going",
                                    body: "Open the app once to keep your reminders going.", category: .backup))
    }
}
