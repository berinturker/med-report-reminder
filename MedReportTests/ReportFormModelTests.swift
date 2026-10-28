import Foundation
import SwiftData
import Testing
import MedReportKit
@testable import MedReport

@MainActor
@Suite("ReportFormModel")
struct ReportFormModelTests {
    private let now = date(2026, 10, 27, 15)

    private func newModel() -> ReportFormModel {
        ReportFormModel(report: nil, defaultLeadDays: 21, now: now, calendar: istanbul)
    }

    @Test func newReportUsesDefaults() {
        let model = newModel()
        #expect(model.original == nil)
        #expect(model.title == "")
        #expect(model.endDate == istanbul.startOfDay(for: now))
        #expect(model.leadDays == 21)
    }

    @Test func titleOfOnlySpacesIsInvalid() {
        let model = newModel()
        model.title = "   "
        #expect(!model.isValid)
        model.title = "Tansiyon raporu"
        #expect(model.isValid)
        model.leadDays = 91
        #expect(!model.isValid)
    }

    @Test func applyTrimsTitleAndPerson() throws {
        let container = try makeContainer()
        let model = newModel()
        model.title = "  Tansiyon raporu "
        model.personName = " Babam "
        let report = model.apply(to: container.mainContext)
        #expect(report.title == "Tansiyon raporu")
        #expect(report.personName == "Babam")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Report>()) == 1)
    }

    @Test func editWithoutApplyLeavesReportUnchanged() throws {
        let container = try makeContainer()
        let report = Report(title: "Eski", personName: "Annem", endDate: date(2026, 11, 5), leadDays: 10)
        container.mainContext.insert(report)
        let model = ReportFormModel(report: report, defaultLeadDays: 21, now: now, calendar: istanbul)
        #expect(model.title == "Eski")
        model.title = "Yeni"
        model.endDate = date(2027, 1, 1)
        model.leadDays = 30
        #expect(report.title == "Eski")
        #expect(report.endDate == date(2026, 11, 5))
        #expect(report.leadDays == 10)
    }

    @Test func applyUpdatesTheOriginal() throws {
        let container = try makeContainer()
        let report = Report(title: "Eski", endDate: date(2026, 11, 5), leadDays: 10)
        container.mainContext.insert(report)
        let id = report.id
        let model = ReportFormModel(report: report, defaultLeadDays: 21, now: now, calendar: istanbul)
        model.title = "Yeni"
        model.endDate = date(2027, 1, 1)
        model.leadDays = 30
        model.notes = "not"
        let result = model.apply(to: container.mainContext)
        #expect(result === report)
        #expect(report.id == id)
        #expect(report.title == "Yeni")
        #expect(report.endDate == date(2027, 1, 1))
        #expect(report.leadDays == 30)
        #expect(report.notes == "not")
        #expect(try container.mainContext.fetchCount(FetchDescriptor<Report>()) == 1)
    }

    @Test func pastEndDateIsDetected() {
        let model = newModel()
        model.endDate = date(2026, 10, 26)
        #expect(model.endDateIsPast(now: now, calendar: istanbul))
        model.endDate = date(2026, 10, 27)
        #expect(!model.endDateIsPast(now: now, calendar: istanbul))
    }

    @Test func suggestionsFollowTypedName() {
        let model = newModel()
        model.personName = "Ba"
        let usages = [NameUsage(name: "Babam", usedAt: date(2026, 1, 1)),
                      NameUsage(name: "Annem", usedAt: date(2026, 1, 2))]
        #expect(model.suggestions(from: usages) == ["Babam"])
    }

    @Test func nameUsagesSkipLinkedMedications() throws {
        let container = try makeContainer()
        let report = Report(title: "R", personName: "Babam", endDate: date(2026, 11, 5))
        let linked = Medication(name: "A", personName: "X", lastPickupDate: date(2026, 10, 1),
                                supplyDays: 30, leadDays: 7, report: report)
        let unlinked = Medication(name: "B", personName: "Annem", lastPickupDate: date(2026, 10, 1),
                                  supplyDays: 30, leadDays: 7)
        let usages = nameUsages(reports: [report], medications: [linked, unlinked])
        #expect(Set(usages.map(\.name)) == ["Babam", "Annem"])
        #expect(usages.count == 2)
        _ = container
    }

    @Test func changingTheEndDateOfAHandledReportStartsANewCycle() throws {
        let container = try makeContainer()
        let report = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        report.markHandled(at: date(2026, 10, 27))
        report.snoozeUntil = date(2026, 10, 27, 18)
        container.mainContext.insert(report)
        let model = ReportFormModel(report: report, defaultLeadDays: 21, now: now, calendar: istanbul)
        model.endDate = date(2027, 11, 5)
        model.apply(to: container.mainContext)
        #expect(!report.isHandled)
        #expect(report.handledAt == nil)
        #expect(report.snoozeUntil == nil)
        #expect(report.endDate == date(2027, 11, 5))
    }

    @Test func editingAHandledReportWithoutANewEndDateKeepsItHandled() throws {
        let container = try makeContainer()
        let report = Report(title: "Tansiyon raporu", endDate: date(2026, 11, 5))
        report.markHandled(at: date(2026, 10, 27))
        container.mainContext.insert(report)
        let model = ReportFormModel(report: report, defaultLeadDays: 21, now: now, calendar: istanbul)
        model.title = "Şeker raporu"
        model.apply(to: container.mainContext)
        #expect(report.isHandled)
        #expect(report.handledAt == date(2026, 10, 27))
        #expect(report.title == "Şeker raporu")
    }
}
