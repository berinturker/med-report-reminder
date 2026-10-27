import Foundation
import UserNotifications

/// The functions of `UNUserNotificationCenter` that the app uses (spec 5.3).
/// The tests use a fake implementation.
@MainActor
protocol NotificationCenterProtocol: AnyObject {
    func add(_ request: UNNotificationRequest) async throws
    func removeAllPendingNotificationRequests()
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
}

/// The real notification center.
@MainActor
final class SystemNotificationCenter: NotificationCenterProtocol {
    func add(_ request: UNNotificationRequest) async throws {
        // The completion-handler API is called synchronously on the main actor,
        // so the non-Sendable request never crosses an isolation boundary (Swift 6).
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            UNUserNotificationCenter.current().add(request) { error in
                if let error { continuation.resume(throwing: error) } else { continuation.resume() }
            }
        }
    }

    func removeAllPendingNotificationRequests() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
}
