import SwiftUI

@main
struct MenubarWeatherApp: App {
    @StateObject private var model: WeatherModel

    init() {
        let model = WeatherModel(
            location: LocationProvider(),
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
                Image(systemName: model.display.symbolName)
                Text(model.display.text)
            }
        }
    }
}
