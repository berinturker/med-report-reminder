import Foundation
import SwiftData
@testable import MedReport

let istanbul: Calendar = {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
    return cal
}()

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
    istanbul.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

/// `uuid(1)` → 00000000-0000-0000-0000-000000000001
func uuid(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}

/// In-memory container. Keep a reference to it: SwiftData crashes if the container of a context is released.
@MainActor
func makeContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: Schema(versionedSchema: SchemaV1.self),
                              migrationPlan: MedReportMigrationPlan.self,
                              configurations: config)
}
