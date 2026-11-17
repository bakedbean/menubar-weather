import CoreLocation
import XCTest
@testable import MenubarWeather

final class LocationProviderTests: XCTestCase {
    // Kilometer accuracy is deferred by macOS's location power saver and may never deliver.
    func testRequestsAtLeastHundredMeterAccuracy() {
        XCTAssertLessThanOrEqual(LocationProvider.desiredAccuracy, kCLLocationAccuracyHundredMeters)
    }
}
