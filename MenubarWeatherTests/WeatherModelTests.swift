import XCTest
@testable import MenubarWeather

@MainActor
final class FakeLocation: LocationProviding {
    var result: Result<Coordinate, Error> = .success(Coordinate(latitude: 1, longitude: 2))
    var suspends = false
    var pending: CheckedContinuation<Coordinate, Error>?

    func currentCoordinate() async throws -> Coordinate {
        if suspends {
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        return try result.get()
    }
}

actor FakeWeather: WeatherFetching {
    private var results: [Result<CurrentWeather, Error>]
    private(set) var callCount = 0

    init(_ results: [Result<CurrentWeather, Error>]) { self.results = results }

    func currentWeather(at coordinate: Coordinate, unit: TemperatureUnit) async throws -> CurrentWeather {
        callCount += 1
        return try results.removeFirst().get()
    }
}

@MainActor
final class WeatherModelTests: XCTestCase {
    let sunny = CurrentWeather(temperature: 72.4, weatherCode: 0, isDay: true)

    func testInitialDisplayIsPlaceholder() {
        let model = WeatherModel(location: FakeLocation(), weather: FakeWeather([]), unit: .fahrenheit)
        XCTAssertEqual(model.display, .placeholder)
    }

    func testSuccessShowsIconAndTemp() async {
        let model = WeatherModel(location: FakeLocation(), weather: FakeWeather([.success(sunny)]), unit: .fahrenheit)
        await model.refresh()
        XCTAssertEqual(model.display, MenuDisplay(symbolName: "sun.max.fill", text: "72°"))
    }

    func testDeniedLocationShowsLocationSlash() async {
        let location = FakeLocation()
        location.result = .failure(LocationError.denied)
        let model = WeatherModel(location: location, weather: FakeWeather([]), unit: .fahrenheit)
        await model.refresh()
        XCTAssertEqual(model.display, .locationDenied)
    }

    func testFetchFailureKeepsLastGoodReading() async {
        let weather = FakeWeather([.success(sunny), .failure(URLError(.notConnectedToInternet))])
        let model = WeatherModel(location: FakeLocation(), weather: weather, unit: .fahrenheit)
        await model.refresh()
        await model.refresh()
        XCTAssertEqual(model.display, MenuDisplay(symbolName: "sun.max.fill", text: "72°"))
        let calls = await weather.callCount
        XCTAssertEqual(calls, 2)
    }

    func testFailureWithNoPriorReadingShowsPlaceholder() async {
        let location = FakeLocation()
        location.result = .failure(LocationError.unavailable)
        let model = WeatherModel(location: location, weather: FakeWeather([]), unit: .fahrenheit)
        await model.refresh()
        XCTAssertEqual(model.display, .placeholder)
    }

    func testConcurrentRefreshRunsOnce() async {
        let location = FakeLocation()
        location.suspends = true
        let weather = FakeWeather([.success(sunny), .success(sunny)])
        let model = WeatherModel(location: location, weather: weather, unit: .fahrenheit)

        let first = Task { await model.refresh() }
        while location.pending == nil { await Task.yield() }
        await model.refresh()
        location.pending?.resume(returning: Coordinate(latitude: 1, longitude: 2))
        await first.value

        let calls = await weather.callCount
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(model.display, MenuDisplay(symbolName: "sun.max.fill", text: "72°"))
    }

    func testHungLocationTimesOutAndReleasesRefresh() async {
        let location = FakeLocation()
        location.suspends = true
        let weather = FakeWeather([.success(sunny)])
        let model = WeatherModel(location: location, weather: weather, unit: .fahrenheit,
                                 refreshTimeout: .milliseconds(50), retryDelays: [])
        await model.refresh()
        XCTAssertEqual(model.display, .placeholder)

        location.suspends = false
        await model.refresh()
        XCTAssertEqual(model.display, MenuDisplay(symbolName: "sun.max.fill", text: "72°"))
        location.pending?.resume(throwing: LocationError.unavailable)
    }

    func testFailureSchedulesRetry() async throws {
        let weather = FakeWeather([.failure(URLError(.notConnectedToInternet)), .success(sunny)])
        let model = WeatherModel(location: FakeLocation(), weather: weather, unit: .fahrenheit,
                                 retryDelays: [.milliseconds(20)])
        await model.refresh()
        XCTAssertEqual(model.display, .placeholder)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(model.display, MenuDisplay(symbolName: "sun.max.fill", text: "72°"))
    }

