import Foundation
import SwiftData
import Testing
import MedReportKit
@testable import MedReport

@MainActor
@Suite("Renewal")
struct RenewalTests {
    @Test func renewalDefaultIsOneYearLater() {
        let report = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        #expect(RenewalView.defaultDate(for: report, calendar: istanbul) == istanbul.startOfDay(for: date(2027, 11, 5)))
    }

    @Test func renewalDefaultOnLeapDay() {
        let report = Report(title: "Tansiyon raporu", endDate: date(2028, 2, 29))
        #expect(RenewalView.defaultDate(for: report, calendar: istanbul) == istanbul.startOfDay(for: date(2029, 2, 28)))
    }

    @Test func renewThroughStoreStartsANewCycle() async throws {
        let container = try makeContainer()
        let center = FakeNotificationCenter()
        let settings = AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let scheduler = NotificationScheduler(center: center, calendar: istanbul, isFastModeAllowed: false)
        let sync = ReminderSync(container: container, settings: settings, scheduler: scheduler, language: { .tr })
        let store = ItemStore(container: container, sync: sync, saveContext: nil,
                              now: { date(2026, 10, 27) }, calendar: istanbul)
        let report = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        report.markHandled(at: date(2026, 10, 27))
        report.snoozeUntil = date(2026, 10, 27, 15)
        store.context.insert(report)

        try await store.renew(report, newEndDate: date(2027, 11, 5))

        #expect(!report.isHandled)
        #expect(report.handledAt == nil)
        #expect(report.snoozeUntil == nil)
        let ids = center.added.map(\.identifier)
        #expect(ids.contains { $0.hasPrefix("report-\(report.id.uuidString)-") })
        #expect(!ids.contains { $0.hasPrefix("renewal-") })
    }
}
