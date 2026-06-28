# Look Away

A native macOS menu bar app that reminds you to step away from the screen on a repeating timer. When a work interval ends, a full-screen blur overlay covers all displays until the break finishes—or you confirm ending early.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Features

- Menu bar timer with pause/resume, manual break, and skip break
- Configurable work and break durations in the menu bar **Settings** panel (saved to `~/.config/look-away/config.json`)
- Full-screen blur break overlay on all monitors
- Skips breaks while the microphone is in use (calls/meetings)
- Pauses during sleep, screen lock, and manual pause
- Optional idle detection — pause the timer when you step away from the keyboard
- Launch at login (toggle in menu bar)
- Pre-break warning notification (optional, off by default)
- Native Liquid Glass UI on macOS 26 (via runtime `NSGlassEffectView`; falls back to materials on older macOS)

## Requirements

- macOS 14 (Sonoma) or later
- **Apple Command Line Tools** (no full Xcode required for `build.sh`)

Install Command Line Tools if needed:

```bash
xcode-select --install
```

## Quick start

Clone the repository:

```bash
git clone git@github.com:dvdcarlomagno/look-away.git
cd look-away
```

Build and run:

```bash
./build.sh
open build/LookAway.app
```

This compiles with `swiftc`, wraps the binary in a `.app` bundle, generates the bubble-gum **eyes** app icon, and ad-hoc signs it for local use.

If macOS blocks the first launch, right-click the app → **Open**.

## Build with Xcode (optional)

If you have Xcode installed:

1. Open `LookAway.xcodeproj` in Xcode.
2. Select the **LookAway** target → **Signing & Capabilities** → choose your development team.
3. Build and run (`Cmd+R`).

## First launch

On first launch, the app creates `~/.config/look-away/config.json` with defaults:

```json
{
  "workDurationMinutes": 120,
  "breakDurationMinutes": 15,
  "preBreakWarningMinutes": 0,
  "idlePauseSeconds": null,
  "launchAtLogin": true
}
```

Copy values from [`config.example.json`](config.example.json) if you prefer to start from the repo template.

## Config reference

| Key | Default | Description |
|-----|---------|-------------|
| `workDurationMinutes` | `120` | Minutes before a break starts |
| `breakDurationMinutes` | `15` | Break overlay duration |
| `preBreakWarningMinutes` | `0` | Minutes before break to notify (`0` = off) |
| `idlePauseSeconds` | `null` | Optional idle pause (`null` = disabled) |
| `launchAtLogin` | `true` | Register app at login |

Edit the file while the app is running—it reloads automatically. Changes made in the menu bar settings panel write to the same file immediately.

## Menu bar controls

- **Pause / Resume** — manual timer pause
- **Break / Skip** — start a break or skip the current one
- **Settings** — edit work/break/warning intervals, idle threshold, and reveal `config.json`
- **Pause when idle** / **Launch at login** — full-width toggles at the bottom of the panel
- **Quit**

Interval fields support +/- steppers and direct numeric entry (press Return to apply).

## Architecture

```
LookAwayApp (MenuBarExtra)
    └── AppViewModel
            ├── ConfigManager      → ~/.config/look-away/config.json
            ├── TimerEngine        → work / break / pause phases
            ├── MicrophoneMonitor  → skip breaks during calls
            ├── SleepWakeMonitor   → pause on sleep / lock
            ├── IdleMonitor        → optional idle pause
            ├── LaunchAtLoginManager
            └── BreakOverlayController → full-screen NSPanel per display
```

| Component | Role |
|-----------|------|
| `TimerEngine` | Core countdown logic, phase transitions, menu bar label updates |
| `BreakOverlayController` | Creates borderless panels on every connected display |
| `NativeGlassBridge` | Bridges `NSGlassEffectView` when available on newer macOS |
| `ConfigManager` | JSON persistence with file watcher for live reload |

## App icon

`./build.sh` generates a pink bubble-gum gradient icon with a white **eyes** SF Symbol via `scripts/generate_app_icon.swift`, bundles it as `AppIcon.icns`, and sets `CFBundleIconFile`.

To regenerate only the icon assets:

```bash
swift scripts/generate_app_icon.swift LookAway/Resources/AppIcon.iconset
iconutil -c icns LookAway/Resources/AppIcon.iconset -o LookAway/Resources/AppIcon.icns
```

If Finder still shows the old icon after rebuilding, restart the Dock:

```bash
killall Dock
```

## Permissions

- **Microphone usage description** is included so macOS can detect when the mic is active during calls. The app does **not** record audio.

## End break early

Click **End Break Early…** on the overlay, then confirm in the dialog. Cancel keeps the break running.

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, project structure, and pull request guidelines.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE).

## Acknowledgments

Inspired by the need for a simple, native macOS break timer that respects calls, sleep, and idle time without cloud accounts or subscriptions.
