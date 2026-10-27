import Foundation
import OSLog
import UserNotifications
import MedReportKit

/// Gives the planned notifications to iOS (spec 7.7, 7.8).
@MainActor
final class NotificationScheduler {
    private let center: any NotificationCenterProtocol
    private let calendar: Calendar
    private let isFastModeAllowed: Bool
    private let logger = Logger(subsystem: "com.berinturker.medreport", category: "notifications")

    /// - Parameter isFastModeAllowed: true only in debug builds.
    init(center: any NotificationCenterProtocol, calendar: Calendar, isFastModeAllowed: Bool) {
        self.center = center
        self.calendar = calendar
        self.isFastModeAllowed = isFastModeAllowed
    }

    func setCategories(language: AppLanguage) {
        center.setNotificationCategories(NotificationCategories.all(language: language))
    }

    /// Removes all pending requests, then adds one request for each planned notification.
    /// An `add` failure is logged and does not stop the other requests (spec 13).
    func replaceAll(with planned: [PlannedNotification], now: Date, fastMode: Bool) async {
        center.removeAllPendingNotificationRequests()
        for notification in planned {
            do {
                try await center.add(request(for: notification, now: now, fastMode: fastMode))
            } catch {
                logger.error("Could not add \(notification.identifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    func request(for planned: PlannedNotification, now: Date, fastMode: Bool) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = planned.title
        content.body = planned.body
        content.sound = .default
        content.categoryIdentifier = planned.category.rawValue
        if let kind = planned.itemKind, let id = planned.itemID {
            content.userInfo = [NotificationUserInfoKey.kind: kind.rawValue, NotificationUserInfoKey.id: id.uuidString]
        }
        return UNNotificationRequest(identifier: planned.identifier, content: content,
                                     trigger: trigger(for: planned.fireDate, now: now, fastMode: fastMode))
    }

    private func trigger(for fireDate: Date, now: Date, fastMode: Bool) -> UNNotificationTrigger {
        if isFastModeAllowed && fastMode {
            // Fast mode: one day is one minute (spec 7.8).
            let days = ReminderLogic.calendarDays(from: now, to: fireDate, calendar: calendar)
            return UNTimeIntervalNotificationTrigger(timeInterval: max(TimeInterval(days * 60), 5), repeats: false)
        }
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }
}
