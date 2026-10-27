import Foundation
import Testing
@testable import MedReportKit

@Suite("ReminderItem")
struct ReminderItemTests {
    let now = date(2026, 10, 27)

    @Test func stateAndDaysUseLogic() {
        let r = report(1, end: date(2026, 11, 5))
        #expect(r.daysRemaining(now: now, calendar: istanbul) == 9)
        #expect(r.state(now: now, calendar: istanbul) == .reminding)
    }

    @Test func urgencyOrder() {
        let overdue  = report(1, end: date(2026, 10, 24))                              // -3
        let tomorrow = medication(2, end: date(2026, 10, 28))                          // 1
        let handled  = report(3, title: "Kardiyoloji raporu", end: date(2026, 10, 20),
                              handledAt: date(2026, 10, 21))
        let normal24 = medication(4, name: "Parol", end: date(2026, 11, 20))           // 24
        let normal19 = medication(5, name: "Coraspin", end: date(2026, 11, 15))        // 19
        let sorted = ReminderItem.sortedByUrgency([normal24, handled, normal19, tomorrow, overdue],
                                                  now: now, calendar: istanbul)
        #expect(sorted.map(\.id) == [uuid(1), uuid(2), uuid(3), uuid(5), uuid(4)])
    }

    @Test func sameStateAndDaysSortsByTitle() {
        let b = medication(1, name: "Beloc", end: date(2026, 11, 15))
        let a = medication(2, name: "Aspirin", end: date(2026, 11, 15))
        #expect(ReminderItem.sortedByUrgency([b, a], now: now, calendar: istanbul).map(\.title)
                == ["Aspirin", "Beloc"])
    }
}
