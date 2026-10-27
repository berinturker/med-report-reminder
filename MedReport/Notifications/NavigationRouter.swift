import Foundation
import Observation

/// A screen to open after the user taps a notification (spec 8.2).
enum Destination: Equatable, Sendable {
    case reportDetail(UUID)
    case medicationForm(UUID)
    case renewal(UUID)
    case home
}

/// Keeps the screen to open. The home view reads `pending` and clears it (Plan 3).
@MainActor
@Observable
final class NavigationRouter {
    var pending: Destination?
}
