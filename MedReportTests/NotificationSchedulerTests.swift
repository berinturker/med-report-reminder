import Foundation
import Testing
import UserNotifications
import MedReportKit
@testable import MedReport

@MainActor
@Suite("NotificationScheduler")
struct NotificationSchedulerTests {

    private func fake() -> FakeNotificationCenter { FakeNotificationCenter() }

    private func scheduler(_ center: FakeNotificationCenter, allowed: Bool = false) -> NotificationScheduler {
        NotificationScheduler(center: center, calendar: istanbul, isFastModeAllowed: allowed)
    }

    private func planned(id: String = "report-X-20261030", fire: Date = date(2026, 10, 30, 10)) -> PlannedNotification {
        PlannedNotification(identifier: id, fireDate: fire, title: "T", body: "B", category: .reportReminder,
                            itemKind: .report, itemID: uuid(1))
    }

    @Test func requestHasContentCategoryUserInfoAndCalendarTrigger() {
        let p = PlannedNotification(identifier: "report-X-20261028", fireDate: date(2026, 10, 28, 10),
                                    title: "T", body: "B", category: .reportReminder,
                                    itemKind: .report, itemID: uuid(1))
        let r = scheduler(fake()).request(for: p, now: date(2026, 10, 27, 12), fastMode: false)
        #expect(r.identifier == "report-X-20261028")
        #expect(r.content.title == "T" && r.content.body == "B")
        #expect(r.content.categoryIdentifier == "REPORT_REMINDER")
        #expect(r.content.userInfo["itemKind"] as? String == "report")
        #expect(r.content.userInfo["itemID"] as? String == uuid(1).uuidString)
        let t = r.trigger as! UNCalendarNotificationTrigger
        #expect(t.dateComponents.hour == 10 && t.dateComponents.minute == 0)
        #expect(t.dateComponents.day == 28 && t.dateComponents.month == 10 && t.dateComponents.year == 2026)
        #expect(!t.repeats)
    }

    @Test func backupHasEmptyUserInfo() {
        let p = PlannedNotification(identifier: "backup", fireDate: date(2026, 12, 30, 10), title: "T", body: "B",
                                    category: .backup, itemKind: nil, itemID: nil)
        let r = scheduler(fake()).request(for: p, now: date(2026, 10, 27, 12), fastMode: false)
        #expect(r.content.userInfo.isEmpty)
        #expect(r.content.categoryIdentifier == "BACKUP")
    }

    @Test func fastModeMapsDaysToMinutes() {
        let r = scheduler(fake(), allowed: true).request(for: planned(), now: date(2026, 10, 27, 12), fastMode: true)
        #expect((r.trigger as! UNTimeIntervalNotificationTrigger).timeInterval == 180)
    }

    @Test func fastModeSameDayIsFiveSeconds() {
        let r = scheduler(fake(), allowed: true)
            .request(for: planned(fire: date(2026, 10, 27, 15)), now: date(2026, 10, 27, 12), fastMode: true)
        #expect((r.trigger as! UNTimeIntervalNotificationTrigger).timeInterval == 5)
    }

    @Test func fastModeIsIgnoredWhenNotAllowed() {
        let r = scheduler(fake(), allowed: false).request(for: planned(), now: date(2026, 10, 27, 12), fastMode: true)
        #expect(r.trigger is UNCalendarNotificationTrigger)
    }

    @Test func replaceAllRemovesThenAdds() async {
        let f = fake()
        f.added = [UNNotificationRequest(identifier: "old", content: UNMutableNotificationContent(), trigger: nil)]
        await scheduler(f).replaceAll(with: [planned(id: "a"), planned(id: "b")], now: date(2026, 10, 27), fastMode: false)
        #expect(f.removeAllCount == 1)
        #expect(f.added.map(\.identifier) == ["a", "b"])
    }

    @Test func addFailureDoesNotStopOtherRequests() async {
        let f = fake(); f.failingIdentifiers = ["a"]
        await scheduler(f).replaceAll(with: [planned(id: "a"), planned(id: "b")], now: date(2026, 10, 27), fastMode: false)
        #expect(f.added.map(\.identifier) == ["b"])
    }

    @Test func categoriesHaveSpecButtons() {
        let cats = NotificationCategories.all(language: .tr)
        #expect(Set(cats.map(\.identifier)) == ["REPORT_REMINDER", "MED_REMINDER", "RENEWAL_DATE", "BACKUP"])
        let report = cats.first { $0.identifier == "REPORT_REMINDER" }!
        #expect(report.actions.map(\.identifier) == ["RENEWED", "SNOOZE"])
        #expect(report.actions.map(\.title) == ["Yeniledim", "3 saat sonra"])
        #expect(report.actions.allSatisfy { $0.options.isEmpty })
        let med = cats.first { $0.identifier == "MED_REMINDER" }!
        #expect(med.actions.map(\.identifier) == ["PICKED_UP", "SNOOZE"])
        #expect(med.actions.map(\.title) == ["Aldım", "3 saat sonra"])
        #expect(cats.first { $0.identifier == "RENEWAL_DATE" }!.actions.isEmpty)
        #expect(cats.first { $0.identifier == "BACKUP" }!.actions.isEmpty)
        let en = NotificationCategories.all(language: .en)
        #expect(en.first { $0.identifier == "REPORT_REMINDER" }!.actions.map(\.title) == ["Renewed", "In 3 hours"])
        #expect(en.first { $0.identifier == "MED_REMINDER" }!.actions.map(\.title) == ["Picked up", "In 3 hours"])
    }
}
