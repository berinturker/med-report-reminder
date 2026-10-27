import Foundation
import Observation
import MedReportKit

/// User settings in `UserDefaults` (spec 6.4). Each property reads and writes `defaults`
/// directly, so two instances on the same suite always agree. Out-of-range stored values
/// are clamped when read (spec 12).
@MainActor
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private enum Key {
        static let notificationHour = "notificationHour"
        static let notificationMinute = "notificationMinute"
        static let defaultReportLeadDays = "defaultReportLeadDays"
        static let defaultMedicationLeadDays = "defaultMedicationLeadDays"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isFastModeOn = "isFastModeOn"
    }

    var notificationHour: Int {
        get { access(keyPath: \.notificationHour); return int(Key.notificationHour, default: 10, in: 0...23) }
        set { withMutation(keyPath: \.notificationHour) { defaults.set(newValue, forKey: Key.notificationHour) } }
    }

    var notificationMinute: Int {
        get { access(keyPath: \.notificationMinute); return int(Key.notificationMinute, default: 0, in: 0...59) }
        set { withMutation(keyPath: \.notificationMinute) { defaults.set(newValue, forKey: Key.notificationMinute) } }
    }

    var defaultReportLeadDays: Int {
        get { access(keyPath: \.defaultReportLeadDays); return int(Key.defaultReportLeadDays, default: 18, in: 0...90) }
        set { withMutation(keyPath: \.defaultReportLeadDays) { defaults.set(newValue, forKey: Key.defaultReportLeadDays) } }
    }

    var defaultMedicationLeadDays: Int {
        get { access(keyPath: \.defaultMedicationLeadDays); return int(Key.defaultMedicationLeadDays, default: 7, in: 0...90) }
        set { withMutation(keyPath: \.defaultMedicationLeadDays) { defaults.set(newValue, forKey: Key.defaultMedicationLeadDays) } }
    }

    var hasCompletedOnboarding: Bool {
        get { access(keyPath: \.hasCompletedOnboarding); return defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { withMutation(keyPath: \.hasCompletedOnboarding) { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) } }
    }

    var isFastModeOn: Bool {
        get { access(keyPath: \.isFastModeOn); return defaults.bool(forKey: Key.isFastModeOn) }
        set { withMutation(keyPath: \.isFastModeOn) { defaults.set(newValue, forKey: Key.isFastModeOn) } }
    }

    func plannerSettings(language: AppLanguage) -> PlannerSettings {
        PlannerSettings(notificationHour: notificationHour, notificationMinute: notificationMinute, language: language)
    }

    private func int(_ key: String, default value: Int, in range: ClosedRange<Int>) -> Int {
        let stored = defaults.object(forKey: key) as? Int ?? value
        return min(max(stored, range.lowerBound), range.upperBound)
    }
}
