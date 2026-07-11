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

struct TimerHeroCard: View {
    @ObservedObject var engine: TimerEngine

    private var accent: Color {
        switch engine.phase {
        case .working:
            return LookAwayBrand.forest
        case .preBreakWarning:
            return LookAwayBrand.wood
        case .onBreak:
            return LookAwayBrand.sage
        case .paused:
            return .secondary
        }
    }

    var body: some View {
        NativeGlassBox(cornerRadius: LookAwayGlass.cardCornerRadius, tint: accent.opacity(0.08)) {
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
    }
}

struct BreakLockScreenTimer: View {
    let time: String

    var body: some View {
        NativeGlassBox(cornerRadius: 36, tint: Color.white.opacity(0.14)) {
            Text(time)
                .font(.system(size: 82, weight: .thin, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color.white.opacity(0.92),
                            Color.white.opacity(0.78),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: Color.white.opacity(0.35), radius: 0, y: 1)
                .padding(.horizontal, 40)
                .padding(.vertical, 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.62),
                            Color.white.opacity(0.18),
                            Color.white.opacity(0.04),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(1)
        }
        .shadow(color: .black.opacity(0.28), radius: 24, y: 12)
    }
}

struct BreakOverlayStatusChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(.caption, design: .rounded, weight: .semibold))
            .foregroundStyle(LookAwayBrand.cream.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(Color.white.opacity(0.14))
                    .background {
                        Capsule()
                            .fill(.ultraThinMaterial)
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.28), lineWidth: 0.5)
                    }
            }
    }
}

struct BreakOverlayStreakBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(count > 0 ? LookAwayBrand.cream : LookAwayBrand.cream.opacity(0.45))

            Text("\(count)")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(LookAwayBrand.cream.opacity(count > 0 ? 0.92 : 0.55))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background {
            Capsule()
                .fill(Color.white.opacity(0.12))
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 0.5)
                }
        }
        .accessibilityLabel("\(count) consecutive breaks")
    }
}

struct AmbientBackdrop: View {
    var body: some View {
        NatureFallbackBackground()
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
