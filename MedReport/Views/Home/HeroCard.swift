import SwiftUI
import MedReportKit

/// The most urgent item, large, with its primary button (spec 9.3).
struct HeroCard: View {
    let item: ReminderItem
    let now: Date
    let calendar: Calendar
    let isWorking: Bool
    let onOpen: () -> Void
    let onAction: (PrimaryAction) -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var ringSize: CGFloat = 96

    var body: some View {
        let days = item.daysRemaining(now: now, calendar: calendar)
        let state = item.state(now: now, calendar: calendar)
        let action = item.primaryAction(now: now, calendar: calendar)
        VStack(spacing: 16) {
            Button(action: onOpen) {
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        if !item.personName.isEmpty {
                            Text(item.personName).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Text(item.title).font(Theme.rounded(.title3)).foregroundStyle(.primary)
                        if action == .enterDate {
                            Text("Enter the new end date").font(Theme.rounded(.headline)).foregroundStyle(.primary)
                        } else {
                            Text(verbatim: "\(days)").font(Theme.rounded(.largeTitle)).foregroundStyle(.primary)
                        }
                        StatusBadge(daysRemaining: days, isHandled: item.isHandled, state: state)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    RingView(progress: item.progress(now: now, calendar: calendar), state: state, centerText: nil)
                        .frame(width: ringSize, height: ringSize)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let action {
                Button { onAction(action) } label: { label(for: action) }
                    .buttonStyle(PrimaryPillButtonStyle())
                    .disabled(isWorking)
            }
        }
        .padding(16)
        .card()
    }

    private func label(for action: PrimaryAction) -> Text {
        switch action {
        case .renewed: Text("Renewed")
        case .pickedUp: Text("Picked up")
        case .enterDate: Text("Enter date")
        }
    }
}
