import Foundation
import Testing
@testable import MedReport

@Suite("Smoke")
struct SmokeTests {
    @Test func appModuleLoads() {
        #expect(Bundle.main.bundleIdentifier != nil)
        #expect(AppEnvironment.isHostingUnitTests)
    }
}
