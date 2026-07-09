import AppKit
import SwiftUI

struct BreakOverlayView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var overlayController: BreakOverlayController
    let onEndBreak: () -> Void

    private var formattedTime: String {
        let total = Int(max(0, engine.remainingSeconds.rounded()))
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                VisualEffectBackground(material: .fullScreenUI, blendingMode: .behindWindow)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                Color.black.opacity(0.10)
                    .frame(width: geometry.size.width, height: geometry.size.height)

                RadialGradient(
                    colors: [LookAwayBrand.pink.opacity(0.16), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: max(geometry.size.width, geometry.size.height) * 0.35
                )
                .frame(width: geometry.size.width, height: geometry.size.height)

                breakPanel
                    .frame(maxWidth: min(380, geometry.size.width - 48))

                if let warning = overlayController.shortcutWarning {
                    VStack {
                        Spacer()
                        Text(warning)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(Color.black.opacity(0.72))
                            }
                            .padding(.bottom, max(24, geometry.safeAreaInsets.bottom + 16))
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(false)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .animation(.easeInOut(duration: 0.2), value: overlayController.shortcutWarning)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private var breakPanel: some View {
        VStack(spacing: 16) {
            HStack {
                LookAwayStatusChip(text: "Break", tint: LookAwayBrand.pink)
                Spacer(minLength: 0)
                StreakBadge(count: engine.consecutiveBreaks)
            }

            VStack(spacing: 4) {
                Text(formattedTime)
                    .font(.system(size: 40, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Text("Rest your eyes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            PhaseProgressRing(
                progress: engine.progressFraction,
                symbol: "eyes",
                tint: LookAwayBrand.pink
            )

            VStack(spacing: 6) {
                Text("Look away")
                    .font(.system(.title3, design: .rounded, weight: .semibold))

                Text("Step away from the screen and give your eyes a rest.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if engine.appliedPenaltyMinutes > 0 {
                    Text("+\(engine.appliedPenaltyMinutes) min from skipped break")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                HoldToConfirmButton(
                    title: "Skip Break",
                    holdingTitle: "Keep holding…",
                    systemImage: "forward.end.fill",
                    role: .destructive,
                    centered: true,
                    onConfirm: onEndBreak
                )
            }
        }
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.5)
                }
        }
        .shadow(color: .black.opacity(0.12), radius: 24, y: 10)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
