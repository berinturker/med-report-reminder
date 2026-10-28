import Foundation

/// Day and state calculations. All functions are pure: the same input always gives the same output.
/// `now` and `calendar` are parameters, so the tests can use a fixed time.
///
/// All day calculations use `Calendar.startOfDay`. Thus, the time of day and
/// daylight saving changes do not change the result.
public enum ReminderLogic {

    // MARK: - Day count

    /// Calendar days between two dates (the time of day is ignored).
    /// Positive if `to` is after `from`, negative if before.
    public static func calendarDays(from: Date, to: Date, calendar: Calendar) -> Int {
        let start = calendar.startOfDay(for: from)
        let end = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Days until the end date. 0 = ends today, negative = the end date is past.
    public static func daysRemaining(until endDate: Date, now: Date, calendar: Calendar) -> Int {
        calendarDays(from: now, to: endDate, calendar: calendar)
    }

    // MARK: - State

    public static func state(daysRemaining: Int, leadDays: Int, isHandled: Bool) -> ReminderState {
        if isHandled { return .handled }
        if daysRemaining < 0 { return .overdue }
        if daysRemaining <= max(leadDays, 0) { return .reminding }
        return .normal
    }

    public static func state(endDate: Date, leadDays: Int, isHandled: Bool, now: Date, calendar: Calendar) -> ReminderState {
        let remaining = daysRemaining(until: endDate, now: now, calendar: calendar)
        return state(daysRemaining: remaining, leadDays: leadDays, isHandled: isHandled)
    }

    // MARK: - Progress

    /// Part of the reminder period that is past, 0...1. Normal → 0, overdue → 1, handled → 1.
    public static func reminderProgress(endDate: Date, leadDays: Int, isHandled: Bool, now: Date, calendar: Calendar) -> Double {
        let remaining = daysRemaining(until: endDate, now: now, calendar: calendar)
        switch state(daysRemaining: remaining, leadDays: leadDays, isHandled: isHandled) {
        case .normal: return 0
        case .overdue, .handled: return 1
        case .reminding:
            let lead = max(leadDays, 0)
            // With no lead days the reminding state is day 0 only.
            if lead == 0 { return 1 }
            return Double(lead - remaining) / Double(lead)
        }
    }

    // MARK: - Derived dates

    /// The day the supply ends: last pickup day + supply days.
    public static func supplyEndDate(lastPickupDate: Date, supplyDays: Int, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: lastPickupDate)
        return calendar.date(byAdding: .day, value: supplyDays, to: start) ?? start
    }

    /// The day the reminders start: end − leadDays.
    public static func reminderStartDate(endDate: Date, leadDays: Int, calendar: Calendar) -> Date {
        let end = calendar.startOfDay(for: endDate)
        return calendar.date(byAdding: .day, value: -max(leadDays, 0), to: end) ?? end
    }

    /// The suggested new end date when a report is renewed: previous end + 1 year.
    /// 29 February → 28 February of the next year.
    public static func suggestedRenewalEndDate(previousEndDate: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: previousEndDate)
        return calendar.date(byAdding: .year, value: 1, to: start) ?? start
    }
}