    func testRetriesStopAfterDelaysExhausted() async throws {
        let failure = Result<CurrentWeather, Error>.failure(URLError(.notConnectedToInternet))
        let weather = FakeWeather([failure, failure, failure, .success(sunny)])
        let model = WeatherModel(location: FakeLocation(), weather: weather, unit: .fahrenheit,
                                 retryDelays: [.milliseconds(10), .milliseconds(10)])
        await model.refresh()
        try await Task.sleep(for: .milliseconds(300))
        let calls = await weather.callCount
        XCTAssertEqual(calls, 3)
        XCTAssertEqual(model.display, .placeholder)
    }

    // MARK: Menu details

    let t1 = Date(timeIntervalSince1970: 1_000_000)
    let full = CurrentWeather(temperature: 48.3, weatherCode: 61, isDay: true, humidity: 62, windSpeed: 8.2,
                              windDirection: 315, tomorrow: DailyForecast(weatherCode: 3, high: 55.4, low: 40.6))

    func testSuccessPopulatesDetails() async {
        let namer = FakePlaceNamer(name: "Brooklyn, NY")
        let model = WeatherModel(location: FakeLocation(), weather: FakeWeather([.success(full)]), unit: .fahrenheit,
                                 placeNamer: namer, now: { self.t1 })
        await model.refresh()
        XCTAssertEqual(model.details, WeatherDetails(
            location: "Brooklyn, NY", conditions: "Light rain", wind: "Wind 8 mph NW",
            humidity: "Humidity 62%", tomorrow: "Tomorrow: Overcast 55°/41°", updated: t1))
    }

    func testApproximateLocationIsLabeled() async {
        let location = FakeLocation()
        location.result = .success(Coordinate(latitude: 1, longitude: 2, source: .approximate))
        let model = WeatherModel(location: location, weather: FakeWeather([.success(full)]), unit: .fahrenheit,
                                 placeNamer: FakePlaceNamer(name: "Brooklyn, NY"))
        await model.refresh()
        XCTAssertEqual(model.details?.location, "Brooklyn, NY (approximate)")
    }

    func testPlaceNameLookedUpOncePerArea() async {
        let location = FakeLocation()
        location.result = .success(Coordinate(latitude: 40.7101, longitude: -74.0101))
        let namer = FakePlaceNamer(name: "Brooklyn, NY")
        let model = WeatherModel(location: location, weather: FakeWeather([.success(full), .success(full)]),
                                 unit: .fahrenheit, placeNamer: namer)
        await model.refresh()
        location.result = .success(Coordinate(latitude: 40.7104, longitude: -74.0098))
        await model.refresh()
        XCTAssertEqual(namer.lookups, 1)
        XCTAssertEqual(model.details?.location, "Brooklyn, NY")
    }

    func testMissingValuesHideRows() async {
        let model = WeatherModel(location: FakeLocation(), weather: FakeWeather([.success(sunny)]), unit: .fahrenheit,
                                 placeNamer: FakePlaceNamer(name: nil), now: { self.t1 })
        await model.refresh()
        XCTAssertEqual(model.details, WeatherDetails(
            location: nil, conditions: "Clear sky", wind: nil, humidity: nil, tomorrow: nil, updated: t1))
    }

    func testFailureKeepsDetailsAndUpdatedTime() async {
        var clock = t1
        let weather = FakeWeather([.success(full), .failure(URLError(.notConnectedToInternet))])
        let model = WeatherModel(location: FakeLocation(), weather: weather, unit: .fahrenheit,
                                 retryDelays: [], placeNamer: FakePlaceNamer(name: "Brooklyn, NY"), now: { clock })
        await model.refresh()
        clock = t1.addingTimeInterval(900)
        await model.refresh()
        XCTAssertEqual(model.details?.updated, t1)
    }

    func testDeniedClearsDetails() async {
        let location = FakeLocation()
        let model = WeatherModel(location: location, weather: FakeWeather([.success(full)]), unit: .fahrenheit,
                                 placeNamer: FakePlaceNamer(name: "Brooklyn, NY"))
        await model.refresh()
        location.result = .failure(LocationError.denied)
        await model.refresh()
        XCTAssertNil(model.details)
    }
}

@MainActor
final class FakePlaceNamer: PlaceNaming {
    let name: String?
    private(set) var lookups = 0
    init(name: String?) { self.name = name }

    func placeName(for coordinate: Coordinate) async -> String? {
        lookups += 1
        return name
    }
}
