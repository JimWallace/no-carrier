import CarrierContent
import CarrierCore
import Foundation
import TestSupport
import Testing

@Suite struct ContentTests {
    @Test func bundledContentLoadsAndValidates() throws {
        let content = try BundledContent.load()
        #expect(content.validate().isEmpty)
        #expect(content.tuning.starterDeck.count == 10)
        #expect(content.card("payload")?.consumed == true)
    }

    @Test func everyCardInTheBriefExists() throws {
        let content = try BundledContent.load()
        let names = [
            "BRUTE.EXE", "OVERFLOW", "STACK SMASH", "SUDO", "SETUID", "INJECT", "PHISH", "FORKBOMB",
            "DICTIONARY", "PROXY", "PROXY CHAIN", "SPOOF", "HONEYPOT", "PROBE", "GREP", "CRON", "DEFRAG",
            "SNIFFER.DMN", "FIREWALL.DMN", "KEYLOGGER.DMN", "CLOAK.DMN", "PAYLOAD", "CORRUPT SECTOR", "TRACER",
        ]
        #expect(Array(content.cards.map(\.name).prefix(names.count)) == names)
    }

    @Test func effectsRoundTripThroughJSON() throws {
        let effects: [Effect] = [
            .damage(amount: 3, hits: 2), .damagePerCycle(amount: 5), .kernelDamage(amount: 8),
            .shield(amount: 5), .draw(amount: 2), .trace(amount: -2), .cyclesNextTurn(amount: 2), .probe,
            .deleteMalware(amount: 1), .retaliate(amount: 4),
            .ifLayer(layer: .auth, then: [.damage(amount: 10, hits: 1)], otherwise: [.damage(amount: 4, hits: 1)]),
        ]
        let data = try JSONEncoder().encode(effects)
        #expect(try JSONDecoder().decode([Effect].self, from: data) == effects)
    }

    @Test func costDecodesNumberXAndNull() throws {
        let json = Data(#"[1, "X", null]"#.utf8)
        #expect(try JSONDecoder().decode([CardCost].self, from: json) == [.fixed(1), .x, .unplayable])
    }

    @Test func unknownEffectOpIsAnError() {
        let json = Data(#"{"op": "teleport", "amount": 3}"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Effect.self, from: json)
        }
    }

    @Test func validationFindsABrokenStarterDeck() throws {
        let content = try BundledContent.load()
        var tuning = content.tuning
        tuning.starterDeck.append("zero-day")
        let broken = ContentPack(
            cards: content.cards, ice: content.ice, osFamilies: content.osFamilies,
            hardware: content.hardware, orgs: content.orgs, tuning: tuning, maps: content.maps,
            objectives: content.objectives, flags: content.flags
        )
        #expect(broken.validate() == [.unknownCard(id: "zero-day", referencedBy: "starterDeck")])
    }

    @Test func validationFindsAMissingInjectedCard() throws {
        let content = try BundledContent.load()
        let ice =
            content.ice + [
                ICEDefinition(id: "worm", name: "WORM", pattern: [[.injectMalware(cardID: "nope")]])
            ]
        let broken = ContentPack(
            cards: content.cards, ice: ice, osFamilies: content.osFamilies,
            hardware: content.hardware, orgs: content.orgs, tuning: content.tuning, maps: content.maps,
            objectives: content.objectives, flags: content.flags
        )
        #expect(broken.validate() == [.unknownCard(id: "nope", referencedBy: "ICE worm")])
    }

    @Test func aMissingFileIsNamed() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("carrier-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(throws: ContentLoadError.missingFile(name: "cards.json", directory: directory.path)) {
            try ContentLoader.load(from: directory)
        }
    }
}
