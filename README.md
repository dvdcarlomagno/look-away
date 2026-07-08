# Look Away

A native macOS menu bar app that reminds you to step away from the screen on a repeating timer. When a work interval ends, a full-screen break overlay covers all displays until the break finishes—or you end it early with deliberate friction.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

## Features

- Menu bar timer with pause/resume, manual break, and hold-to-skip
- **Break streak** — consecutive completed breaks shown with a flame icon; skipping resets the streak
- **Skip penalty** — ending a break early adds extra minutes to your next break (configurable)
- **Emergency exit** — optional instant escape on the break screen (resets streak, no penalty)
- Configurable work and break durations in the menu bar **Settings** panel (saved to `~/.config/look-away/config.json`)
- Full-screen blur break overlay on all monitors, centered content, keyboard focus captured
- Break overlay hardening — shielding window level, blocked shortcuts (⌘Q, ⌘W, ⌘Tab, Esc), menu bar disabled during breaks
- Skips breaks while the microphone is in use (calls/meetings) — checks **all** input devices, not just the system default
- Pauses while the display is off, the Mac is asleep, or the screen is locked; **resumes** where you left off on a short return, **restarts the work timer** (and counts the break streak) when away time reaches the configured break duration (manual pause always resumes)
- Launch at login (toggle in menu bar)
- Pre-break warning notification (optional, off by default) with **Extend 3 minutes** action in the notification and menu bar
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
  "skipPenaltyMinutes": 5,
  "allowEmergencyExit": true,
  "launchAtLogin": true
}
```

Break streak data is stored separately in `~/.config/look-away/stats.json`.

Copy values from [`config.example.json`](config.example.json) if you prefer to start from the repo template.

## Config reference

| Key | Default | Description |
|-----|---------|-------------|
| `workDurationMinutes` | `120` | Minutes before a break starts |
| `breakDurationMinutes` | `15` | Break overlay duration |
| `preBreakWarningMinutes` | `0` | Minutes before break to notify (`0` = off) |
| `skipPenaltyMinutes` | `5` | Extra minutes added to the next break after an early skip (`0` = off) |
| `allowEmergencyExit` | `true` | Show **Emergency exit…** link on the break screen |
| `launchAtLogin` | `true` | Register app at login |

Edit the file while the app is running—it reloads automatically. Changes made in the menu bar settings panel write to the same file immediately.

## Menu bar controls

- **Pause / Resume** — manual timer pause (single tap)
- **Extend 3 min** — shown during the pre-break warning; adds 3 minutes to the work session (also available as a notification action)
- **Restart** — hold 5 seconds to reset the work timer; during a break, same hold ends the break early (streak + penalty apply)
- **Break / Skip** — start a break, or hold **Skip** for 5 seconds during a break to end early
- **Settings** — edit intervals, skip penalty, emergency exit; reveal `config.json`
- **Launch at login** — full-width toggle at the bottom of the panel
- **Quit** — disabled while a break is active

The menu bar panel closes automatically when a break starts. The menu bar icon is dimmed and disabled during breaks.

Interval fields support +/- steppers and direct numeric entry (press Return to apply).

## Break overlay

When a break starts, a centered card appears on every connected display:

- Countdown timer and progress ring
- **Streak badge** (flame icon + consecutive completed breaks)
- **Skip Break** — hold for 5 seconds to end early (resets streak, adds skip penalty to next break)
- **Emergency exit…** — one-click link with confirmation (resets streak, no penalty; can be disabled in settings)

The overlay uses a shielding window level, captures keyboard focus, and blocks common escape shortcuts. A brief **“Break in progress”** toast appears if a blocked shortcut is pressed.

## Architecture

```
LookAwayApp (MenuBarExtra)
    └── AppViewModel
            ├── ConfigManager           → ~/.config/look-away/config.json
            ├── TimerEngine             → work / break / pause phases, streak & penalty
            ├── MicrophoneMonitor       → skip breaks during calls
            ├── SleepWakeMonitor        → pause while away; long return restarts work timer
            ├── LaunchAtLoginManager
            └── BreakOverlayController  → full-screen NSPanel per display
                    └── BreakInputShield → keyboard shortcut blocking during breaks
```

| Component | Role |
|-----------|------|
| `TimerEngine` | Core countdown logic, phase transitions, streak/penalty, menu bar label updates |
| `BreakOverlayController` | Multi-display panels, keep-front timer, emergency exit dialog |
| `BreakInputShield` | Local/global event monitors for blocked shortcuts during breaks |
| `BreakStats` / `stats.json` | Persists consecutive break streak and pending skip penalty |
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

- **Microphone usage description** is included so macOS can detect when the mic is active during calls. The app does **not** record audio. Call detection scans every audio input device (built-in and external), so a break is deferred even when the active call uses a non-default microphone.
- **Accessibility** (optional) — granting Look Away Accessibility access in System Settings improves global shortcut blocking during breaks. Local blocking works when the app is frontmost without this permission.

## Skipping vs completing a break

| Action | Streak | Next break penalty |
|--------|--------|-------------------|
| Complete break (timer reaches 0) | +1 | None |
| **Skip Break** (hold 5s) or menu **Skip** / **Restart** during break | Reset to 0 | +`skipPenaltyMinutes` |
| **Emergency exit** (confirm dialog) | Reset to 0 | None |

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, project structure, and pull request guidelines.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE).

## Acknowledgments

Inspired by the need for a simple, native macOS break timer that respects calls and sleep without cloud accounts or subscriptions.
