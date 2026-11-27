import CarrierCore
import TestSupport
import Testing

/// Kickoff §4, "Security layers" and "Weakness tags".
@Suite struct DamageRulesTests {
    let content: ContentPack
    let engine: Engine

    init() throws {
        content = try BundledContent.load()
        engine = Engine(content: content)
    }

    @Test func excessCarriesFromFirewallToAuth() {
        var fixture = FightFixture()
        fixture.layers = [SecurityLayer(kind: .firewall, hp: 4), SecurityLayer(kind: .auth, hp: 10)]
        fixture.hand = ["brute"]
        let (state, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [0, 8])
        #expect(events.contains(.layerBreached(layer: .firewall)))
    }

    @Test func excessStopsAtKernel() {
        var fixture = FightFixture()
        fixture.layers = [
            SecurityLayer(kind: .firewall, hp: 0), SecurityLayer(kind: .auth, hp: 4),
            SecurityLayer(kind: .kernel, hp: 8),
        ]
        fixture.hand = ["brute", "brute"]
        var (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [0, 0, 8])
        let events: [Event]
        (state, events) = engine.apply(.play(handIndex: 0), to: state)
        #expect(state.layerHP == [0, 0, 8])
        #expect(events.contains(.kernelBlocked(amount: 6)))
    }

    @Test func payloadIsRefusedBeforeKernel() {
        var fixture = FightFixture()
        fixture.layers = [SecurityLayer(kind: .firewall, hp: 5), SecurityLayer(kind: .kernel, hp: 8)]
        fixture.hand = ["payload"]
        let before = fixture.state(content: content)
        let (state, events) = engine.apply(.play(handIndex: 0), to: before)
        #expect(state == before)
        #expect(events == [.actionRejected(reason: .wrongLayer(cardID: "payload", required: .kernel))])
    }

    @Test func payloadDamagesKernelAndIsConsumed() {
        var fixture = FightFixture()
        fixture.layers = [SecurityLayer(kind: .firewall, hp: 0), SecurityLayer(kind: .kernel, hp: 10)]
        fixture.hand = ["payload"]
        let (state, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [0, 2])
        #expect(state.fight.consumedCards.map(\.cardID) == ["payload"])
        #expect(!state.fight.allCards.contains { $0.cardID == "payload" })
        #expect(events.contains(.cardConsumed(cardID: "payload")))
    }

    @Test func weakTagsDealHalfAgainRoundedDown() {
        var fixture = FightFixture()
        fixture.weak = [.overflow]
        fixture.hand = ["overflow"]
        let (state, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [13, 20])
        #expect(events.contains(.damageDealt(layer: .firewall, amount: 7, modifier: .weak)))
    }

    @Test func resistedTagsDealHalfRoundedDown() {
        var fixture = FightFixture()
        fixture.resist = [.overflow]
        fixture.hand = ["overflow"]
        let (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [18, 20])
    }

    @Test func untaggedExploitsIgnoreWeakness() {
        var fixture = FightFixture()
        fixture.weak = [.overflow]
        fixture.resist = [.privesc]
        fixture.hand = ["brute"]
        let (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [14, 20])
    }

    @Test func keyloggerBonusComesBeforeTheMultiplier() {
        var fixture = FightFixture()
        fixture.weak = [.overflow]
        fixture.daemons = ["keylogger"]
        fixture.hand = ["overflow"]
        let (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [10, 20])
    }

    @Test func multiHitExploitsApplyModifiersPerHit() {
        var fixture = FightFixture()
        fixture.weak = [.inject]
        fixture.hand = ["inject"]
        let (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [12, 20])
    }

    @Test func sudoHitsHarderOnAuth() {
        var fixture = FightFixture()
        fixture.hand = ["sudo"]
        var (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [16, 20])
        fixture.layers = [SecurityLayer(kind: .firewall, hp: 0), SecurityLayer(kind: .auth, hp: 20)]
        (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.layerHP == [0, 10])
    }

    @Test func dictionarySpendsEveryCycle() {
        var fixture = FightFixture()
        fixture.hand = ["dictionary"]
        fixture.cycles = 3
        let (state, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.fight.cycles == 0)
        #expect(state.layerHP == [5, 20])
        #expect(events.first == .cardPlayed(cardID: "dictionary", cyclesSpent: 3))
    }

    @Test func breachingEveryLayerCapturesTheNode() {
        var fixture = FightFixture()
        fixture.layers = [SecurityLayer(kind: .firewall, hp: 2), SecurityLayer(kind: .auth, hp: 3)]
        fixture.hand = ["brute", "brute"]
        let (state, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.fight.outcome == .captured)
        #expect(events.suffix(2) == [.nodeCaptured, .fightEnded(outcome: .captured)])
        let (after, refused) = engine.apply(.play(handIndex: 0), to: state)
        #expect(after == state)
        #expect(refused == [.actionRejected(reason: .fightOver)])
    }
}
