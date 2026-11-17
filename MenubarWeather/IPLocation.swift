import Foundation

/// Approximate location from the public IP address (ipwho.is, no key).
enum IPLocation {
    static let url = URL(string: "https://ipwho.is/")!

    static func decode(_ data: Data) throws -> Coordinate {
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.success, let latitude = response.latitude, let longitude = response.longitude else {
            throw URLError(.cannotParseResponse)
        }
        return Coordinate(latitude: latitude, longitude: longitude)
    }

    private struct Response: Decodable {
        let success: Bool
        let latitude: Double?
        let longitude: Double?
    }
}

struct IPLocationProvider: LocationProviding {
    var session: URLSession = .shared

    func currentCoordinate() async throws -> Coordinate {
        let (data, response) = try await session.data(from: IPLocation.url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try IPLocation.decode(data)
    }
}
