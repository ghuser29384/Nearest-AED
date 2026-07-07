import XCTest
@testable import AEDNowOffline

final class AEDSearchServiceTests: XCTestCase {
    func testLikelyAccessibleAEDSortsBeforeCloserRestrictedAED() throws {
        let origin = Coordinate(latitude: 51.5000, longitude: -0.1200)
        let restrictedClose = makeRecord(
            id: "restricted-close",
            latitude: 51.5001,
            longitude: -0.1200,
            accessType: .restricted,
            likelyAccessible: false,
            confidence: .high
        )
        let publicFarther = makeRecord(
            id: "public-farther",
            latitude: 51.5010,
            longitude: -0.1200,
            accessType: .public24h,
            likelyAccessible: true,
            confidence: .medium
        )

        let service = AEDSearchService(repository: repository([restrictedClose, publicFarther]))

        let defaultResults = try service.nearestAEDs(from: origin, showAll: false)
        XCTAssertEqual(defaultResults.map(\.record.id), ["public-farther"])

        let allResults = try service.nearestAEDs(from: origin, showAll: true)
        XCTAssertEqual(allResults.first?.record.id, "public-farther")
    }

    func testDistanceSortsWithinSameAccessibilityRank() throws {
        let origin = Coordinate(latitude: 51.5000, longitude: -0.1200)
        let farther = makeRecord(id: "farther", latitude: 51.5030, longitude: -0.1200, accessType: .public24h, likelyAccessible: true)
        let closer = makeRecord(id: "closer", latitude: 51.5010, longitude: -0.1200, accessType: .public24h, likelyAccessible: true)

        let service = AEDSearchService(repository: repository([farther, closer]))
        let results = try service.nearestAEDs(from: origin)

        XCTAssertEqual(results.map(\.record.id), ["closer", "farther"])
    }

    func testOpeningHoursCanPromoteLimitedHoursAED() throws {
        let origin = Coordinate(latitude: 51.5000, longitude: -0.1200)
        let unknownClose = makeRecord(id: "unknown-close", latitude: 51.5001, longitude: -0.1200, accessType: .unknown)
        let alwaysOpenFarther = makeRecord(
            id: "limited-24h",
            latitude: 51.5010,
            longitude: -0.1200,
            accessType: .publicLimitedHours,
            openingHoursRaw: "Mo-Su 00:00-24:00"
        )

        let service = AEDSearchService(repository: repository([unknownClose, alwaysOpenFarther]))
        let results = try service.nearestAEDs(from: origin)

        XCTAssertEqual(results.first?.record.id, "limited-24h")
    }

    func testExactRadiusFilterRemovesBoundingBoxCornerCandidates() throws {
        let origin = Coordinate(latitude: 0, longitude: 0)
        let inside = makeRecord(id: "inside", latitude: 0.1, longitude: 0, accessType: .public24h, likelyAccessible: true)
        let outside = makeRecord(id: "outside", latitude: 0.1, longitude: 0.1, accessType: .public24h, likelyAccessible: true)

        let service = AEDSearchService(repository: repository([inside, outside]), defaultRadiusMeters: 12_000)
        let results = try service.nearestAEDs(from: origin, showAll: true)

        XCTAssertEqual(results.map(\.record.id), ["inside"])
    }

    private func repository(_ records: [AEDRecord]) -> StaticAEDRepository {
        StaticAEDRepository(
            records: records,
            sourceMetadata: AEDSourceMetadata(
                sourceName: "Unit test",
                attributionText: nil,
                importedAt: Date(),
                newestSourceUpdatedAt: Date(),
                recordCount: records.count,
                reliability: "high"
            )
        )
    }

    private func makeRecord(
        id: String,
        latitude: Double,
        longitude: Double,
        accessType: AccessType,
        likelyAccessible: Bool? = nil,
        openingHoursRaw: String? = nil,
        confidence: AEDConfidence = .medium
    ) -> AEDRecord {
        AEDRecord(
            id: id,
            source: "Unit test",
            sourceRecordID: id,
            sourceUpdatedAt: Date(),
            importedAt: Date(),
            latitude: latitude,
            longitude: longitude,
            name: id,
            address: nil,
            locationDescription: nil,
            indoorLocation: nil,
            accessType: accessType,
            openingHoursRaw: openingHoursRaw,
            isCurrentlyLikelyAccessible: likelyAccessible,
            accessInstructions: nil,
            cabinetCodeInstruction: nil,
            phone: nil,
            lastVerifiedAt: Date(),
            confidence: confidence,
            notes: nil,
            attributionText: nil
        )
    }
}
