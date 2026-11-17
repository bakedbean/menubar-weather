# Menubar Weather — Design

## Intent
A glanceable macOS menubar item showing the current local temperature and an icon for current conditions. Nothing more.

## Goals
- Menubar shows `[icon] 72°` for the user's current location.
- Location follows the user (travel) via macOS Location Services.

## Non-goals
Forecasts, multiple cities, alerts, settings UI, dock icon, main window.

## Approaches
1. **Location Services (chosen)** — accurate, follows the user; one-time permission prompt; requires a real app bundle.
2. IP geolocation — no prompt, but city-level-or-worse accuracy and wrong on VPN.
3. Fixed typed-in city — exact but doesn't travel.

User picked 1.

## Design
- **App:** native SwiftUI, `MenuBarExtra` (macOS 14+ target), `LSUIElement = YES` so there's no dock icon. Xcode project, sandboxed with location + outgoing-network entitlements and an `NSLocationUsageDescription` string.
- **Location:** `CLLocationManager`, request authorization on first launch, fetch a one-shot location each refresh.
- **Weather:** Open-Meteo `/v1/forecast?current=temperature_2m,weather_code,is_day` (free, no key). Unit `fahrenheit`/`celsius` chosen from the Mac's locale measurement system.
- **Refresh:** every 15 min, on wake from sleep, and on manual "Refresh".
- **Icon:** WMO `weather_code` + `is_day` → SF Symbol (e.g. `sun.max`, `moon.stars`, `cloud.sun`, `cloud.rain`, `cloud.snow`, `cloud.bolt`, `cloud.fog`).
- **Menu (on click):** "Refresh", "Quit".
- **Failure states:** location denied → `location.slash` icon with `--°`; network/API error → keep last good reading (show `--°` if none).

## Left to the builder (my calls)
- Project generation method and file layout.
- Exact code→symbol mapping table.
- Unit tests for the weather-code mapping and API response decoding.
