import SwiftUI
import MedReportKit

/// One row of the Home lists: title, person and state (spec 9.3).
struct ItemCard: View {
    let item: ReminderItem
    let isArchived: Bool
    let now: Date
    let calendar: Calendar

    @ScaledMetric(relativeTo: .body) private var ringSize: CGFloat = 48

    var body: some View {
        let days = item.daysRemaining(now: now, calendar: calendar)
        let state = item.state(now: now, calendar: calendar)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title).font(.headline).foregroundStyle(.primary)
                if !item.personName.isEmpty {
                    Text(item.personName).font(.subheadline).foregroundStyle(.secondary)
                }
                if isArchived {
                    Text("Tracking stopped").font(.footnote).foregroundStyle(.secondary)
                } else {
                    StatusBadge(daysRemaining: days, isHandled: item.isHandled, state: state)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if !isArchived {
                RingView(progress: item.progress(now: now, calendar: calendar), state: state, centerText: nil)
                    .frame(width: ringSize, height: ringSize)
            }
        }
        .padding(16)
        .frame(minHeight: 44)
        .card()
    }
}
