import Foundation
import Testing
import MedReportKit
@testable import MedReport

@MainActor
@Suite("ReminderItem mapping")
struct ReminderItemMappingTests {

    @Test func medicationUsesReportPersonAndSupplyEnd() {
        let r = Report(title: "Tansiyon raporu", personName: "Babam", endDate: date(2027, 1, 1))
        let m = Medication(name: "Beloc", personName: "Yanlış", lastPickupDate: date(2026, 10, 1),
                           supplyDays: 30, leadDays: 7, report: r)
        let item = ReminderItem(medication: m, calendar: istanbul)
        #expect(item.kind == .medication && item.id == m.id && item.title == "Beloc")
        #expect(item.personName == "Babam")
        #expect(item.endDate == istanbul.startOfDay(for: date(2026, 10, 31)))
        #expect(item.leadDays == 7)
        #expect(!item.isHandled)
    }

    @Test func reportCopiesHandledAndSnooze() {
        let r = Report(title: "Kardiyoloji", endDate: date(2026, 10, 20))
        r.markHandled(at: date(2026, 10, 21))
        r.snoozeUntil = date(2026, 10, 27, 15)
        let item = ReminderItem(report: r)
        #expect(item.kind == .report && item.id == r.id && item.title == "Kardiyoloji")
        #expect(item.endDate == date(2026, 10, 20) && item.leadDays == 18)
        #expect(item.isHandled && item.handledAt == date(2026, 10, 21))
        #expect(item.snoozeUntil == date(2026, 10, 27, 15))
    }

    @Test func activeExcludesArchivedAndMedicationsOfArchivedReports() {
        let archived = Report(title: "Eski", endDate: date(2027, 1, 1)); archived.isArchived = true
        let open = Report(title: "Tansiyon raporu", endDate: date(2027, 1, 1))
        let m1 = Medication(name: "A", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: archived)
        let m2 = Medication(name: "B", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        let m3 = Medication(name: "C", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7); m3.isArchived = true
        let items = ReminderItem.active(reports: [archived, open], medications: [m1, m2, m3], calendar: istanbul)
        #expect(Set(items.map(\.title)) == ["Tansiyon raporu", "B"])
    }
}
