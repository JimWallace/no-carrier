import CarrierCore
import TestSupport
import Testing

/// Kickoff §4, "ICE", and §6, "Hardware".
@Suite struct ICERulesTests {
    let content: ContentPack
    let engine: Engine

    init() throws {
        content = try BundledContent.load()
        engine = Engine(content: content)
    }

    @Test func attacksHitProxyThenIntegrity() {
        var fixture = FightFixture()
        fixture.ice = ["blackice"]
        fixture.hand = ["proxy"]
        var (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        let events: [Event]
        (state, events) = engine.apply(.endTurn, to: state)
        #expect(events.contains(.attackResolved(proxyAbsorbed: 5, integrityLost: 3, integrity: 37)))
        #expect(state.fight.integrity == 37)
    }

    @Test func iceFollowsItsPattern() {
        var fixture = FightFixture()
        fixture.ice = ["sentry"]
        var (state, _) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.fight.trace == 3)
        #expect(state.fight.integrity == 40)
        (state, _) = engine.apply(.endTurn, to: state)
        #expect(state.fight.integrity == 36)
        (state, _) = engine.apply(.endTurn, to: state)
        #expect(state.fight.trace == 6)
    }

    @Test func modemAndCloakScaleTrace() {
        var fixture = FightFixture()
        fixture.ice = ["sentry"]
        fixture.tracePercent = 150
        fixture.daemons = ["cloak"]
        let state = fixture.state(content: content)
        #expect(engine.telegraph(state.fight) == [ICETelegraph(iceID: "sentry", intents: [.trace(amount: 3)])])
        let (after, _) = engine.apply(.endTurn, to: state)
        #expect(after.fight.trace == 3)
    }

    @Test func tierTwoICEHitsHarder() {
        var fixture = FightFixture()
        fixture.ice = ["blackice"]
        fixture.cpuTier = 2
        let (state, _) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.fight.integrity == 30)
    }

    @Test func tierThreeICEActsTwice() {
        var fixture = FightFixture()
        fixture.ice = ["sentry"]
        fixture.cpuTier = 3
        let state = fixture.state(content: content)
        #expect(engine.telegraph(state.fight).first?.intents == [.trace(amount: 3), .attack(amount: 4)])
        let (after, _) = engine.apply(.endTurn, to: state)
        #expect(after.fight.trace == 3)
        #expect(after.fight.integrity == 36)
        #expect(after.fight.ice.first?.step == 2)
    }

    @Test func watchdogPurgesTheLargestDaemon() {
        var fixture = FightFixture()
        fixture.ice = ["watchdog"]
        fixture.daemons = ["sniffer", "keylogger", "cloak"]
        let (state, events) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.fight.daemons.map(\.cardID) == ["sniffer", "cloak"])
        #expect(events.contains(.daemonPurged(cardID: "keylogger")))
    }

    @Test func watchdogBreaksTiesByAge() {
        var fixture = FightFixture()
        fixture.ice = ["watchdog"]
        fixture.daemons = ["cloak", "sniffer"]
        let (state, _) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.fight.daemons.map(\.cardID) == ["sniffer"])
    }

    @Test func gatekeeperHardensThenInjectsMalware() {
        var fixture = FightFixture()
        fixture.ice = ["gatekeeper"]
        fixture.drawPile = Array(repeating: "brute", count: 10)
        var (state, _) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.layerHP == [25, 20])
        #expect(state.fight.machine.layers[0].maxHP == 25)
        let events: [Event]
        (state, events) = engine.apply(.endTurn, to: state)
        #expect(events.contains(.malwareInjected(cardID: "corrupt-sector")))
        #expect(state.fight.discardPile.contains { $0.cardID == "corrupt-sector" })
    }

    @Test func honeypotHitsBackOnce() {
        var fixture = FightFixture()
        fixture.ice = ["blackice", "blackice"]
        fixture.hand = ["honeypot"]
        var (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        let events: [Event]
        (state, events) = engine.apply(.endTurn, to: state)
        #expect(events.filter { $0 == .retaliated(amount: 4) }.count == 1)
        #expect(state.layerHP == [16, 20])
        #expect(state.fight.integrity == 40 - 4 - 8)
    }

    @Test func integrityZeroEndsTheRun() {
        var fixture = FightFixture()
        fixture.ice = ["blackice"]
        fixture.integrity = 8
        let (state, _) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.fight.outcome == .flatlined)
        #expect(state.fight.integrity == 0)
    }

    @Test func fullTraceIsNoCarrier() {
        var fixture = FightFixture()
        fixture.ice = ["sentry"]
        fixture.trace = 98
        let (state, events) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.fight.outcome == .traced)
        #expect(events.last == .fightEnded(outcome: .traced))
    }
}
