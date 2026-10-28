import Foundation
import Testing
@testable import MedReportKit

@Suite("HomeSummary")
struct HomeSummaryTests {
    let now = date(2026, 10, 27)

    @Test func progressAcrossThePeriod() {
        func p(_ end: Date, lead: Int = 10, handled: Bool = false) -> Double {
            ReminderLogic.reminderProgress(endDate: end, leadDays: lead, isHandled: handled, now: now, calendar: istanbul)
        }
        #expect(p(date(2026, 11, 20)) == 0)              // 24 days, normal
        #expect(p(date(2026, 11, 6)) == 0)               // 10 days, first reminder day
        #expect(p(date(2026, 11, 1)) == 0.5)             // 5 of 10
        #expect(p(date(2026, 10, 27)) == 1)              // ends today
        #expect(p(date(2026, 10, 20)) == 1)              // overdue
        #expect(p(date(2026, 10, 27), lead: 0) == 1)
        #expect(p(date(2026, 10, 28), lead: -3) == 0)    // negative lead acts as 0: 1 day left is normal
        #expect(p(date(2026, 11, 20), handled: true) == 1)
    }

    @Test func primaryActionByKindAndState() {
        #expect(report(1, end: date(2026, 11, 1)).primaryAction(now: now, calendar: istanbul) == .renewed)
        #expect(report(2, end: date(2026, 10, 20)).primaryAction(now: now, calendar: istanbul) == .renewed)
        #expect(report(3, end: date(2026, 10, 20), handledAt: date(2026, 10, 21)).primaryAction(now: now, calendar: istanbul) == .enterDate)
        #expect(medication(4, end: date(2026, 10, 30)).primaryAction(now: now, calendar: istanbul) == .pickedUp)
        #expect(report(5, end: date(2027, 6, 1)).primaryAction(now: now, calendar: istanbul) == nil)
    }

    @Test func summaryKeepsEightAndHeroIsFirst() {
        let items = (1...10).map { medication($0, end: date(2026, 11, 10 + $0)) } + [report(11, end: date(2026, 10, 25))]
        let s = HomeSummary.make(items: items, now: now, calendar: istanbul)
        #expect(s.strip.count == 8)
        #expect(s.strip.first?.id == uuid(11))
        #expect(s.hero?.id == uuid(11))
    }

    @Test func summaryOfNoItemsIsEmpty() {
        let s = HomeSummary.make(items: [], now: now, calendar: istanbul)
        #expect(s.strip.isEmpty && s.hero == nil)
    }
}
