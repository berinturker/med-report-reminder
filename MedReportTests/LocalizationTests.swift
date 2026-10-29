import Foundation
import SwiftUI
import Testing
import MedReportKit
@testable import MedReport

@Suite("Localization and theme")
struct LocalizationTests {
    @Test func turkishTranslationIsBundled() throws {
        let path = try #require(Bundle.main.path(forResource: "tr", ofType: "lproj"))
        let tr = try #require(Bundle(path: path))
        #expect(tr.localizedString(forKey: "Reminders", value: nil, table: nil) == "Hatırlatmalar")
    }

    @Test func stateColorsMatchSpec() {
        #expect(ReminderState.normal.color == .green)
        #expect(ReminderState.reminding.color == .orange)
        #expect(ReminderState.overdue.color == .red)
        #expect(ReminderState.handled.color == .gray)
    }
}
