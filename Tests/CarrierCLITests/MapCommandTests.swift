import Testing

@testable import carrier_cli

@Suite struct MapCommandTests {
    @Test func readsTheMapCommands() {
        #expect(MapCommand.parse("attack 4") == .attack(node: 4))
        #expect(MapCommand.parse("a 4") == .attack(node: 4))
        #expect(MapCommand.parse("4") == .attack(node: 4))
        #expect(MapCommand.parse("re 2") == .reinforce(node: 2))
        #expect(MapCommand.parse("wait") == .wait)
        #expect(MapCommand.parse("scan 7") == .scan(node: 7))
        #expect(MapCommand.parse("?") == .help)
        #expect(MapCommand.parse("") == .empty)
    }

    @Test func refusesWhatItCannotRead() {
        #expect(MapCommand.parse("attack") == .unknown("ATTACK"))
        #expect(MapCommand.parse("attack 12") == .unknown("ATTACK 12"))
        #expect(MapCommand.parse("12") == .unknown("12"))
        #expect(MapCommand.parse("-9223372036854775808") == .unknown("-9223372036854775808"))
        #expect(MapCommand.parse("hack the planet") == .unknown("HACK THE PLANET"))
    }

    @Test func tabCompletesTheFirstWord() {
        #expect(MapCommand.complete("sc").text == "SCAN ")
        #expect(MapCommand.complete("").matches.count == MapCommand.words.count)
        #expect(MapCommand.complete("scan 4").matches.isEmpty)
    }
}
