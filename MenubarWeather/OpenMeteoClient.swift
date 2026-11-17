import Foundation

enum OpenMeteo {
    static func url(for coordinate: Coordinate, unit: TemperatureUnit) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: unit.rawValue),
        ]
        return components.url!
    }

    static func decode(_ data: Data) throws -> CurrentWeather {
        let current = try JSONDecoder().decode(Response.self, from: data).current
        return CurrentWeather(temperature: current.temperature, weatherCode: current.weatherCode, isDay: current.isDay == 1)
    }

    private struct Response: Decodable {
        let current: Current
    }

    private struct Current: Decodable {
        let temperature: Double
        let weatherCode: Int
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }
}

struct OpenMeteoClient: WeatherFetching {
    var session: URLSession = .shared

    func currentWeather(at coordinate: Coordinate, unit: TemperatureUnit) async throws -> CurrentWeather {
        let (data, response) = try await session.data(from: OpenMeteo.url(for: coordinate, unit: unit))
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try OpenMeteo.decode(data)
    }
}
