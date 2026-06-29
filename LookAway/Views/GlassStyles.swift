import AppKit
import SwiftUI

enum LookAwayGlass {
    static let panelCornerRadius: CGFloat = 22
    static let cardCornerRadius: CGFloat = 18
}

extension View {
    func lookAwayCapsuleGlass(tint: Color? = nil) -> some View {
        padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                if NativeGlass.isSupported {
                    NativeGlassCapsule(tint: tint)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
    }

    func lookAwayGlassCard(cornerRadius: CGFloat = LookAwayGlass.cardCornerRadius, tint: Color? = nil) -> some View {
        background {
            NativeGlassBox(cornerRadius: cornerRadius, tint: tint) {
                Color.clear
            }
            .allowsHitTesting(false)
        }
    }
}

private struct NativeGlassCapsule: NSViewRepresentable {
    var tint: Color?

    func makeNSView(context: Context) -> NSView {
        guard NativeGlass.isSupported,
              let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type else {
            let effect = NSVisualEffectView()
            effect.material = .menu
            effect.blendingMode = .behindWindow
            effect.state = .active
            return effect
        }

        let glass = glassType.init(frame: .zero)
        glass.setValue(999.0, forKey: "cornerRadius")
        if let tint {
            glass.setValue(NSColor(tint), forKey: "tintColor")
        }
        return glass
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard NativeGlass.isSupported else { return }
        nsView.setValue(999.0, forKey: "cornerRadius")
        if let tint {
            nsView.setValue(NSColor(tint), forKey: "tintColor")
        }
    }
}

struct GlassActionButtonStyle: ButtonStyle {
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .rounded, weight: .medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .background {
                NativeGlassBox(cornerRadius: 12, tint: tint) {
                    Color.clear.frame(maxWidth: .infinity, minHeight: 1)
                }
                .allowsHitTesting(false)
            }
    }
}

struct PhaseProgressRing: View {
    let progress: Double
    let symbol: String
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.quaternary.opacity(0.35), lineWidth: 6)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.35), tint, tint.opacity(0.85)],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Image(systemName: symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(tint)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 74, height: 74)
    }
}

struct TimerHeroCard: View {
    @ObservedObject var engine: TimerEngine

    private var accent: Color {
        switch engine.phase {
        case .working:
            return LookAwayBrand.pink
        case .preBreakWarning:
            return .red
        case .onBreak:
            return .mint
        case .paused:
            return .secondary
        }
    }

    var body: some View {
        NativeGlassBox(cornerRadius: LookAwayGlass.cardCornerRadius, tint: accent.opacity(0.08)) {
            HStack(spacing: 16) {
                PhaseProgressRing(
                    progress: engine.progressFraction,
                    symbol: engine.phaseSymbol,
                    tint: accent
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(engine.phaseDisplayName)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text(engine.displayTime)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    if !engine.statusDetail.isEmpty {
                        Text(engine.statusDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }
}

struct AmbientBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.12, blue: 0.22),
                    Color(red: 0.04, green: 0.08, blue: 0.14),
                    Color(red: 0.10, green: 0.16, blue: 0.18),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [.mint.opacity(0.18), .clear],
                center: .topLeading,
                startRadius: 40,
                endRadius: 420
            )

            RadialGradient(
                colors: [.blue.opacity(0.16), .clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

struct LookAwayGlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        if NativeGlass.isSupported {
            NativeGlassStack(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}
