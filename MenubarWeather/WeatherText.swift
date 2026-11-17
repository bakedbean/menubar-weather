/// Human-readable strings for the menu's info rows.
enum WeatherText {
    static func conditions(code: Int) -> String {
        switch code {
        case 0: "Clear sky"
        case 1: "Mainly clear"
        case 2: "Partly cloudy"
        case 3: "Overcast"
        case 45, 48: "Fog"
        case 51: "Light drizzle"
        case 53: "Drizzle"
        case 55: "Heavy drizzle"
        case 56, 57: "Freezing drizzle"
        case 61: "Light rain"
        case 63: "Rain"
        case 65: "Heavy rain"
        case 66, 67: "Freezing rain"
        case 71: "Light snow"
        case 73: "Snow"
        case 75: "Heavy snow"
        case 77: "Snow grains"
        case 80: "Light showers"
        case 81: "Showers"
        case 82: "Heavy showers"
        case 85: "Light snow showers"
        case 86: "Snow showers"
        case 95: "Thunderstorm"
        case 96, 99: "Thunderstorm with hail"
        default: "Unknown conditions"
        }
    }

    static func wind(speed: Double, directionDegrees: Double, unit: TemperatureUnit) -> String {
        let rounded = Int(speed.rounded())
        guard rounded > 0 else { return "Wind calm" }
        let points = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((directionDegrees / 45).rounded()) % 8
        return "Wind \(rounded) \(unit == .fahrenheit ? "mph" : "km/h") \(points[index])"
    }

    static func humidity(_ percent: Int) -> String {
        "Humidity \(percent)%"
    }

    static func tomorrow(_ forecast: DailyForecast) -> String {
        "Tomorrow: \(conditions(code: forecast.weatherCode)) \(formatTemperature(forecast.high))/\(formatTemperature(forecast.low))"
    }

    static func location(name: String, source: LocationSource) -> String {
        switch source {
        case .precise: name
        case .lastKnown: "\(name) (last known)"
        case .approximate: "\(name) (approximate)"
        }
    }
}
