import AppKit
import SwiftUI

struct HoldToConfirmButton: View {
    let title: String
    let holdingTitle: String
    let systemImage: String
    var holdDuration: TimeInterval = 5
    var role: ButtonRole?
    var compact: Bool = false
    var centered: Bool = false
    let onConfirm: () -> Void

    @State private var holdProgress: Double = 0
    @State private var isHolding = false
    @State private var holdTimer: Timer?

    private var cornerRadius: CGFloat { compact ? 8 : 10 }
    private var verticalPadding: CGFloat { compact ? 5 : 9 }
    private var horizontalPadding: CGFloat { compact ? 10 : 12 }

    var body: some View {
        Button {
            // Tap alone does nothing — hold required.
        } label: {
            Label(isHolding ? holdingTitle : title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                .font(.system(compact ? .caption : .body, design: .rounded, weight: .medium))
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.primary.opacity(isHolding ? 0.12 : 0.08))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                        }
                }
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(progressFillColor.opacity(0.22))
                            .frame(width: geometry.size.width * holdProgress, height: geometry.size.height)
                    }
                    .allowsHitTesting(false)
                }
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: false, vertical: true)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isHolding {
                        beginHold()
                    }
                }
                .onEnded { _ in
                    cancelHold()
                }
        )
    }

    private var foregroundColor: Color {
        switch role {
        case .destructive:
            return .red
        default:
            return .primary
        }
    }

    private var progressFillColor: Color {
        role == .destructive ? .red : LookAwayBrand.pink
    }

    private func beginHold() {
        isHolding = true
        holdProgress = 0
        let start = Date()
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            Task { @MainActor in
                let elapsed = Date().timeIntervalSince(start)
                let progress = min(1, elapsed / holdDuration)
                holdProgress = progress
                if progress >= 1 {
                    timer.invalidate()
                    holdTimer = nil
                    isHolding = false
                    holdProgress = 0
                    onConfirm()
                }
            }
        }
        if let holdTimer {
            RunLoop.main.add(holdTimer, forMode: .common)
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        isHolding = false
        holdProgress = 0
    }
}

struct StreakBadge: View {
    let count: Int
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 3 : 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: compact ? 10 : 12, weight: .semibold))
                .foregroundStyle(count > 0 ? Color.orange : Color.secondary.opacity(0.5))

            Text("\(count)")
                .font(.system(size: compact ? 11 : 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
        .accessibilityLabel("\(count) consecutive breaks")
    }
}

struct MenuActionButtonStyle: ButtonStyle {
    var role: ButtonRole?
    var centered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .medium))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
            .padding(.horizontal, centered ? 8 : 12)
            .padding(.vertical, 9)
            .background(background(isPressed: configuration.isPressed))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var foregroundColor: Color {
        switch role {
        case .destructive:
            return .red
        default:
            return .primary
        }
    }

    @ViewBuilder
    private func background(isPressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.primary.opacity(isPressed ? 0.14 : 0.08))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
            }
    }
}

struct ConfigNumberRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Spacer(minLength: 0)

                stepperButton(systemName: "minus") {
                    applyValue(value - step(for: value))
                }

                valueEditor

                stepperButton(systemName: "plus") {
                    applyValue(value + step(for: value))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .lookAwaySurface()
        .onAppear {
            textValue = "\(value)"
        }
        .onChange(of: value) { _, newValue in
            if !isFocused {
                textValue = "\(newValue)"
            }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                commitTextValue()
            }
        }
    }

    private var valueEditor: some View {
        HStack(spacing: 3) {
            TextField("", text: $textValue)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: valueFieldWidth)
                .focused($isFocused)
                .onSubmit(commitTextValue)

            Text(unit)
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .frame(minWidth: 72)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        }
    }

    private var valueFieldWidth: CGFloat {
        max(28, CGFloat(max(2, textValue.count)) * 10)
    }

    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
                .frame(width: 28, height: 28)
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .background {
            Circle()
                .fill(Color.primary.opacity(0.08))
        }
    }

    private func applyValue(_ newValue: Int) {
        let clamped = min(max(newValue, range.lowerBound), range.upperBound)
        value = clamped
        textValue = "\(clamped)"
    }

    private func commitTextValue() {
        let trimmed = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Int(trimmed) else {
            textValue = "\(value)"
            return
        }
        applyValue(parsed)
    }

    private func step(for current: Int) -> Int {
        if range.upperBound >= 60 && current >= 15 { return 5 }
        if current >= 10 { return 5 }
        return 1
    }
}

struct ConfigToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded, weight: .medium))
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .lookAwaySurface()
    }
}
