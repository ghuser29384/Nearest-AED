import XCTest
@testable import AEDNowOffline

final class AEDMetadataTests: XCTestCase {
    func testSyntheticSourceShowsDevelopmentWarning() {
        let metadata = AEDSourceMetadata(
            sourceName: "Synthetic permitted development seed",
            attributionText: nil,
            importedAt: Date(),
            newestSourceUpdatedAt: Date(),
            recordCount: 100_006,
            reliability: "unknown"
        )

        XCTAssertEqual(
            metadata.warning(),
            "Bundled AED data is synthetic development seed data. Import a permitted real AED dataset before field use."
        )
    }

    func testOldSourceShowsStaleWarning() {
        let now = Date()
        let metadata = AEDSourceMetadata(
            sourceName: "Permitted AED source",
            attributionText: nil,
            importedAt: now,
            newestSourceUpdatedAt: now.addingTimeInterval(-400 * 24 * 60 * 60),
            recordCount: 10,
            reliability: "high"
        )

        XCTAssertEqual(
            metadata.warning(now: now, staleAfterDays: 365),
            "AED data is older than 365 days and may be outdated."
        )
    }

    func testUnknownLicenceShowsWarning() {
        let metadata = AEDSourceMetadata(
            sourceName: "Permitted AED source",
            attributionText: "Required attribution",
            importedAt: Date(),
            newestSourceUpdatedAt: Date(),
            recordCount: 10,
            reliability: "high"
        )

        XCTAssertTrue(metadata.warnings().contains(
            "AED source licence is unknown. Do not redistribute this data until the licence permits app/database use."
        ))
    }

    func testSourceMetadataCarriesSourceLicenceAndLastUpdated() {
        let importedAt = Date(timeIntervalSince1970: 1_704_067_200)
        let metadata = AEDSourceMetadata(
            datasetID: "osm-aed",
            regionID: "london",
            version: "2026.07.07",
            sourceName: "OpenStreetMap emergency=defibrillator",
            sourceUpdatedAt: importedAt,
            attributionText: "OpenStreetMap contributors",
            licence: "ODbL-1.0",
            importedAt: importedAt,
            newestSourceUpdatedAt: importedAt,
            recordCount: 1,
            reliability: "medium"
        )

        XCTAssertEqual(metadata.sourceName, "OpenStreetMap emergency=defibrillator")
        XCTAssertEqual(metadata.licence, "ODbL-1.0")
        XCTAssertEqual(metadata.newestSourceUpdatedAt, importedAt)
        XCTAssertFalse(metadata.warnings(now: importedAt).contains(
            "AED source licence is unknown. Do not redistribute this data until the licence permits app/database use."
        ))
    }

    func testNoOfflineDataCopyNamesEmergencyServices() {
        XCTAssertEqual(
            EmergencyCopy.noOfflineDataForArea(settings: .unitedKingdom),
            "No offline data for this area. Call 999 or 112 now; dispatchers may have more current AED information."
        )
    }
}
