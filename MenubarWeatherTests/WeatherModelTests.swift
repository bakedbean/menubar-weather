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
}
