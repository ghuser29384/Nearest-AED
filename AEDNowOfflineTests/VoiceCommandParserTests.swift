import XCTest
@testable import AEDNowOffline

final class VoiceCommandParserTests: XCTestCase {
    func testRequiredCommandPhrases() {
        let cases: [(String, VoiceCommand)] = [
            ("nearest AED", .nearestAED),
            ("find AED", .nearestAED),
            ("show defibrillator", .nearestAED),
            ("next AED", .nextAED),
            ("previous AED", .previousAED),
            ("read aloud", .readAloud),
            ("repeat", .repeatInstruction),
            ("call emergency", .callEmergency),
            ("runner mode", .runnerMode),
            ("I am with the person", .withPatient),
            ("bigger text", .biggerText),
            ("stop listening", .stopListening)
        ]

        for (phrase, command) in cases {
            XCTAssertEqual(VoiceCommandParser.parse(phrase), command, phrase)
        }
    }

    func testNearestAEDCommand() {
        XCTAssertEqual(VoiceCommandParser.parse("please find nearest AED"), .nearestAED)
    }

    func testDefibrillatorFuzzyCommand() {
        XCTAssertEqual(VoiceCommandParser.parse("show defibrilator"), .nearestAED)
    }

    func testNextAEDCommand() {
        XCTAssertEqual(VoiceCommandParser.parse("next AED"), .nextAED)
    }

    func testCallEmergencyCommand() {
        XCTAssertEqual(VoiceCommandParser.parse("call emergency now"), .callEmergency)
    }

    func testStopListeningCommand() {
        XCTAssertEqual(VoiceCommandParser.parse("stop listening"), .stopListening)
    }
}
