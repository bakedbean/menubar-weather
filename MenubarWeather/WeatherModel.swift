import Foundation

struct MenuDisplay: Equatable {
    let symbolName: String
    let text: String

    static let placeholder = MenuDisplay(symbolName: "thermometer", text: "--°")
    static let locationDenied = MenuDisplay(symbolName: "location.slash", text: "--°")
}

@MainActor
final class WeatherModel: ObservableObject {
    @Published private(set) var display: MenuDisplay = .placeholder

    private let location: LocationProviding
    private let weather: WeatherFetching
    private let unit: TemperatureUnit
    private var isRefreshing = false
    var refreshTimer: Timer?
    var wakeObserver: NSObjectProtocol?

    init(location: LocationProviding, weather: WeatherFetching, unit: TemperatureUnit) {
        self.location = location
        self.weather = weather
        self.unit = unit
    }

    /// Denied location replaces the display; any other failure keeps the last reading.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let coordinate = try await location.currentCoordinate()
            let current = try await weather.currentWeather(at: coordinate, unit: unit)
            display = MenuDisplay(
                symbolName: WeatherIcon.symbolName(code: current.weatherCode, isDay: current.isDay),
                text: formatTemperature(current.temperature)
            )
        } catch LocationError.denied {
            display = .locationDenied
        } catch {
            // Keep the last good reading.
        }
    }
}
