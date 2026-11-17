import Foundation

struct Coordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct CurrentWeather: Equatable, Sendable {
    let temperature: Double
    let weatherCode: Int
    let isDay: Bool
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
