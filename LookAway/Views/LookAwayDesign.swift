import SwiftUI

enum LookAwayBrand {
    static let pink = Color(red: 1.0, green: 0.42, blue: 0.78)
    static let pinkSoft = Color(red: 1.0, green: 0.74, blue: 0.90)
}

enum MenuPanelMetrics {
    /// Uniform gap between buttons, settings rows, and panel sections.
    static let spacing: CGFloat = 6
    static let padding: CGFloat = 14
    static let cornerRadius: CGFloat = 10
    static let controlHorizontalPadding: CGFloat = 12
    static let controlVerticalPadding: CGFloat = 9
    static let rowHorizontalPadding: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 8
    static let stepperSize: CGFloat = 28
    static let stepperIconSize: CGFloat = 11

    static var controlFont: Font {
        .system(.body, design: .rounded, weight: .medium)
    }

    static var valueFont: Font {
        .system(.body, design: .rounded, weight: .semibold)
    }

    static var sectionFont: Font {
        .system(.body, design: .rounded, weight: .semibold)
    }
}

struct LookAwayStatusChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(MenuPanelMetrics.controlFont)
            .foregroundStyle(tint)
            .padding(.horizontal, MenuPanelMetrics.controlHorizontalPadding * 0.65)
            .padding(.vertical, MenuPanelMetrics.controlVerticalPadding * 0.45)
            .background {
                Capsule()
                    .fill(tint.opacity(0.14))
            }
    }
}

struct LookAwaySurface: ViewModifier {
    var cornerRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func lookAwaySurface(cornerRadius: CGFloat = 10) -> some View {
        modifier(LookAwaySurface(cornerRadius: cornerRadius))
    }
}
