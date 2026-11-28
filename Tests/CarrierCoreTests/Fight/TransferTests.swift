import CarrierCore
import TestSupport
import Testing

/// Addendum 01, §3.2: the TRANSFER in a TARGET fight, COMPRESS and
/// NULL ROUTE.
@Suite struct TransferTests {
    let content: ContentPack
    let engine: Engine

    init() throws {
        content = try BundledContent.load()
        engine = Engine(content: content)
    }

    func targetFight(hand: [String] = ["brute"], ice: [String] = []) -> FightFixture {
        var fixture = FightFixture()
        fixture.layers = [SecurityLayer(kind: .firewall, hp: 1)]
        fixture.hand = hand
        fixture.ice = ice
        fixture.drawPile = Array(repeating: "proxy", count: 20)
        fixture.transfer = TransferProgress(totalMB: 6, rateMB: 2)
        return fixture
    }

    @Test func breachingATargetStartsTheTransferInsteadOfCapturing() {
        let (state, events) = engine.apply(.play(handIndex: 0), to: targetFight().state(content: content))
        #expect(state.fight.outcome == nil)
        #expect(state.fight.transfer?.started == true)
        #expect(events.contains(.transferStarted(totalMB: 6)))
        #expect(!events.contains(.nodeCaptured))
    }

    @Test func theTransferMovesAtTheStartOfEachTurnUntilComplete() {
        var (state, _) = engine.apply(.play(handIndex: 0), to: targetFight().state(content: content))
        var events: [Event]
        (state, events) = engine.apply(.endTurn, to: state)
        #expect(events.contains(.transferProgressed(by: 2, doneMB: 2, totalMB: 6)))
        (state, _) = engine.apply(.endTurn, to: state)
        (state, events) = engine.apply(.endTurn, to: state)
        #expect(state.fight.transfer?.isComplete == true)
        #expect(events.contains(.transferComplete))
        #expect(state.fight.outcome == nil)
        (state, events) = engine.apply(.endTurn, to: state)
        #expect(!events.contains { if case .transferProgressed = $0 { true } else { false } })
    }

    @Test func iceEscalatesEachTurnTheTransferRuns() {
        var (state, _) = engine.apply(.play(handIndex: 0), to: targetFight(ice: ["blackice"]).state(content: content))
        #expect(engine.telegraph(state.fight).first?.intents == [.attack(amount: 8)])
        (state, _) = engine.apply(.endTurn, to: state)
        #expect(engine.telegraph(state.fight).first?.intents == [.attack(amount: 6), .harden(amount: 3)])
        (state, _) = engine.apply(.endTurn, to: state)
        #expect(engine.telegraph(state.fight).first?.intents == [.attack(amount: 10)])
    }

    @Test func compressSpeedsTheCopy() {
        var (state, _) = engine.apply(
            .play(handIndex: 0), to: targetFight(hand: ["brute", "compress"]).state(content: content))
        let events: [Event]
        (state, events) = engine.apply(.play(handIndex: 0), to: state)
        #expect(events.contains(.transferProgressed(by: 3, doneMB: 3, totalMB: 6)))
    }

    @Test func compressDoesNothingBeforeTheTransfer() {
        var fixture = targetFight(hand: ["compress"])
        fixture.layers = [SecurityLayer(kind: .firewall, hp: 10)]
        let (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(state.fight.transfer?.doneMB == 0)
    }

    @Test func nullRouteCutsTraceThisTurnOnly() {
        var fixture = FightFixture()
        fixture.ice = ["sentry"]
        fixture.hand = ["null-route"]
        fixture.drawPile = Array(repeating: "proxy", count: 20)
        var (state, _) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(engine.telegraph(state.fight).first?.intents == [.trace(amount: 1)])
        #expect(state.fight.proxy == 4)
        (state, _) = engine.apply(.endTurn, to: state)
        #expect(state.fight.trace == 1)
        #expect(state.fight.turnTraceShield == 0)
    }
}
