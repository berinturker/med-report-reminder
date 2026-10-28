import Foundation
import Testing
import MedReportKit
@testable import MedReport

@MainActor
@Suite("Destination")
struct DestinationTests {

    @Test func forItemRoutesByKind() throws {
        let c = try makeContainer()
        let context = c.mainContext
        let r = Report(title: "R", endDate: date(2026, 12, 1))
        let linked = Medication(name: "Linked", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7, report: r)
        let unlinked = Medication(name: "Unlinked", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        context.insert(r)
        context.insert(linked)
        context.insert(unlinked)
        try context.save()

        #expect(Destination.forItem(kind: .report, id: r.id, in: context) == .reportDetail(r.id))
        #expect(Destination.forItem(kind: .medication, id: linked.id, in: context) == .reportDetail(r.id))
        #expect(Destination.forItem(kind: .medication, id: unlinked.id, in: context) == .medicationForm(unlinked.id))
        #expect(Destination.forItem(kind: .report, id: uuid(99), in: context) == .home)
        #expect(Destination.forItem(kind: .medication, id: uuid(99), in: context) == .home)
    }

    @Test func resolvedDestinationOfDeletedItemIsHome() throws {
        let c = try makeContainer()
        let context = c.mainContext
        let r = Report(title: "R", endDate: date(2026, 12, 1))
        let m = Medication(name: "M", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        context.insert(r)
        context.insert(m)
        try context.save()
        let reportID = r.id
        let medicationID = m.id
        context.delete(r)
        context.delete(m)
        try context.save()

        #expect(Destination.reportDetail(reportID).resolved(in: context) == .home)
        #expect(Destination.renewal(reportID).resolved(in: context) == .home)
        #expect(Destination.medicationForm(medicationID).resolved(in: context) == .home)
    }

    @Test func resolvedKeepsExistingItems() throws {
        let c = try makeContainer()
        let context = c.mainContext
        let r = Report(title: "R", endDate: date(2026, 12, 1))
        let m = Medication(name: "M", lastPickupDate: date(2026, 10, 1), supplyDays: 30, leadDays: 7)
        context.insert(r)
        context.insert(m)
        try context.save()

        #expect(Destination.reportDetail(r.id).resolved(in: context) == .reportDetail(r.id))
        #expect(Destination.renewal(r.id).resolved(in: context) == .renewal(r.id))
        #expect(Destination.medicationForm(m.id).resolved(in: context) == .medicationForm(m.id))
        #expect(Destination.home.resolved(in: context) == .home)
    }
}
