import AppKit
import SwiftUI

/// AppKit-backed full-bleed background — NSHostingController panels often ignore SwiftUI image updates.
struct NatureBackgroundImageView: NSViewRepresentable {
    let image: NSImage?

    func makeNSView(context: Context) -> AspectFillImageNSView {
        AspectFillImageNSView()
    }

    func updateNSView(_ nsView: AspectFillImageNSView, context: Context) {
        nsView.image = image
    }
}

final class AspectFillImageNSView: NSView {
    var image: NSImage? {
        didSet { needsDisplay = true }
    }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let image else {
            NSColor.clear.setFill()
            dirtyRect.fill()
            return
        }

        let imageSize = image.size
        guard imageSize.width > 0, imageSize.height > 0 else { return }

        let widthRatio = bounds.width / imageSize.width
        let heightRatio = bounds.height / imageSize.height
        let scale = max(widthRatio, heightRatio)
        let drawRect = NSRect(
            x: (bounds.width - imageSize.width * scale) / 2,
            y: (bounds.height - imageSize.height * scale) / 2,
            width: imageSize.width * scale,
            height: imageSize.height * scale
        )

        image.draw(in: drawRect, from: .zero, operation: .copy, fraction: 1)
    }
}

struct BreakOverlayView: View {
    @ObservedObject var engine: TimerEngine
    @ObservedObject var overlayController: BreakOverlayController
    @ObservedObject var natureBackground: NatureBackgroundService
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
                backgroundLayer(size: geometry.size)

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.12),
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.48),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(width: geometry.size.width, height: geometry.size.height)

                breakContent(maxWidth: min(420, geometry.size.width - 48))

                if let photographer = natureBackground.photographerName, natureBackground.backgroundImage != nil {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Photo · \(photographer)")
                                .font(.system(.caption2, design: .rounded))
                                .foregroundStyle(LookAwayBrand.cream.opacity(0.72))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background {
                                    Capsule()
                                        .fill(Color.black.opacity(0.35))
                                }
                                .padding(.trailing, max(20, geometry.safeAreaInsets.trailing + 12))
                                .padding(.bottom, max(16, geometry.safeAreaInsets.bottom + 12))
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .allowsHitTesting(false)
                }

                if let warning = overlayController.shortcutWarning {
                    VStack {
                        Spacer()
                        Text(warning)
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundStyle(LookAwayBrand.cream)
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

    @ViewBuilder
    private func backgroundLayer(size: CGSize) -> some View {
        ZStack {
            NatureFallbackBackground()
                .frame(width: size.width, height: size.height)

            if natureBackground.backgroundImage != nil {
                NatureBackgroundImageView(image: natureBackground.backgroundImage)
                    .frame(width: size.width, height: size.height)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: natureBackground.backgroundImage != nil)
    }

    private func breakContent(maxWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                BreakOverlayStatusChip(text: "Break")
                Spacer(minLength: 0)
                BreakOverlayStreakBadge(count: engine.consecutiveBreaks)
            }
            .padding(.bottom, 28)

            Spacer(minLength: 0)

            VStack(spacing: 22) {
                BreakLockScreenTimer(time: formattedTime)

                VStack(spacing: 8) {
                    Text("Look away")
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .foregroundStyle(LookAwayBrand.cream)

                    Text("Step away from the screen. Let your eyes wander into something calm.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(LookAwayBrand.cream.opacity(0.72))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 340)

                    if engine.appliedPenaltyMinutes > 0 {
                        Text("+\(engine.appliedPenaltyMinutes) min from skipped break")
                            .font(.caption)
                            .foregroundStyle(Color.orange.opacity(0.92))
                    }
                }
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.35), radius: 8, y: 2)
            }

            Spacer(minLength: 0)

            HoldToConfirmButton(
                title: "Skip Break",
                holdingTitle: "Keep holding…",
                systemImage: "forward.end.fill",
                holdDuration: LookAwayMetrics.holdConfirmDuration,
                role: .destructive,
                centered: true,
                overlayGlass: true,
                onConfirm: onEndBreak
            )
            .frame(maxWidth: maxWidth)
            .padding(.top, 32)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
        .frame(maxWidth: maxWidth)
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
