import XCTest
@testable import MenubarWeather

final class WeatherTextTests: XCTestCase {
    func testConditionDescriptions() {
        let cases: [(Int, String)] = [
            (0, "Clear sky"), (1, "Mainly clear"), (2, "Partly cloudy"), (3, "Overcast"),
            (45, "Fog"), (51, "Light drizzle"), (55, "Heavy drizzle"), (57, "Freezing drizzle"),
            (61, "Light rain"), (63, "Rain"), (65, "Heavy rain"), (66, "Freezing rain"),
            (71, "Light snow"), (75, "Heavy snow"), (77, "Snow grains"),
            (80, "Light showers"), (82, "Heavy showers"), (85, "Light snow showers"), (86, "Snow showers"),
            (95, "Thunderstorm"), (99, "Thunderstorm with hail"), (42, "Unknown conditions"),
        ]
        for (code, text) in cases { XCTAssertEqual(WeatherText.conditions(code: code), text, "code \(code)") }
    }

    func testWind() {
        XCTAssertEqual(WeatherText.wind(speed: 8.2, directionDegrees: 315, unit: .fahrenheit), "Wind 8 mph NW")
        XCTAssertEqual(WeatherText.wind(speed: 12.6, directionDegrees: 0, unit: .celsius), "Wind 13 km/h N")
        XCTAssertEqual(WeatherText.wind(speed: 5, directionDegrees: 350, unit: .fahrenheit), "Wind 5 mph N")
        XCTAssertEqual(WeatherText.wind(speed: 5, directionDegrees: 120, unit: .fahrenheit), "Wind 5 mph SE")
        XCTAssertEqual(WeatherText.wind(speed: 0.3, directionDegrees: 90, unit: .fahrenheit), "Wind calm")
    }

    func testHumidity() {
        XCTAssertEqual(WeatherText.humidity(62), "Humidity 62%")
    }

    func testTomorrow() {
        XCTAssertEqual(WeatherText.tomorrow(DailyForecast(weatherCode: 61, high: 55.4, low: 40.6)),
                       "Tomorrow: Light rain 55°/41°")
    }

    func testLocationLabelSuffixBySource() {
        XCTAssertEqual(WeatherText.location(name: "Brooklyn, NY", source: .precise), "Brooklyn, NY")
        XCTAssertEqual(WeatherText.location(name: "Brooklyn, NY", source: .approximate), "Brooklyn, NY (approximate)")
        XCTAssertEqual(WeatherText.location(name: "Brooklyn, NY", source: .lastKnown), "Brooklyn, NY (last known)")
    }
}
