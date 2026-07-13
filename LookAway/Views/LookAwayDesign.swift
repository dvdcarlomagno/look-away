import SwiftUI

enum LookAwayBrand {
    /// Single app accent — warm pink
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.78)
    /// Softer pink for glass tints and highlights
    static let accentSoft = Color(red: 1.0, green: 0.74, blue: 0.90)

    static var pink: Color { accent }
    static var pinkSoft: Color { accentSoft }
}

enum LookAwayMetrics {
    static let holdConfirmDuration: TimeInterval = 11
}

enum MenuPanelMetrics {
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

    var body: some View {
        Text(text)
            .font(MenuPanelMetrics.controlFont)
            .foregroundStyle(LookAwayBrand.accent)
            .padding(.horizontal, MenuPanelMetrics.controlHorizontalPadding * 0.65)
            .padding(.vertical, MenuPanelMetrics.controlVerticalPadding * 0.45)
            .lookAwayCapsuleSurface(tint: LookAwayGlass.accentTint())
    }
}
