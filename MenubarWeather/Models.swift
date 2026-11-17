import Foundation

enum LocationSource: Sendable {
    case precise, lastKnown, approximate
}

struct Coordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    var source: LocationSource = .precise
}

struct DailyForecast: Equatable, Sendable {
    let weatherCode: Int
    let high: Double
    let low: Double
}

struct CurrentWeather: Equatable, Sendable {
    let temperature: Double
    let weatherCode: Int
    let isDay: Bool
    var humidity: Int? = nil
    var windSpeed: Double? = nil
    var windDirection: Double? = nil
    var tomorrow: DailyForecast? = nil
}

enum TemperatureUnit: String, Sendable {
    case fahrenheit, celsius

    static func preferred(for locale: Locale) -> TemperatureUnit {
        locale.measurementSystem == .us ? .fahrenheit : .celsius
    }
}

protocol WeatherFetching: Sendable {
    func currentWeather(at coordinate: Coordinate, unit: TemperatureUnit) async throws -> CurrentWeather
}
