import AppKit
import Foundation

@MainActor
final class IdleMonitor: ObservableObject {
    @Published private(set) var isIdle = false

    private var timer: Timer?
    private var thresholdSeconds: TimeInterval?

    /// Poll interval — idle thresholds are usually minutes, so 5s is plenty.
    private static let pollInterval: TimeInterval = 5

    func updateThreshold(_ seconds: TimeInterval?) {
        thresholdSeconds = seconds
        if seconds == nil {
            if isIdle { isIdle = false }
            timer?.invalidate()
            timer = nil
        } else if timer == nil {
            startPolling()
        }
    }

    private func startPolling() {
        timer?.invalidate()
        refreshIdleState()

        let pollTimer = Timer(fire: Date(), interval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshIdleState()
            }
        }
        pollTimer.tolerance = Self.pollInterval * 0.2
        RunLoop.main.add(pollTimer, forMode: .common)
        timer = pollTimer
    }

    private func refreshIdleState() {
        guard let thresholdSeconds else {
            if isIdle { isIdle = false }
            return
        }

        let idleTime = CGEventSource.secondsSinceLastEventType(
            CGEventSourceStateID.hidSystemState,
            eventType: CGEventType(rawValue: ~0)!
        )
        let nowIdle = idleTime >= thresholdSeconds
        guard nowIdle != isIdle else { return }
        isIdle = nowIdle
    }
}
