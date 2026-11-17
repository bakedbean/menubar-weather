import SwiftUI

@main
struct MenubarWeatherApp: App {
    var body: some Scene {
        MenuBarExtra("--°", systemImage: "thermometer") {
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
