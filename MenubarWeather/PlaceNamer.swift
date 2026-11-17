import CoreLocation

/// Reverse-geocodes with Apple's geocoder: "Locality, Region", e.g. "Brooklyn, NY".
struct AppleGeocoderPlaceNamer: PlaceNaming {
    func placeName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        let parts = [placemark.locality ?? placemark.subAdministrativeArea, placemark.administrativeArea]
            .compactMap { $0 }
        return parts.isEmpty ? placemark.country : parts.joined(separator: ", ")
    }
}
