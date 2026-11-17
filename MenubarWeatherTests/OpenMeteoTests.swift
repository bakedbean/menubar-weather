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
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,is_day"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
        ]))
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
