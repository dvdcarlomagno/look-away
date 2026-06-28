import AppKit
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
            VisualEffectBackground(material: .fullScreenUI, blendingMode: .behindWindow)
                .ignoresSafeArea()

            Color.black.opacity(0.10)
                .ignoresSafeArea()

            RadialGradient(
                colors: [LookAwayBrand.pink.opacity(0.16), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()

            breakPanel
                .frame(maxWidth: 380)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var breakPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedTime)
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    Text("Rest your eyes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                LookAwayStatusChip(text: "Break", tint: LookAwayBrand.pink)
            }

            HStack(spacing: 16) {
                PhaseProgressRing(
                    progress: engine.progressFraction,
                    symbol: "eyes",
                    tint: LookAwayBrand.pink
                )

                VStack(alignment: .leading, spacing: 6) {
                    Text("Look away")
                        .font(.system(.title3, design: .rounded, weight: .semibold))

                    Text("Break ends in \(formattedTime)")
                        .font(.system(.body, design: .rounded))
                        .foregroundStyle(.secondary)

                    Text("Step away from the screen and give your eyes a rest.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(14)
            .lookAwaySurface(cornerRadius: 12)

            Button {
                onEndBreak()
            } label: {
                Label("End Break Early…", systemImage: "forward.end.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MenuActionButtonStyle(centered: true))
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
