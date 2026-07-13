# Break overlay (lock screen)

## Layout (top → bottom, centered)

1. **Streak badge** — flame + consecutive completed breaks (subtle glass capsule on macOS 26)
2. **Countdown** — bold monospaced timer in a pink-tinted liquid glass pill
3. **Look Away** — title below the timer
4. **Skip** — hold-to-skip at bottom of screen (~20% opacity)

## Background

- True black (`Color.black`) on every display via opaque `NSPanel`
- No photos, gradients, or earthy/nature imagery

## Skip friction

- Hold **11 seconds** on overlay skip or menu bar **Skip** / **Restart** during break
- Resets streak; adds `skipPenaltyMinutes` to next break

## Files

- `LookAway/Views/BreakOverlayView.swift` — overlay SwiftUI
- `LookAway/Controllers/BreakOverlayController.swift` — multi-monitor panels + input shield
