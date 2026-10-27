import Foundation

/// The reminder state of a report or a medication. It is not saved; the app calculates it each time.
public enum ReminderState: Equatable, CaseIterable, Sendable {
    /// Days remaining > leadDays
    case normal
    /// 0 ≤ days remaining ≤ leadDays
    case reminding
    /// Days remaining < 0
    case overdue
    /// The user tapped "Renewed"; the app waits for the new end date
    case handled

    /// For the sort order on the home screen: the smaller value comes first.
    public var sortPriority: Int {
        switch self {
        case .overdue: 0
        case .reminding: 1
        case .handled: 2
        case .normal: 3
        }
    }

    /// True if the item needs attention (the hero card and the upcoming strip use it).
    public var needsAttention: Bool {
        self != .normal
    }
}
