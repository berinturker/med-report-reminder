import Foundation
import Testing
@testable import MedReportKit

@Suite("StatusText")
struct StatusTextTests {
    @Test(arguments: zip(
        [12, 2, 1, 0, -1, -3],
        ["12 days left", "2 days left", "Ends tomorrow", "Ends today", "1 day overdue", "3 days overdue"]))
    func english(days: Int, expected: String) {
        #expect(StatusText.text(daysRemaining: days, isHandled: false, language: .en) == expected)
    }

    @Test(arguments: zip(
        [12, 2, 1, 0, -1, -3],
        ["12 gün kaldı", "2 gün kaldı", "Yarın bitiyor", "Bugün bitiyor", "1 gün geçti", "3 gün geçti"]))
    func turkish(days: Int, expected: String) {
        #expect(StatusText.text(daysRemaining: days, isHandled: false, language: .tr) == expected)
    }

    @Test func handled() {
        #expect(StatusText.text(daysRemaining: -5, isHandled: true, language: .en) == "Waiting for new date")
        #expect(StatusText.text(daysRemaining: -5, isHandled: true, language: .tr) == "Yeni tarih bekleniyor")
    }
}
