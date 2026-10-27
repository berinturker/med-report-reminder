import Foundation
import SwiftData
import Testing
import UserNotifications
import MedReportKit
@testable import MedReport

@MainActor
@Suite("NotificationActionHandler")
struct NotificationActionHandlerTests {

    private struct Env {
        let container: ModelContainer
        let center: FakeNotificationCenter
        let router: NavigationRouter
        let handler: NotificationActionHandler
    }

    private func make() throws -> Env {
        let container = try makeContainer()
        let center = FakeNotificationCenter()
        let settings = AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let scheduler = NotificationScheduler(center: center, calendar: istanbul, isFastModeAllowed: false)
        let sync = ReminderSync(container: container, settings: settings, scheduler: scheduler, language: { .tr })
        let router = NavigationRouter()
        return Env(container: container, center: center, router: router,
                   handler: NotificationActionHandler(container: container, sync: sync, router: router))
    }

    private func info(_ kind: String, _ id: UUID) -> [AnyHashable: Any] {
        ["itemKind": kind, "itemID": id.uuidString]
    }

    @Test func renewedMarksReportHandledAndSyncs() async throws {
        let env = try make()
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        env.container.mainContext.insert(r)
        try env.container.mainContext.save()
        let now = date(2026, 10, 27, 12)

        await env.handler.handle(actionIdentifier: "RENEWED", userInfo: info("report", r.id), now: now, calendar: istanbul)

        #expect(r.isHandled && r.handledAt == now)
        #expect(env.center.removeAllCount == 1)
        let ids = env.center.added.map(\.identifier)
        #expect(ids.dropLast().allSatisfy { $0.hasPrefix("renewal-\(r.id.uuidString)-") })
        #expect(ids.first == "renewal-\(r.id.uuidString)-20261030")
        #expect(ids.last == "backup")
    }

    @Test func pickedUpResetsSupply() async throws {
        let env = try make()
        let m = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        env.container.mainContext.insert(m)
        try env.container.mainContext.save()

        await env.handler.handle(actionIdentifier: "PICKED_UP", userInfo: info("medication", m.id),
                                 now: date(2026, 10, 27, 18), calendar: istanbul)

        #expect(m.lastPickupDate == istanbul.startOfDay(for: date(2026, 10, 27)))
        #expect(env.center.added.first?.identifier == "med-\(m.id.uuidString)-20261119")
    }

    @Test func secondSnoozeReplacesFirst() async throws {
        let env = try make()
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        env.container.mainContext.insert(r)
        try env.container.mainContext.save()

        await env.handler.handle(actionIdentifier: "SNOOZE", userInfo: info("report", r.id),
                                 now: date(2026, 10, 27, 12), calendar: istanbul)
        await env.handler.handle(actionIdentifier: "SNOOZE", userInfo: info("report", r.id),
                                 now: date(2026, 10, 27, 13), calendar: istanbul)

        #expect(r.snoozeUntil == date(2026, 10, 27, 16))
        let snoozes = env.center.added.filter { $0.identifier.hasPrefix("snooze-") }
        #expect(snoozes.count == 1)
        #expect((snoozes.first?.trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour == 16)
    }

    @Test func renewedClearsSnooze() async throws {
        let env = try make()
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        r.snoozeUntil = date(2026, 10, 27, 15)
        env.container.mainContext.insert(r)
        try env.container.mainContext.save()

        await env.handler.handle(actionIdentifier: "RENEWED", userInfo: info("report", r.id),
                                 now: date(2026, 10, 27, 12), calendar: istanbul)

        #expect(r.snoozeUntil == nil)
        #expect(!env.center.added.contains { $0.identifier.hasPrefix("snooze-") })
    }

    @Test func actionForDeletedItemOnlySyncs() async throws {
        let env = try make()
        await env.handler.handle(actionIdentifier: "RENEWED", userInfo: info("report", uuid(99)),
                                 now: date(2026, 10, 27, 12), calendar: istanbul)
        await env.handler.handle(actionIdentifier: "RENEWED", userInfo: [:],
                                 now: date(2026, 10, 27, 12), calendar: istanbul)
        #expect(env.center.removeAllCount == 2)
    }

    @Test func tapRoutes() throws {
        let env = try make()
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        let linked = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: r)
        let standalone = Medication(name: "Parol", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        env.container.mainContext.insert(r)
        env.container.mainContext.insert(linked)
        env.container.mainContext.insert(standalone)
        try env.container.mainContext.save()

        env.handler.handleTap(categoryIdentifier: "REPORT_REMINDER", userInfo: info("report", r.id))
        #expect(env.router.pending == .reportDetail(r.id))
        env.handler.handleTap(categoryIdentifier: "MED_REMINDER", userInfo: info("medication", linked.id))
        #expect(env.router.pending == .reportDetail(r.id))
        env.handler.handleTap(categoryIdentifier: "MED_REMINDER", userInfo: info("medication", standalone.id))
        #expect(env.router.pending == .medicationForm(standalone.id))
        env.handler.handleTap(categoryIdentifier: "RENEWAL_DATE", userInfo: info("report", r.id))
        #expect(env.router.pending == .renewal(r.id))
        env.handler.handleTap(categoryIdentifier: "BACKUP", userInfo: [:])
        #expect(env.router.pending == .home)
    }
}
