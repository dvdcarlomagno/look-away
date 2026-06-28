import AppKit
import SwiftUI

enum NativeGlass {
    static var isSupported: Bool {
        NSClassFromString("NSGlassEffectView") != nil
    }
}

struct NativeGlassBox<Content: View>: NSViewRepresentable {
    var cornerRadius: CGFloat = 18
    var tint: Color?
    let content: Content

    init(cornerRadius: CGFloat = 18, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.tint = tint
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> GlassSizingView {
        let wrapper = GlassSizingView()
        context.coordinator.wrapper = wrapper

        if NativeGlass.isSupported,
           let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassType.init(frame: .zero)
            glass.translatesAutoresizingMaskIntoConstraints = false
            applyGlassProperties(to: glass)

            let hosting = NSHostingView(rootView: content)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            glass.setValue(hosting, forKey: "contentView")

            wrapper.install(glassView: glass, hostingView: hosting)
            context.coordinator.hostingView = hosting
            return wrapper
        }

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.cornerCurve = .continuous

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        wrapper.install(glassView: effect, hostingView: hosting)
        context.coordinator.hostingView = hosting
        return wrapper
    }

    func updateNSView(_ nsView: GlassSizingView, context: Context) {
        context.coordinator.hostingView?.rootView = content

        if let glass = context.coordinator.wrapper?.glassView {
            applyGlassProperties(to: glass)
        }
    }

    private func applyGlassProperties(to glass: NSView) {
        guard NativeGlass.isSupported else { return }
        glass.setValue(cornerRadius, forKey: "cornerRadius")
        if let tint {
            glass.setValue(NSColor(tint), forKey: "tintColor")
        } else {
            glass.setValue(nil, forKey: "tintColor")
        }
    }

    final class Coordinator {
        weak var wrapper: GlassSizingView?
        var hostingView: NSHostingView<Content>?
    }
}

struct NativeGlassStack<Content: View>: NSViewRepresentable {
    var spacing: CGFloat = 10
    let content: Content

    init(spacing: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> GlassSizingView {
        let wrapper = GlassSizingView()

        if NativeGlass.isSupported,
           let containerType = NSClassFromString("NSGlassEffectContainerView") as? NSView.Type {
            let container = containerType.init(frame: .zero)
            container.translatesAutoresizingMaskIntoConstraints = false
            container.setValue(spacing, forKey: "spacing")

            let hosting = NSHostingView(rootView: content)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            container.setValue(hosting, forKey: "contentView")

            wrapper.install(glassView: container, hostingView: hosting)
            context.coordinator.hostingView = hosting
            context.coordinator.wrapper = wrapper
            return wrapper
        }

        let hosting = NSHostingView(rootView: content)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        wrapper.install(glassView: hosting, hostingView: hosting)
        context.coordinator.hostingView = hosting
        context.coordinator.wrapper = wrapper
        return wrapper
    }

    func updateNSView(_ nsView: GlassSizingView, context: Context) {
        context.coordinator.hostingView?.rootView = content
        if NativeGlass.isSupported {
            context.coordinator.wrapper?.glassView.setValue(spacing, forKey: "spacing")
        }
    }

    final class Coordinator {
        weak var wrapper: GlassSizingView?
        var hostingView: NSHostingView<Content>?
    }
}

final class GlassSizingView: NSView {
    private(set) var glassView: NSView!
    private weak var sizingHostingView: NSView?

    func install(glassView: NSView, hostingView: NSView) {
        self.glassView = glassView
        sizingHostingView = hostingView

        addSubview(glassView)
        NSLayoutConstraint.activate([
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    override var intrinsicContentSize: NSSize {
        guard let hosting = sizingHostingView else {
            return super.intrinsicContentSize
        }
        hosting.layoutSubtreeIfNeeded()
        let size = hosting.intrinsicContentSize
        return NSSize(
            width: max(size.width, 1),
            height: max(size.height, 1)
        )
    }
}
