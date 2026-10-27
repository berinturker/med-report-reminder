import Foundation

/// A value copy of one report or one medication.
/// The planner and the home screen use this type, not the SwiftData models.
public struct ReminderItem: Sendable, Equatable, Identifiable {
    public enum Kind: String, Sendable { case report, medication }

    public let kind: Kind
    public let id: UUID
    /// Report title or medication name.
    public let title: String
    /// Effective person name (spec 6.5).
    public let personName: String
    /// Report end date or supply end date.
    public let endDate: Date
    public let leadDays: Int
    /// Always false for a medication.
    public let isHandled: Bool
    public let handledAt: Date?
    public let snoozeUntil: Date?

    public init(
        kind: Kind, id: UUID, title: String, personName: String, endDate: Date,
        leadDays: Int, isHandled: Bool = false, handledAt: Date? = nil, snoozeUntil: Date? = nil
    ) {
        self.kind = kind
        self.id = id
        self.title = title
        self.personName = personName
        self.endDate = endDate
        self.leadDays = leadDays
        self.isHandled = isHandled
        self.handledAt = handledAt
        self.snoozeUntil = snoozeUntil
    }

    public func daysRemaining(now: Date, calendar: Calendar) -> Int {
        ReminderLogic.daysRemaining(until: endDate, now: now, calendar: calendar)
    }

    public func state(now: Date, calendar: Calendar) -> ReminderState {
        ReminderLogic.state(endDate: endDate, leadDays: leadDays, isHandled: isHandled, now: now, calendar: calendar)
    }

    /// Order: state priority, then days remaining, then title, then id.
    public static func sortedByUrgency(_ items: [ReminderItem], now: Date, calendar: Calendar) -> [ReminderItem] {
        items
            .map { (item: $0,
                    priority: $0.state(now: now, calendar: calendar).sortPriority,
                    days: $0.daysRemaining(now: now, calendar: calendar)) }
            .sorted { a, b in
                if a.priority != b.priority { return a.priority < b.priority }
                if a.days != b.days { return a.days < b.days }
                if a.item.title != b.item.title { return a.item.title < b.item.title }
                return a.item.id.uuidString < b.item.id.uuidString
            }
            .map(\.item)
    }
}
