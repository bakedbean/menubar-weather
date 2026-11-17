import XCTest
@testable import MenubarWeather

final class MenuBarIconTests: XCTestCase {
    func testColoredWeatherSymbolsUseMulticolor() {
        for name in ["sun.max.fill", "moon.stars.fill", "cloud.sun.fill", "cloud.rain.fill", "cloud.bolt.rain.fill"] {
            XCTAssertEqual(MenuBarIcon.style(for: name), .multicolor, name)
        }
    }

    func testPlainCloudsAreTinted() {
        for name in ["cloud.fill", "cloud.fog.fill", "cloud", "cloud.snow.fill"] {
            XCTAssertEqual(MenuBarIcon.style(for: name), .tinted, name)
        }
    }

    func testStatusSymbolsStayTemplate() {
        XCTAssertEqual(MenuBarIcon.style(for: "thermometer"), .template)
        XCTAssertEqual(MenuBarIcon.style(for: "location.slash"), .template)
    }

    func testRenderedImageTemplateFlagFollowsStyle() throws {
        XCTAssertFalse(try XCTUnwrap(MenuBarIcon.image(for: "sun.max.fill")).isTemplate)
        XCTAssertFalse(try XCTUnwrap(MenuBarIcon.image(for: "cloud.fill")).isTemplate)
        XCTAssertTrue(try XCTUnwrap(MenuBarIcon.image(for: "thermometer")).isTemplate)
    }
}
