# Design system

## Accent

| Token | Value | Usage |
|-------|-------|-------|
| `LookAwayBrand.accent` | `rgb(1.0, 0.42, 0.78)` | Streak flame, status chips, glass tints, hold progress |
| `LookAwayBrand.accentSoft` | `rgb(1.0, 0.74, 0.90)` | Reserved for soft highlights |

Aliases: `LookAwayBrand.pink`, `LookAwayBrand.pinkSoft`.

## Non-accent colors

- **Primary / secondary** — system text colors in menu panel
- **Red** — destructive only (quit, skip penalty warnings, destructive hold buttons in menu)
- **White** — break overlay timer and title on black background

## Corner radii

| Token | Value | Usage |
|-------|-------|-------|
| `LookAwayGlass.panelCornerRadius` | 22 | Menu panel outer shell |
| `LookAwayGlass.controlCornerRadius` | 10 | Buttons, settings rows |
| Break timer glass | 36 | Lock screen countdown pill |

## Typography

- Rounded system design throughout
- Menu controls: `MenuPanelMetrics.controlFont` (body, medium)
- Break timer: 80pt **bold**, monospaced digits

## App icon

Pink gradient + white **eyes** SF Symbol — see `scripts/generate_app_icon.swift`.
