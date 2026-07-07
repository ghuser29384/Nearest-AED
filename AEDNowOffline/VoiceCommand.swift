import Foundation

enum VoiceCommand: String, CaseIterable, Identifiable {
    case nearestAED
    case nextAED
    case previousAED
    case readAloud
    case repeatInstruction
    case callEmergency
    case runnerMode
    case withPatient
    case biggerText
    case stopListening

    var id: String { rawValue }

    var phrases: [String] {
        switch self {
        case .nearestAED:
            return ["nearest aed", "find aed", "show defibrillator", "show defib", "find defibrillator"]
        case .nextAED:
            return ["next aed", "next defibrillator", "next"]
        case .previousAED:
            return ["previous aed", "previous defibrillator", "back"]
        case .readAloud:
            return ["read aloud", "read it aloud", "speak"]
        case .repeatInstruction:
            return ["repeat", "repeat instruction", "say again"]
        case .callEmergency:
            return ["call emergency", "call 999", "call 112", "call emergency services"]
        case .runnerMode:
            return ["runner mode", "i am the aed runner", "i am the runner"]
        case .withPatient:
            return ["i am with the person", "with the person", "patient mode"]
        case .biggerText:
            return ["bigger text", "larger text", "make text bigger"]
        case .stopListening:
            return ["stop listening", "stop voice commands"]
        }
    }

    var confirmation: String {
        switch self {
        case .nearestAED: return "Nearest AED."
        case .nextAED: return "Next AED."
        case .previousAED: return "Previous AED."
        case .readAloud: return "Read aloud."
        case .repeatInstruction: return "Repeat."
        case .callEmergency: return "Call 999 / 112."
        case .runnerMode: return "Runner mode."
        case .withPatient: return "I am with the person."
        case .biggerText: return "Bigger text."
        case .stopListening: return "Stop listening."
        }
    }
}

enum VoiceCommandParser {
    static func parse(_ transcript: String) -> VoiceCommand? {
        let normalizedTranscript = normalize(transcript)
        guard !normalizedTranscript.isEmpty else { return nil }

        for command in VoiceCommand.allCases {
            if command.phrases.contains(where: { normalizedTranscript.contains(normalize($0)) }) {
                return command
            }
        }

        let words = normalizedTranscript.split(separator: " ").map(String.init)
        let windows = phraseWindows(words)
        for command in VoiceCommand.allCases {
            for phrase in command.phrases.map(normalize) {
                if windows.contains(where: { fuzzyMatch($0, phrase: phrase) }) {
                    return command
                }
            }
        }

        return nil
    }

    private static func phraseWindows(_ words: [String]) -> [String] {
        guard !words.isEmpty else { return [] }
        var values: [String] = []
        for length in 1...min(5, words.count) {
            for start in 0...(words.count - length) {
                values.append(words[start..<(start + length)].joined(separator: " "))
            }
        }
        return values
    }

    private static func fuzzyMatch(_ text: String, phrase: String) -> Bool {
        let maxDistance = phrase.count <= 6 ? 1 : 2
        return levenshtein(text, phrase) <= maxDistance
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "a e d", with: "aed")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let left = Array(lhs)
        let right = Array(rhs)
        guard !left.isEmpty else { return right.count }
        guard !right.isEmpty else { return left.count }

        var previous = Array(0...right.count)
        for (i, leftChar) in left.enumerated() {
            var current = [i + 1]
            for (j, rightChar) in right.enumerated() {
                if leftChar == rightChar {
                    current.append(previous[j])
                } else {
                    current.append(min(previous[j], previous[j + 1], current[j]) + 1)
                }
            }
            previous = current
        }
        return previous[right.count]
    }
}

