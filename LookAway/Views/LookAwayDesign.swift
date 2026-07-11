import SwiftUI

enum LookAwayBrand {
    /// Primary accent — forest green
    static let forest = Color(red: 0.24, green: 0.45, blue: 0.31)
    /// Secondary — warm wood brown
    static let wood = Color(red: 0.55, green: 0.40, blue: 0.28)
    /// Soft highlight — sage
    static let sage = Color(red: 0.61, green: 0.72, blue: 0.58)
    /// Warm off-white for overlays
    static let cream = Color(red: 0.96, green: 0.94, blue: 0.88)
    /// Deep forest for gradients
    static let forestDeep = Color(red: 0.12, green: 0.22, blue: 0.16)
    /// Warm bark brown for gradients
    static let bark = Color(red: 0.28, green: 0.20, blue: 0.14)

    /// Legacy alias — use `forest` instead
    static var pink: Color { forest }
    static var pinkSoft: Color { sage }
}

enum LookAwayMetrics {
    static let holdConfirmDuration: TimeInterval = 11
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
                    .fill(LookAwayBrand.forest.opacity(0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(LookAwayBrand.forest.opacity(0.12), lineWidth: 0.5)
                    }
            }
    }
}

extension View {
    func lookAwaySurface(cornerRadius: CGFloat = 10) -> some View {
        modifier(LookAwaySurface(cornerRadius: cornerRadius))
    }
}

struct NatureFallbackBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                LookAwayBrand.forestDeep,
                LookAwayBrand.forest.opacity(0.85),
                LookAwayBrand.bark,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [LookAwayBrand.sage.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 480
            )
        }
        .overlay {
            RadialGradient(
                colors: [LookAwayBrand.wood.opacity(0.18), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 420
            )
        }
    }
}
