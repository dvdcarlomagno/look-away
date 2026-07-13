import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject var engine: TimerEngine
    let onEndBreak: () -> Void

    private var formattedTime: String {
        let total = Int(max(0, engine.remainingSeconds.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                VStack(spacing: 20) {
                    overlayStreakBadge

                    timerDisplay

                    Text("Look Away")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.82))
                }

                Spacer(minLength: 0)

                skipControl
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 32)
        }
    }

    private var overlayStreakBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(engine.consecutiveBreaks > 0 ? LookAwayBrand.accent : .white.opacity(0.35))

            Text("\(engine.consecutiveBreaks)")
                .font(.system(.body, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(engine.consecutiveBreaks > 0 ? .white.opacity(0.92) : .white.opacity(0.4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .lookAwayOverlayCapsule()
        .accessibilityLabel("\(engine.consecutiveBreaks) consecutive breaks")
    }

    private var timerDisplay: some View {
        Text(formattedTime)
            .font(.system(size: 80, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 44)
            .padding(.vertical, 22)
            .lookAwayOverlayTimerGlass()
    }

    private var skipControl: some View {
        HoldToConfirmButton(
            title: "Skip",
            holdingTitle: "Keep holding…",
            systemImage: "forward.end.fill",
            role: .destructive,
            centered: true,
            overlayGlass: true,
            onConfirm: onEndBreak
        )
        .frame(maxWidth: 160)
        .opacity(0.2)
    }
}

private struct LookAwayOverlayTimerGlass: ViewModifier {
    func body(content: Content) -> some View {
        #if LIQUID_GLASS
        content.glassEffect(
            .regular.tint(LookAwayBrand.accent.opacity(0.16)),
            in: .rect(cornerRadius: 36)
        )
        #else
        content
            .background {
                RoundedRectangle(cornerRadius: 36, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 36, style: .continuous)
                            .strokeBorder(LookAwayBrand.accent.opacity(0.22), lineWidth: 1)
                    }
            }
        #endif
    }
}

private struct LookAwayOverlayCapsuleGlass: ViewModifier {
    func body(content: Content) -> some View {
        #if LIQUID_GLASS
        content.glassEffect(
            .regular.tint(LookAwayBrand.accent.opacity(0.1)),
            in: .capsule
        )
        #else
        content
            .background {
                Capsule(style: .continuous)
                    .fill(Color.white.opacity(0.06))
            }
        #endif
    }
}

private extension View {
    func lookAwayOverlayTimerGlass() -> some View {
        modifier(LookAwayOverlayTimerGlass())
    }

    func lookAwayOverlayCapsule() -> some View {
        modifier(LookAwayOverlayCapsuleGlass())
    }
}
