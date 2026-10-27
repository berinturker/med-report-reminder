import Foundation
import Testing
@testable import MedReportKit

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
                    settings: PlannerSettings(notificationHour: 2, notificationMinute: 30, language: .tr), cal: berlin)
        let dstDay = all.filter { $0.identifier.hasSuffix("-20260329") }
        #expect(dstDay.count == 1)
        #expect(berlin.component(.day, from: dstDay[0].fireDate) == 29)
    }
}

@Suite("NotificationPlanner — plan")
struct NotificationPlannerPlanTests {
    let now = date(2026, 10, 27, 12)

    private func p(_ items: [ReminderItem]) -> [PlannedNotification] {
        NotificationPlanner.plan(items: items, now: now, settings: tenAM, calendar: istanbul)
    }

    @Test func noItemsNoBackup() {
        #expect(p([]).isEmpty)
    }

    @Test func singleItemIs63PlusBackup() {
        let all = p([report(1, end: date(2026, 11, 5))])
        #expect(all.count == 64)
        #expect(all.last!.identifier == "backup")
        #expect(all.last!.fireDate == date(2026, 12, 30, 10))
        #expect(all.last!.category == .backup)
        #expect(all.last!.itemID == nil)
    }

    @Test func tenItemsNeverAbove64() {
        let items = (1...10).map { report($0, end: date(2026, 10, 20)) }
        let all = p(items)
        #expect(all.count == 64)
        #expect(zip(all, all.dropFirst()).allSatisfy { $0.fireDate <= $1.fireDate })
        #expect(all.prefix(10).allSatisfy { $0.fireDate == date(2026, 10, 28, 10) })
    }

    @Test func seventyItemsKeepEarliest() {
        let items = (1...70).map { report($0, end: date(2026, 10, 20)) }
        let all = p(items)
        #expect(all.count == 64)
        #expect(all.prefix(63).allSatisfy { $0.fireDate == date(2026, 10, 28, 10) })
        #expect(all.last!.fireDate == date(2026, 10, 29, 10))
    }

    @Test func overdueComesFirstOnSameDate() {
        let reminding = medication(1, end: date(2026, 11, 1))      // reminding on 28 Oct
        let overdue = report(2, end: date(2026, 10, 20))           // overdue on 28 Oct
        let all = p([reminding, overdue])
        #expect(all[0].itemID == uuid(2))
        #expect(all[1].itemID == uuid(1))
    }

    @Test func samePrioritySortsByIdentifier() {
        let all = p([report(2, end: date(2026, 10, 20)), report(1, end: date(2026, 10, 20))])
        #expect(all[0].itemID == uuid(1))
        #expect(all[1].itemID == uuid(2))
    }

    @Test func snoozeStaysAfterReplan() {
        let all = p([report(1, end: date(2026, 11, 5), snooze: date(2026, 10, 27, 15))])
        #expect(all.first!.identifier == "snooze-\(uuid(1).uuidString)")
    }

    @Test func planUsesSettingsLanguage() {
        var english = tenAM
        english.language = .en
        let item = report(1, title: "Blood pressure report", end: date(2026, 11, 5))
        let tr = NotificationPlanner.plan(items: [item], now: now, settings: tenAM, calendar: istanbul)
        let en = NotificationPlanner.plan(items: [item], now: now, settings: english, calendar: istanbul)
        #expect(tr.first!.title == "Blood pressure report 8 gün sonra bitiyor")
        #expect(en.first!.title == "Blood pressure report ends in 8 days")
        #expect(en.last!.title == "Keep your reminders going")
        #expect(tr.map(\.identifier) == en.map(\.identifier))
    }
}

@Suite("NotificationPlanner — invalid settings")
struct NotificationPlannerInvalidSettingsTests {
    @Test func outOfRangeTimeIsClampedAndTerminates() {
        let settings = PlannerSettings(notificationHour: 24, notificationMinute: 60, language: .tr)
        let all = NotificationPlanner.plan(items: [report(1, end: date(2026, 11, 5))],
                                           now: date(2026, 10, 27, 12), settings: settings, calendar: istanbul)
        #expect(all.count == 64)
        #expect(all.first!.fireDate == date(2026, 10, 27, 23, 59))
    }

    @Test func negativeTimeIsClamped() {
        let settings = PlannerSettings(notificationHour: -1, notificationMinute: -5, language: .tr)
        let first = NotificationPlanner.plan(items: [report(1, end: date(2026, 11, 5))],
                                             now: date(2026, 10, 27, 12), settings: settings, calendar: istanbul).first!
        #expect(first.fireDate == date(2026, 10, 28, 0, 0))
    }
}
