import Testing

@testable import CarrierTerminal

/// Kickoff §7: a card plays by number or by name; only the hand can be typed.
@Suite struct CommandInputTests {
    let parser = CommandParser(
        handNames: ["BRUTE.EXE", "PROXY", "PROBE", "BRUTE.EXE", "STACK SMASH"],
        allCardNames: ["BRUTE.EXE", "PROXY", "PROBE", "STACK SMASH", "PAYLOAD"]
    )

    @Test func numbersPlayByPosition() {
        #expect(parser.parse("2") == .play(handIndex: 1))
        #expect(parser.parse("0") == .play(handIndex: 9))
    }

    @Test func namesPlayCaseInsensitively() {
        #expect(parser.parse("brute.exe") == .play(handIndex: 0))
        #expect(parser.parse("stack   smash") == .play(handIndex: 4))
    }

    @Test func aUniquePrefixIsEnough() {
        #expect(parser.parse("st") == .play(handIndex: 4))
        #expect(parser.parse("lo") == .logout)
        #expect(parser.parse("pr") == .unknown("PR"))
    }

    @Test func commandsAndMistakes() {
        #expect(parser.parse("end") == .endTurn)
        #expect(parser.parse("?") == .help)
        #expect(parser.parse("payload") == .notInHand("PAYLOAD"))
        #expect(parser.parse("format c:") == .unknown("FORMAT C:"))
        #expect(parser.parse("   ") == .empty)
    }

    @Test func tabCompletesToTheCommonPrefix() {
        #expect(parser.complete("pr").text == "PRO")
        #expect(parser.complete("pr").matches == ["PROXY", "PROBE"])
        #expect(parser.complete("b").text == "BRUTE.EXE")
        #expect(parser.complete("z").matches.isEmpty)
    }

    @Test func aDigitOnAnEmptyLinePlaysAtOnce() {
        var editor = LineEditor()
        #expect(editor.handle(UInt8(ascii: "3"), completer: parser.complete) == .digit(3))
    }

    @Test func typingTabAndReturnSubmitAName() {
        var editor = LineEditor()
        _ = editor.handle(UInt8(ascii: "s"), completer: parser.complete)
        _ = editor.handle(9, completer: parser.complete)
        #expect(editor.buffer == "STACK SMASH")
        #expect(editor.handle(13, completer: parser.complete) == .submit("STACK SMASH"))
        #expect(editor.buffer.isEmpty)
    }

    @Test func arrowKeysAreIgnored() {
        var editor = LineEditor()
        for byte in [UInt8(27), UInt8(ascii: "["), UInt8(ascii: "A")] {
            #expect(editor.handle(byte, completer: parser.complete) == .ignored)
        }
        #expect(editor.buffer.isEmpty)
        #expect(editor.handle(3, completer: parser.complete) == .quit)
    }

    @Test func wrapKeepsEveryLineInsideTheColumns() {
        let lines = Columns.wrap("CONNECT a-very-long-hostname.first-continental.example.com ICE: GATEKEEPER, WATCHDOG")
        #expect(lines.allSatisfy { $0.count <= Columns.textWidth })
        #expect(lines.joined(separator: " ").contains("WATCHDOG"))
    }
}

@Suite struct CommandNumberBoundsTests {
    @Test(arguments: ["-9223372036854775808", "-1", "100", "9223372036854775807"])
    func outOfRangeNumbersAreNonsense(text: String) {
        let parser = CommandParser(handNames: ["PROXY"], allCardNames: ["PROXY"])
        #expect(parser.parse(text) == .unknown(text))
    }
}

@Suite struct InfoCommandTests {
    @Test func infoNamesACardByItsNumber() {
        let parser = CommandParser(handNames: ["PROXY", "BRUTE.EXE"], allCardNames: ["PROXY", "BRUTE.EXE"])
        #expect(parser.parse("info 2") == .info(handIndex: 1))
        #expect(parser.parse("? 1") == .info(handIndex: 0))
        #expect(parser.parse("info 0") == .info(handIndex: 9))
        #expect(parser.parse("info 500") == .unknown("INFO 500"))
    }
}
