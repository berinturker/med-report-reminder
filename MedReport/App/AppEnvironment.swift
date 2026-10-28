import Foundation
import SwiftData
import UIKit
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
    let store: ItemStore

    /// The device language selects the app language (spec D10).
    static var currentLanguage: AppLanguage {
        AppLanguage.current(preferredLanguages: Locale.preferredLanguages)
    }

    /// True in the app process that hosts the unit tests (`XCTestConfigurationFilePath` is set).
    nonisolated static var isHostingUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// True when the app was launched with the argument "-uiTesting".
    nonisolated static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
    }

    private init() {
        // UI tests use an in-memory store and their own settings, so they never touch real data.
        let configuration = ModelConfiguration(isStoredInMemoryOnly: Self.isUITesting, cloudKitDatabase: .none)
        do {
            container = try ModelContainer(for: Schema(versionedSchema: SchemaV1.self),
                                           migrationPlan: MedReportMigrationPlan.self,
                                           configurations: configuration)
        } catch {
            fatalError("Could not open the data store: \(error)")
        }
        if Self.isUITesting {
            UserDefaults.standard.removePersistentDomain(forName: "uiTesting")
            settings = AppSettings(defaults: UserDefaults(suiteName: "uiTesting") ?? .standard)
        } else {
            settings = AppSettings(defaults: .standard)
        }
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
                            language: { AppEnvironment.currentLanguage },
                            beginBackgroundTask: AppEnvironment.beginBackgroundTask)
        actions = NotificationActionHandler(container: container, sync: sync, router: router)
        store = ItemStore(container: container, sync: sync)
    }

    /// Holds one background task id, so the end function and the expiration handler share it.
    @MainActor
    private final class BackgroundTaskBox {
        var id = UIBackgroundTaskIdentifier.invalid
        func end() {
            guard id != .invalid else { return }
            UIApplication.shared.endBackgroundTask(id)
            id = .invalid
        }
    }

    /// Asks iOS for extra time so a sync finishes when the user leaves the app (final review I2).
    private static func beginBackgroundTask() -> @MainActor () -> Void {
        let box = BackgroundTaskBox()
        // iOS calls the expiration handler on the main thread.
        box.id = UIApplication.shared.beginBackgroundTask(withName: "ReminderSync") {
            MainActor.assumeIsolated { box.end() }
        }
        return { box.end() }
    }

    func registerCategories() {
        scheduler.setCategories(language: Self.currentLanguage)
    }
}
