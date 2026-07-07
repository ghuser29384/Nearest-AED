import XCTest
@testable import AEDNowOffline

final class DistanceBearingTests: XCTestCase {
    func testDistanceBetweenNearbyLondonCoordinates() {
        let start = Coordinate(latitude: 51.5007, longitude: -0.1246)
        let end = Coordinate(latitude: 51.5014, longitude: -0.1419)

        let distance = DistanceBearing.distanceMeters(from: start, to: end)

        XCTAssertEqual(distance, 1_200, accuracy: 150)
    }

    func testBearingEast() {
        let start = Coordinate(latitude: 0, longitude: 0)
        let end = Coordinate(latitude: 0, longitude: 1)

        let bearing = DistanceBearing.bearingDegrees(from: start, to: end)

        XCTAssertEqual(bearing, 90, accuracy: 0.1)
        XCTAssertEqual(DistanceBearing.compassDirection(for: bearing), "east")
    }

    func testRelativeBearingUsesHeading() {
        let relative = DistanceBearing.relativeBearingDegrees(bearing: 10, heading: 350)

        XCTAssertEqual(relative, 20, accuracy: 0.1)
    }
}

