# Menubar Weather Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A menubar-only macOS app showing `[SF Symbol] 72°` for the user's current location.

**Architecture:** SwiftUI `MenuBarExtra` app. Pure, tested units (icon mapping, temperature formatting, Open-Meteo URL/decoding) feed a `@MainActor` `WeatherModel` that depends on two protocols (`LocationProviding`, `WeatherFetching`) so its state logic is tested with fakes. The real `CLLocationManager` wrapper and app wiring are verified by running the app.

**Tech Stack:** Swift 6.2, SwiftUI, CoreLocation, URLSession, XCTest, XcodeGen (`brew install xcodegen`) to generate the `.xcodeproj` from `project.yml`.

**Spec:** `docs/superpowers/specs/2026-11-17-menubar-weather-design.md`

## Global Constraints

- Deployment target macOS 14.0; `SWIFT_VERSION = 6.0` (strict concurrency).
- `LSUIElement = YES` (no dock icon, no main window).
- App Sandbox on, with entitlements `com.apple.security.personal-information.location` and `com.apple.security.network.client`.
- Info.plist `NSLocationUsageDescription`: "Menubar Weather uses your location to show local weather."
- Bundle id `com.local.MenubarWeather`; ad-hoc signing (`CODE_SIGN_IDENTITY = "-"`).
- Weather API: `https://api.open-meteo.com/v1/forecast?latitude=…&longitude=…&current=temperature_2m,weather_code,is_day&temperature_unit=<fahrenheit|celsius>`. No API key.
- Refresh every 15 minutes (900 s), on wake from sleep, and on menu "Refresh".
- Menu items exactly: "Refresh", "Quit".
- No third-party Swift dependencies.

## Review Focus

1. **Location permission denied/restricted** → `location.slash` with `--°`, not a hang or crash. (Task 3 test `testDeniedLocationShowsLocationSlash`)
2. **Network/API failure after a good reading** → last good reading stays on screen. (Task 3 test `testFetchFailureKeepsLastGoodReading`)
3. **Temperatures that round to zero from below** (e.g. -0.4) → `0°`, never `-0°`. (Task 1 test `testNegativeZeroFormatsAsZero`)
4. **Unknown/new WMO code** → generic `cloud` symbol rather than an empty label. (Task 1 test `testUnknownCodeFallsBackToCloud`)
5. **Overlapping refreshes** (timer + wake + manual at once) → only one fetch in flight; extra calls are dropped. (Task 3 test `testConcurrentRefreshRunsOnce`)

---

### Task 1: Project scaffold, icon mapping, temperature formatting

**Files:**
- Create: `project.yml`, `.gitignore` (ignore `*.xcodeproj`, `build/`, `DerivedData/`)
- Create: `MenubarWeather/Info.plist`, `MenubarWeather/MenubarWeather.entitlements`
- Create: `MenubarWeather/MenubarWeatherApp.swift` (placeholder `MenuBarExtra("--°", systemImage: "thermometer") { Button("Quit") { NSApp.terminate(nil) } }`)
- Create: `MenubarWeather/WeatherIcon.swift`, `MenubarWeather/TemperatureFormat.swift`
- Test: `MenubarWeatherTests/WeatherIconTests.swift`, `MenubarWeatherTests/TemperatureFormatTests.swift`

**Interfaces:**
- Produces: `enum WeatherIcon { static func symbolName(code: Int, isDay: Bool) -> String }`
- Produces: `func formatTemperature(_ value: Double) -> String` (rounded, with `°`, no unit letter)

- [ ] **Step 1:** `git init`; `brew install xcodegen` if missing. Write `project.yml`: app target `MenubarWeather` (macOS application, sources `MenubarWeather`, Info.plist + entitlements per Global Constraints) and unit-test target `MenubarWeatherTests` hosted by the app. Run `xcodegen generate`. Expected: `MenubarWeather.xcodeproj` created.

- [ ] **Step 2: Write failing tests**

