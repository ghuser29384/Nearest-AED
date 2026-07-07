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

        XCTAssertTrue(staticText(matching: "Call 999 or 112 now. If someone is unresponsive and not breathing normally, start CPR. If you are alone with the person, do not leave them unless instructed by emergency services. Send someone else for the AED if possible.").waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Call 999 / 112"].exists)
        XCTAssertTrue(app.buttons["Find nearest AED"].exists)
        XCTAssertTrue(app.buttons["I am with the person"].exists)
        XCTAssertTrue(app.buttons["I am the AED runner"].exists)
        saveEvidence("01-emergency-home")
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
        saveEvidence("03-aed-runner-mode")

        app.buttons["Next AED"].tap()
        XCTAssertTrue(app.staticTexts["UI Test Second AED"].waitForExistence(timeout: 2))
    }

    func testWithPatientModeShowsSafetyControls() {
        app.launchEnvironment["AED_UI_TEST_INITIAL_MODE"] = "withPatient"
        launch()

        XCTAssertTrue(staticText(matching: "Call 999 / 112. Start CPR if unresponsive and not breathing normally. Shout for help. Send someone else for the AED.").waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["Call 999 / 112"].exists)
        XCTAssertTrue(app.buttons["Read CPR/AED steps"].exists)
        XCTAssertTrue(app.buttons["Show nearest AED for helper"].exists)
        saveEvidence("02-with-patient-mode")
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

    func testStaleAEDDataWarningIsVisible() {
        launch()

        XCTAssertTrue(app.staticTexts["AED data is older than 365 days and may be outdated."].waitForExistence(timeout: 2))
        app.swipeUp()
        saveEvidence("04-stale-data-warning")
    }

    func testNoLocationFallbackShowsBundledList() {
        app.launchEnvironment["AED_UI_TEST_INITIAL_MODE"] = "runner"
        app.launchEnvironment["AED_UI_TEST_LOCATION_LAT"] = nil
        app.launchEnvironment["AED_UI_TEST_LOCATION_LON"] = nil
        launch()

        XCTAssertTrue(app.staticTexts["Location unavailable"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Showing bundled AED list fallback."].exists)
        XCTAssertTrue(app.textFields["Search AED list"].exists)
        XCTAssertTrue(app.staticTexts["UI Test Nearest AED"].exists)
        saveEvidence("05-no-location-fallback")
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

    func testVoiceControlLabelsMatchVisiblePrimaryText() {
        launch()

        let primaryButtons = [
            "Call 999 / 112",
            "Find nearest AED",
            "I am with the person",
            "I am the AED runner",
            "Listen",
            "Stop listening"
        ]
        for label in primaryButtons {
            XCTAssertTrue(app.buttons[label].waitForExistence(timeout: 2), "Missing Voice Control-compatible button: \(label)")
        }
        saveEvidence("06-voice-control-labels")
        saveLabelAudit(primaryButtons)
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

    private func staticText(matching label: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func saveEvidence(_ name: String) {
        guard let directory = ProcessInfo.processInfo.environment["QA_EVIDENCE_DIR"],
              !directory.isEmpty
        else {
            return
        }

        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: directoryURL.appendingPathComponent("\(name).png"))
            try app.debugDescription.write(
                to: directoryURL.appendingPathComponent("\(name)-accessibility.txt"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            XCTFail("Unable to save QA evidence \(name): \(error)")
        }
    }

    private func saveLabelAudit(_ labels: [String]) {
        guard let directory = ProcessInfo.processInfo.environment["QA_EVIDENCE_DIR"],
              !directory.isEmpty
        else {
            return
        }

        let directoryURL = URL(fileURLWithPath: directory, isDirectory: true)
        let body = labels.map { label in
            "\(label): \(app.buttons[label].exists ? "button exists with matching accessibility label" : "missing")"
        }.joined(separator: "\n")

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try body.write(
                to: directoryURL.appendingPathComponent("06-voice-control-show-names-label-audit.txt"),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            XCTFail("Unable to save Voice Control label audit: \(error)")
        }
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
