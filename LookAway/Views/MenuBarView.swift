import AppKit
import Combine
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    let configManager: ConfigManager
    let timerEngine: TimerEngine
    let microphoneMonitor: MicrophoneMonitor
    let sleepWakeMonitor: SleepWakeMonitor
    let breakOverlayController: BreakOverlayController

    private var cancellables = Set<AnyCancellable>()

    init() {
        configManager = ConfigManager()
        timerEngine = TimerEngine(config: configManager.config)
        microphoneMonitor = MicrophoneMonitor()
        sleepWakeMonitor = SleepWakeMonitor()
        breakOverlayController = BreakOverlayController()

        breakOverlayController.bind(to: timerEngine)
        breakOverlayController.installObservers()

        LaunchAtLoginManager.syncWithConfig(configManager.config.launchAtLogin)

        bind()

        configManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func bind() {
        configManager.$config
            .sink { [weak self] config in
                self?.timerEngine.applyConfig(config)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            microphoneMonitor.$isMicActive,
            sleepWakeMonitor.$isSystemPaused,
            sleepWakeMonitor.$pauseDetail
        )
        .sink { [weak self] micActive, systemPaused, systemPauseDetail in
            self?.timerEngine.handleExternalPause(
                micActive: micActive,
                systemPaused: systemPaused,
                systemPauseDetail: systemPauseDetail
            )
        }
        .store(in: &cancellables)
    }

    var launchAtLogin: Bool {
        LaunchAtLoginManager.isEnabled
    }

    func togglePause() {
        timerEngine.setManualPause(!timerEngine.isManuallyPaused)
        timerEngine.handleExternalPause(
            micActive: microphoneMonitor.isMicActive,
            systemPaused: sleepWakeMonitor.isSystemPaused,
            systemPauseDetail: sleepWakeMonitor.pauseDetail
        )
    }

    func restartTimer() {
        timerEngine.restartTimer()
        timerEngine.handleExternalPause(
            micActive: microphoneMonitor.isMicActive,
            systemPaused: sleepWakeMonitor.isSystemPaused,
            systemPauseDetail: sleepWakeMonitor.pauseDetail
        )
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard enabled != LaunchAtLoginManager.isEnabled else { return }
        if LaunchAtLoginManager.setEnabled(enabled) {
            configManager.update { $0.launchAtLogin = enabled }
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}

struct MenuBarView: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var viewModel: AppViewModel
    @ObservedObject var timerEngine: TimerEngine
    @State private var showsSettings = false
    @State private var draftConfig: AppConfig

    init(viewModel: AppViewModel, timerEngine: TimerEngine) {
        self.viewModel = viewModel
        self.timerEngine = timerEngine
        _draftConfig = State(initialValue: viewModel.configManager.config)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            compactHeader

            quickActions

            if showsSettings {
                settingsPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            footer
        }
        .padding(12)
        .frame(width: showsSettings ? 320 : 280)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
        .animation(.smooth(duration: 0.22), value: showsSettings)
        .onChange(of: viewModel.configManager.config) { _, newValue in
            draftConfig = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: .lookAwayBreakStarted)) { _ in
            dismiss()
        }
        .disabled(timerEngine.phase == .onBreak)
        .opacity(timerEngine.phase == .onBreak ? 0.6 : 1)
    }

    private var compactHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timerEngine.displayTime)
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Text(timerEngine.phaseDisplayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if !timerEngine.statusDetail.isEmpty {
                    Text(timerEngine.statusDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                StreakBadge(count: timerEngine.consecutiveBreaks, compact: true)

                if timerEngine.phase == .onBreak {
                    LookAwayStatusChip(text: "Break", tint: LookAwayBrand.pink)
                } else if timerEngine.phase == .paused {
                    LookAwayStatusChip(text: "Paused", tint: .secondary)
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                menuButton(
                    title: timerEngine.isManuallyPaused ? "Resume" : "Pause",
                    symbol: timerEngine.isManuallyPaused ? "play.fill" : "pause.fill",
                    centered: true
                ) {
                    viewModel.togglePause()
                }

                HoldToConfirmButton(
                    title: "Restart",
                    holdingTitle: "Keep holding…",
                    systemImage: "arrow.clockwise",
                    centered: true,
                    onConfirm: { viewModel.restartTimer() }
                )
            }

            if timerEngine.phase == .onBreak {
                HoldToConfirmButton(
                    title: "Skip",
                    holdingTitle: "Keep holding…",
                    systemImage: "forward.end.fill",
                    role: .destructive,
                    centered: true,
                    onConfirm: { viewModel.timerEngine.abortBreakEarly() }
                )
            } else {
                menuButton(title: "Break", symbol: "cup.and.saucer.fill", centered: true) {
                    viewModel.timerEngine.startBreakNow()
                }
            }

            if timerEngine.pendingPenaltyMinutes > 0 && timerEngine.phase != .onBreak {
                Text("Next break +\(timerEngine.pendingPenaltyMinutes) min from skip")
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Intervals")

            ConfigNumberRow(
                title: "Work duration",
                subtitle: "Time before a break",
                value: workMinutesBinding,
                range: 1...(24 * 60),
                unit: "m"
            )

            ConfigNumberRow(
                title: "Break duration",
                subtitle: "Rest overlay length",
                value: breakMinutesBinding,
                range: 1...180,
                unit: "m"
            )

            ConfigNumberRow(
                title: "Pre-break warning",
                subtitle: "0 turns this off",
                value: warningMinutesBinding,
                range: 0...60,
                unit: "m"
            )

            sectionLabel("Behavior")

            ConfigNumberRow(
                title: "Skip penalty",
                subtitle: "Extra minutes on next break",
                value: skipPenaltyMinutesBinding,
                range: 0...60,
                unit: "m"
            )

            ConfigToggleRow(
                title: "Emergency exit",
                subtitle: "Show link on break screen",
                isOn: allowEmergencyExitBinding
            )

            Button {
                viewModel.configManager.openConfigFile()
            } label: {
                Label("Reveal config.json", systemImage: "doc.text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            ConfigToggleRow(
                title: "Launch at login",
                subtitle: "Start automatically",
                isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                )
            )

            Button {
                showsSettings.toggle()
            } label: {
                Label(
                    showsSettings ? "Hide settings" : "Settings",
                    systemImage: showsSettings ? "chevron.up" : "chevron.down"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(MenuActionButtonStyle())

            Button {
                viewModel.quit()
            } label: {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(MenuActionButtonStyle(role: .destructive))
            .disabled(timerEngine.phase == .onBreak)
            .keyboardShortcut("q")
        }
    }

    private var workMinutesBinding: Binding<Int> {
        Binding(
            get: { draftConfig.workDurationMinutes },
            set: { newValue in updateDraft { $0.workDurationMinutes = newValue } }
        )
    }

    private var breakMinutesBinding: Binding<Int> {
        Binding(
            get: { draftConfig.breakDurationMinutes },
            set: { newValue in updateDraft { $0.breakDurationMinutes = newValue } }
        )
    }

    private var warningMinutesBinding: Binding<Int> {
        Binding(
            get: { draftConfig.preBreakWarningMinutes },
            set: { newValue in updateDraft { $0.preBreakWarningMinutes = newValue } }
        )
    }

    private var skipPenaltyMinutesBinding: Binding<Int> {
        Binding(
            get: { draftConfig.skipPenaltyMinutes },
            set: { newValue in updateDraft { $0.skipPenaltyMinutes = newValue } }
        )
    }

    private var allowEmergencyExitBinding: Binding<Bool> {
        Binding(
            get: { draftConfig.allowEmergencyExit },
            set: { newValue in updateDraft { $0.allowEmergencyExit = newValue } }
        )
    }

    private func updateDraft(_ transform: (inout AppConfig) -> Void) {
        var copy = draftConfig
        transform(&copy)
        draftConfig = copy
        viewModel.configManager.replace(with: copy)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 2)
            .padding(.top, 2)
    }

    private func menuButton(title: String, symbol: String, centered: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MenuActionButtonStyle(centered: centered))
    }
}
