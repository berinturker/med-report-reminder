import Foundation
import Testing
import MedReportKit
@testable import MedReport

@MainActor
@Suite("AppSettings")
struct AppSettingsTests {
    private func fresh() -> UserDefaults {
        UserDefaults(suiteName: "test-\(UUID().uuidString)")!
    }

    @Test func defaultsMatchSpec() {
        let s = AppSettings(defaults: fresh())
        #expect(s.notificationHour == 10 && s.notificationMinute == 0)
        #expect(s.defaultReportLeadDays == 18 && s.defaultMedicationLeadDays == 7)
        #expect(!s.hasCompletedOnboarding && !s.isFastModeOn)
    }

    @Test func valuesPersistAcrossInstances() {
        let d = fresh()
        AppSettings(defaults: d).notificationHour = 8
        #expect(AppSettings(defaults: d).notificationHour == 8)
    }

    @Test func outOfRangeStoredTimeIsClamped() {
        let d = fresh()
        d.set(99, forKey: "notificationHour")
        d.set(-4, forKey: "notificationMinute")
        let s = AppSettings(defaults: d)
        #expect(s.notificationHour == 23 && s.notificationMinute == 0)
        #expect(s.plannerSettings(language: .en) ==
                PlannerSettings(notificationHour: 23, notificationMinute: 0, language: .en))
    }

    @Test func leadDaysAreClampedToSpecRange() {
        let d = fresh()
        d.set(500, forKey: "defaultReportLeadDays")
        d.set(-1, forKey: "defaultMedicationLeadDays")
        let s = AppSettings(defaults: d)
        #expect(s.defaultReportLeadDays == 90 && s.defaultMedicationLeadDays == 0)
    }
}
