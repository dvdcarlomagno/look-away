import AppKit
import Combine
import SwiftUI

@MainActor
final class BreakOverlayController: ObservableObject {
    @Published private(set) var shortcutWarning: String?

    private var panels: [NSPanel] = []
    private weak var timerEngine: TimerEngine?
    private weak var natureBackground: NatureBackgroundService?
    private let inputShield = BreakInputShield()
    private var keepFrontTimer: Timer?
    private var warningClearTimer: Timer?
    private var natureBackgroundCancellable: AnyCancellable?

    func bind(to engine: TimerEngine, natureBackground: NatureBackgroundService) {
        timerEngine = engine
        self.natureBackground = natureBackground

        natureBackgroundCancellable = natureBackground.$backgroundImage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshOverlayRoots()
            }
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
        guard let engine = timerEngine, let natureBackground else { return }

        inputShield.onBlockedShortcut = { [weak self] message in
            self?.showShortcutWarning(message)
        }
        inputShield.activate()
        mountOverlayPanels(engine: engine, natureBackground: natureBackground)
        startKeepFrontTimer()

        Task {
            await natureBackground.ensureBackgroundForBreak()
            refreshOverlayRoots()
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func hideOverlay() {
        stopKeepFrontTimer()
        inputShield.deactivate()
        warningClearTimer?.invalidate()
        warningClearTimer = nil
        shortcutWarning = nil
        natureBackground?.reset()

        for panel in panels {
            panel.orderOut(nil)
            panel.close()
        }
        panels.removeAll()
    }

    private func mountOverlayPanels(engine: TimerEngine, natureBackground: NatureBackgroundService) {
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

            let hosting = NSHostingController(
                rootView: makeBreakOverlayView(engine: engine, natureBackground: natureBackground)
            )
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
    }

    private func makeBreakOverlayView(engine: TimerEngine, natureBackground: NatureBackgroundService) -> BreakOverlayView {
        BreakOverlayView(
            engine: engine,
            overlayController: self,
            natureBackground: natureBackground,
            onEndBreak: { [weak engine] in
                engine?.abortBreakEarly()
            }
        )
    }

    private func refreshOverlayRoots() {
        guard let engine = timerEngine, let natureBackground, !panels.isEmpty else { return }

        for panel in panels {
            guard let hosting = panel.contentViewController as? NSHostingController<BreakOverlayView> else { continue }
            hosting.rootView = makeBreakOverlayView(engine: engine, natureBackground: natureBackground)
        }
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
        refreshOverlayRoots()

        warningClearTimer?.invalidate()
        warningClearTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.shortcutWarning = nil
                self?.refreshOverlayRoots()
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
