import SwiftUI

@main
struct MenubarWeatherApp: App {
    @StateObject private var model: WeatherModel

    init() {
        let model = WeatherModel(
            location: FallbackLocationProvider(
                primary: LocationProvider(),
                approximate: IPLocationProvider(),
                store: UserDefaultsCoordinateStore()
            ),
            weather: OpenMeteoClient(),
            unit: .preferred(for: .current),
            placeNamer: AppleGeocoderPlaceNamer()
        )
        _model = StateObject(wrappedValue: model)
        model.startAutoRefresh()
    }

    var body: some Scene {
        MenuBarExtra {
            if let details = model.details {
                if let location = details.location { Text(location) }
                Text(details.conditions)
                if let wind = details.wind { Text(wind) }
                if let humidity = details.humidity { Text(humidity) }
                if let tomorrow = details.tomorrow {
                    Divider()
                    Text(tomorrow)
                }
                Divider()
                Text("Updated \(details.updated.formatted(date: .omitted, time: .shortened))")
            }
            Button("Refresh") { Task { await model.refresh() } }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        } label: {
            HStack(spacing: 4) {
                if let icon = MenuBarIcon.image(for: model.display.symbolName) {
                    Image(nsImage: icon)
                } else {
                    Image(systemName: model.display.symbolName)
                }
                Text(model.display.text)
            }
        }
    }
}
