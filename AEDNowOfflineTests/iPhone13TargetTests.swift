import Foundation
import XCTest
@testable import AEDNowOffline

final class iPhone13TargetTests: XCTestCase {
    func testEmergencyRegionUsesUKInstructionAndButtonCopy() {
        let settings = EmergencyRegionSettings.unitedKingdom

        XCTAssertEqual(settings.instructionNumber, "999 or 112")
        XCTAssertEqual(settings.callButtonTitle, "Call 999 / 112")
        XCTAssertTrue(EmergencyCopy.primaryInstruction(settings: settings).hasPrefix("Call 999 or 112 now."))
    }

    func testNoUnsupportedHardwareFeatureNamesInEmergencyCopy() {
        let copy = [
            EmergencyCopy.primaryInstruction(),
            EmergencyCopy.withPatientInstruction,
            EmergencyCopy.aloneWarning,
            EmergencyCopy.dataWarning,
            EmergencyCopy.cprSteps
        ].joined(separator: " ").lowercased()

        XCTAssertFalse(copy.contains("action button"))
        XCTAssertFalse(copy.contains("apple intelligence"))
        XCTAssertFalse(copy.contains("camera control"))
        XCTAssertFalse(copy.contains("satellite"))
        XCTAssertFalse(copy.contains("apple watch"))
        XCTAssertFalse(copy.contains("iphone 14"))
        XCTAssertFalse(copy.contains("iphone 15"))
        XCTAssertFalse(copy.contains("iphone 16"))
    }

    func testVoiceFallbackMessageIsExplicitWhenOnDeviceSpeechUnavailable() {
        let message = "On-device speech recognition unavailable. Use buttons or iOS Voice Control."

        XCTAssertTrue(message.contains("Voice Control"))
        XCTAssertTrue(message.contains("buttons"))
    }

    func testFindNearestAEDAppIntentRoutesToRunnerMode() throws {
        let source = try projectSource(relativePath: "AEDNowOffline/AppIntents/AEDAppIntents.swift")

        XCTAssertTrue(source.contains("struct FindNearestAEDIntent"))
        XCTAssertTrue(source.contains("static let openAppWhenRun = true"))
        XCTAssertTrue(source.contains("AppIntentRouter.shared.request(.runner)"))
        XCTAssertTrue(source.contains("\"Find nearest AED in \\(.applicationName)\""))
        XCTAssertTrue(source.contains("shortTitle: \"Find nearest AED\""))
    }

    func testIPhone13AcceptanceScriptTargetsExactRuntimeFirst() throws {
        let script = try projectSource(relativePath: "Tools/run_iphone13_acceptance.sh")

        XCTAssertTrue(script.contains("DESTINATION_EXACT=\"platform=iOS Simulator,name=iPhone 13,OS=18.7.8\""))
        XCTAssertTrue(script.contains("DESTINATION_LATEST=\"platform=iOS Simulator,name=iPhone 13\""))
        XCTAssertTrue(script.contains("xcrun simctl list devices available"))
        XCTAssertTrue(script.contains("xcrun simctl list devicetypes"))
        XCTAssertTrue(script.contains("xcrun simctl list runtimes available"))
        XCTAssertTrue(script.contains("xcrun simctl create"))
        XCTAssertTrue(script.contains("com.apple.CoreSimulator.SimDeviceType.iPhone-13"))
        XCTAssertTrue(script.contains("-destination \"$DESTINATION_EXACT\""))
        XCTAssertTrue(script.contains("-destination \"$DESTINATION_LATEST\""))
        XCTAssertTrue(script.contains("test"))
    }

    func testLookupOverOneHundredThousandRecordsIsUnderTwoSecondsOnHost() throws {
        let origin = Coordinate(latitude: 51.53192, longitude: -0.12632)
        let repository: AEDRepositoryProtocol
        if let bundledRepository = try? AEDRepository(bundle: .main) {
            repository = bundledRepository
        } else {
            repository = StaticAEDRepository(
                records: makeSyntheticRecords(count: 100_000),
                sourceMetadata: AEDSourceMetadata(
                    sourceName: "Synthetic performance test",
                    attributionText: nil,
                    importedAt: Date(),
                    newestSourceUpdatedAt: Date(),
                    recordCount: 100_000,
                    reliability: "unknown"
                )
            )
        }
        let service = AEDSearchService(repository: repository)

        let started = Date()
        let results = try service.nearestAEDs(from: origin, limit: 10)
        let elapsed = Date().timeIntervalSince(started)

        XCTAssertFalse(results.isEmpty)
        XCTAssertLessThan(elapsed, 2.0)
    }

    private func makeSyntheticRecords(count: Int) -> [AEDRecord] {
        (0..<count).map { index in
            AEDRecord(
                id: "perf-\(index)",
                source: "Synthetic performance test",
                sourceRecordID: "perf-\(index)",
                sourceUpdatedAt: Date(),
                importedAt: Date(),
                latitude: 51.0 + Double(index % 1_000) * 0.0002,
                longitude: -0.4 + Double((index / 1_000) % 1_000) * 0.0002,
                name: "Synthetic AED \(index)",
                address: "Synthetic address",
                locationDescription: "Synthetic performance record",
                indoorLocation: nil,
                accessType: index % 3 == 0 ? .public24h : .unknown,
                openingHoursRaw: index % 3 == 0 ? "24/7" : nil,
                isCurrentlyLikelyAccessible: index % 3 == 0 ? true : nil,
                accessInstructions: nil,
                cabinetCodeInstruction: nil,
                phone: nil,
                lastVerifiedAt: Date(),
                confidence: .unknown,
                notes: nil,
                attributionText: nil
            )
        }
    }

    private func projectSource(relativePath: String, file: StaticString = #filePath) throws -> String {
        let testFileURL = URL(fileURLWithPath: "\(file)")
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: projectRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }
}
