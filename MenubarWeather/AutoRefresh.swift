import AppKit

extension WeatherModel {
    /// Refreshes now, every `interval` seconds, and on wake from sleep.
    func startAutoRefresh(interval: TimeInterval = 900) {
        Task { await refresh() }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }
}
