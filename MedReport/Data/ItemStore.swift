import Foundation
import SwiftData

/// The one place where the views change and save data. Every change is saved and then synced
/// with the notification planner (spec 5.4). A failed save rolls back and does not sync (spec 13).
@MainActor @Observable
final class ItemStore {
    private let container: ModelContainer
    private let sync: ReminderSync
    private let saveContext: (ModelContext) throws -> Void

    /// `saveContext` is for tests; the default calls `context.save()`.
    init(container: ModelContainer, sync: ReminderSync, saveContext: ((ModelContext) throws -> Void)? = nil) {
        self.container = container
        self.sync = sync
        self.saveContext = saveContext ?? { try $0.save() }
    }

    var context: ModelContext { container.mainContext }

    /// Save, then sync. On failure: roll back, rethrow, and do not sync.
    func save() async throws {
        try persist()
        await sync.sync()
    }

    func markRenewed(_ report: Report, now: Date) async throws {
        report.markHandled(at: now)
        try await save()
    }

    func markPickedUp(_ medication: Medication, now: Date, calendar: Calendar) async throws {
        medication.markPickedUp(on: now, calendar: calendar)
        try persist()
        await sync.sync(now: now, calendar: calendar)
    }

    func renew(_ report: Report, newEndDate: Date) async throws {
        report.renew(newEndDate: newEndDate)
        try await save()
    }

    func setArchived(_ report: Report, _ archived: Bool) async throws {
        report.isArchived = archived
        try await save()
    }

    func setArchived(_ medication: Medication, _ archived: Bool) async throws {
        medication.isArchived = archived
        try await save()
    }

    /// Deletes the report; its medications go with it (cascade).
    func delete(_ report: Report) async throws {
        context.delete(report)
        try await save()
    }

    func delete(_ medication: Medication) async throws {
        context.delete(medication)
        try await save()
    }

    private func persist() throws {
        do {
            try saveContext(context)
        } catch {
            context.rollback()
            throw error
        }
    }
}
