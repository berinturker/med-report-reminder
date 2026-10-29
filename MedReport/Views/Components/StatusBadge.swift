import SwiftUI
import MedReportKit

struct StatusBadge: View {
    let daysRemaining: Int
    let isHandled: Bool
    let state: ReminderState

    init(daysRemaining: Int, isHandled: Bool, state: ReminderState) {
        self.daysRemaining = daysRemaining
        self.isHandled = isHandled
        self.state = state
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(state.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Text(StatusText.text(daysRemaining: daysRemaining, isHandled: isHandled,
                                 language: AppEnvironment.currentLanguage))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
