import Foundation

enum UITestFixtures {
    static let origin = Coordinate(latitude: 51.53192, longitude: -0.12632)

    static let records: [AEDRecord] = [
        AEDRecord(
            id: "ui-test-nearest",
            source: "UI test source",
            sourceRecordID: "ui-001",
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_704_067_200),
            importedAt: Date(timeIntervalSince1970: 1_704_067_200),
            latitude: 51.53210,
            longitude: -0.12640,
            name: "UI Test Nearest AED",
            address: "Synthetic iPhone 13 test address",
            locationDescription: "Inside main entrance, left wall",
            indoorLocation: "Ground floor",
            accessType: .public24h,
            openingHoursRaw: "24/7",
            isCurrentlyLikelyAccessible: true,
            accessInstructions: "Use for UI testing only.",
            cabinetCodeInstruction: nil,
            phone: nil,
            lastVerifiedAt: Date(timeIntervalSince1970: 1_704_067_200),
            confidence: .high,
            notes: "Synthetic UI test record.",
            attributionText: "Synthetic UI test data"
        ),
        AEDRecord(
            id: "ui-test-second",
            source: "UI test source",
            sourceRecordID: "ui-002",
            sourceUpdatedAt: Date(timeIntervalSince1970: 1_704_067_200),
            importedAt: Date(timeIntervalSince1970: 1_704_067_200),
            latitude: 51.53300,
            longitude: -0.12680,
            name: "UI Test Second AED",
            address: "Second synthetic iPhone 13 test address",
            locationDescription: "Outside front entrance",
            indoorLocation: nil,
            accessType: .public24h,
            openingHoursRaw: "24/7",
            isCurrentlyLikelyAccessible: true,
            accessInstructions: "Use for UI testing only.",
            cabinetCodeInstruction: nil,
            phone: nil,
            lastVerifiedAt: Date(timeIntervalSince1970: 1_704_067_200),
            confidence: .high,
            notes: "Synthetic UI test record.",
            attributionText: "Synthetic UI test data"
        )
    ]

    static let repository = StaticAEDRepository(
        records: records,
        sourceMetadata: AEDSourceMetadata(
            sourceName: "UI test source",
            attributionText: "Synthetic UI test data",
            importedAt: Date(timeIntervalSince1970: 1_704_067_200),
            newestSourceUpdatedAt: Date(timeIntervalSince1970: 1_704_067_200),
            recordCount: records.count,
            reliability: "high"
        )
    )
}

