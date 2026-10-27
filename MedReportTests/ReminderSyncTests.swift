import Foundation
import SwiftData
import Testing
import MedReportKit
@testable import MedReport

@MainActor
@Suite("ReminderSync")
struct ReminderSyncTests {

    private func make(language: AppLanguage) throws -> (ModelContainer, FakeNotificationCenter, ReminderSync) {
        let container = try makeContainer()
        let center = FakeNotificationCenter()
        let settings = AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let scheduler = NotificationScheduler(center: center, calendar: istanbul, isFastModeAllowed: false)
        let sync = ReminderSync(container: container, settings: settings, scheduler: scheduler, language: { language })
        return (container, center, sync)
    }

    @Test func syncSchedulesActiveItemsOnly() async throws {
        let (container, center, sync) = try make(language: .tr)
        let open = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        let archived = Report(title: "Eski", endDate: date(2026, 11, 5)); archived.isArchived = true
        container.mainContext.insert(open)
        container.mainContext.insert(archived)
        try container.mainContext.save()

        await sync.sync(now: date(2026, 10, 27, 12), calendar: istanbul)

        let ids = center.added.map(\.identifier)
        #expect(ids.count == 64)
        #expect(ids.dropLast().allSatisfy { $0.hasPrefix("report-\(open.id.uuidString)-") })
        #expect(ids.last == "backup")
        #expect(!ids.contains { $0.contains(archived.id.uuidString) })
        #expect(center.added.first!.content.title == "Tansiyon raporu 8 gün sonra bitiyor")
    }

    @Test func syncUsesLanguage() async throws {
        let (container, center, sync) = try make(language: .en)
        container.mainContext.insert(Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5)))
        try container.mainContext.save()

        await sync.sync(now: date(2026, 10, 27, 12), calendar: istanbul)

        #expect(center.added.first!.content.title == "Tansiyon raporu ends in 8 days")
        #expect(center.added.last!.content.title == "Keep your reminders going")
    }

    @Test func syncWithNoItemsRemovesAll() async throws {
        let (_, center, sync) = try make(language: .tr)
        await sync.sync(now: date(2026, 10, 27, 12), calendar: istanbul)
        #expect(center.removeAllCount == 1)
        #expect(center.added.isEmpty)
    }

    /// Final review I1: a second sync must not interleave with a running one.
    @Test func concurrentSyncsDoNotInterleave() async throws {
        let (container, center, sync) = try make(language: .tr)
        center.yieldsPerAdd = 3
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        container.mainContext.insert(r)
        try container.mainContext.save()
        let now = date(2026, 10, 27, 12)

        async let first: Void = sync.sync(now: now, calendar: istanbul)
        while center.added.isEmpty { await Task.yield() }   // the first sync is now between two adds

        r.markHandled(at: now)
        try container.mainContext.save()
        await sync.sync(now: now, calendar: istanbul)
        await first

        let ids = center.added.map(\.identifier)
        #expect(!ids.contains { $0.hasPrefix("report-") })
        #expect(ids.count <= 64)
        #expect(ids.last == "backup")
    }

    /// Final review I2: each sync runs inside a background task.
    @Test func eachSyncRunsInABackgroundTask() async throws {
        let container = try makeContainer()
        let center = FakeNotificationCenter()
        let settings = AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let scheduler = NotificationScheduler(center: center, calendar: istanbul, isFastModeAllowed: false)
        var begun = 0
        var ended = 0
        let sync = ReminderSync(container: container, settings: settings, scheduler: scheduler, language: { .tr },
                                beginBackgroundTask: { begun += 1; return { ended += 1 } })
        await sync.sync(now: date(2026, 10, 27, 12), calendar: istanbul)
        await sync.sync(now: date(2026, 10, 27, 13), calendar: istanbul)
        #expect(begun == 2 && ended == 2)
    }
}
