import Foundation
import SwiftData
import MedReportKit

/// The single entry point for notifications (spec 5.4).
/// No other component adds or removes a notification.
@MainActor
final class ReminderSync {
    private let container: ModelContainer
    private let settings: AppSettings
    private let scheduler: NotificationScheduler
    private let language: @MainActor () -> AppLanguage

    init(container: ModelContainer, settings: AppSettings, scheduler: NotificationScheduler,
         language: @escaping @MainActor () -> AppLanguage) {
        self.container = container
        self.settings = settings
        self.scheduler = scheduler
        self.language = language
    }

    /// Entry point for the app.
    func sync() async {
        await sync(now: Date(), calendar: Calendar.current)
    }

    func sync(now: Date, calendar: Calendar) async {
        let context = container.mainContext
        let reports = (try? context.fetch(FetchDescriptor<Report>())) ?? []
        let medications = (try? context.fetch(FetchDescriptor<Medication>())) ?? []
        let items = ReminderItem.active(reports: reports, medications: medications, calendar: calendar)
        let planned = NotificationPlanner.plan(items: items, now: now,
                                               settings: settings.plannerSettings(language: language()),
                                               calendar: calendar)
        await scheduler.replaceAll(with: planned, now: now, fastMode: settings.isFastModeOn)
    }
}
