import Foundation
import SwiftData
import Testing
import MedReportKit
@testable import MedReport

@MainActor
@Suite("ItemStore")
struct ItemStoreTests {
    private struct Env {
        let container: ModelContainer
        let center: FakeNotificationCenter
        let store: ItemStore
    }

    private func make(saveContext: ((ModelContext) throws -> Void)? = nil) throws -> Env {
        let container = try makeContainer()
        let center = FakeNotificationCenter()
        let settings = AppSettings(defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        let scheduler = NotificationScheduler(center: center, calendar: istanbul, isFastModeAllowed: false)
        let sync = ReminderSync(container: container, settings: settings, scheduler: scheduler, language: { .tr })
        return Env(container: container, center: center,
                   store: ItemStore(container: container, sync: sync, saveContext: saveContext,
                                    now: { date(2026, 10, 27) }, calendar: istanbul))
    }

    @Test func saveSyncs() async throws {
        let env = try make()
        env.store.context.insert(Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5)))
        try await env.store.save()
        #expect(!env.center.added.isEmpty)
    }

    @Test func markRenewedClearsSnoozeAndSyncs() async throws {
        let env = try make()
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        r.snoozeUntil = date(2026, 10, 27, 15)
        env.store.context.insert(r)
        try await env.store.markRenewed(r, now: date(2026, 10, 27, 12))
        #expect(r.snoozeUntil == nil)
        #expect(r.isHandled)
        #expect(env.center.removeAllCount == 1)
        let ids = env.center.added.map(\.identifier)
        #expect(ids.first == "renewal-\(r.id.uuidString)-20261030")
        #expect(ids.last == "backup")
        #expect(ids.dropLast().allSatisfy { $0.hasPrefix("renewal-\(r.id.uuidString)-") })
    }

    @Test func archiveAndRestoreReport() async throws {
        let env = try make()
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        let m = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: r)
        env.store.context.insert(r)
        env.store.context.insert(m)
        try await env.store.save()
        let both = { (env: Env) in
            let ids = env.center.added.map(\.identifier)
            return ids.contains { $0.contains(r.id.uuidString) } && ids.contains { $0.contains(m.id.uuidString) }
        }
        #expect(both(env))

        try await env.store.setArchived(r, true)
        #expect(!env.center.added.contains { $0.identifier.contains(r.id.uuidString) || $0.identifier.contains(m.id.uuidString) })

        try await env.store.setArchived(r, false)
        #expect(both(env))
    }

    @Test func deleteReportDeletesItsMedications() async throws {
        let env = try make()
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        let m = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: r)
        env.store.context.insert(r)
        env.store.context.insert(m)
        try await env.store.save()
        let id = r.id.uuidString
        try await env.store.delete(r)
        #expect(try env.store.context.fetchCount(FetchDescriptor<Report>()) == 0)
        #expect(try env.store.context.fetchCount(FetchDescriptor<Medication>()) == 0)
        #expect(!env.center.added.contains { $0.identifier.contains(id) })
    }

    @Test func failedSaveRollsBackAndDoesNotSync() async throws {
        let env = try make(saveContext: { _ in throw CocoaError(.validationMissingMandatoryProperty) })
        env.store.context.insert(Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5)))
        await #expect(throws: CocoaError.self) { try await env.store.save() }
        #expect(try env.store.context.fetchCount(FetchDescriptor<Report>()) == 0)
        #expect(env.center.removeAllCount == 0)
    }
}
