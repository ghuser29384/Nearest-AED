import XCTest
@testable import AEDNowOffline

final class LocationFreshnessTests: XCTestCase {
    func testFreshCurrentLocationIsPreferred() {
        let now = Date()
        let current = LocationSnapshot(
            coordinate: Coordinate(latitude: 51.5, longitude: -0.12),
            timestamp: now,
            horizontalAccuracy: 12
        )
        let lastKnown = LocationSnapshot(
            coordinate: Coordinate(latitude: 53.4, longitude: -2.2),
            timestamp: now.addingTimeInterval(-500),
            horizontalAccuracy: 20
        )

        let result = LocationFreshnessEvaluator.bestAvailable(current: current, lastKnown: lastKnown, now: now)

        XCTAssertEqual(result, .fresh(current))
    }

    func testStaleCurrentLocationIsMarkedStale() {
        let now = Date()
        let current = LocationSnapshot(
            coordinate: Coordinate(latitude: 51.5, longitude: -0.12),
            timestamp: now.addingTimeInterval(-500),
            horizontalAccuracy: 12
        )

        let result = LocationFreshnessEvaluator.bestAvailable(current: current, lastKnown: nil, now: now)

        guard case .stale(let snapshot) = result else {
            return XCTFail("Expected stale location")
        }
        XCTAssertTrue(snapshot.isMarkedStale)
    }

    func testLastKnownLocationIsUsedWhenCurrentLocationUnavailable() {
        let now = Date()
        let lastKnown = LocationSnapshot(
            coordinate: Coordinate(latitude: 51.5, longitude: -0.12),
            timestamp: now.addingTimeInterval(-30),
            horizontalAccuracy: 12
        )

        let result = LocationFreshnessEvaluator.bestAvailable(current: nil, lastKnown: lastKnown, now: now)

        guard case .stale(let snapshot) = result else {
            return XCTFail("Expected stale fallback location")
        }
        XCTAssertEqual(snapshot.coordinate, lastKnown.coordinate)
    }

    func testUnavailableWhenNoLocationExists() {
        let result = LocationFreshnessEvaluator.bestAvailable(current: nil, lastKnown: nil)

        XCTAssertEqual(result, .unavailable)
    }
}

