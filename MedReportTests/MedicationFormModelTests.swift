import Foundation
import SwiftData
import Testing
import MedReportKit
@testable import MedReport

@MainActor
@Suite("MedicationFormModel")
struct MedicationFormModelTests {
    private let now = date(2026, 10, 27, 15)

    private func newModel(report: Report? = nil) -> MedicationFormModel {
        MedicationFormModel(medication: nil, preselectedReport: report, defaultLeadDays: 7, now: now, calendar: istanbul)
    }

    @Test func newMedicationDefaults() throws {
        let container = try makeContainer()
        let report = Report(title: "R", personName: "Babam", endDate: date(2026, 12, 1), leadDays: 18)
        container.mainContext.insert(report)
        let model = newModel(report: report)
        #expect(model.original == nil)
        #expect(model.supplyDays == 30)
        #expect(model.leadDays == 7)
        #expect(model.lastPickupDate == istanbul.startOfDay(for: now))
        #expect(model.report === report)
        #expect(!model.showsPersonField)
        #expect(newModel().showsPersonField)
    }

    @Test func previewIsPickupPlusSupply() {
        let model = newModel()
        model.lastPickupDate = date(2026, 10, 1)
        model.supplyDays = 60
        #expect(model.previewEndDate(calendar: istanbul) == istanbul.startOfDay(for: date(2026, 11, 30)))
    }

    @Test func validation() {
        let model = newModel()
        model.name = "  "
        #expect(!model.isValid)
        model.name = "Diltiazem"
        #expect(model.isValid)
        model.supplyDays = 0
        #expect(!model.isValid)
        model.supplyDays = 366
        #expect(!model.isValid)
        model.supplyDays = 365
        #expect(model.isValid)
        model.leadDays = 91
        #expect(!model.isValid)
    }

    @Test func linkingAReportClearsOwnPerson() throws {
        let container = try makeContainer()
        let report = Report(title: "R", personName: "Annem", endDate: date(2026, 12, 1), leadDays: 18)
        container.mainContext.insert(report)
        let model = newModel()
        model.name = " Diltiazem "
        model.personName = "Babam"
        model.report = report
        let med = model.apply(to: container.mainContext, calendar: istanbul)
        #expect(med.name == "Diltiazem")
        #expect(med.personName == "")
        #expect(med.report === report)
    }

    @Test func unlinkingUsesOwnPerson() throws {
        let container = try makeContainer()
        let report = Report(title: "R", personName: "Annem", endDate: date(2026, 12, 1), leadDays: 18)
        container.mainContext.insert(report)
        let existing = Medication(name: "M", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: report)
        container.mainContext.insert(existing)
        let model = MedicationFormModel(medication: existing, preselectedReport: nil, defaultLeadDays: 7,
                                        now: now, calendar: istanbul)
        #expect(model.report === report)
        model.report = nil
        model.personName = " Annem "
        let med = model.apply(to: container.mainContext, calendar: istanbul)
        #expect(med === existing)
        #expect(med.report == nil)
        #expect(med.personName == "Annem")
        #expect(med.effectivePersonName == "Annem")
    }

    @Test func editWithoutApplyLeavesMedicationUnchanged() throws {
        let container = try makeContainer()
        let existing = Medication(name: "M", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        container.mainContext.insert(existing)
        let model = MedicationFormModel(medication: existing, preselectedReport: nil, defaultLeadDays: 3,
                                        now: now, calendar: istanbul)
        #expect(model.leadDays == 7)
        model.name = "Other"
        model.supplyDays = 90
        #expect(existing.name == "M")
        #expect(existing.supplyDays == 30)
    }

    @Test func applyStoresPickupAsStartOfDay() throws {
        let container = try makeContainer()
        let model = newModel()
        model.name = "M"
        model.lastPickupDate = date(2026, 10, 20, 15, 30)
        let med = model.apply(to: container.mainContext, calendar: istanbul)
        #expect(med.lastPickupDate == istanbul.startOfDay(for: date(2026, 10, 20, 15, 30)))
    }
}
