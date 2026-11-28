import CarrierCore
import CarrierTerminal
import TestSupport
import Testing

/// Keywords in bold on the crack screens, and `? WORD`.
@Suite struct CrackScreenTests {
    let session: CrackSession

    init() throws {
        let crack = try #require(try BundledContent.load().crack)
        session = CrackSession(engine: CrackRunEngine(content: crack), seed: 1)
    }

    @Test func emphasizeBoldsOnlyTheKeywords() {
        let screen = CrackScreen(session: session, style: Phosphor(enabled: true))
        let line = screen.emphasize("NEXT GUESS COSTS 50% ALARM.")
        #expect(line == "NEXT \u{1B}[1mGUESS\u{1B}[22m COSTS 50% \u{1B}[1mALARM\u{1B}[22m.")
    }

    @Test func plainOutputHasNoEscapeCodes() {
        let screen = CrackScreen(session: session, style: .plain)
        #expect(screen.emphasize("NEXT GUESS COSTS 50% ALARM.") == "NEXT GUESS COSTS 50% ALARM.")
    }

    @Test func defineExplainsAKeywordAsCardText() throws {
        var session = session
        session.submit("? alarm")
        let index = try #require(session.log.lastIndex { $0.contains("ALARM: ") })
        #expect(session.logIsCardText[index])
    }

    @Test func defineRefusesAWordThatIsNotAKeyword() {
        var session = session
        session.submit("? banana")
        #expect(session.log.suffix(3).joined().contains("NOT A KEYWORD"))
    }
}
