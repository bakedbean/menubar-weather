import AppKit

/// Builds the menubar icon. Weather symbols render in color (non-template) so macOS doesn't flatten them;
/// symbols with no colored layers get a gray-blue palette tint.
enum MenuBarIcon {
    enum Style: Equatable { case multicolor, tinted, template }

    static let cloudColor = NSColor(srgbRed: 0.55, green: 0.65, blue: 0.78, alpha: 1)
    static let snowColor = NSColor(srgbRed: 0.75, green: 0.88, blue: 1.0, alpha: 1)

    private static let tinted: Set<String> = ["cloud", "cloud.fill", "cloud.fog.fill", "cloud.snow.fill"]
    private static let template: Set<String> = ["thermometer", "location.slash"]

    static func style(for symbolName: String) -> Style {
        if template.contains(symbolName) { return .template }
        if tinted.contains(symbolName) { return .tinted }
        return .multicolor
    }

    static func image(for symbolName: String) -> NSImage? {
        let size = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let style = style(for: symbolName)
        let config: NSImage.SymbolConfiguration = switch style {
        case .multicolor: size.applying(.preferringMulticolor())
        case .tinted: size.applying(NSImage.SymbolConfiguration(paletteColors: [cloudColor, snowColor]))
        case .template: size
        }
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        image?.isTemplate = style == .template
        return image
    }
}
