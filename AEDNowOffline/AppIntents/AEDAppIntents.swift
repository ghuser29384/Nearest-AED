import AppIntents
import Foundation

struct FindNearestAEDIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Nearest AED"
    static let description = IntentDescription("Open AED Now Offline in runner mode and show the nearest AED.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AppIntentRouter.shared.request(.runner)
        }
        return .result(dialog: "Opening nearest AED.")
    }
}

struct OpenRunnerModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Runner Mode"
    static let description = IntentDescription("Open AED Now Offline for the person going to get the AED.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AppIntentRouter.shared.request(.runner)
        }
        return .result(dialog: "Opening runner mode.")
    }
}

struct OpenWithPatientModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Open With Patient Mode"
    static let description = IntentDescription("Open AED Now Offline for someone staying with the person.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            AppIntentRouter.shared.request(.withPatient)
        }
        return .result(dialog: "Opening with patient mode.")
    }
}

struct AEDAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [
            AppShortcut(
                intent: FindNearestAEDIntent(),
                phrases: [
                    "Find nearest AED in \(.applicationName)",
                    "Find defibrillator with \(.applicationName)",
                    "Nearest AED with \(.applicationName)"
                ],
                shortTitle: "Find nearest AED",
                systemImageName: "bolt.heart.fill"
            ),
            AppShortcut(
                intent: OpenRunnerModeIntent(),
                phrases: [
                    "Runner mode in \(.applicationName)",
                    "I am the AED runner in \(.applicationName)"
                ],
                shortTitle: "Runner Mode",
                systemImageName: "figure.run"
            ),
            AppShortcut(
                intent: OpenWithPatientModeIntent(),
                phrases: [
                    "I am with the person in \(.applicationName)",
                    "With patient mode in \(.applicationName)"
                ],
                shortTitle: "With Patient",
                systemImageName: "person.fill"
            )
        ]
    }
}
