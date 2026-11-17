import XCTest
@testable import MenubarWeather

final class WeatherIconTests: XCTestCase {
    func testClearDayAndNight() {
        XCTAssertEqual(WeatherIcon.symbolName(code: 0, isDay: true), "sun.max.fill")
        XCTAssertEqual(WeatherIcon.symbolName(code: 0, isDay: false), "moon.stars.fill")
    }

    func testMappingTable() {
        let cases: [(Int, Bool, String)] = [
            (1, true, "cloud.sun.fill"), (2, false, "cloud.moon.fill"), (3, true, "cloud.fill"),
            (45, true, "cloud.fog.fill"), (48, true, "cloud.fog.fill"),
            (51, true, "cloud.drizzle.fill"), (57, true, "cloud.drizzle.fill"),
            (61, true, "cloud.rain.fill"), (67, true, "cloud.rain.fill"),
            (80, true, "cloud.heavyrain.fill"), (82, true, "cloud.heavyrain.fill"),
            (71, true, "cloud.snow.fill"), (77, true, "cloud.snow.fill"),
            (85, true, "cloud.snow.fill"), (86, true, "cloud.snow.fill"),
            (95, true, "cloud.bolt.rain.fill"), (99, true, "cloud.bolt.rain.fill"),
        ]
        for (code, day, expected) in cases {
            XCTAssertEqual(WeatherIcon.symbolName(code: code, isDay: day), expected, "code \(code)")
        }
    }

    func testUnknownCodeFallsBackToCloud() {
        XCTAssertEqual(WeatherIcon.symbolName(code: 42, isDay: true), "cloud")
    }
}