```swift
// WeatherIconTests
func testClearDayAndNight() {
    XCTAssertEqual(WeatherIcon.symbolName(code: 0, isDay: true), "sun.max.fill")
    XCTAssertEqual(WeatherIcon.symbolName(code: 0, isDay: false), "moon.stars.fill")
}
func testMappingTable() {
    let cases: [(Int, Bool, String)] = [
        (1, true, "cloud.sun.fill"), (2, false, "cloud.moon.fill"), (3, true, "cloud.fill"),
        (45, true, "cloud.fog.fill"), (48, true, "cloud.fog.fill"),
        (51, true, "cloud.drizzle.fill"), (57, true, "cloud.drizzle.fill"),
        (61, true, "cloud.rain.fill"), (67, true, "cloud.rain.fill"), (80, true, "cloud.heavyrain.fill"), (82, true, "cloud.heavyrain.fill"),
        (71, true, "cloud.snow.fill"), (77, true, "cloud.snow.fill"), (85, true, "cloud.snow.fill"), (86, true, "cloud.snow.fill"),
        (95, true, "cloud.bolt.rain.fill"), (99, true, "cloud.bolt.rain.fill"),
    ]
    for (code, day, expected) in cases {
        XCTAssertEqual(WeatherIcon.symbolName(code: code, isDay: day), expected, "code \(code)")
    }
}
func testUnknownCodeFallsBackToCloud() {
    XCTAssertEqual(WeatherIcon.symbolName(code: 42, isDay: true), "cloud")
}

// TemperatureFormatTests
func testRounds() { XCTAssertEqual(formatTemperature(72.4), "72°"); XCTAssertEqual(formatTemperature(72.5), "73°") }
func testNegative() { XCTAssertEqual(formatTemperature(-3.6), "-4°") }
func testNegativeZeroFormatsAsZero() { XCTAssertEqual(formatTemperature(-0.4), "0°") }
```

- [ ] **Step 3:** Run `xcodebuild test -project MenubarWeather.xcodeproj -scheme MenubarWeather -destination 'platform=macOS'`. Expected: FAIL (symbols undefined).

- [ ] **Step 4:** Implement `WeatherIcon.symbolName` as a `switch` over WMO code ranges matching the table (codes 1–2 use day/night variants; 0 too). Implement `formatTemperature` with `.rounded()` and normalize `-0` to `0`.

- [ ] **Step 5:** Re-run tests. Expected: PASS. Also run `open` on the built app once: thermometer + `--°` appears in the menubar, no dock icon.

- [ ] **Step 6: Commit** — `git add -A && git commit -m "feat: scaffold menubar app with icon mapping and temperature formatting"`

---

### Task 2: Open-Meteo client and unit selection

**Files:**
- Create: `MenubarWeather/OpenMeteoClient.swift`, `MenubarWeather/Models.swift`
- Test: `MenubarWeatherTests/OpenMeteoTests.swift`

**Interfaces:**
- Produces (`Models.swift`):
  - `struct Coordinate: Equatable, Sendable { let latitude: Double; let longitude: Double }`
  - `struct CurrentWeather: Equatable, Sendable { let temperature: Double; let weatherCode: Int; let isDay: Bool }`
  - `enum TemperatureUnit: String, Sendable { case fahrenheit, celsius; static func preferred(for locale: Locale) -> TemperatureUnit }` — `.fahrenheit` iff `locale.measurementSystem == .us`
  - `protocol WeatherFetching: Sendable { func currentWeather(at: Coordinate, unit: TemperatureUnit) async throws -> CurrentWeather }`
- Produces (`OpenMeteoClient.swift`):
  - `enum OpenMeteo { static func url(for: Coordinate, unit: TemperatureUnit) -> URL; static func decode(_ data: Data) throws -> CurrentWeather }`
  - `struct OpenMeteoClient: WeatherFetching { var session: URLSession = .shared }` — throws on non-2xx

- [ ] **Step 1: Write failing tests**

```swift
func testURL() {
    let url = OpenMeteo.url(for: Coordinate(latitude: 40.71, longitude: -74.01), unit: .fahrenheit)
    let items = Set(URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!)
    XCTAssertEqual(url.host, "api.open-meteo.com"); XCTAssertEqual(url.path, "/v1/forecast")
    XCTAssertTrue(items.isSuperset(of: [
        URLQueryItem(name: "latitude", value: "40.71"), URLQueryItem(name: "longitude", value: "-74.01"),
        URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
        URLQueryItem(name: "temperature_unit", value: "fahrenheit")]))
}
func testDecode() throws {
    let json = #"{"latitude":40.7,"current":{"time":"2026-11-17T12:00","interval":900,"temperature_2m":48.3,"weather_code":61,"is_day":1}}"#
    XCTAssertEqual(try OpenMeteo.decode(Data(json.utf8)), CurrentWeather(temperature: 48.3, weatherCode: 61, isDay: true))
}
func testDecodeMalformedThrows() { XCTAssertThrowsError(try OpenMeteo.decode(Data("{}".utf8))) }
func testPreferredUnit() {
    XCTAssertEqual(TemperatureUnit.preferred(for: Locale(identifier: "en_US")), .fahrenheit)
    XCTAssertEqual(TemperatureUnit.preferred(for: Locale(identifier: "en_GB")), .celsius)
    XCTAssertEqual(TemperatureUnit.preferred(for: Locale(identifier: "de_DE")), .celsius)
}
```

