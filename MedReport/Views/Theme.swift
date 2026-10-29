import SwiftUI
import MedReportKit

extension ReminderState {
    /// Color shows only the state (spec 6.6).
    var color: Color {
        switch self {
        case .normal: .green
        case .reminding: .orange
        case .overdue: .red
        case .handled: .gray
        }
    }
}

enum Theme {
    /// Numbers and headings use text styles in the rounded design, so Dynamic Type works.
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded, weight: weight)
    }
}

struct CardBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

extension View {
    func card() -> some View { modifier(CardBackground()) }
}

/// The one black pill primary button of a screen.
struct PrimaryPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.rounded(.headline, weight: .semibold))
            .foregroundStyle(Color(.systemBackground))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(Color.primary, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
