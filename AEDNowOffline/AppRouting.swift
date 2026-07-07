import Combine
import Foundation

enum AppMode: String, Identifiable {
    case home
    case withPatient
    case runner

    var id: String { rawValue }
}

struct EmergencyRegionSettings: Equatable {
    var regionName: String
    var instructionNumber: String
    var callButtonTitle: String
    var dialNumber: String

    static let unitedKingdom = EmergencyRegionSettings(
        regionName: "United Kingdom",
        instructionNumber: "999 or 112",
        callButtonTitle: "Call 999 / 112",
        dialNumber: "999"
    )
}

enum EmergencyCopy {
    static func primaryInstruction(settings: EmergencyRegionSettings = .unitedKingdom) -> String {
        "Call \(settings.instructionNumber) now. If someone is unresponsive and not breathing normally, start CPR. If you are alone with the person, do not leave them unless instructed by emergency services. Send someone else for the AED if possible."
    }

    static let withPatientInstruction = "Call 999 / 112. Start CPR if unresponsive and not breathing normally. Shout for help. Send someone else for the AED."

    static let aloneWarning = "Do not leave the person if you are the only rescuer unless emergency services instruct you."

    static let dataWarning = "AED data may be incomplete, outdated, inaccessible, or wrong. In an emergency, call 999/112. Dispatchers may have more current AED information."

    static let cprSteps = "If unresponsive and not breathing normally: call emergency services, start CPR, use an AED as soon as available, and follow AED prompts. Do not touch the person during rhythm analysis or shock. Resume CPR when the AED instructs."

    static func noOfflineDataForArea(settings: EmergencyRegionSettings = .unitedKingdom) -> String {
        "No offline data for this area. Call \(settings.instructionNumber) now; dispatchers may have more current AED information."
    }
}

@MainActor
final class AppIntentRouter: ObservableObject {
    static let shared = AppIntentRouter()

    @Published var requestedMode: AppMode?

    private init() {}

    func request(_ mode: AppMode) {
        requestedMode = mode
    }
}
