import XCTest
@testable import MenubarWeather

@MainActor
final class InMemoryCoordinateStore: CoordinateStore {
    var lastCoordinate: Coordinate?
}

@MainActor
final class FallbackLocationProviderTests: XCTestCase {
    let precise = Coordinate(latitude: 40.71, longitude: -74.01)
    let saved = Coordinate(latitude: 41.0, longitude: -73.0)
    let approximate = Coordinate(latitude: 40.0, longitude: -74.0)

    func makeProvider(primary: FakeLocation, approximate: FakeLocation, store: InMemoryCoordinateStore) -> FallbackLocationProvider {
        FallbackLocationProvider(primary: primary, approximate: approximate, store: store, primaryTimeout: .milliseconds(50))
    }

    func testFreshFixIsReturnedAndSaved() async throws {
        let primary = FakeLocation(); primary.result = .success(precise)
        let store = InMemoryCoordinateStore()
        let provider = makeProvider(primary: primary, approximate: FakeLocation(), store: store)
        let coordinate = try await provider.currentCoordinate()
        XCTAssertEqual(coordinate, precise)
        XCTAssertEqual(store.lastCoordinate, precise)
    }

    func testSlowFixFallsBackToSavedCoordinate() async throws {
        let primary = FakeLocation(); primary.suspends = true
        let store = InMemoryCoordinateStore(); store.lastCoordinate = saved
        let ip = FakeLocation(); ip.result = .success(approximate)
        let coordinate = try await makeProvider(primary: primary, approximate: ip, store: store).currentCoordinate()
        XCTAssertEqual(coordinate, saved)
        primary.pending?.resume(throwing: LocationError.unavailable)
    }

    func testNoSavedCoordinateUsesApproximateLookup() async throws {
        let primary = FakeLocation(); primary.result = .failure(LocationError.unavailable)
        let ip = FakeLocation(); ip.result = .success(approximate)
        let store = InMemoryCoordinateStore()
        let coordinate = try await makeProvider(primary: primary, approximate: ip, store: store).currentCoordinate()
        XCTAssertEqual(coordinate, approximate)
        XCTAssertNil(store.lastCoordinate, "approximate locations aren't saved as precise ones")
    }

    func testDeniedIsNotMaskedByFallback() async {
        let primary = FakeLocation(); primary.result = .failure(LocationError.denied)
        let store = InMemoryCoordinateStore(); store.lastCoordinate = saved
        let ip = FakeLocation(); ip.result = .success(approximate)
        do {
            _ = try await makeProvider(primary: primary, approximate: ip, store: store).currentCoordinate()
            XCTFail("expected denied")
        } catch {
            XCTAssertEqual(error as? LocationError, .denied)
        }
    }

    func testLateFixIsSavedForNextTime() async throws {
        let primary = FakeLocation(); primary.suspends = true
        let ip = FakeLocation(); ip.result = .success(approximate)
        let store = InMemoryCoordinateStore()
        _ = try await makeProvider(primary: primary, approximate: ip, store: store).currentCoordinate()
        primary.pending?.resume(returning: precise)
        for _ in 0..<20 where store.lastCoordinate == nil { await Task.yield() }
        XCTAssertEqual(store.lastCoordinate, precise)
    }

    func testAllSourcesFailingThrowsUnavailable() async {
        let primary = FakeLocation(); primary.result = .failure(LocationError.unavailable)
        let ip = FakeLocation(); ip.result = .failure(URLError(.notConnectedToInternet))
        do {
            _ = try await makeProvider(primary: primary, approximate: ip, store: InMemoryCoordinateStore()).currentCoordinate()
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? LocationError, .unavailable)
        }
    }
}

final class IPLocationTests: XCTestCase {
    func testDecode() throws {
        let json = #"{"ip":"203.0.113.9","success":true,"city":"Brooklyn","latitude":40.6501,"longitude":-73.9496}"#
        XCTAssertEqual(try IPLocation.decode(Data(json.utf8)), Coordinate(latitude: 40.6501, longitude: -73.9496))
    }

    func testDecodeErrorPayloadThrows() {
        XCTAssertThrowsError(try IPLocation.decode(Data(#"{"success":false,"message":"Reserved range"}"#.utf8)))
    }

    func testURL() {
        XCTAssertEqual(IPLocation.url.absoluteString, "https://ipwho.is/")
    }
}

@MainActor
final class UserDefaultsCoordinateStoreTests: XCTestCase {
    func testRoundTrip() {
        let defaults = UserDefaults(suiteName: "MenubarWeatherTests")!
        defaults.removePersistentDomain(forName: "MenubarWeatherTests")
        let store = UserDefaultsCoordinateStore(defaults: defaults)
        XCTAssertNil(store.lastCoordinate)
        store.lastCoordinate = Coordinate(latitude: 1.5, longitude: -2.5)
        XCTAssertEqual(UserDefaultsCoordinateStore(defaults: defaults).lastCoordinate, Coordinate(latitude: 1.5, longitude: -2.5))
    }
}
