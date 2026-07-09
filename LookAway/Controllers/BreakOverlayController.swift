import AppKit
import SwiftUI

@MainActor
final class BreakOverlayController: ObservableObject {
    @Published private(set) var shortcutWarning: String?

    private var panels: [NSPanel] = []
    private weak var timerEngine: TimerEngine?
    private let inputShield = BreakInputShield()
    private var keepFrontTimer: Timer?
    private var warningClearTimer: Timer?

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
        MenuBarWindowDismisser.closeIfOpen()
        guard let engine = timerEngine else { return }

        inputShield.onBlockedShortcut = { [weak self] message in
            self?.showShortcutWarning(message)
        }
        inputShield.activate()
        startKeepFrontTimer()

        for (index, screen) in NSScreen.screens.enumerated() {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.level = BreakOverlayWindowLevel.shield
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.ignoresMouseEvents = false
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = false

            let view = BreakOverlayView(
                engine: engine,
                overlayController: self,
                onEndBreak: { [weak engine] in
                    engine?.abortBreakEarly()
                }
            )

            let hosting = NSHostingController(rootView: view)
            if #available(macOS 13.0, *) {
                hosting.sizingOptions = []
            }
            panel.contentViewController = hosting
            pinHostingViewToPanel(hosting, panel: panel)
            panel.setFrame(screen.frame, display: true)
            panel.orderFrontRegardless()

            panels.append(panel)

            if index == 0 {
                panel.makeKeyAndOrderFront(nil)
            }
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func hideOverlay() {
        stopKeepFrontTimer()
        inputShield.deactivate()
        warningClearTimer?.invalidate()
        warningClearTimer = nil
        shortcutWarning = nil

        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
    }

    private func startKeepFrontTimer() {
        stopKeepFrontTimer()
        keepFrontTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.panels.isEmpty else { return }
                for panel in self.panels {
                    panel.orderFrontRegardless()
                }
            }
        }
        if let keepFrontTimer {
            RunLoop.main.add(keepFrontTimer, forMode: .common)
        }
    }

    private func stopKeepFrontTimer() {
        keepFrontTimer?.invalidate()
        keepFrontTimer = nil
    }

    private func showShortcutWarning(_ message: String) {
        shortcutWarning = message

        warningClearTimer?.invalidate()
        warningClearTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.shortcutWarning = nil
            }
        }
    }

    private func pinHostingViewToPanel(_ hosting: NSHostingController<BreakOverlayView>, panel: NSPanel) {
        guard let contentView = panel.contentView else { return }
        let hostView = hosting.view
        hostView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostView.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }
}
