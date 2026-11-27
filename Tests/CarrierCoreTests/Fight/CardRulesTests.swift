import CarrierCore
import TestSupport
import Testing

/// Kickoff §4 and §5: cycles, RAM, draws and the script and proxy cards.
@Suite struct CardRulesTests {
    let content: ContentPack
    let engine: Engine

    init() throws {
        content = try BundledContent.load()
        engine = Engine(content: content)
    }

    @Test func aCardNeedsItsCycles() {
        var fixture = FightFixture()
        fixture.hand = ["stack-smash"]
        fixture.cycles = 1
        let before = fixture.state(content: content)
        let (state, events) = engine.apply(.play(handIndex: 0), to: before)
        #expect(state == before)
        #expect(events == [.actionRejected(reason: .notEnoughCycles(cardID: "stack-smash", cost: 2, cycles: 1))])
    }

    @Test func malwareIsUnplayable() {
        var fixture = FightFixture()
        fixture.hand = ["corrupt-sector"]
        let (_, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(events == [.actionRejected(reason: .unplayable(cardID: "corrupt-sector"))])
    }

    @Test func aMissingHandIndexIsRefused() {
        let (_, events) = engine.apply(.play(handIndex: 3), to: FightFixture().state(content: content))
        #expect(events == [.actionRejected(reason: .noSuchCard(handIndex: 3))])
    }

    @Test func daemonsAreLimitedByRAM() {
        var fixture = FightFixture()
        fixture.hand = ["keylogger", "sniffer", "sniffer"]
        fixture.cycles = 10
        var (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        (state, _) = engine.apply(.play(handIndex: 0), to: state)
        #expect(state.fight.daemons.map(\.cardID) == ["keylogger", "sniffer"])
        let (after, events) = engine.apply(.play(handIndex: 0), to: state)
        #expect(after == state)
        #expect(events == [.actionRejected(reason: .notEnoughRAM(cardID: "sniffer", needed: 2, free: 1))])
    }

    @Test func probeRevealsDrawsAndExhausts() {
        var fixture = FightFixture()
        fixture.weak = [.social]
        fixture.hand = ["probe"]
        fixture.drawPile = ["brute"]
        let (state, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.fight.revealed)
        #expect(state.handIDs == ["brute"])
        #expect(state.fight.exhaustPile.map(\.cardID) == ["probe"])
        #expect(events.contains(.weaknessRevealed(weak: [.social], resist: [])))
        #expect(state.fight.cycles == 3)
    }

    @Test func drawingFromAnEmptyPileReshufflesTheDiscards() {
        var fixture = FightFixture()
        fixture.hand = ["grep"]
        fixture.discardPile = ["brute", "proxy"]
        let (state, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.handIDs.sorted() == ["brute", "proxy"])
        #expect(state.fight.discardPile.map(\.cardID) == ["grep"])
        #expect(events.contains(.deckReshuffled(count: 2)))
    }

    @Test func spoofLowersTraceButNotBelowZero() {
        var fixture = FightFixture()
        fixture.hand = ["spoof", "spoof"]
        fixture.trace = 3
        var (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.fight.trace == 1)
        #expect(state.fight.proxy == 3)
        let events: [Event]
        (state, events) = engine.apply(.play(handIndex: 0), to: state)
        #expect(state.fight.trace == 0)
        #expect(events.contains(.traceChanged(by: -1, total: 0)))
    }

    @Test func phishAddsTrace() {
        var fixture = FightFixture()
        fixture.hand = ["phish"]
        let (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.fight.trace == 1)
        #expect(state.layerHP == [13, 20])
    }

    @Test func defragDeletesMalwareFromTheHandFirst() {
        var fixture = FightFixture()
        fixture.hand = ["defrag", "tracer"]
        fixture.drawPile = ["brute"]
        fixture.discardPile = ["corrupt-sector"]
        let (state, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(!state.handIDs.contains("tracer"))
        #expect(state.fight.discardPile.map(\.cardID).contains("corrupt-sector"))
        #expect(events.contains(.malwareDeleted(cardID: "tracer")))
    }

    @Test func cronAddsCyclesNextTurn() {
        var fixture = FightFixture()
        fixture.hand = ["cron"]
        var (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        (state, _) = engine.apply(.endTurn, to: state)
        #expect(state.fight.cycles == 5)
        #expect(state.fight.bonusCyclesNextTurn == 0)
    }

    @Test func daemonsTriggerAtTheStartOfTheTurn() {
        var fixture = FightFixture()
        fixture.daemons = ["sniffer", "firewall-dmn"]
        fixture.proxy = 9
        let (state, _) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.layerHP == [17, 20])
        #expect(state.fight.proxy == 4)
    }

    @Test func tracerInHandAddsTraceAtTheEndOfTheTurn() {
        var fixture = FightFixture()
        fixture.hand = ["tracer"]
        let (state, events) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.fight.trace == 2)
        #expect(events.contains(.malwareTriggered(cardID: "tracer")))
    }

    @Test func endTurnDiscardsTheHandAndDrawsAFreshOne() {
        var fixture = FightFixture()
        fixture.hand = ["brute", "proxy"]
        fixture.drawPile = ["spoof", "spoof", "spoof", "spoof", "spoof", "spoof"]
        let (state, _) = engine.apply(.endTurn, to: fixture.state(content: content))
        #expect(state.handIDs == ["spoof", "spoof", "spoof", "spoof", "spoof"])
        #expect(state.fight.discardPile.map(\.cardID) == ["brute", "proxy"])
        #expect(state.fight.cycles == 3)
        #expect(state.fight.turn == 2)
    }

    @Test func logoutCostsTraceAndLeavesTheNode() {
        var fixture = FightFixture()
        fixture.trace = 20
        let (state, events) = engine.apply(.logout, to: fixture.state(content: content))
        #expect(state.fight.trace == 30)
        #expect(state.fight.outcome == .loggedOut)
        #expect(state.layerHP == [20, 20])
        #expect(events.last == .fightEnded(outcome: .loggedOut))
    }

    @Test func logoutThatFillsTraceIsNoCarrier() {
        var fixture = FightFixture()
        fixture.trace = 95
        let (state, _) = engine.apply(.logout, to: fixture.state(content: content))
        #expect(state.fight.outcome == .traced)
    }
}
