import Combine
import SwiftUI

@MainActor
final class AEDAppModel: ObservableObject {
    @Published var mode: AppMode = .home
    @Published var results: [AEDSearchResult] = []
    @Published var fallbackRecords: [AEDRecord] = []
    @Published var selectedIndex = 0
    @Published var showAllAEDs = false
    @Published var statusMessage = "Ready offline."
    @Published var dataSourceWarnings: [String] = []
    @Published var voiceConfirmation: String?
    @Published var callConfirmationPresented = false
    @Published var largerText = false
    @Published private(set) var isEmergencyModeActive = false

    let settings: EmergencyRegionSettings
    let locationManager: LocationManager
    let headingManager: HeadingManager
    let voiceCommandManager: VoiceCommandManager
    let speechOutputService: SpeechOutputService
    let emergencyCallService: EmergencyCallService

    private var searchService: AEDSearchService
    private let isUITestMode: Bool
    private var cancellables: Set<AnyCancellable> = []
    private var hasSpokenStartupInstruction = false

    var selectedResult: AEDSearchResult? {
        guard results.indices.contains(selectedIndex) else { return nil }
        return results[selectedIndex]
    }

    init(
        repository: AEDRepositoryProtocol? = nil,
        settings: EmergencyRegionSettings = .unitedKingdom,
        uiTestConfiguration: UITestConfiguration = .current
    ) {
        self.settings = settings
        isUITestMode = uiTestConfiguration.isEnabled
        locationManager = LocationManager()
        headingManager = HeadingManager()
        voiceCommandManager = VoiceCommandManager()
        speechOutputService = SpeechOutputService()
        emergencyCallService = EmergencyCallService(settings: settings)
        speechOutputService.isMuted = uiTestConfiguration.isEnabled && uiTestConfiguration.muteSpeech
        voiceCommandManager.forceOnDeviceRecognitionUnavailable = uiTestConfiguration.isSpeechUnavailableForced

        let activeRepository: AEDRepositoryProtocol
        if let repository {
            activeRepository = repository
        } else if uiTestConfiguration.isEnabled {
            activeRepository = UITestFixtures.repository
        } else if let bundled = try? AEDRepository() {
            activeRepository = bundled
        } else {
            activeRepository = StaticAEDRepository(
                records: [],
                sourceMetadata: AEDSourceMetadata(
                    sourceName: "Missing bundled source",
                    attributionText: nil,
                    importedAt: nil,
                    newestSourceUpdatedAt: nil,
                    recordCount: 0,
                    reliability: "unknown"
                )
            )
        }

        searchService = AEDSearchService(repository: activeRepository)
        refreshDataWarnings()
        if let location = uiTestConfiguration.location {
            locationManager.applyTestingLocation(location)
        }
        if let initialMode = uiTestConfiguration.initialMode {
            mode = initialMode
        }
        bindDeviceUpdates()

        if let simulatedVoiceCommand = uiTestConfiguration.simulatedVoiceCommand {
            Task { @MainActor in
                self.handleVoiceCommand(simulatedVoiceCommand)
            }
        }
    }

    func startEmergencyMode() {
        isEmergencyModeActive = true
        refreshDataWarnings()
        if !hasSpokenStartupInstruction {
            hasSpokenStartupInstruction = true
            speechOutputService.speak(EmergencyCopy.primaryInstruction(settings: settings))
        }
        if !isUITestMode {
            locationManager.requestWhenInUsePermission()
            locationManager.requestOneShotLocation()
        }
        headingManager.start()
        refreshNearest()
    }

    func open(_ mode: AppMode) {
        self.mode = mode
        startEmergencyMode()
        if mode == .runner {
            selectedIndex = 0
            refreshNearest()
        }
    }

    func setShowAllAEDs(_ showAll: Bool) {
        showAllAEDs = showAll
        selectedIndex = 0
        refreshNearest()
    }

    func refreshNearest() {
        do {
            switch locationManager.bestAvailableLocation() {
            case .fresh(let snapshot):
                results = try searchService.nearestAEDs(
                    from: snapshot.coordinate,
                    headingDegrees: headingManager.headingDegrees,
                    showAll: showAllAEDs
                )
                fallbackRecords = []
                selectedIndex = min(selectedIndex, max(0, results.count - 1))
                statusMessage = results.isEmpty ? "No AEDs found in the bundled database near this location." : "Nearest AEDs ready."
            case .stale(let snapshot):
                results = try searchService.nearestAEDs(
                    from: snapshot.coordinate,
                    headingDegrees: headingManager.headingDegrees,
                    showAll: showAllAEDs
                )
                fallbackRecords = []
                selectedIndex = min(selectedIndex, max(0, results.count - 1))
                statusMessage = "Location may be outdated."
            case .unavailable:
                results = []
                fallbackRecords = try searchService.fallbackRecords()
                selectedIndex = 0
                statusMessage = fallbackRecords.isEmpty ? "Location unavailable and no bundled AED records are loaded." : "Location unavailable. Showing AED list fallback."
            }
        } catch {
            results = []
            fallbackRecords = []
            statusMessage = "AED database unavailable."
        }
    }

