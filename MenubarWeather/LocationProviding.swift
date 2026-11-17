enum LocationError: Error {
    case denied, unavailable
}

protocol LocationProviding: Sendable {
    @MainActor func currentCoordinate() async throws -> Coordinate
}
