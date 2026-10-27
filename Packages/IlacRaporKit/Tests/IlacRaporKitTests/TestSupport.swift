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

// MARK: - Item factories

func report(
    _ n: Int, title: String = "Tansiyon raporu", person: String = "Babam",
    end: Date, lead: Int = 18, handledAt: Date? = nil, snooze: Date? = nil
) -> ReminderItem {
    ReminderItem(kind: .report, id: uuid(n), title: title, personName: person, endDate: end,
                 leadDays: lead, isHandled: handledAt != nil, handledAt: handledAt, snoozeUntil: snooze)
}

func medication(
    _ n: Int, name: String = "Beloc", person: String = "Babam",
    end: Date, lead: Int = 7, snooze: Date? = nil
) -> ReminderItem {
    ReminderItem(kind: .medication, id: uuid(n), title: name, personName: person, endDate: end,
                 leadDays: lead, snoozeUntil: snooze)
}

// MARK: - Planner settings

let tenAM = PlannerSettings(notificationHour: 10, notificationMinute: 0, language: .tr)
