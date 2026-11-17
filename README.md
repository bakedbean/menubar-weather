# Menubar Weather

A tiny macOS menubar app that shows the current temperature and a colored weather icon for where you are.

```
 ☀ 50°
┌──────────────────────────────┐
│ Brooklyn, NY                 │
│ Clear sky                    │
│ Wind 6 mph W                 │
│ Humidity 60%                 │
├──────────────────────────────┤
│ Tomorrow: Overcast 55°/40°   │
├──────────────────────────────┤
│ Updated 1:25 PM              │
│ Refresh                      │
│ Quit                         │
└──────────────────────────────┘
```

No dock icon, no window, no API keys.

## Features

- Temperature and a multicolor SF Symbol for current conditions (day and night variants). Plain clouds, fog and snow get a gray-blue tint.
- Menu with location name, conditions, wind, humidity, tomorrow's high/low and the time of the last update.
- °F with mph, or °C with km/h, picked from your Mac's region settings.
- Refreshes every 15 minutes, on wake from sleep, and from the Refresh menu item. Failed refreshes retry after 30 s, 60 s and 120 s.

## Requirements

- macOS 14 or later
- Xcode 16 or later (built and tested with Xcode 26)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Build and run

The Xcode project is generated from `project.yml` and isn't checked in.

```sh
xcodegen generate
xcodebuild -project MenubarWeather.xcodeproj -scheme MenubarWeather -configuration Release -derivedDataPath build build
open build/Build/Products/Release/MenubarWeather.app
```

Or run `xcodegen generate`, open `MenubarWeather.xcodeproj` in Xcode and press Run.

To keep it, copy `MenubarWeather.app` to `/Applications`. To start it at login, add it in System Settings → General → Login Items.

On first launch macOS asks for location access. Click **Allow**.

## How location works

1. Asks macOS Location Services, waiting up to 10 seconds.
2. If macOS is slow, uses the last precise location it received (saved between launches). The menu marks it "(last known)".
3. If it has never had a precise location, it uses an approximate one from your IP address via [ipwho.is](https://ipwho.is). The menu marks it "(approximate)".

If you deny location access, the menubar shows a crossed-out location icon and `--°`. The app doesn't fall back to IP location in that case.

## Data sources and privacy

| What | Service | Sends |
|------|---------|-------|
| Weather | [Open-Meteo](https://open-meteo.com) | Your coordinates |
| Place name | Apple's geocoder (CoreLocation) | Your coordinates |
| Approximate location (fallback only) | [ipwho.is](https://ipwho.is) | Your IP address |

Your last location is stored only in the app's local preferences. Nothing else is stored or sent.

## Development

Run the unit tests:

```sh
./test.sh
```

The app is a SwiftUI `MenuBarExtra`, written in Swift 6 with strict concurrency.

| File | Role |
|------|------|
| `MenubarWeatherApp.swift` | App entry point, menubar label and menu |
| `WeatherModel.swift` | Refresh logic, failure handling, menu rows |
| `AutoRefresh.swift` | 15-minute timer and wake-from-sleep refresh |
| `LocationProvider.swift` | CoreLocation wrapper |
| `FallbackLocationProvider.swift` | Last-known and approximate location fallbacks |
| `IPLocation.swift` | ipwho.is lookup |
| `PlaceNamer.swift` | Reverse geocoding for the location name |
| `OpenMeteoClient.swift` | Weather API request and decoding |
| `WeatherIcon.swift`, `MenuBarIcon.swift` | Weather code → colored SF Symbol |
| `WeatherText.swift` | Menu row text |

Design notes are in `docs/superpowers/specs/`.

## Known issues

- **Location prompt after rebuilds.** The app is signed ad hoc, so macOS may ask for location access again after each rebuild. Signing with an Apple Development certificate (free with an Apple ID) avoids this.
- **Slow location fixes.** macOS sometimes takes a minute or more to return a location, or doesn't return one at all. The fallbacks above cover this.
