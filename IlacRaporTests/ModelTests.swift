import Foundation
import SwiftData
import Testing
@testable import IlacRapor

@MainActor
@Suite("Models")
struct ModelTests {

    private let cal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return cal
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    /// Returns the container: SwiftData crashes if the container of a context is released.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Report.self, Medication.self, configurations: config)
    }

    // MARK: Report

    @Test("Report: renewal cycle")
    func reportRenewCycle() {
        let report = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 10))
        let now = date(2026, 10, 27)

        #expect(report.reminderState(now: now, calendar: cal) == .reminding) // 14 days left

        report.markHandled(at: now)
        #expect(report.isHandled)
        #expect(report.handledAt == now)
        #expect(report.reminderState(now: now, calendar: cal) == .handled)

        report.renew(newEndDate: date(2027, 11, 10))
        #expect(!report.isHandled)
        #expect(report.handledAt == nil)
        #expect(report.reminderState(now: now, calendar: cal) == .normal)
    }

    @Test("Saved with a past end date → overdue immediately")
    func reportCreatedWithPastDate() {
        let report = Report(title: "Kardiyoloji", endDate: date(2026, 10, 20))
        #expect(report.reminderState(now: date(2026, 10, 27), calendar: cal) == .overdue)
        #expect(report.daysRemaining(now: date(2026, 10, 27), calendar: cal) == -7)
    }

    // MARK: Medication

    @Test("Medication: supply end and pickup cycle")
    func medicationPickupCycle() {
        let med = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30)
        let now = date(2026, 10, 27)

        #expect(med.daysRemaining(now: now, calendar: cal) == 4)                 // ends on 31 October
        #expect(med.reminderState(now: now, calendar: cal) == .reminding)

        med.markPickedUp(on: date(2026, 10, 27, 18), calendar: cal)
        #expect(med.lastPickupDate == cal.startOfDay(for: now))
        #expect(med.daysRemaining(now: now, calendar: cal) == 30)
        #expect(med.reminderState(now: now, calendar: cal) == .normal)
    }

    @Test("Person name: from the report if linked, else its own")
    func effectivePersonName() {
        let report = Report(title: "Tansiyon", personName: "Babam", endDate: date(2027, 1, 1))
        let linked = Medication(name: "Beloc", personName: "Yanlış", report: report)
        let standalone = Medication(name: "Parol", personName: "Annem")

        #expect(linked.effectivePersonName == "Babam")
        #expect(standalone.effectivePersonName == "Annem")
    }

    // MARK: SwiftData

    @Test("Deleting a report deletes its medications; a medication without a report stays")
    func cascadeDelete() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let report = Report(title: "Tansiyon", endDate: date(2027, 1, 1))
        context.insert(report)
        let linked = Medication(name: "Beloc")
        context.insert(linked)
        linked.report = report
        let standalone = Medication(name: "Parol")
        context.insert(standalone)
        try context.save()

        #expect(report.medications?.count == 1)

        context.delete(report)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Medication>())
        #expect(remaining.map(\.name) == ["Parol"])
        #expect(try context.fetchCount(FetchDescriptor<Report>()) == 0)
    }
}
