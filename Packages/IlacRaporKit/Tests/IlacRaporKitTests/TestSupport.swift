import Foundation
@testable import IlacRaporKit

// MARK: - Calendars and dates

func calendar(_ timeZone: String = "Europe/Istanbul") -> Calendar {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: timeZone)!
    return cal
}

let istanbul = calendar("Europe/Istanbul")

func date(
    _ y: Int, _ m: Int, _ d: Int,
    _ h: Int = 12, _ min: Int = 0,
    in cal: Calendar = istanbul
) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

// MARK: - Identifiers

/// `uuid(1)` → 00000000-0000-0000-0000-000000000001
func uuid(_ n: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
}
