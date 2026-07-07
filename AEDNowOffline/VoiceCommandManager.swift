import AVFoundation
import Combine
import Foundation
import Speech

@MainActor
final class VoiceCommandManager: NSObject, ObservableObject {
    @Published private(set) var isListening = false
    @Published private(set) var statusMessage = "Voice commands off."
    @Published private(set) var lastTranscript = ""
    @Published private(set) var onDeviceRecognitionAvailable = false

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var speechRecognizer: SFSpeechRecognizer?
    private var lastHandledCommand: VoiceCommand?
    private var commandHandler: ((VoiceCommand) -> Void)?
    var forceOnDeviceRecognitionUnavailable = false

    func startListening(locale: Locale = Locale(identifier: "en-GB"), onCommand: @escaping (VoiceCommand) -> Void) {
        commandHandler = onCommand
        if forceOnDeviceRecognitionUnavailable {
            onDeviceRecognitionAvailable = false
            statusMessage = "On-device speech recognition unavailable. Use buttons or iOS Voice Control."
            return
        }
        speechRecognizer = SFSpeechRecognizer(locale: locale)

        guard let speechRecognizer else {
            statusMessage = "Speech recognition unavailable. Use buttons or iOS Voice Control."
            return
        }

        guard speechRecognizer.supportsOnDeviceRecognition else {
            onDeviceRecognitionAvailable = false
            statusMessage = "On-device speech recognition unavailable. Use buttons or iOS Voice Control."
            return
        }

        onDeviceRecognitionAvailable = true

        SFSpeechRecognizer.requestAuthorization { [weak self] speechStatus in
            AVAudioSession.sharedInstance().requestRecordPermission { microphoneAllowed in
                Task { @MainActor in
                    guard let self else { return }
                    guard speechStatus == .authorized, microphoneAllowed else {
                        self.statusMessage = "Speech or microphone permission unavailable. Use buttons or iOS Voice Control."
                        return
                    }
                    self.beginRecognition(with: speechRecognizer)
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
        statusMessage = "Voice commands off."
        lastHandledCommand = nil
    }

    private func beginRecognition(with speechRecognizer: SFSpeechRecognizer) {
        stopListening()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        recognitionRequest = request

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            statusMessage = "Voice commands unavailable. Use buttons or iOS Voice Control."
            return
        }

        isListening = true
        statusMessage = "Listening for voice commands."

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let transcript = result?.bestTranscription.formattedString {
                    self.lastTranscript = transcript
                    if let command = VoiceCommandParser.parse(transcript),
                       command != self.lastHandledCommand {
                        self.lastHandledCommand = command
                        self.statusMessage = command.confirmation
                        self.commandHandler?(command)
                    }
                }

                if error != nil || result?.isFinal == true {
                    self.stopListening()
                }
            }
        }
    }
}
