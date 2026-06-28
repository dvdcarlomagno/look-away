import SwiftUI

@main
struct LookAwayApp: App {
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel, timerEngine: viewModel.timerEngine)
        } label: {
            MenuBarLabelView(engine: viewModel.timerEngine)
        }
        .menuBarExtraStyle(.window)
    }
}

/// Isolated, lightweight menu-bar label — avoids re-rendering glass/heavy SwiftUI on every tick.
private struct MenuBarLabelView: View {
    @ObservedObject var engine: TimerEngine

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: engine.menuBarSymbol)
                .symbolRenderingMode(.hierarchical)

            Text(engine.menuBarCompactText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
    }
}
