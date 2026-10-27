import Foundation

/// The settings that the planner needs.
public struct PlannerSettings: Sendable, Equatable {
    public var notificationHour: Int
    public var notificationMinute: Int

    public init(notificationHour: Int, notificationMinute: Int) {
        self.notificationHour = notificationHour
        self.notificationMinute = notificationMinute
    }
}

/// Calculates the local notifications for the reminder items (spec 7).
/// Pure: the same input always gives the same output.
public enum NotificationPlanner {
    /// iOS keeps a maximum of 64 pending notifications for each app.
    public static let maxPending = 64
    /// Maximum candidates for one item.
    public static let maxPerItem = 63
    /// A handled report gets one notification every 3 days.
    public static let renewalIntervalDays = 3

    // MARK: - Full plan

    /// All notifications to schedule. Never more than `maxPending`.
    /// Order: fire date, then the item state priority on that date, then identifier.
    public static func plan(
        items: [ReminderItem], now: Date,
        settings: PlannerSettings, calendar: Calendar
    ) -> [PlannedNotification] {
        let ranked = items.flatMap { item in
            candidates(for: item, now: now, settings: settings, calendar: calendar).map { notification in
                (notification: notification,
                 priority: item.state(now: notification.fireDate, calendar: calendar).sortPriority)
            }
        }
        .sorted { a, b in
            if a.notification.fireDate != b.notification.fireDate { return a.notification.fireDate < b.notification.fireDate }
            if a.priority != b.priority { return a.priority < b.priority }
            return a.notification.identifier < b.notification.identifier
        }

        var kept = ranked.prefix(maxPending - 1).map(\.notification)
        if let last = kept.last, let backup = backupNotification(after: last.fireDate, settings: settings, calendar: calendar) {
            kept.append(backup)
        }
        return kept
    }

    private static func backupNotification(after date: Date, settings: PlannerSettings, calendar: Calendar) -> PlannedNotification? {
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)),
              let fire = fireDate(on: nextDay, settings: settings, calendar: calendar) else { return nil }
        let content = NotificationText.backup
        return PlannedNotification(identifier: "backup", fireDate: fire, title: content.title, body: content.body,
                                   category: content.category, itemKind: nil, itemID: nil)
    }

    // MARK: - Candidates for one item

    static func candidates(
        for item: ReminderItem, now: Date,
        settings: PlannerSettings, calendar: Calendar
    ) -> [PlannedNotification] {
        var snooze: PlannedNotification?
        if let snoozeUntil = item.snoozeUntil, snoozeUntil > now {
            snooze = makeNotification(item, identifier: "snooze-\(item.id.uuidString)",
                                      fireDate: snoozeUntil, calendar: calendar)
        }

        let dailyLimit = maxPerItem - (snooze == nil ? 0 : 1)
        var result = item.isHandled
            ? renewalDays(item, now: now, settings: settings, calendar: calendar, limit: dailyLimit)
            : dailyDays(item, now: now, settings: settings, calendar: calendar, limit: dailyLimit)

        if let snooze {
            result.append(snooze)
            result.sort { $0.fireDate < $1.fireDate }
        }
        return result
    }

    // MARK: - Private

    /// One notification each day from the reminder start date (or today).
    private static func dailyDays(
        _ item: ReminderItem, now: Date,
        settings: PlannerSettings, calendar: Calendar, limit: Int
    ) -> [PlannedNotification] {
        let reminderStart = ReminderLogic.reminderStartDate(endDate: item.endDate, leadDays: item.leadDays, calendar: calendar)
        let startDay = max(reminderStart, calendar.startOfDay(for: now))
        let prefix = item.kind == .report ? "report" : "med"

        var result: [PlannedNotification] = []
        var offset = 0
        while result.count < limit {
            defer { offset += 1 }
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay),
                  let fire = fireDate(on: day, settings: settings, calendar: calendar) else { break }
            guard fire > now else { continue }
            result.append(makeNotification(item, identifier: "\(prefix)-\(item.id.uuidString)-\(dayStamp(fire, calendar))",
                                           fireDate: fire, calendar: calendar))
        }
        return result
    }

    /// One notification every `renewalIntervalDays`, from `handledAt`.
    private static func renewalDays(
        _ item: ReminderItem, now: Date,
        settings: PlannerSettings, calendar: Calendar, limit: Int
    ) -> [PlannedNotification] {
        let base = calendar.startOfDay(for: item.handledAt ?? now)

        var result: [PlannedNotification] = []
        var k = 1
        while result.count < limit {
            defer { k += 1 }
            guard let day = calendar.date(byAdding: .day, value: k * renewalIntervalDays, to: base),
                  let fire = fireDate(on: day, settings: settings, calendar: calendar) else { break }
            guard fire > now else { continue }
            result.append(makeNotification(item, identifier: "renewal-\(item.id.uuidString)-\(dayStamp(fire, calendar))",
                                           fireDate: fire, calendar: calendar))
        }
        return result
    }

    /// The notification time on `day`. A time that does not exist (daylight saving) moves forward.
    /// An hour outside 0...23 or a minute outside 0...59 is clamped into the range.
    static func fireDate(on day: Date, settings: PlannerSettings, calendar: Calendar) -> Date? {
        let hour = min(max(settings.notificationHour, 0), 23)
        let minute = min(max(settings.notificationMinute, 0), 59)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0,
                             of: day, matchingPolicy: .nextTime, repeatedTimePolicy: .first, direction: .forward)
    }

    /// `yyyyMMdd` in the calendar's time zone.
    static func dayStamp(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func makeNotification(
        _ item: ReminderItem, identifier: String, fireDate: Date, calendar: Calendar
    ) -> PlannedNotification {
        let content = NotificationText.content(for: item, fireDate: fireDate, calendar: calendar)
        return PlannedNotification(identifier: identifier, fireDate: fireDate,
                                   title: content.title, body: content.body, category: content.category,
                                   itemKind: item.kind, itemID: item.id)
    }
}
