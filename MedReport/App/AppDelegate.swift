import UIKit
// The completion handlers of this delegate are not marked Sendable in every SDK version.
@preconcurrency import UserNotifications

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

    /// A button or a tap on a notification (spec 8.3).
    /// iOS requires the completion handler on the main thread: the `async` form of this method
    /// calls it from a background thread and crashed on a real iPhone ("Call must be made on main
    /// thread"). The handler is called only after the save and the sync are done, so iOS does not
    /// suspend the app in the middle.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler: @escaping () -> Void) {
        // Copy the values as Sendable values before going to the main actor.
        let action = response.actionIdentifier
        let content = response.notification.request.content
        let category = content.categoryIdentifier
        let kind = content.userInfo[NotificationUserInfoKey.kind] as? String
        let id = content.userInfo[NotificationUserInfoKey.id] as? String
        let deliveredAt = response.notification.date
        Task { @MainActor in
            await AppEnvironment.shared.actions.respond(actionIdentifier: action, categoryIdentifier: category,
                                                        kind: kind, id: id, deliveredAt: deliveredAt,
                                                        now: Date(), calendar: .current)
            completionHandler()
        }
    }

    /// A notification while the app is open: show it as a banner with a sound (spec 8.4).
    /// iOS calls this method on the main thread; the handler is called at once on the same thread.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
