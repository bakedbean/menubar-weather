import Foundation

enum OpenMeteo {
    static func url(for coordinate: Coordinate, unit: TemperatureUnit) -> URL {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(coordinate.latitude)),
            URLQueryItem(name: "longitude", value: String(coordinate.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day,relative_humidity_2m,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: unit.rawValue),
            URLQueryItem(name: "wind_speed_unit", value: unit == .fahrenheit ? "mph" : "kmh"),
        ]
        return components.url!
    }

    static func decode(_ data: Data) throws -> CurrentWeather {
        let response = try JSONDecoder().decode(Response.self, from: data)
        let current = response.current
        return CurrentWeather(
            temperature: current.temperature, weatherCode: current.weatherCode, isDay: current.isDay == 1,
            humidity: current.humidity, windSpeed: current.windSpeed, windDirection: current.windDirection,
            tomorrow: response.daily?.tomorrow
        )
    }

    private struct Response: Decodable {
        let current: Current
        let daily: Daily?
    }

    /// Index 0 is today, 1 is tomorrow (local to the location via `timezone=auto`).
    private struct Daily: Decodable {
        let weatherCode: [Int]
        let high: [Double]
        let low: [Double]

        var tomorrow: DailyForecast? {
            guard weatherCode.count > 1, high.count > 1, low.count > 1 else { return nil }
            return DailyForecast(weatherCode: weatherCode[1], high: high[1], low: low[1])
        }

        enum CodingKeys: String, CodingKey {
            case weatherCode = "weather_code"
            case high = "temperature_2m_max"
            case low = "temperature_2m_min"
        }
    }

    private struct Current: Decodable {
        let temperature: Double
        let weatherCode: Int
        let isDay: Int
        let humidity: Int?
        let windSpeed: Double?
        let windDirection: Double?

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
            case humidity = "relative_humidity_2m"
            case windSpeed = "wind_speed_10m"
            case windDirection = "wind_direction_10m"
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
