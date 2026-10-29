import Foundation
import MedReportKit

/// Person names of all reports and of medications without a report; `usedAt` = `createdAt` (spec 10).
func nameUsages(reports: [Report], medications: [Medication]) -> [NameUsage] {
    reports.map { NameUsage(name: $0.personName, usedAt: $0.createdAt) }
        + medications.filter { $0.report == nil }.map { NameUsage(name: $0.personName, usedAt: $0.createdAt) }
}
