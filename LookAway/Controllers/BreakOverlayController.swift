import AppKit
import SwiftUI

@MainActor
final class BreakOverlayController: ObservableObject {
    private var panels: [NSPanel] = []
    private var hostingControllers: [NSHostingController<BreakOverlayView>] = []
    private weak var timerEngine: TimerEngine?

    func bind(to engine: TimerEngine) {
        timerEngine = engine
    }

    func installObservers() {
        NotificationCenter.default.addObserver(
            forName: .lookAwayBreakStarted,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showOverlay()
            }
        }

        NotificationCenter.default.addObserver(
            forName: .lookAwayBreakEnded,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hideOverlay()
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.panels.isEmpty else { return }
                self.hideOverlay()
                self.showOverlay()
            }
        }
    }

    func showOverlay() {
        hideOverlay()
        guard let engine = timerEngine else { return }

        for screen in NSScreen.screens {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .screenSaver
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = false
            panel.isFloatingPanel = true

            let view = BreakOverlayView(
                engine: engine,
                onEndBreak: { [weak self, weak engine] in
                    self?.requestEndBreakEarly(engine: engine)
                }
            )

            let hosting = NSHostingController(rootView: view)
            hosting.view.frame = screen.frame
            panel.contentViewController = hosting
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()

            panels.append(panel)
            hostingControllers.append(hosting)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func hideOverlay() {
        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
        hostingControllers.removeAll()
    }

    private func requestEndBreakEarly(engine: TimerEngine?) {
        let alert = NSAlert()
        alert.messageText = "End break early?"
        alert.informativeText = "Are you sure you want to end this break before the timer finishes?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "End Break")
        alert.addButton(withTitle: "Keep Resting")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            engine?.confirmEndBreakEarly()
        }
    }
}
