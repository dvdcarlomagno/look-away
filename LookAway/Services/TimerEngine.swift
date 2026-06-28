import AppKit
import Combine
import Foundation
import UserNotifications

enum TimerPhase: Equatable {
    case working
    case preBreakWarning
    case onBreak
    case paused
}

@MainActor
final class TimerEngine: ObservableObject {
    @Published private(set) var phase: TimerPhase = .working
    @Published private(set) var remainingSeconds: TimeInterval = 0
    @Published private(set) var isManuallyPaused = false
    @Published private(set) var statusDetail: String = ""
    /// Lightweight menu-bar fields — only published when their values change.
    @Published private(set) var menuBarCompactText: String = ""
    @Published private(set) var menuBarSymbol: String = "eyes"

    private var config: AppConfig
    private var tickTimer: Timer?
    private var lastTickDate: Date?
    private var preBreakWarningSent = false
    /// High-precision countdown; UI reads `remainingSeconds` at most once per second.
    private var internalRemaining: TimeInterval = 0
    private var lastPublishedDisplaySecond: Int = -1

    var menuBarLabel: String {
        switch phase {
        case .onBreak:
            return "Break: \(displayTime)"
        case .paused:
            if statusDetail.contains("call") {
                return "Call active"
            }
            return "Paused"
        case .preBreakWarning:
            return "Break soon: \(displayTime)"
        case .working:
            return "\(displayTime) left"
        }
    }

    var displayTime: String {
        formattedTime(remainingSeconds)
    }

    var phaseDisplayName: String {
        switch phase {
        case .working:
            return "Focus session"
        case .preBreakWarning:
            return "Break approaching"
        case .onBreak:
            return "Rest your eyes"
        case .paused:
            return "Paused"
        }
    }

    var phaseSymbol: String {
        switch phase {
        case .working:
            return "laptopcomputer"
        case .preBreakWarning:
            return "bell.badge"
        case .onBreak:
            return "eye.fill"
        case .paused:
            return "pause.circle"
        }
    }

    var activePhaseDuration: TimeInterval {
        switch phase {
        case .working:
            return config.workDurationSeconds
        case .preBreakWarning:
            return config.preBreakWarningSeconds
        case .onBreak:
            return config.breakDurationSeconds
        case .paused:
            return config.workDurationSeconds
        }
    }

    var progressFraction: Double {
        let total = activePhaseDuration
        guard total > 0 else { return 0 }
        return max(0, min(1, 1 - (remainingSeconds / total)))
    }

    init(config: AppConfig) {
        self.config = config
        internalRemaining = config.workDurationSeconds
        remainingSeconds = config.workDurationSeconds
        syncMenuBarPresentation(force: true)
        startTicking()
    }

    func applyConfig(_ config: AppConfig) {
        let previous = self.config
        self.config = config
        switch phase {
        case .working:
            if config.workDurationMinutes != previous.workDurationMinutes {
                internalRemaining = config.workDurationSeconds
            } else {
                internalRemaining = min(internalRemaining, config.workDurationSeconds)
            }
        case .onBreak:
            if config.breakDurationMinutes != previous.breakDurationMinutes {
                internalRemaining = config.breakDurationSeconds
            } else {
                internalRemaining = min(internalRemaining, config.breakDurationSeconds)
            }
        case .preBreakWarning:
            if config.preBreakWarningMinutes != previous.preBreakWarningMinutes {
                internalRemaining = config.preBreakWarningSeconds
            } else {
                internalRemaining = min(internalRemaining, config.preBreakWarningSeconds)
            }
        case .paused:
            break
        }
        publishRemainingIfDisplayChanged(force: true)
    }

    func setManualPause(_ paused: Bool) {
        isManuallyPaused = paused
        reevaluatePhase()
    }

    func startBreakNow() {
        beginBreak()
    }

    func skipBreak() {
        guard phase == .onBreak else { return }
        endBreak()
    }

    func handleExternalPause(micActive: Bool, systemPaused: Bool, userIdle: Bool = false) {
        if phase == .onBreak { return }

        let newDetail: String
        if micActive {
            newDetail = "Paused — call active"
        } else if systemPaused {
            newDetail = "Paused — system asleep"
        } else if isManuallyPaused {
            newDetail = "Paused manually"
        } else if userIdle {
            newDetail = "Paused — idle"
        } else {
            newDetail = ""
        }

        if newDetail != statusDetail {
            statusDetail = newDetail
            if phase == .paused {
                syncMenuBarPresentation(force: true)
            }
        }

        reevaluatePhase(micActive: micActive, systemPaused: systemPaused, userIdle: userIdle)
    }

    func confirmEndBreakEarly() {
        guard phase == .onBreak else { return }
        endBreak()
    }

