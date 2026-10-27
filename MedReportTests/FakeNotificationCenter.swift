import Foundation
import UserNotifications
@testable import MedReport

/// Records what the scheduler does. `added` holds the requests that are pending now:
/// `removeAllPendingNotificationRequests` clears it, like the real center.
@MainActor
final class FakeNotificationCenter: NotificationCenterProtocol {
    struct AddFailure: Error {}

    var added: [UNNotificationRequest] = []
    var removeAllCount = 0
    var categories: Set<UNNotificationCategory> = []
    var failingIdentifiers: Set<String> = []

    func add(_ request: UNNotificationRequest) async throws {
        if failingIdentifiers.contains(request.identifier) { throw AddFailure() }
        added.removeAll { $0.identifier == request.identifier }
        added.append(request)
    }

    func removeAllPendingNotificationRequests() {
        removeAllCount += 1
        added = []
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
        self.categories = categories
    }
}
