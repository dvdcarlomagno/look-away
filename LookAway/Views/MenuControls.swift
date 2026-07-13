import AppKit
import SwiftUI

struct HoldToConfirmButton: View {
    let title: String
    let holdingTitle: String
    let systemImage: String
    var holdDuration: TimeInterval = LookAwayMetrics.holdConfirmDuration
    var role: ButtonRole?
    var compact: Bool = false
    var centered: Bool = false
    var overlayGlass: Bool = false
    let onConfirm: () -> Void

    @State private var holdProgress: Double = 0
    @State private var isHolding = false
    @State private var holdTimer: Timer?

    private var cornerRadius: CGFloat { MenuPanelMetrics.cornerRadius }
    private var verticalPadding: CGFloat { MenuPanelMetrics.controlVerticalPadding }
    private var horizontalPadding: CGFloat { MenuPanelMetrics.controlHorizontalPadding }

    var body: some View {
        Button {
            // Tap alone does nothing — hold required.
        } label: {
            Label(isHolding ? holdingTitle : title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: centered ? .center : .leading)
                .font(MenuPanelMetrics.controlFont)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, horizontalPadding)
                .padding(.vertical, verticalPadding)
                .overlay(alignment: .leading) {
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(progressFillColor.opacity(0.22))
                            .frame(width: geometry.size.width * holdProgress, height: geometry.size.height)
                    }
                    .allowsHitTesting(false)
                }
                .lookAwayGlassSurface(cornerRadius: cornerRadius, tint: glassTint, interactive: true)
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
            return overlayGlass ? Color(red: 1, green: 0.55, blue: 0.52) : .red
        default:
            return overlayGlass ? .white : .primary
        }
    }

    private var glassTint: Color? {
        if overlayGlass {
            return role == .destructive
                ? LookAwayGlass.overlayDestructiveTint
                : LookAwayGlass.overlayTint
        }
        return role == .destructive
            ? Color.red.opacity(0.08)
            : LookAwayGlass.menuPanelTint
    }

    private var progressFillColor: Color {
        role == .destructive ? .red : LookAwayBrand.accent
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
        HStack(spacing: compact ? 4 : 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: compact ? MenuPanelMetrics.stepperIconSize : 12, weight: .semibold))
                .foregroundStyle(count > 0 ? LookAwayBrand.accent : Color.secondary.opacity(0.5))

            Text("\(count)")
                .font(MenuPanelMetrics.valueFont)
                .monospacedDigit()
                .foregroundStyle(count > 0 ? .primary : .secondary)
        }
        .padding(.horizontal, compact ? 8 : 10)
        .padding(.vertical, compact ? 4 : 6)
        .lookAwayCapsuleSurface(tint: LookAwayGlass.menuPanelTint)
        .accessibilityLabel("\(count) consecutive breaks")
    }
}

/// Menu bar action buttons — liquid glass with interactive press feedback.

