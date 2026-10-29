import SwiftUI
import MedReportKit

struct RingView: View {
    let progress: Double
    let state: ReminderState
    let centerText: String?

    init(progress: Double, state: ReminderState, centerText: String?) {
        self.progress = progress
        self.state = state
        self.centerText = centerText
    }

    var body: some View {
        ZStack {
            Circle().stroke(state.color.opacity(0.2), lineWidth: 10)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(state.color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let centerText {
                Text(centerText)
                    .font(Theme.rounded(.title2))
                    .foregroundStyle(.primary)
            }
        }
        .padding(5)
    }
}
