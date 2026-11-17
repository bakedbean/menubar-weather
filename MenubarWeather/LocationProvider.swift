import CoreLocation

/// One-shot location lookups via CLLocationManager; asks for permission on first use.
@MainActor
final class LocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    // Coarser requests get deferred by the macOS location power saver and may never deliver.
    nonisolated static let desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyHundredMeters

    private let manager = CLLocationManager()
    private var authContinuation: CheckedContinuation<Void, Never>?
    private var locationContinuation: CheckedContinuation<Coordinate, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = Self.desiredAccuracy
    }

    func currentCoordinate() async throws -> Coordinate {
        if manager.authorizationStatus == .notDetermined {
            await withCheckedContinuation { continuation in
                authContinuation?.resume()
                authContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }
        switch manager.authorizationStatus {
        case .denied, .restricted: throw LocationError.denied
        case .notDetermined: throw LocationError.unavailable
        default: break
        }
        // A previous request abandoned by the caller's timeout is failed, not leaked.
        return try await withCheckedThrowingContinuation { continuation in
            locationContinuation?.resume(throwing: LocationError.unavailable)
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    // CLLocationManager calls its delegate on the thread that created it (main).
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            guard self.manager.authorizationStatus != .notDetermined else { return }
            authContinuation?.resume()
            authContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let coordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        MainActor.assumeIsolated {
            locationContinuation?.resume(returning: coordinate)
            locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            locationContinuation?.resume(throwing: LocationError.unavailable)
            locationContinuation = nil
        }
    }
}
