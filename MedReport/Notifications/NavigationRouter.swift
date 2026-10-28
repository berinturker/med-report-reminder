import Foundation
import Observation
import SwiftData
import MedReportKit

/// A screen to open after the user taps a notification or an item (spec 8.2).
/// It holds ids, never models, so a deleted item cannot be read from the navigation path.
enum Destination: Hashable, Sendable {
    case reportDetail(UUID)
    case medicationForm(UUID)
    case renewal(UUID)
    case home
}

extension Destination {
    /// The screen for one item (spec 8.2): report → .reportDetail; medication → its report's detail,
    /// or .medicationForm when it has no report; an id that does not exist → .home.
    @MainActor static func forItem(kind: ReminderItem.Kind, id: UUID, in context: ModelContext) -> Destination {
        switch kind {
        case .report:
            return Report.find(id, in: context) == nil ? .home : .reportDetail(id)
        case .medication:
            guard let medication = Medication.find(id, in: context) else { return .home }
            if let reportID = medication.report?.id { return .reportDetail(reportID) }
            return .medicationForm(id)
        }
    }

    /// .home when the report or medication of this destination does not exist (Plan 2 follow-up).
    @MainActor func resolved(in context: ModelContext) -> Destination {
        switch self {
        case .reportDetail(let id), .renewal(let id):
            Report.find(id, in: context) == nil ? .home : self
        case .medicationForm(let id):
            Medication.find(id, in: context) == nil ? .home : self
        case .home:
            .home
        }
    }
}

extension Report {
    /// The stored report with this id, or nil.
    @MainActor static func find(_ id: UUID, in context: ModelContext) -> Report? {
        try? context.fetch(FetchDescriptor<Report>(predicate: #Predicate { $0.id == id })).first
    }
}

extension Medication {
    /// The stored medication with this id, or nil.
    @MainActor static func find(_ id: UUID, in context: ModelContext) -> Medication? {
        try? context.fetch(FetchDescriptor<Medication>(predicate: #Predicate { $0.id == id })).first
    }
}

/// Keeps the screen to open. The home view reads `pending` and clears it.
@MainActor
@Observable
final class NavigationRouter {
    var pending: Destination?
}
