import Foundation

/// What the primary button of a reminder does.
public enum PrimaryAction: Sendable, Equatable { case renewed, pickedUp, enterDate }

extension ReminderItem {
    /// Part of the reminder period that is past, 0...1.
    public func progress(now: Date, calendar: Calendar) -> Double {
        ReminderLogic.reminderProgress(endDate: endDate, leadDays: leadDays, isHandled: isHandled, now: now, calendar: calendar)
    }

    /// Report reminding/overdue → renewed; medication reminding/overdue → picked up;
    /// handled → enter date; normal → none.
    public func primaryAction(now: Date, calendar: Calendar) -> PrimaryAction? {
        switch state(now: now, calendar: calendar) {
        case .normal: nil
        case .handled: .enterDate
        case .reminding, .overdue: kind == .report ? .renewed : .pickedUp
        }
    }
}

/// The data of the home screen: the upcoming strip and the hero card.
public struct HomeSummary: Sendable, Equatable {
    public static let stripLimit = 8
    /// The first items by urgency, at most `stripLimit`.
    public let strip: [ReminderItem]
    /// The most urgent item; nil when there are no items.
    public let hero: ReminderItem?

    public static func make(items: [ReminderItem], now: Date, calendar: Calendar) -> HomeSummary {
        let sorted = ReminderItem.sortedByUrgency(items, now: now, calendar: calendar)
        return HomeSummary(strip: Array(sorted.prefix(stripLimit)), hero: sorted.first)
    }
}
