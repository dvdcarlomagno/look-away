import AppKit
import Combine
import SwiftUI

@MainActor
final class AppViewModel: ObservableObject {
    let configManager: ConfigManager
    let timerEngine: TimerEngine
    let microphoneMonitor: MicrophoneMonitor
    let sleepWakeMonitor: SleepWakeMonitor
    let natureBackgroundService = NatureBackgroundService()
    let breakOverlayController: BreakOverlayController
    let secretsManager = SecretsManager.shared
    private let notificationHandler = NotificationHandler()

    private var cancellables = Set<AnyCancellable>()

    init() {
        configManager = ConfigManager()
        timerEngine = TimerEngine(config: configManager.config)
        microphoneMonitor = MicrophoneMonitor()
        sleepWakeMonitor = SleepWakeMonitor()
        breakOverlayController = BreakOverlayController()
        breakOverlayController.bind(to: timerEngine, natureBackground: natureBackgroundService)
        breakOverlayController.installObservers()

        notificationHandler.timerEngine = timerEngine
        notificationHandler.install()

        LaunchAtLoginManager.syncWithConfig(configManager.config.launchAtLogin)

        bind()

        if NatureBackgroundService.shouldPreload(
            phase: timerEngine.phase,
            remainingSeconds: timerEngine.remainingSeconds
        ) {
            natureBackgroundService.preloadForUpcomingBreak()
        }

        configManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        secretsManager.objectWillChange
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

        Publishers.CombineLatest(timerEngine.$phase, timerEngine.$remainingSeconds)
            .sink { [weak self] phase, remainingSeconds in
                guard let self else { return }
                if NatureBackgroundService.shouldPreload(phase: phase, remainingSeconds: remainingSeconds) {
                    self.natureBackgroundService.preloadForUpcomingBreak()
                }
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

    func saveUnsplashAccessKey(_ key: String) {
        secretsManager.saveUnsplashAccessKey(key)
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
    @State private var draftUnsplashAccessKey: String
    @FocusState private var unsplashKeyFocused: Bool

    init(viewModel: AppViewModel, timerEngine: TimerEngine) {
        self.viewModel = viewModel
        self.timerEngine = timerEngine
        _draftConfig = State(initialValue: viewModel.configManager.config)
        _draftUnsplashAccessKey = State(initialValue: viewModel.secretsManager.unsplashAccessKey ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: MenuPanelMetrics.spacing) {
            compactHeader

            quickActions

            if showsSettings {
                settingsPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            footer
        }
        .padding(MenuPanelMetrics.padding)
        .frame(width: showsSettings ? 300 : 280)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
        .animation(.smooth(duration: 0.22), value: showsSettings)
        .onChange(of: viewModel.configManager.config) { _, newValue in
            draftConfig = newValue
        }
        .onChange(of: viewModel.secretsManager.unsplashAccessKey) { _, newValue in
            if !unsplashKeyFocused {
                draftUnsplashAccessKey = newValue ?? ""
            }
        }
        .onChange(of: showsSettings) { _, isOpen in
            if isOpen {
                draftUnsplashAccessKey = viewModel.secretsManager.unsplashAccessKey ?? ""
            } else {
                commitUnsplashAccessKey()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lookAwayBreakStarted)) { _ in
            dismiss()
        }
        .disabled(timerEngine.phase == .onBreak)
        .opacity(timerEngine.phase == .onBreak ? 0.6 : 1)
    }

    private var compactHeader: some View {
        HStack(alignment: .center, spacing: MenuPanelMetrics.spacing) {
            VStack(alignment: .leading, spacing: 2) {
                Text(timerEngine.displayTime)
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                    .monospacedDigit()

                Text(timerEngine.phaseDisplayName)
                    .font(MenuPanelMetrics.controlFont)
                    .foregroundStyle(.secondary)

                if !timerEngine.statusDetail.isEmpty {
                    Text(timerEngine.statusDetail)
                        .font(MenuPanelMetrics.controlFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: MenuPanelMetrics.spacing) {
                StreakBadge(count: timerEngine.consecutiveBreaks, compact: true)

                if timerEngine.phase == .onBreak {
                    LookAwayStatusChip(text: "Break", tint: LookAwayBrand.forest)
                } else if timerEngine.phase == .paused {
                    LookAwayStatusChip(text: "Paused", tint: .secondary)
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(spacing: MenuPanelMetrics.spacing) {
            HStack(spacing: MenuPanelMetrics.spacing) {
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
            } else if timerEngine.phase == .preBreakWarning {
                HStack(spacing: MenuPanelMetrics.spacing) {
                    menuButton(title: "Extend 3 min", symbol: "plus.circle", centered: true) {
                        viewModel.timerEngine.extendSession()
                    }

                    menuButton(title: "Break", symbol: "cup.and.saucer.fill", centered: true) {
                        viewModel.timerEngine.startBreakNow()
                    }
                }
            } else {
                menuButton(title: "Break", symbol: "cup.and.saucer.fill", centered: true) {
                    viewModel.timerEngine.startBreakNow()
                }
            }

            if timerEngine.pendingPenaltyMinutes > 0 && timerEngine.phase != .onBreak {
                Text("Next break +\(timerEngine.pendingPenaltyMinutes) min from skip")
                    .font(MenuPanelMetrics.controlFont)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 2)
                    .padding(.top, 2)
            }
        }
    }

    private var settingsPanel: some View {
        VStack(alignment: .leading, spacing: MenuPanelMetrics.spacing) {
            sectionLabel("Intervals", isFirst: true)

            ConfigNumberRow(
                title: "Work duration",
                subtitle: "Time before a break",
                value: workMinutesBinding,
                range: 1...(24 * 60),
                unit: "m",
                compact: true,
                showsSubtitle: false
            )

            ConfigNumberRow(
                title: "Break duration",
                subtitle: "Rest overlay length",
                value: breakMinutesBinding,
                range: 1...180,
                unit: "m",
                compact: true,
                showsSubtitle: false
            )

            sectionLabel("Behavior")

            ConfigToggleRow(
                title: "Launch at login",
                subtitle: "Start automatically",
                isOn: Binding(
                    get: { viewModel.launchAtLogin },
                    set: { viewModel.setLaunchAtLogin($0) }
                ),
                compact: true,
                showsSubtitle: false
            )

            sectionLabel("Nature backgrounds")

            ConfigSecureFieldRow(
                title: "Unsplash access key",
                subtitle: "Access Key from unsplash.com/developers",
                text: $draftUnsplashAccessKey,
                placeholder: "Paste Access Key (Client-ID)",
                compact: true,
                showsSubtitle: false,
                isFocused: $unsplashKeyFocused,
                onCommit: commitUnsplashAccessKey
            )

            if viewModel.secretsManager.unsplashAccessKey == nil {
                Text("Without a key, breaks use a calm gradient instead of tree photos.")
                    .font(MenuPanelMetrics.controlFont)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 2)
            }

            Button {
                viewModel.configManager.openConfigFile()
            } label: {
                Label("Reveal config.json", systemImage: "doc.text")
                    .font(MenuPanelMetrics.controlFont)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)

            Button {
                NSWorkspace.shared.open(SecretsManager.secretsFileURL.deletingLastPathComponent())
            } label: {
                Label("Reveal secrets folder", systemImage: "key")
                    .font(MenuPanelMetrics.controlFont)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        VStack(spacing: MenuPanelMetrics.spacing) {
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

    private func updateDraft(_ transform: (inout AppConfig) -> Void) {
        var copy = draftConfig
        transform(&copy)
        draftConfig = copy
        viewModel.configManager.replace(with: copy)
    }

    private func commitUnsplashAccessKey() {
        viewModel.saveUnsplashAccessKey(draftUnsplashAccessKey)
    }

    private func sectionLabel(_ title: String, isFirst: Bool = false) -> some View {
        Text(title.uppercased())
            .font(MenuPanelMetrics.sectionFont)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 2)
            .padding(.top, isFirst ? 0 : MenuPanelMetrics.spacing)
    }

    private func menuButton(title: String, symbol: String, centered: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(MenuActionButtonStyle(centered: centered))
    }
}
