# Liquid Glass — Look Away

## Pattern (Apple SwiftUI)

Follow [Applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views):

- **Menu panel:** one outer `.glassEffect(.regular.tint(...), in: .rect(cornerRadius:))` via `LookAwayGlassPanel`, clipped to the same corner radius. **No** `GlassEffectContainer` wrapper around the whole panel (causes double-corner artifacts).
- **Inner controls:** `lookAwayControlSurface` / `lookAwayCapsuleSurface` — subtle pink-tinted fills, not nested glass.
- **Break overlay timer:** direct `.glassEffect` on the bold countdown pill only.
- Apply `.glassEffect` **after** padding and overlays that affect appearance.

## Palette

- Single accent: `LookAwayBrand.accent` — `Color(red: 1.0, green: 0.42, blue: 0.78)`
- Soft tint: `LookAwayBrand.accentSoft` — for highlights
- Glass tints: `LookAwayGlass.menuPanelTint`, `LookAwayGlass.overlayTint` (pink at low opacity)
- Destructive: system red only (skip penalty, quit)

## Do not use

- AppKit `NSGlassEffectView` via KVC/`NSViewRepresentable` — unstable from SwiftUI hosting views.
- Nested glass plates under labels inside an already-glass panel — blurs text and shows border artifacts.
- Multiple accent colors (forest, wood, sage, etc.) — removed intentionally.

## Build

`./build.sh` probes the SDK for `glassEffect` and defines `LIQUID_GLASS` when available (macOS 26 SDK). Without it, the app uses `.ultraThinMaterial` and subtle fill fallbacks.

## Files

- `LookAway/Views/GlassStyles.swift` — `LookAwayGlassPanel`, tokens, button backgrounds
- `LookAway/Views/LookAwayDesign.swift` — accent colors, metrics, status chips
