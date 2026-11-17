import XCTest
@testable import MenubarWeather

final class TemperatureFormatTests: XCTestCase {
    func testRounds() {
        XCTAssertEqual(formatTemperature(72.4), "72°")
        XCTAssertEqual(formatTemperature(72.5), "73°")
    }

    func testNegative() {
        XCTAssertEqual(formatTemperature(-3.6), "-4°")
    }

    func testNegativeZeroFormatsAsZero() {
        XCTAssertEqual(formatTemperature(-0.4), "0°")
    }
}
