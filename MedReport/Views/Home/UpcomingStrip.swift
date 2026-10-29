import SwiftUI
import MedReportKit

/// The most urgent items as small rings in a horizontal row (spec 9.3).
struct UpcomingStrip: View {
    let items: [ReminderItem]
    let now: Date
    let calendar: Calendar
    let onSelect: (ReminderItem) -> Void

    @ScaledMetric(relativeTo: .title2) private var ringSize: CGFloat = 72
    @ScaledMetric(relativeTo: .footnote) private var columnWidth: CGFloat = 104

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(items, id: \.id) { item in
                    let days = item.daysRemaining(now: now, calendar: calendar)
                    let state = item.state(now: now, calendar: calendar)
                    Button { onSelect(item) } label: {
                        VStack(spacing: 6) {
                            RingView(progress: item.progress(now: now, calendar: calendar), state: state,
                                     centerText: "\(days)")
                                .frame(width: ringSize, height: ringSize)
                            Text(item.title)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            StatusBadge(daysRemaining: days, isHandled: item.isHandled, state: state)
                        }
                        .frame(width: columnWidth)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}
