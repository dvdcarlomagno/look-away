import SwiftUI

enum LookAwayBrand {
    static let pink = Color(red: 1.0, green: 0.42, blue: 0.78)
    static let pinkSoft = Color(red: 1.0, green: 0.74, blue: 0.90)
}

struct LookAwayStatusChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
