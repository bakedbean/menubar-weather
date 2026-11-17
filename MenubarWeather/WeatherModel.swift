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
    private let refreshTimeout: Duration
    private let retryDelays: [Duration]
    private var isRefreshing = false
    private var retryAttempt = 0
    private var retryTask: Task<Void, Never>?
    var refreshTimer: Timer?
    var wakeObserver: NSObjectProtocol?

    init(location: LocationProviding, weather: WeatherFetching, unit: TemperatureUnit,
         refreshTimeout: Duration = .seconds(45),
         retryDelays: [Duration] = [.seconds(30), .seconds(60), .seconds(120)]) {
        self.location = location
        self.weather = weather
        self.unit = unit
        self.refreshTimeout = refreshTimeout
        self.retryDelays = retryDelays
    }

    /// Denied location replaces the display; any other failure keeps the last reading
    /// and retries after each of `retryDelays`. A hung lookup is abandoned after `refreshTimeout`.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        retryTask?.cancel()
        retryTask = nil

        do {
            let current = try await withTimeout(refreshTimeout) { [location, weather, unit] in
                let coordinate = try await location.currentCoordinate()
                return try await weather.currentWeather(at: coordinate, unit: unit)
            }
            display = MenuDisplay(
                symbolName: WeatherIcon.symbolName(code: current.weatherCode, isDay: current.isDay),
                text: formatTemperature(current.temperature)
            )
            retryAttempt = 0
        } catch LocationError.denied {
            display = .locationDenied
            retryAttempt = 0
        } catch {
            scheduleRetry()
        }
    }

    private func scheduleRetry() {
        guard retryAttempt < retryDelays.count else {
            retryAttempt = 0
            return
        }
        let delay = retryDelays[retryAttempt]
        retryAttempt += 1
        retryTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
}
