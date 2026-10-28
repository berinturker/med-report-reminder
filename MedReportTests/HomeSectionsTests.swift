import Foundation
import Testing
import MedReportKit
@testable import MedReport

@MainActor
@Suite("HomeSections")
struct HomeSectionsTests {
    private let now = date(2026, 10, 27)

    @Test func reportsByEndDateAndArchivedApart() throws {
        let c = try makeContainer()
        let a = Report(title: "A", endDate: date(2026, 12, 1))
        let b = Report(title: "B", endDate: date(2026, 11, 1))
        let old = Report(title: "Old", endDate: date(2026, 10, 1))
        old.isArchived = true
        [a, b, old].forEach { c.mainContext.insert($0) }
        let s = HomeSections.make(reports: [a, b, old], medications: [], now: now, calendar: istanbul)
        #expect(s.reports.map(\.title) == ["B", "A"])
        #expect(s.archivedReports.map(\.title) == ["Old"])
    }

    @Test func unlinkedMedicationsBySupplyEnd() throws {
        let c = try makeContainer()
        let r = Report(title: "R", endDate: date(2026, 12, 1))
        let linked = Medication(name: "Linked", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: r)
        let late = Medication(name: "Late", lastPickupDate: date(2026, 10, 20), supplyDays: 30, leadDays: 7)
        let early = Medication(name: "Early", lastPickupDate: date(2026, 10, 5), supplyDays: 30, leadDays: 7)
        [r].forEach { c.mainContext.insert($0) }
        [linked, late, early].forEach { c.mainContext.insert($0) }
        let s = HomeSections.make(reports: [r], medications: [linked, late, early], now: now, calendar: istanbul)
        #expect(s.unlinkedMedications.map(\.name) == ["Early", "Late"])
        #expect(s.summary.strip.contains { $0.id == linked.id })
    }

    @Test func medicationOfArchivedReportIsNowhere() throws {
        let c = try makeContainer()
        let r = Report(title: "R", endDate: date(2026, 12, 1))
        r.isArchived = true
        let m = Medication(name: "Linked", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: r)
        c.mainContext.insert(r)
        c.mainContext.insert(m)
        let s = HomeSections.make(reports: [r], medications: [m], now: now, calendar: istanbul)
        #expect(s.unlinkedMedications.isEmpty)
        #expect(s.archivedMedications.isEmpty)
        #expect(!s.summary.strip.contains { $0.id == m.id })
    }

    @Test func archiveCountCountsReportsAndUnlinkedMedications() throws {
        let c = try makeContainer()
        let r = Report(title: "R", endDate: date(2026, 12, 1))
        r.isArchived = true
        let m = Medication(name: "M", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        m.isArchived = true
        let linked = Medication(name: "L", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: r)
        [r].forEach { c.mainContext.insert($0) }
        [m, linked].forEach { c.mainContext.insert($0) }
        let s = HomeSections.make(reports: [r], medications: [m, linked], now: now, calendar: istanbul)
        #expect(s.archiveCount == 2)
    }

    @Test func sectionsUseTheGivenNow() throws {
        let c = try makeContainer()
        let r = Report(title: "R", endDate: date(2026, 10, 28))
        c.mainContext.insert(r)
        let before = date(2026, 10, 27, 23, 59)
        let after = date(2026, 10, 28, 0, 1)
        let s1 = HomeSections.make(reports: [r], medications: [], now: before, calendar: istanbul)
        let s2 = HomeSections.make(reports: [r], medications: [], now: after, calendar: istanbul)
        #expect(s1.summary.hero?.daysRemaining(now: before, calendar: istanbul) == 1)
        #expect(s2.summary.hero?.daysRemaining(now: after, calendar: istanbul) == 0)
    }
}
