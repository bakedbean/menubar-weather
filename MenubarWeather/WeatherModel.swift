import Foundation

struct MenuDisplay: Equatable {
    let symbolName: String
    let text: String

    static let placeholder = MenuDisplay(symbolName: "thermometer", text: "--°")
    static let locationDenied = MenuDisplay(symbolName: "location.slash", text: "--°")
}

/// Pre-formatted info rows for the menu; nil rows are hidden.
struct WeatherDetails: Equatable {
    var location: String?
    let conditions: String
    var wind: String?
    var humidity: String?
    var tomorrow: String?
    let updated: Date
}

@MainActor
final class WeatherModel: ObservableObject {
    @Published private(set) var display: MenuDisplay = .placeholder
    @Published private(set) var details: WeatherDetails?

    private let location: LocationProviding
    private let weather: WeatherFetching
    private let unit: TemperatureUnit
    private let placeNamer: PlaceNaming
    private let now: @MainActor () -> Date
    private var cachedPlace: (area: String, name: String)?
    private let refreshTimeout: Duration
    private let retryDelays: [Duration]
    private var isRefreshing = false
    private var retryAttempt = 0
    private var retryTask: Task<Void, Never>?
    var refreshTimer: Timer?
    var wakeObserver: NSObjectProtocol?

    init(location: LocationProviding, weather: WeatherFetching, unit: TemperatureUnit,
         refreshTimeout: Duration = .seconds(45),
         retryDelays: [Duration] = [.seconds(30), .seconds(60), .seconds(120)],
         placeNamer: PlaceNaming = NoPlaceNames(),
         now: @escaping @MainActor () -> Date = { Date() }) {
        self.placeNamer = placeNamer
        self.now = now
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
            let (coordinate, current, place) = try await withTimeout(refreshTimeout) { [self] in
                let coordinate = try await location.currentCoordinate()
                let current = try await weather.currentWeather(at: coordinate, unit: unit)
                return (coordinate, current, await placeName(for: coordinate))
            }
            display = MenuDisplay(
                symbolName: WeatherIcon.symbolName(code: current.weatherCode, isDay: current.isDay),
                text: formatTemperature(current.temperature)
            )
            details = makeDetails(current, place: place, source: coordinate.source)
            retryAttempt = 0
        } catch LocationError.denied {
            display = .locationDenied
            details = nil
            retryAttempt = 0
        } catch {
            scheduleRetry()
        }
    }

    /// Names are cached per ~1 km area (2 decimal places) so refreshes don't re-geocode.
    private func placeName(for coordinate: Coordinate) async -> String? {
        let area = String(format: "%.2f,%.2f", coordinate.latitude, coordinate.longitude)
        if let cachedPlace, cachedPlace.area == area { return cachedPlace.name }
        guard let name = await placeNamer.placeName(for: coordinate) else { return nil }
        cachedPlace = (area, name)
        return name
    }

    private func makeDetails(_ current: CurrentWeather, place: String?, source: LocationSource) -> WeatherDetails {
        var wind: String?
        if let speed = current.windSpeed, let direction = current.windDirection {
            wind = WeatherText.wind(speed: speed, directionDegrees: direction, unit: unit)
        }
        return WeatherDetails(
            location: place.map { WeatherText.location(name: $0, source: source) },
            conditions: WeatherText.conditions(code: current.weatherCode),
            wind: wind,
            humidity: current.humidity.map(WeatherText.humidity),
            tomorrow: current.tomorrow.map(WeatherText.tomorrow),
            updated: now()
        )
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
