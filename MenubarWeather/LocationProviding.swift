enum LocationError: Error {
    case denied, unavailable
}

protocol LocationProviding: Sendable {
    @MainActor func currentCoordinate() async throws -> Coordinate
}

protocol PlaceNaming: Sendable {
    /// A short place name like "Brooklyn, NY", or nil if it can't be found.
    @MainActor func placeName(for coordinate: Coordinate) async -> String?
}

struct NoPlaceNames: PlaceNaming {
    func placeName(for coordinate: Coordinate) async -> String? { nil }
}
