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

## Addendum (2026-11-17): fallback location and menu details
- **Location fallback (user picked):** macOS location with a 10 s limit → last precise fix (saved in UserDefaults) → approximate IP lookup (ipwho.is). Denial is never masked. A late precise fix is saved for next time.
- **Menu (user approved):** disabled info rows, then Refresh / Quit:
  location name ("Brooklyn, NY", with "(approximate)" / "(last known)" suffix; hidden if the lookup fails), conditions in words (from the WMO code), "Wind 8 mph NW" (mph with °F, km/h with °C), "Humidity 62%", "Tomorrow: Light rain 55°/41°" (local day via `timezone=auto`), "Updated 1:15 PM". Missing values hide their row.
- Place names come from Apple's reverse geocoder and are looked up only when the coordinate changes (~1 km).
