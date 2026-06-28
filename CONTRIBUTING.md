# Contributing to Look Away

Thank you for considering a contribution. This project is a native macOS menu bar app built with Swift and SwiftUI.

## Before you start

1. Read the [README](README.md) for build instructions and architecture overview.
2. Search [existing issues](https://github.com/dvdcarlomagno/look-away/issues) to avoid duplicate work.
3. For large changes, open an issue first to discuss the approach.

## Development setup

### Requirements

- macOS 14 (Sonoma) or later
- Apple Command Line Tools (`xcode-select --install`)
- Xcode 15+ (optional, for the Xcode project workflow)

### Quick build

```bash
./build.sh
open build/LookAway.app
```

### Xcode workflow

1. Open `LookAway.xcodeproj`.
2. Select the LookAway target → Signing & Capabilities → choose your development team.
3. Build and run (`Cmd+R`).

## Project structure

| Path | Purpose |
|------|---------|
| `LookAway/LookAwayApp.swift` | App entry point, menu bar extra |
| `LookAway/Models/` | Data models (`AppConfig`, `BreakStats`) |
| `LookAway/Services/` | Timer, config, monitors (mic, sleep), launch-at-login, input shield |
| `LookAway/Views/` | SwiftUI UI (menu bar panel, break overlay, hold-to-confirm controls) |
| `LookAway/Controllers/` | `NSPanel` overlay controller for multi-display breaks |
| `scripts/` | App icon generation |
| `build.sh` | Command-line build without full Xcode |

### Key services

| File | Purpose |
|------|---------|
| `TimerEngine.swift` | Work/break/pause phases, streak, skip penalty |
| `BreakOverlayController.swift` | Multi-monitor overlay panels, emergency exit |
| `BreakInputShield.swift` | Blocks ⌘Q / ⌘W / ⌘Tab / Esc during breaks |
| `BreakStats.swift` | Streak and pending penalty persistence (`stats.json`) |
| `MenuBarWindowDismisser.swift` | Closes menu bar window when break starts |

## Coding guidelines

- Match existing Swift style: `@MainActor` for UI-bound services, `ObservableObject` + `@Published` for state.
- Keep menu bar updates lightweight — `TimerEngine` publishes display fields only when values change.
- Prefer extending existing services over adding parallel implementations.
- No new dependencies unless discussed in an issue first; the app intentionally stays dependency-free.
- Test on both Apple Silicon and Intel when touching build or platform code.
- When changing `build.sh` source list, update `LookAway.xcodeproj` in the same PR.

## Pull request process

1. Fork the repository and create a branch from `main`.
2. Make focused changes with a clear commit message.
3. Verify the app builds with `./build.sh` (or Xcode).
4. Manually smoke-test:
   - Timer tick, pause/resume, restart (hold)
   - Break overlay appears centered on all displays
   - Hold **Skip Break** ends break early (streak resets, penalty applied)
   - **Emergency exit** ends break without penalty
   - Menu bar closes and disables during break
   - Settings persist to `config.json`
5. Open a PR describing **what** changed and **why**.
6. Link any related issues.

## Reporting bugs

Include:

- macOS version and chip (Apple Silicon / Intel)
- How you built the app (`build.sh` vs Xcode)
- Steps to reproduce
- Expected vs actual behavior
- Screenshots or screen recordings when UI-related
- Single vs multi-monitor setup if overlay-related

## Feature requests

Open an issue with:

- The problem you want solved
- Proposed behavior
- Why it fits the scope of a focused break-timer menu bar app

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
