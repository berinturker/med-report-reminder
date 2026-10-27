import Foundation
import Testing
@testable import IlacRaporKit

@Suite("NotificationPlanner — candidates")
struct NotificationPlannerCandidateTests {
    let now = date(2026, 10, 27, 12)          // after 10:00
    let id1 = uuid(1).uuidString

    private func c(_ item: ReminderItem, now: Date? = nil, settings: PlannerSettings = tenAM,
                   cal: Calendar = istanbul) -> [PlannedNotification] {
        NotificationPlanner.candidates(for: item, now: now ?? self.now, settings: settings, calendar: cal)
    }

    @Test func inWindowStartsTomorrowWhenTimeIsPast() {
        let first = c(report(1, end: date(2026, 11, 5))).first!
        #expect(first.identifier == "report-\(id1)-20261028")
        #expect(first.fireDate == date(2026, 10, 28, 10))
        #expect(first.title == "Tansiyon raporu 8 gün sonra bitiyor")
        #expect(first.category == .reportReminder)
        #expect(first.itemKind == .report)
        #expect(first.itemID == uuid(1))
    }

    @Test func inWindowStartsTodayBeforeTime() {
        let first = c(report(1, end: date(2026, 11, 5)), now: date(2026, 10, 27, 9)).first!
        #expect(first.fireDate == date(2026, 10, 27, 10))
    }

    @Test func fireTimeEqualToNowIsSkipped() {
        let first = c(report(1, end: date(2026, 11, 5)), now: date(2026, 10, 27, 10)).first!
        #expect(first.fireDate == date(2026, 10, 28, 10))
    }

    @Test func normalItemStartsAtReminderStart() {
        let first = c(medication(1, end: date(2026, 12, 26))).first!
        #expect(first.identifier == "med-\(id1)-20261219")
        #expect(first.title == "Beloc ilacın 7 gün sonra bitiyor")
    }

    @Test func dailyAndOverdueContinueTo63() {
        let all = c(report(1, end: date(2026, 11, 5)))
        #expect(all.count == 63)
        #expect(all.last!.fireDate == date(2026, 12, 29, 10))
        #expect(all.last!.title == "Tansiyon raporu: süresi doldu")
    }

    @Test func handledReportEveryThreeDays() {
        let all = c(report(1, end: date(2026, 10, 20), handledAt: date(2026, 10, 27, 12)))
        #expect(all.prefix(3).map(\.identifier) ==
                ["renewal-\(id1)-20261030", "renewal-\(id1)-20261102", "renewal-\(id1)-20261105"])
        #expect(all.allSatisfy { $0.category == .renewalDate })
        #expect(all.count == 63)
    }

    @Test func handledLongAgoSkipsPastDays() {
        let first = c(report(1, end: date(2026, 9, 1), handledAt: date(2026, 10, 1))).first!
        #expect(first.fireDate == date(2026, 10, 28, 10))
    }

    @Test func futureSnoozeIsAdded() {
        let all = c(report(1, end: date(2026, 11, 5), snooze: date(2026, 10, 27, 15)))
        let snooze = all.first { $0.identifier == "snooze-\(id1)" }!
        #expect(snooze.fireDate == date(2026, 10, 27, 15))
        #expect(snooze.title == "Tansiyon raporu 9 gün sonra bitiyor")
        #expect(all.count == 63)
    }

    @Test func pastSnoozeIsIgnored() {
        let all = c(report(1, end: date(2026, 11, 5), snooze: date(2026, 10, 27, 11)))
        #expect(!all.contains { $0.identifier.hasPrefix("snooze-") })
    }

    @Test func nonexistentLocalTimeStillPlansThatDay() {
        let berlin = calendar("Europe/Berlin")
        let all = c(report(1, end: date(2026, 4, 5, in: berlin)),
                    now: date(2026, 3, 20, 12, in: berlin),
                    settings: PlannerSettings(notificationHour: 2, notificationMinute: 30), cal: berlin)
        let dstDay = all.filter { $0.identifier.hasSuffix("-20260329") }
        #expect(dstDay.count == 1)
        #expect(berlin.component(.day, from: dstDay[0].fireDate) == 29)
    }
}
