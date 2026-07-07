import AVFoundation
import Combine
import Foundation

@MainActor
final class SpeechOutputService: NSObject, ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()
    var isMuted = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, interrupt: Bool = true) {
        guard !isMuted else { return }
        if interrupt {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        utterance.prefersAssistiveTechnologySettings = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}

extension SpeechOutputService: AVSpeechSynthesizerDelegate {}
