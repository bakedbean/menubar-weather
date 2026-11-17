import XCTest
@testable import MenubarWeather

final class OpenMeteoTests: XCTestCase {
    func testURL() {
        let url = OpenMeteo.url(for: Coordinate(latitude: 40.71, longitude: -74.01), unit: .fahrenheit)
        let items = Set(URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!)
        XCTAssertEqual(url.host, "api.open-meteo.com")
        XCTAssertEqual(url.path, "/v1/forecast")
        XCTAssertTrue(items.isSuperset(of: [
            URLQueryItem(name: "latitude", value: "40.71"),
            URLQueryItem(name: "longitude", value: "-74.01"),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day,relative_humidity_2m,wind_speed_10m,wind_direction_10m"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "forecast_days", value: "2"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "wind_speed_unit", value: "mph"),
        ]))
    }

    func testCelsiusUsesKilometersPerHour() {
        let url = OpenMeteo.url(for: Coordinate(latitude: 1, longitude: 2), unit: .celsius)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertTrue(items.contains(URLQueryItem(name: "wind_speed_unit", value: "kmh")))
    }

    func testDecodeFullResponse() throws {
        let json = #"""
        {"current":{"temperature_2m":48.3,"weather_code":61,"is_day":1,"relative_humidity_2m":62,"wind_speed_10m":8.2,"wind_direction_10m":315},
         "daily":{"time":["2026-11-17","2026-11-18"],"weather_code":[61,3],"temperature_2m_max":[50.1,55.4],"temperature_2m_min":[39.0,40.6]}}
        """#
        XCTAssertEqual(try OpenMeteo.decode(Data(json.utf8)), CurrentWeather(
            temperature: 48.3, weatherCode: 61, isDay: true,
            humidity: 62, windSpeed: 8.2, windDirection: 315,
            tomorrow: DailyForecast(weatherCode: 3, high: 55.4, low: 40.6)))
    }

    func testDecodeWithoutTomorrowLeavesItNil() throws {
        let json = #"{"current":{"temperature_2m":48.3,"weather_code":61,"is_day":1},"daily":{"weather_code":[61],"temperature_2m_max":[50.1],"temperature_2m_min":[39.0]}}"#
        XCTAssertNil(try OpenMeteo.decode(Data(json.utf8)).tomorrow)
    }

    func testDecode() throws {
        let json = #"{"latitude":40.7,"current":{"time":"2026-11-17T12:00","interval":900,"temperature_2m":48.3,"weather_code":61,"is_day":1}}"#
        XCTAssertEqual(try OpenMeteo.decode(Data(json.utf8)),
                       CurrentWeather(temperature: 48.3, weatherCode: 61, isDay: true))
    }

    func testDecodeMalformedThrows() {
        XCTAssertThrowsError(try OpenMeteo.decode(Data("{}".utf8)))
    }

    func testPreferredUnit() {
        XCTAssertEqual(TemperatureUnit.preferred(for: Locale(identifier: "en_US")), .fahrenheit)
        XCTAssertEqual(TemperatureUnit.preferred(for: Locale(identifier: "en_GB")), .celsius)
        XCTAssertEqual(TemperatureUnit.preferred(for: Locale(identifier: "de_DE")), .celsius)
    }
}
