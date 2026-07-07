import Foundation

struct UITestConfiguration {
    var isEnabled: Bool
    var initialMode: AppMode?
    var location: LocationSnapshot?
    var isSpeechUnavailableForced: Bool
    var simulatedVoiceCommand: VoiceCommand?
    var muteSpeech: Bool

    static let current = UITestConfiguration(processInfo: .processInfo)

    init(processInfo: ProcessInfo) {
        self.init(arguments: processInfo.arguments, environment: processInfo.environment)
    }

    init(arguments: [String], environment: [String: String]) {
        isEnabled = environment["AED_UI_TEST_MODE"] == "1" || arguments.contains("-AEDUITestMode")
        initialMode = environment["AED_UI_TEST_INITIAL_MODE"].flatMap(AppMode.init(rawValue:))
        isSpeechUnavailableForced = environment["AED_UI_TEST_FORCE_SPEECH_UNAVAILABLE"] == "1"
        simulatedVoiceCommand = environment["AED_UI_TEST_SIMULATED_VOICE_COMMAND"].flatMap(VoiceCommand.init(rawValue:))
        muteSpeech = environment["AED_UI_TEST_MUTE_SPEECH"] != "0"

        if let latitudeText = environment["AED_UI_TEST_LOCATION_LAT"],
           let longitudeText = environment["AED_UI_TEST_LOCATION_LON"],
           let latitude = Double(latitudeText),
           let longitude = Double(longitudeText) {
            let stale = environment["AED_UI_TEST_STALE_LOCATION"] == "1"
            let timestamp = stale ? Date().addingTimeInterval(-600) : Date()
            location = LocationSnapshot(
                coordinate: Coordinate(latitude: latitude, longitude: longitude),
                timestamp: timestamp,
                horizontalAccuracy: 12,
                isMarkedStale: stale
            )
        } else {
            location = nil
        }
    }
}