    private func startTicking() {
        tickTimer?.invalidate()
        lastTickDate = Date()
        let timer = Timer(fire: Date(), interval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    private func tick() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastTickDate ?? now)
        lastTickDate = now

        internalRemaining = max(0, internalRemaining - elapsed)
        publishRemainingIfDisplayChanged()

        switch phase {
        case .working:
            handleWorkingTick()
        case .preBreakWarning:
            handlePreBreakWarningTick()
        case .onBreak:
            handleBreakTick()
        case .paused:
            break
        }
    }

    private func publishRemainingIfDisplayChanged(force: Bool = false) {
        let displaySecond = Int(max(0, internalRemaining).rounded(.up))
        guard force || displaySecond != lastPublishedDisplaySecond else { return }
        lastPublishedDisplaySecond = displaySecond
        remainingSeconds = internalRemaining
        syncMenuBarPresentation(force: force)
    }

    private func syncMenuBarPresentation(force: Bool = false) {
        let newText: String
        switch phase {
        case .onBreak, .working, .preBreakWarning:
            newText = displayTime
        case .paused:
            newText = statusDetail.contains("call") ? "Call active" : "Paused"
        }
        if force || newText != menuBarCompactText {
            menuBarCompactText = newText
        }

        if force || menuBarSymbol != "eyes" {
            menuBarSymbol = "eyes"
        }
    }

    private func handleWorkingTick() {
        if config.preBreakWarningMinutes > 0,
           internalRemaining <= config.preBreakWarningSeconds,
           internalRemaining > 0 {
            if phase != .preBreakWarning {
                phase = .preBreakWarning
                syncMenuBarPresentation(force: true)
                sendPreBreakNotificationIfNeeded()
            }
        }

        if internalRemaining <= 0 {
            triggerBreakOrPauseForCall()
        }
    }

    private func handlePreBreakWarningTick() {
        if internalRemaining <= 0 {
            triggerBreakOrPauseForCall()
        }
    }

    private func triggerBreakOrPauseForCall() {
        if MicrophoneMonitor.checkMicrophoneInUse() {
            phase = .paused
            statusDetail = "Paused — call active"
            internalRemaining = 0
            publishRemainingIfDisplayChanged(force: true)
            stopTicking()
        } else {
            beginBreak()
        }
    }

    private func handleBreakTick() {
        if internalRemaining <= 0 {
            endBreak()
        }
    }

    private func beginBreak() {
        phase = .onBreak
        internalRemaining = config.breakDurationSeconds
        preBreakWarningSent = false
        statusDetail = ""
        publishRemainingIfDisplayChanged(force: true)
        if tickTimer == nil { startTicking() }
        NotificationCenter.default.post(name: .lookAwayBreakStarted, object: nil)
    }

    private func endBreak() {
        phase = .working
        internalRemaining = config.workDurationSeconds
        preBreakWarningSent = false
        statusDetail = ""
        publishRemainingIfDisplayChanged(force: true)
        if tickTimer == nil { startTicking() }
        NotificationCenter.default.post(name: .lookAwayBreakEnded, object: nil)
    }

    private func reevaluatePhase(micActive: Bool? = nil, systemPaused: Bool? = nil, userIdle: Bool? = nil) {
        let mic = micActive ?? MicrophoneMonitor.checkMicrophoneInUse()
        let asleep = systemPaused ?? false
        let idle = userIdle ?? false

        if phase == .onBreak { return }

        let shouldPause = isManuallyPaused || mic || asleep || idle

        if shouldPause {
            if phase != .paused {
                phase = .paused
                syncMenuBarPresentation(force: true)
                stopTicking()
            }
        } else if phase == .paused {
            if internalRemaining <= 0 {
                beginBreak()
            } else if config.preBreakWarningMinutes > 0 && internalRemaining <= config.preBreakWarningSeconds {
                phase = .preBreakWarning
                syncMenuBarPresentation(force: true)
                if tickTimer == nil { startTicking() }
            } else {
                phase = .working
                syncMenuBarPresentation(force: true)
                if tickTimer == nil { startTicking() }
            }
        }
    }

    private func sendPreBreakNotificationIfNeeded() {
        guard !preBreakWarningSent else { return }
        preBreakWarningSent = true

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Break starting soon"
            content.body = "Your look-away break begins in \(Int(self.config.preBreakWarningMinutes)) minute(s)."
            let request = UNNotificationRequest(
                identifier: "look-away-pre-break",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func formattedTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%dm %02ds", minutes, secs)
    }
}

extension Notification.Name {
    static let lookAwayBreakStarted = Notification.Name("lookAwayBreakStarted")
    static let lookAwayBreakEnded = Notification.Name("lookAwayBreakEnded")
}
