import Foundation
import SwiftData
import Testing
@testable import MedReport

@MainActor
@Suite("Models")
struct ModelTests {

    // MARK: Report

    @Test("Report: renewal cycle")
    func reportRenewCycle() {
        let report = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 10))
        let now = date(2026, 10, 27)

        report.markHandled(at: now)
        #expect(report.isHandled)
        #expect(report.handledAt == now)

        report.renew(newEndDate: date(2027, 11, 10))
        #expect(!report.isHandled)
        #expect(report.handledAt == nil)
        #expect(report.endDate == date(2027, 11, 10))
    }

    @Test func newFieldsHaveDefaults() {
        let r = Report(title: "Tansiyon raporu", endDate: date(2027, 1, 1))
        let m = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        #expect(r.snoozeUntil == nil && r.isArchived == false)
        #expect(m.snoozeUntil == nil && m.isArchived == false)
    }

    // MARK: Medication

    @Test("Medication: supply end and pickup cycle")
    func medicationPickupCycle() {
        let med = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        #expect(med.supplyEndDate(calendar: istanbul) == istanbul.startOfDay(for: date(2026, 10, 31)))

        med.markPickedUp(on: date(2026, 10, 27, 18), calendar: istanbul)
        #expect(med.lastPickupDate == istanbul.startOfDay(for: date(2026, 10, 27)))
        #expect(med.supplyEndDate(calendar: istanbul) == istanbul.startOfDay(for: date(2026, 11, 26)))
    }

    @Test("Person name: from the report if linked, else its own")
    func effectivePersonName() {
        let report = Report(title: "Tansiyon", personName: "Babam", endDate: date(2027, 1, 1))
        let linked = Medication(name: "Beloc", personName: "Yanlış", lastPickupDate: date(2026, 10, 1),
                                supplyDays: 30, leadDays: 7, report: report)
        let standalone = Medication(name: "Parol", personName: "Annem", lastPickupDate: date(2026, 10, 1),
                                    supplyDays: 30, leadDays: 7)
        #expect(linked.effectivePersonName == "Babam")
        #expect(standalone.effectivePersonName == "Annem")
    }

    @Test func archivedReportArchivesItsMedications() {
        let r = Report(title: "Tansiyon raporu", endDate: date(2027, 1, 1))
        let linked = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: r)
        #expect(!linked.isEffectivelyArchived)
        r.isArchived = true
        #expect(linked.isEffectivelyArchived)
        #expect(linked.isArchived == false)   // the record does not change (spec 6.5)
    }

    @Test func pickupAndRenewClearSnooze() {
        let r = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 1))
        r.snoozeUntil = date(2026, 10, 27, 15)
        r.renew(newEndDate: date(2027, 11, 1))
        #expect(r.snoozeUntil == nil)
        let m = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        m.snoozeUntil = date(2026, 10, 27, 15)
        m.markPickedUp(on: date(2026, 10, 27, 18), calendar: istanbul)
        #expect(m.snoozeUntil == nil)
        #expect(m.lastPickupDate == istanbul.startOfDay(for: date(2026, 10, 27)))
    }

    // MARK: SwiftData

    @Test("Deleting a report deletes its medications; a medication without a report stays")
    func cascadeDelete() throws {
        let container = try makeContainer()
        let context = container.mainContext

        let report = Report(title: "Tansiyon", endDate: date(2027, 1, 1))
        context.insert(report)
        let linked = Medication(name: "Beloc", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        context.insert(linked)
        linked.report = report
        let standalone = Medication(name: "Parol", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
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