    func nextAED() {
        guard !results.isEmpty else { return }
        selectedIndex = min(selectedIndex + 1, results.count - 1)
    }

    func previousAED() {
        guard !results.isEmpty else { return }
        selectedIndex = max(selectedIndex - 1, 0)
    }

    func readSelectedAED(prefix: String? = nil) {
        let prefixText = prefix.map { "\($0) " } ?? ""
        guard let selectedResult else {
            speechOutputService.speak("\(prefixText)\(statusMessage) \(EmergencyCopy.primaryInstruction(settings: settings))")
            return
        }
        speechOutputService.speak("\(prefixText)\(selectedResult.readout) \(EmergencyCopy.primaryInstruction(settings: settings))")
    }

    func repeatEmergencyInstruction(prefix: String? = nil) {
        let prefixText = prefix.map { "\($0) " } ?? ""
        speechOutputService.speak("\(prefixText)\(EmergencyCopy.primaryInstruction(settings: settings))")
    }

    func readCPRSteps() {
        speechOutputService.speak("\(EmergencyCopy.cprSteps) \(EmergencyCopy.aloneWarning)")
    }

    func requestEmergencyCall() {
        startEmergencyMode()
        callConfirmationPresented = true
    }

    func confirmEmergencyCall() {
        emergencyCallService.openCallPrompt()
    }

    func startVoiceCommands() {
        startEmergencyMode()
        voiceCommandManager.startListening { [weak self] command in
            self?.handleVoiceCommand(command)
        }
    }

    func stopVoiceCommands() {
        voiceCommandManager.stopListening()
    }

    private func handleVoiceCommand(_ command: VoiceCommand) {
        voiceConfirmation = command.confirmation

        switch command {
        case .nearestAED, .runnerMode:
            open(.runner)
            readSelectedAED(prefix: command.confirmation)
        case .nextAED:
            nextAED()
            readSelectedAED(prefix: command.confirmation)
        case .previousAED:
            previousAED()
            readSelectedAED(prefix: command.confirmation)
        case .readAloud:
            readSelectedAED(prefix: command.confirmation)
        case .repeatInstruction:
            repeatEmergencyInstruction(prefix: command.confirmation)
        case .callEmergency:
            speechOutputService.speak(command.confirmation)
            requestEmergencyCall()
        case .withPatient:
            open(.withPatient)
            repeatEmergencyInstruction(prefix: command.confirmation)
        case .biggerText:
            largerText = true
            speechOutputService.speak(command.confirmation)
        case .stopListening:
            stopVoiceCommands()
            speechOutputService.speak(command.confirmation)
        }
    }

    private func bindDeviceUpdates() {
        locationManager.$currentLocation
            .dropFirst()
            .sink { [weak self] _ in self?.refreshNearest() }
            .store(in: &cancellables)

        headingManager.$headingDegrees
            .dropFirst()
            .sink { [weak self] _ in self?.refreshNearest() }
            .store(in: &cancellables)
    }

    private func refreshDataWarnings() {
        dataSourceWarnings = searchService.metadata()?.warnings() ?? []
    }
}

@main
struct AEDNowOfflineApp: App {
    @StateObject private var model = AEDAppModel(settings: .unitedKingdom)
    @StateObject private var intentRouter = AppIntentRouter.shared

    var body: some Scene {
        WindowGroup {
            EmergencyHomeView()
                .environmentObject(model)
                .onAppear {
                    model.startEmergencyMode()
                    if let requestedMode = intentRouter.requestedMode {
                        model.open(requestedMode)
                        intentRouter.requestedMode = nil
                    }
                }
                .onReceive(intentRouter.$requestedMode.compactMap { $0 }) { mode in
                    model.open(mode)
                    intentRouter.requestedMode = nil
                }
                .confirmationDialog(
                    model.settings.callButtonTitle,
                    isPresented: $model.callConfirmationPresented,
                    titleVisibility: .visible
                ) {
                    Button(model.settings.callButtonTitle) {
                        model.confirmEmergencyCall()
                    }
                    .accessibilityLabel(model.settings.callButtonTitle)
                    .accessibilityInputLabels([model.settings.callButtonTitle])

                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(EmergencyCopy.primaryInstruction(settings: model.settings))
                }
        }
    }
}
