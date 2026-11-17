import Foundation

@MainActor
protocol CoordinateStore: AnyObject {
    var lastCoordinate: Coordinate? { get set }
}

final class UserDefaultsCoordinateStore: CoordinateStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var lastCoordinate: Coordinate? {
        get {
            guard let lat = defaults.object(forKey: "lastLatitude") as? Double,
                  let lon = defaults.object(forKey: "lastLongitude") as? Double else { return nil }
            return Coordinate(latitude: lat, longitude: lon)
        }
        set {
            defaults.set(newValue?.latitude, forKey: "lastLatitude")
            defaults.set(newValue?.longitude, forKey: "lastLongitude")
        }
    }
}

/// Precise location first; if it's slow or fails, the last precise fix, then an approximate lookup.
/// Denial is never masked. A precise fix that arrives after the timeout is still saved for next time.
@MainActor
final class FallbackLocationProvider: LocationProviding {
    private let primary: LocationProviding
    private let approximate: LocationProviding
    private let store: CoordinateStore
    private let primaryTimeout: Duration

    init(primary: LocationProviding, approximate: LocationProviding, store: CoordinateStore,
         primaryTimeout: Duration = .seconds(10)) {
        self.primary = primary
        self.approximate = approximate
        self.store = store
        self.primaryTimeout = primaryTimeout
    }

    func currentCoordinate() async throws -> Coordinate {
        let primaryTask = Task { [primary, store] in
            let coordinate = try await primary.currentCoordinate()
            store.lastCoordinate = coordinate
            return coordinate
        }
        do {
            return try await withTimeout(primaryTimeout) { try await primaryTask.value }
        } catch LocationError.denied {
            throw LocationError.denied
        } catch {}

        if let saved = store.lastCoordinate {
            return Coordinate(latitude: saved.latitude, longitude: saved.longitude, source: .lastKnown)
        }
        do {
            let rough = try await approximate.currentCoordinate()
            return Coordinate(latitude: rough.latitude, longitude: rough.longitude, source: .approximate)
        } catch {
            throw LocationError.unavailable
        }
    }
}
