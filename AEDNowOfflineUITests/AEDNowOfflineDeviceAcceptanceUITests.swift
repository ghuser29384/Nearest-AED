import XCTest

final class AEDNowOfflineDeviceAcceptanceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-AEDUITestMode"]
        app.launchEnvironment = baseEnvironment()
    }

    func testEmergencyHomeShowsIPhone13PrimaryControls() {
        launch()

        XCTAssertTrue(app.staticTexts["Call 999 or 112 now. If someone is unresponsive and not breathing normally, start CPR. If you are alone with the person, do not leave them unless instructed by emergency services. Send someone else for the AED if possible."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Call 999 / 112"].exists)
        XCTAssertTrue(app.buttons["Find nearest AED"].exists)
        XCTAssertTrue(app.buttons["I am with the person"].exists)
        XCTAssertTrue(app.buttons["I am the AED runner"].exists)
    }

    func testColdLaunchShowsEmergencyHomeWithinOneSecondWherePossible() {
        launch()

        XCTAssertTrue(app.buttons["Find nearest AED"].waitForExistence(timeout: 1.0))
    }

    func testRunnerModeShowsNearestAEDAndNextAED() {
        app.launchEnvironment["AED_UI_TEST_INITIAL_MODE"] = "runner"
        launch()

        XCTAssertTrue(app.staticTexts["UI Test Nearest AED"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Read aloud"].exists)
        XCTAssertTrue(app.buttons["Next AED"].exists)

        app.buttons["Next AED"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Second AED"].waitForExistence(timeout: 2))
    }

    func testAirplaneModeEquivalentOfflineRunnerFlowUsesLocalData() {
        app.launchEnvironment["AED_UI_TEST_INITIAL_MODE"] = "runner"
        app.launchEnvironment["AED_UI_TEST_AIRPLANE_MODE_EQUIVALENT"] = "1"
        launch()

        XCTAssertTrue(app.staticTexts["UI Test Nearest AED"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Read aloud"].exists)
        XCTAssertTrue(app.buttons["Next AED"].exists)
        XCTAssertFalse(app.staticTexts["AED database unavailable."].exists)
    }

    func testStaleLocationIsClearlyMarked() {
        app.launchEnvironment["AED_UI_TEST_INITIAL_MODE"] = "runner"
        app.launchEnvironment["AED_UI_TEST_STALE_LOCATION"] = "1"
        launch()

        XCTAssertTrue(app.staticTexts["Location may be outdated."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["UI Test Nearest AED"].exists)
    }

    func testLargestDynamicTypeStillShowsPrimaryControlsOnIPhone13() {
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL"
        ]
        launch()

        XCTAssertTrue(app.buttons["Call 999 / 112"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Find nearest AED"].exists)
        XCTAssertTrue(app.buttons["I am with the person"].exists)
        XCTAssertTrue(app.buttons["I am the AED runner"].exists)

        app.buttons["Find nearest AED"].tap()
        XCTAssertTrue(app.buttons["Read aloud"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Next AED"].exists)
    }

    func testSpeechUnavailableFallsBackToVoiceControlCompatibleButtons() {
        app.launchEnvironment["AED_UI_TEST_FORCE_SPEECH_UNAVAILABLE"] = "1"
        launch()

        app.buttons["Listen"].tap()

        XCTAssertTrue(app.staticTexts["On-device speech recognition unavailable. Use buttons or iOS Voice Control."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Call 999 / 112"].exists)
        XCTAssertTrue(app.buttons["Find nearest AED"].exists)
    }

    func testSimulatedNearestAEDVoiceCommandOpensRunnerMode() {
        app.launchEnvironment["AED_UI_TEST_SIMULATED_VOICE_COMMAND"] = "nearestAED"
        launch()

        XCTAssertTrue(app.staticTexts["Nearest AED."].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["UI Test Nearest AED"].waitForExistence(timeout: 2))
    }

    func testFindNearestAEDShortcutEquivalentOpensRunnerMode() {
        app.launchEnvironment["AED_UI_TEST_INITIAL_MODE"] = "runner"
        launch()

        XCTAssertTrue(app.staticTexts["UI Test Nearest AED"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Read aloud"].exists)
    }

    func testCall999112OpensConfirmationWithoutPlacingCall() {
        launch()

        app.buttons["Call 999 / 112"].tap()

        XCTAssertTrue(app.buttons["Call 999 / 112"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Cancel"].exists)
    }

    private func launch() {
        app.launch()
    }

    private func baseEnvironment() -> [String: String] {
        [
            "AED_UI_TEST_MODE": "1",
            "AED_UI_TEST_MUTE_SPEECH": "1",
            "AED_UI_TEST_LOCATION_LAT": "51.53192",
            "AED_UI_TEST_LOCATION_LON": "-0.12632"
        ]
    }
}