struct ConfigNumberRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let unit: String
    var compact: Bool = false
    var showsSubtitle: Bool = true

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if compact {
                HStack(spacing: MenuPanelMetrics.spacing) {
                    compactTitle

                    compactStepper
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(MenuPanelMetrics.controlFont)
                        Text(subtitle)
                            .font(MenuPanelMetrics.controlFont)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 10) {
                        Spacer(minLength: 0)

                        stepperButton(systemName: "minus") {
                            applyValue(value - step(for: value))
                        }

                        valueEditor()

                        stepperButton(systemName: "plus") {
                            applyValue(value + step(for: value))
                        }

                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .padding(.horizontal, MenuPanelMetrics.rowHorizontalPadding)
        .padding(.vertical, MenuPanelMetrics.rowVerticalPadding)
        .lookAwayGlassSurface(cornerRadius: MenuPanelMetrics.cornerRadius)
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

    private var compactTitle: some View {
        Group {
            if showsSubtitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(MenuPanelMetrics.controlFont)
                    Text(subtitle)
                        .font(MenuPanelMetrics.controlFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text(title)
                    .font(MenuPanelMetrics.controlFont)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactStepper: some View {
        HStack(spacing: MenuPanelMetrics.spacing) {
            stepperButton(systemName: "minus", size: MenuPanelMetrics.stepperSize) {
                applyValue(value - step(for: value))
            }

            valueEditor(compact: true)

            stepperButton(systemName: "plus", size: MenuPanelMetrics.stepperSize) {
                applyValue(value + step(for: value))
            }
        }
    }

    private func valueEditor(compact: Bool = false) -> some View {
        HStack(spacing: 4) {
            TextField("", text: $textValue)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .frame(width: valueFieldWidth)
                .font(MenuPanelMetrics.valueFont)
                .focused($isFocused)
                .onSubmit(commitTextValue)

            Text(unit)
                .font(MenuPanelMetrics.valueFont)
                .foregroundStyle(.secondary)
                .fixedSize()
        }
        .frame(minWidth: compact ? 64 : 72)
        .padding(.horizontal, MenuPanelMetrics.controlHorizontalPadding * 0.75)
        .padding(.vertical, MenuPanelMetrics.controlVerticalPadding * 0.55)
        .lookAwayGlassSurface(
            cornerRadius: LookAwayGlass.insetCornerRadius,
            tint: LookAwayGlass.menuPanelTint
        )
    }

    private var valueFieldWidth: CGFloat {
        max(28, CGFloat(max(2, textValue.count)) * 10)
    }

    private func stepperButton(systemName: String, size: CGFloat = MenuPanelMetrics.stepperSize, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: MenuPanelMetrics.stepperIconSize, weight: .bold))
                .frame(width: size, height: size)
                .contentShape(Circle())
        }
        .buttonStyle(.borderless)
        .lookAwayCapsuleSurface(tint: LookAwayGlass.menuPanelTint)
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

struct ConfigSegmentedRow<T: Hashable & Identifiable>: View where T: CaseIterable {
    let title: String
    let subtitle: String
    @Binding var selection: T
    let options: [T]
    let label: (T) -> String
    var compact: Bool = false
    var showsSubtitle: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? MenuPanelMetrics.spacing : 8) {
            Group {
                if showsSubtitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(MenuPanelMetrics.controlFont)
                        Text(subtitle)
                            .font(MenuPanelMetrics.controlFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 1 : nil)
                    }
                } else {
                    Text(title)
                        .font(MenuPanelMetrics.controlFont)
                        .lineLimit(1)
                }
            }

            Picker("", selection: $selection) {
                ForEach(options) { option in
                    Text(label(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .font(MenuPanelMetrics.controlFont)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MenuPanelMetrics.rowHorizontalPadding)
        .padding(.vertical, MenuPanelMetrics.rowVerticalPadding)
        .lookAwayGlassSurface(cornerRadius: MenuPanelMetrics.cornerRadius)
    }
}

struct ConfigSecureFieldRow: View {
    let title: String
    let subtitle: String
    @Binding var text: String
    var placeholder: String = ""
    var compact: Bool = false
    var showsSubtitle: Bool = true
    var isFocused: FocusState<Bool>.Binding
    var onCommit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? MenuPanelMetrics.spacing : 8) {
            Group {
                if showsSubtitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(MenuPanelMetrics.controlFont)
                        Text(subtitle)
                            .font(MenuPanelMetrics.controlFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 2 : nil)
                    }
                } else {
                    Text(title)
                        .font(MenuPanelMetrics.controlFont)
                        .lineLimit(1)
                }
            }

            SecureField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(MenuPanelMetrics.controlFont)
                .focused(isFocused)
                .onSubmit(onCommit)
                .padding(.horizontal, MenuPanelMetrics.controlHorizontalPadding)
                .padding(.vertical, MenuPanelMetrics.controlVerticalPadding * 0.75)
                .lookAwayGlassSurface(
                    cornerRadius: LookAwayGlass.insetCornerRadius,
                    tint: LookAwayGlass.menuPanelTint
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MenuPanelMetrics.rowHorizontalPadding)
        .padding(.vertical, MenuPanelMetrics.rowVerticalPadding)
        .lookAwayGlassSurface(cornerRadius: MenuPanelMetrics.cornerRadius)
        .onChange(of: isFocused.wrappedValue) { _, focused in
            if !focused {
                onCommit()
            }
        }
    }
}

struct ConfigToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var compact: Bool = false
    var showsSubtitle: Bool = true

    var body: some View {
        HStack(spacing: MenuPanelMetrics.spacing) {
            Group {
                if showsSubtitle {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(MenuPanelMetrics.controlFont)
                        Text(subtitle)
                            .font(MenuPanelMetrics.controlFont)
                            .foregroundStyle(.secondary)
                            .lineLimit(compact ? 1 : nil)
                    }
                } else {
                    Text(title)
                        .font(MenuPanelMetrics.controlFont)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.regular)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, MenuPanelMetrics.rowHorizontalPadding)
        .padding(.vertical, MenuPanelMetrics.rowVerticalPadding)
        .lookAwayGlassSurface(cornerRadius: MenuPanelMetrics.cornerRadius)
    }
}
