import CarrierCore
import TestSupport
import Testing

/// The ability vocabulary the UI shows (2026-11-28 playtest: "I don't
/// understand what each card does").
@Suite struct CardAbilityTests {
    let content: ContentPack

    init() throws {
        content = try BundledContent.load()
    }

    func card(_ id: String) throws -> CardDefinition {
        try #require(content.card(id))
    }

    @Test func everyCardSaysWhatItDoes() {
        for card in content.cards {
            #expect(!card.headline.isEmpty, "\(card.id) has no headline")
            #expect(!card.abilities.isEmpty, "\(card.id) has no abilities")
            #expect(card.abilities.allSatisfy { !$0.long.isEmpty })
        }
    }

    @Test func headlinesUseTheKeywords() throws {
        #expect(try card("brute").headline == "ATK 6")
        #expect(try card("inject").headline == "ATK 3x2")
        #expect(try card("dictionary").headline == "ATK 5/CYC")
        #expect(try card("sudo").headline == "ATK 4 (10 VS AUTH)")
        #expect(try card("proxy").headline == "DEF 5")
        #expect(try card("spoof").headline == "DEF 3 TRACE -2")
        #expect(try card("sniffer").headline == "ATK 3/TURN")
        #expect(try card("keylogger").headline == "EXPLOITS +2")
        #expect(try card("payload").headline == "KERNEL 8")
        #expect(try card("tracer").headline == "HELD: TRACE +2")
        #expect(try card("corrupt-sector").headline == "DEAD")
    }

    @Test func fullAbilitiesCarryFlagsAndNoise() throws {
        let payload = try card("payload").abilities.map(\.short)
        #expect(payload.contains("KERNEL ONLY"))
        #expect(payload.contains("SPENT"))
        #expect(payload.contains("NOISE 2"))
        #expect(try card("probe").abilities.map(\.short).contains("ONCE"))
        #expect(try card("scrub").abilities.map(\.short).contains("ALERT -5"))
        #expect(try card("sniffer").abilities.map(\.short).contains("RAM 2"))
    }

    @Test func theGlossaryCoversEveryHeadlineKeyword() {
        let keywords = Set(AbilityGlossary.entries.map(\.keyword))
        let used = ["ATK", "DEF", "KERNEL", "DRAW", "TRACE", "PROBE", "THORNS", "MUTE", "CLEAN", "XFER"]
        for word in used {
            #expect(keywords.contains(word), "\(word) is missing from the key")
        }
    }
}
