import Foundation
import SwiftData
import MedReportKit

/// The shared objects of the app. The SwiftUI scene and the `AppDelegate` use the same
/// `ModelContainer`, so a notification action changes the data that the views show (spec 8.1).
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let container: ModelContainer
    let settings: AppSettings
    let router: NavigationRouter
    let scheduler: NotificationScheduler
    let sync: ReminderSync
    let actions: NotificationActionHandler

    /// The device language selects the app language (spec D10).
    static var currentLanguage: AppLanguage {
        AppLanguage.current(preferredLanguages: Locale.preferredLanguages)
    }

    private init() {
        do {
            container = try ModelContainer(for: Schema(versionedSchema: SchemaV1.self),
                                           migrationPlan: MedReportMigrationPlan.self,
                                           configurations: ModelConfiguration())
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
        settings = AppSettings(defaults: .standard)
        router = NavigationRouter()
        #if DEBUG
        let fastModeAllowed = true
        #else
        let fastModeAllowed = false
        #endif
        // autoupdatingCurrent follows time zone changes (spec 13).
        scheduler = NotificationScheduler(center: SystemNotificationCenter(), calendar: .autoupdatingCurrent,
                                          isFastModeAllowed: fastModeAllowed)
        sync = ReminderSync(container: container, settings: settings, scheduler: scheduler,
                            language: { AppEnvironment.currentLanguage })
        actions = NotificationActionHandler(container: container, sync: sync, router: router)
    }

    /// Every save in the app goes through this method, so a sync follows each save (spec 5.4).
    func saveAndSync() async throws {
        try container.mainContext.save()
        await sync.sync()
    }

    func registerCategories() {
        scheduler.setCategories(language: Self.currentLanguage)
    }
}
