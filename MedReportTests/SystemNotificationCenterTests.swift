import Foundation
import Testing
import UserNotifications
@testable import MedReport

@MainActor
@Suite("SystemNotificationCenter")
struct SystemNotificationCenterTests {
    /// iOS calls the completion handler on a background queue. A main-actor closure there
    /// traps at run time in Swift 6. This test fails by crashing if that comes back.
    @Test func addCompletesFromBackgroundQueueWithoutTrap() async {
        let center = SystemNotificationCenter()
        let content = UNMutableNotificationContent()
        content.title = "Test"
        let request = UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content,
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false))
        try? await center.add(request)
        center.removeAllPendingNotificationRequests()
    }
}