- [ ] **Step 2:** Run tests. Expected: FAIL (undefined).
- [ ] **Step 3:** Implement per Interfaces. Decode via private `Decodable` structs with `CodingKeys` for `temperature_2m`, `weather_code`, `is_day` (Int → Bool).
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -am "feat: add Open-Meteo client and locale-based unit"` (add new files first).

---

### Task 3: WeatherModel state logic

**Files:**
- Create: `MenubarWeather/WeatherModel.swift`, `MenubarWeather/LocationProviding.swift`
- Test: `MenubarWeatherTests/WeatherModelTests.swift`

**Interfaces:**
- Consumes: `WeatherIcon.symbolName`, `formatTemperature`, `Coordinate`, `CurrentWeather`, `TemperatureUnit`, `WeatherFetching`
- Produces:
  - `enum LocationError: Error { case denied, unavailable }`
  - `protocol LocationProviding: Sendable { @MainActor func currentCoordinate() async throws -> Coordinate }`
  - `struct MenuDisplay: Equatable { let symbolName: String; let text: String; static let placeholder = MenuDisplay(symbolName: "thermometer", text: "--°"); static let locationDenied = MenuDisplay(symbolName: "location.slash", text: "--°") }`
  - `@MainActor final class WeatherModel: ObservableObject { @Published private(set) var display: MenuDisplay; init(location: LocationProviding, weather: WeatherFetching, unit: TemperatureUnit); func refresh() async }`

Rules: success → `MenuDisplay(symbolName: WeatherIcon.symbolName(...), text: formatTemperature(...))`. `LocationError.denied` → `.locationDenied` (overrides last reading). Any other error → keep current `display`. If a refresh is already running, a second `refresh()` returns immediately.

- [ ] **Step 1: Write failing tests** using fakes `FakeLocation` (returns coordinate or throws; optional suspend via continuation) and `FakeWeather` (returns queued results, counts calls).

```swift
func testInitialDisplayIsPlaceholder()            // display == .placeholder
func testSuccessShowsIconAndTemp()                 // weather 72.4/code 0/day → MenuDisplay("sun.max.fill", "72°")
func testDeniedLocationShowsLocationSlash()        // location throws .denied → .locationDenied
func testFetchFailureKeepsLastGoodReading()        // success then URLError → display unchanged from success
func testFailureWithNoPriorReadingShowsPlaceholder() // location .unavailable first → .placeholder
func testConcurrentRefreshRunsOnce()               // start refresh with suspended location, call refresh() again, resume → FakeWeather.callCount == 1
```

- [ ] **Step 2:** Run tests. Expected: FAIL.
- [ ] **Step 3:** Implement `WeatherModel` with a private `isRefreshing` flag per the rules above.
- [ ] **Step 4:** Run tests. Expected: PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat: add WeatherModel with failure handling"`

---

### Task 4: Real location provider and app wiring

**Files:**
- Create: `MenubarWeather/LocationProvider.swift`
- Modify: `MenubarWeather/MenubarWeatherApp.swift`

**Interfaces:**
- Consumes: `LocationProviding`, `LocationError`, `WeatherModel`, `OpenMeteoClient`, `TemperatureUnit.preferred(for: .current)`
- Produces: `@MainActor final class LocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate`

- [ ] **Step 1:** Implement `LocationProvider.currentCoordinate()`: if status `.notDetermined`, call `requestWhenInUseAuthorization()` and await the authorization callback; `.denied`/`.restricted` → throw `.denied`; then `requestLocation()` and resume a `CheckedContinuation` from `didUpdateLocations` (→ `Coordinate`) or `didFailWithError` (→ `.unavailable`). Use `desiredAccuracy = kCLLocationAccuracyKilometer`.
- [ ] **Step 2:** Wire the app: `@StateObject` `WeatherModel`; `MenuBarExtra { Button("Refresh") { Task { await model.refresh() } }; Divider(); Button("Quit") { NSApp.terminate(nil) } } label: { Label(model.display.text, systemImage: model.display.symbolName).labelStyle(.titleAndIcon) }`. Start refreshing on launch: an initial `refresh()`, a `Timer` every 900 s, and an observer on `NSWorkspace.didWakeNotification` that calls `refresh()`.
- [ ] **Step 3:** Run the test suite. Expected: all PASS.
- [ ] **Step 4: Manual verification.** Build and launch. Expected: (a) the location permission prompt appears with the usage string; (b) after allowing it, the icon and temperature match https://open-meteo.com for your city; (c) "Refresh" updates it; (d) deny location in System Settings → Privacy → Location Services, then Refresh → `location.slash --°`; (e) turn off Wi-Fi, then Refresh → the last reading stays.
- [ ] **Step 5: Commit** — `git commit -m "feat: wire location and refresh into menubar app"`
