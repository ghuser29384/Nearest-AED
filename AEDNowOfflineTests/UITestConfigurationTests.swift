import XCTest
@testable import AEDNowOffline

final class UITestConfigurationTests: XCTestCase {
    func testParsesUITestLaunchEnvironment() {
        let configuration = UITestConfiguration(
            arguments: ["AEDNowOffline", "-AEDUITestMode"],
            environment: [
                "AED_UI_TEST_INITIAL_MODE": "runner",
                "AED_UI_TEST_LOCATION_LAT": "51.53192",
                "AED_UI_TEST_LOCATION_LON": "-0.12632",
                "AED_UI_TEST_STALE_LOCATION": "1",
                "AED_UI_TEST_FORCE_SPEECH_UNAVAILABLE": "1",
                "AED_UI_TEST_SIMULATED_VOICE_COMMAND": "nearestAED",
                "AED_UI_TEST_MUTE_SPEECH": "1"
            ]
        )

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(configuration.initialMode, .runner)
        XCTAssertEqual(configuration.location?.coordinate, Coordinate(latitude: 51.53192, longitude: -0.12632))
        XCTAssertEqual(configuration.location?.isMarkedStale, true)
        XCTAssertTrue(configuration.isSpeechUnavailableForced)
        XCTAssertEqual(configuration.simulatedVoiceCommand, .nearestAED)
        XCTAssertTrue(configuration.muteSpeech)
    }
}
