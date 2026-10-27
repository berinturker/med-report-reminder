import Foundation
import OSLog
import SwiftData
import UserNotifications
import MedReportKit

/// Changes the model for the notification buttons and taps (spec 8.2, 8.3).
@MainActor
final class NotificationActionHandler {
    static let snoozeInterval: TimeInterval = 3 * 60 * 60

    private let container: ModelContainer
    private let sync: ReminderSync
    private let router: NavigationRouter
    private let logger = Logger(subsystem: "com.berinturker.medreport", category: "actions")

    init(container: ModelContainer, sync: ReminderSync, router: NavigationRouter) {
        self.container = container
        self.sync = sync
        self.router = router
    }

    /// Entry point for the notification delegate. It returns only after the save and the sync
    /// are done, so iOS does not suspend the app in the middle (spec 8.3 step 5).
    func respond(actionIdentifier: String, categoryIdentifier: String, kind: String?, id: String?,
                 deliveredAt: Date?, now: Date, calendar: Calendar) async {
        var userInfo: [AnyHashable: Any] = [:]
        if let kind { userInfo[NotificationUserInfoKey.kind] = kind }
        if let id { userInfo[NotificationUserInfoKey.id] = id }
        switch actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            handleTap(categoryIdentifier: categoryIdentifier, userInfo: userInfo)
        case UNNotificationDismissActionIdentifier:
            break
        default:
            await handle(actionIdentifier: actionIdentifier, userInfo: userInfo, deliveredAt: deliveredAt,
                         now: now, calendar: calendar)
        }
    }

    /// Steps (spec 8.3): find the item → change it → save → sync.
    /// A missing item or an unknown action changes nothing, but the sync still runs.
    /// - Parameter deliveredAt: the delivery date of the notification. "Picked up" on a notification
    ///   from before the last pickup is ignored, so an old notification cannot move the supply end later.
    func handle(actionIdentifier: String, userInfo: [AnyHashable: Any], deliveredAt: Date? = nil,
                now: Date, calendar: Calendar) async {
        if let action = NotificationAction(rawValue: actionIdentifier), let ref = itemReference(userInfo) {
            apply(action, to: ref, deliveredAt: deliveredAt, now: now, calendar: calendar)
            do {
                try container.mainContext.save()
            } catch {
                logger.error("Could not save after \(actionIdentifier, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        await sync.sync(now: now, calendar: calendar)
    }

    /// Tap on the notification body.
    func handleTap(categoryIdentifier: String, userInfo: [AnyHashable: Any]) {
        let ref = itemReference(userInfo)
        switch (PlannedNotification.Category(rawValue: categoryIdentifier), ref) {
        case (.reportReminder?, let ref?):
            router.pending = .reportDetail(ref.id)
        case (.medReminder?, let ref?):
            if let reportID = medication(ref.id)?.report?.id {
                router.pending = .reportDetail(reportID)
            } else {
                router.pending = .medicationForm(ref.id)
            }
        case (.renewalDate?, let ref?):
            router.pending = .renewal(ref.id)
        default:
            router.pending = .home
        }
    }

    // MARK: - Private

    private func apply(_ action: NotificationAction, to ref: (kind: ReminderItem.Kind, id: UUID),
                       deliveredAt: Date?, now: Date, calendar: Calendar) {
        switch (action, ref.kind) {
        case (.renewed, .report):
            guard let report = report(ref.id) else { return }
            report.markHandled(at: now)
            report.snoozeUntil = nil
        case (.pickedUp, .medication):
            guard let medication = medication(ref.id) else { return }
            if let deliveredAt, medication.lastPickupDate >= calendar.startOfDay(for: deliveredAt) {
                logger.notice("Ignored PICKED_UP from a notification before the last pickup")
                return
            }
            medication.markPickedUp(on: now, calendar: calendar)
        case (.snooze, .report):
            report(ref.id)?.snoozeUntil = now.addingTimeInterval(Self.snoozeInterval)
        case (.snooze, .medication):
            medication(ref.id)?.snoozeUntil = now.addingTimeInterval(Self.snoozeInterval)
        default:
            logger.notice("Action \(action.rawValue, privacy: .public) does not apply to \(ref.kind.rawValue, privacy: .public)")
        }
    }

    private func itemReference(_ userInfo: [AnyHashable: Any]) -> (kind: ReminderItem.Kind, id: UUID)? {
        guard let kindValue = userInfo[NotificationUserInfoKey.kind] as? String,
              let kind = ReminderItem.Kind(rawValue: kindValue),
              let idValue = userInfo[NotificationUserInfoKey.id] as? String,
              let id = UUID(uuidString: idValue) else { return nil }
        return (kind, id)
    }

    private func report(_ id: UUID) -> Report? {
        try? container.mainContext.fetch(FetchDescriptor<Report>(predicate: #Predicate { $0.id == id })).first
    }

    private func medication(_ id: UUID) -> Medication? {
        try? container.mainContext.fetch(FetchDescriptor<Medication>(predicate: #Predicate { $0.id == id })).first
    }
}
