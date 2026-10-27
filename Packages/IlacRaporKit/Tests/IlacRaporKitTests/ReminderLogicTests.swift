import Foundation
import Testing
@testable import IlacRaporKit

// MARK: - Day count

@Suite("Day count")
struct DayCountTests {
    let cal = calendar()

    @Test("Same day, different hours → 0")
    func sameDayDifferentHours() {
        let now = date(2026, 10, 27, 23, 50)
        let end = date(2026, 10, 27, 0, 5)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: cal) == 0)
    }

    @Test("Midnight crossing: 23:59 → next day 00:00 = 1 day")
    func midnightCrossing() {
        let now = date(2026, 10, 27, 23, 59)
        let end = date(2026, 10, 28, 0, 0)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: cal) == 1)
    }

    @Test("Past date → negative")
    func pastDateIsNegative() {
        let now = date(2026, 10, 27)
        let end = date(2026, 10, 24)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: cal) == -3)
    }

    @Test("Daylight saving change does not break the result (Berlin, 29 March 2026)")
    func daylightSavingTransition() {
        let berlin = calendar("Europe/Berlin")
        let now = date(2026, 3, 28, 23, 30, in: berlin)
        let end = date(2026, 3, 30, 0, 30, in: berlin)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: berlin) == 2)
    }

    @Test("Year boundary")
    func yearBoundary() {
        let now = date(2026, 12, 31)
        let end = date(2027, 1, 18)
        #expect(ReminderLogic.daysRemaining(until: end, now: now, calendar: cal) == 18)
    }
}

// MARK: - State

@Suite("Reminder state")
struct StateTests {

    @Test("End date today → reminding")
    func endsToday() {
        #expect(ReminderLogic.state(daysRemaining: 0, leadDays: 18, isHandled: false) == .reminding)
    }

    @Test("End date past → overdue")
    func pastEndIsOverdue() {
        #expect(ReminderLogic.state(daysRemaining: -1, leadDays: 18, isHandled: false) == .overdue)
    }

    @Test("Boundary: remaining == leadDays → reminding, leadDays + 1 → normal")
    func leadDaysBoundary() {
        #expect(ReminderLogic.state(daysRemaining: 18, leadDays: 18, isHandled: false) == .reminding)
        #expect(ReminderLogic.state(daysRemaining: 19, leadDays: 18, isHandled: false) == .normal)
    }

    @Test("leadDays larger than remaining → reminds from the start")
    func leadDaysLargerThanRemaining() {
        #expect(ReminderLogic.state(daysRemaining: 5, leadDays: 18, isHandled: false) == .reminding)
    }

    @Test("handled overrides all states, also overdue")
    func handledOverridesOverdue() {
        #expect(ReminderLogic.state(daysRemaining: -10, leadDays: 18, isHandled: true) == .handled)
        #expect(ReminderLogic.state(daysRemaining: 100, leadDays: 18, isHandled: true) == .handled)
    }

    @Test("Negative leadDays operates as zero")
    func negativeLeadDays() {
        #expect(ReminderLogic.state(daysRemaining: 0, leadDays: -5, isHandled: false) == .reminding)
        #expect(ReminderLogic.state(daysRemaining: 1, leadDays: -5, isHandled: false) == .normal)
    }

    @Test("Sort priority: overdue < reminding < handled < normal")
    func sortPriority() {
        let sorted = ReminderState.allCases.sorted { $0.sortPriority < $1.sortPriority }
        #expect(sorted == [.overdue, .reminding, .handled, .normal])
    }
}

// MARK: - Derived dates

@Suite("Derived dates")
struct DerivedDateTests {
    let cal = calendar()

    @Test("Supply end = pickup + supply days, time set to start of day")
    func supplyEnd() {
        let end = ReminderLogic.supplyEndDate(lastPickupDate: date(2026, 1, 1, 17, 45), supplyDays: 30, calendar: cal)
        #expect(end == date(2026, 1, 31, 0, 0))
    }

    @Test("Supply end crosses February correctly")
    func supplyEndAcrossFebruary() {
        let end = ReminderLogic.supplyEndDate(lastPickupDate: date(2027, 2, 1), supplyDays: 30, calendar: cal)
        #expect(end == date(2027, 3, 3, 0, 0))
    }

    @Test("Reminder start = end − leadDays")
    func reminderStart() {
        let start = ReminderLogic.reminderStartDate(endDate: date(2026, 3, 20), leadDays: 18, calendar: cal)
        #expect(start == date(2026, 3, 2, 0, 0))
    }

    @Test("Renewal suggestion: + 1 year")
    func renewalSuggestion() {
        let next = ReminderLogic.suggestedRenewalEndDate(previousEndDate: date(2026, 11, 14), calendar: cal)
        #expect(next == date(2027, 11, 14, 0, 0))
    }

    @Test("Renewal suggestion: 29 February → 28 February")
    func renewalSuggestionLeapDay() {
        let next = ReminderLogic.suggestedRenewalEndDate(previousEndDate: date(2028, 2, 29), calendar: cal)
        #expect(next == date(2029, 2, 28, 0, 0))
    }
}
