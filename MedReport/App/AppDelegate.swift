import UIKit
import UserNotifications

/// Receives the notification actions, also when the app was not running (spec 8.1).
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // The delegate must be set before launch completes, or iOS does not deliver the action.
        UNUserNotificationCenter.current().delegate = self
        let environment = AppEnvironment.shared
        environment.registerCategories()
        Task { await environment.sync.sync() }
        return true
    }

    /// A button or a tap on a notification. The method returns only after the save and the
    /// sync are done: iOS may suspend the app as soon as it returns (spec 8.3).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        // Copy the values as Sendable values before going to the main actor.
        let action = response.actionIdentifier
        let content = response.notification.request.content
        let category = content.categoryIdentifier
        let kind = content.userInfo[NotificationUserInfoKey.kind] as? String
        let id = content.userInfo[NotificationUserInfoKey.id] as? String
        let deliveredAt = response.notification.date
        await AppEnvironment.shared.actions.respond(actionIdentifier: action, categoryIdentifier: category,
                                                    kind: kind, id: id, deliveredAt: deliveredAt,
                                                    now: Date(), calendar: .current)
    }

    /// A notification while the app is open: show it as a banner with a sound (spec 8.4).
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
