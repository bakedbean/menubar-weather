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
            unit: .preferred(for: .current)
        )
        _model = StateObject(wrappedValue: model)
        model.startAutoRefresh()
    }

    var body: some Scene {
        MenuBarExtra {
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
