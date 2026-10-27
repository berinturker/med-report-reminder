import Foundation
import Testing
@testable import MedReportKit

@Suite("AppLanguage")
struct AppLanguageTests {
    @Test func selectsTurkishOnlyForTr() {
        #expect(AppLanguage.current(preferredLanguages: ["tr-TR", "en-US"]) == .tr)
        #expect(AppLanguage.current(preferredLanguages: ["tr"]) == .tr)
        #expect(AppLanguage.current(preferredLanguages: ["TR-tr"]) == .tr)
        #expect(AppLanguage.current(preferredLanguages: ["en-US", "tr-TR"]) == .en)
        #expect(AppLanguage.current(preferredLanguages: ["de-DE"]) == .en)
        #expect(AppLanguage.current(preferredLanguages: ["zh-Hant-TW"]) == .en)
        #expect(AppLanguage.current(preferredLanguages: ["trv"]) == .en)
        #expect(AppLanguage.current(preferredLanguages: []) == .en)
    }

    @Test func localeIdentifiers() {
        #expect(AppLanguage.en.locale.identifier == "en_US")
        #expect(AppLanguage.tr.locale.identifier == "tr_TR")
    }
}
