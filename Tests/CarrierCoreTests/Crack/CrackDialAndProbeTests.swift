import CarrierCore
import TestSupport
import Testing

/// The two non-symbol cards (addendum 03, §3): a DIAL turns in place, a
/// PROBE reveals a slot.
@Suite struct CrackDialAndProbeTests {
    let content: CrackContent

    /// A deck of dials and probes only, with energy to spare.
    init() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.starterDeck = Array(repeating: "dial-a", count: 8) + Array(repeating: "probe", count: 8)
        crack.energy = 20
        content = crack
    }

    func start(_ seed: UInt64 = 9) -> (CrackEngine, CrackState) {
        let engine = CrackEngine(content: content)
        return (engine, engine.start(seed: seed).0)
    }

    func handIndex(of kind: CrackCardKind, in state: CrackState, _ engine: CrackEngine) throws -> Int {
        try #require(state.hand.firstIndex { engine.kind($0) == kind })
    }

    @Test func aDialTurnsInPlaceForOneEnergyAStepTheShortWayRound() throws {
        var (engine, state) = start()
        state = engine.apply(.play(handIndex: try handIndex(of: .dial, in: state, engine), slot: 0), to: state).0
        let before = state.energy
        // A E K R X Z wraps: A to Z is one step back.
        let (after, events) = engine.apply(.turn(slot: 0, symbol: "Z"), to: state)
        #expect(after.board[0]?.symbol == "Z")
        #expect(after.energy == before - content.costs.turn)
        #expect(events == [.turned(slot: 0, from: "A", to: "Z")])
        #expect(engine.turnCost(from: "A", to: "R") == 3 * content.costs.turn)
    }

    @Test func aTurnedDialIsWhatTheGuessReads() throws {
        var (engine, state) = start()
        state = engine.apply(.play(handIndex: try handIndex(of: .dial, in: state, engine), slot: 1), to: state).0
        state = engine.apply(.turn(slot: 1, symbol: "K"), to: state).0
        #expect(engine.boardSymbols(state) == [nil, "K", nil, nil])
    }

    @Test func onlyADialTurns() throws {
        let (engine, state) = start()
        #expect(engine.apply(.turn(slot: 0, symbol: "K"), to: state).1 == [.rejected(.notADial)])
    }

    @Test func aDialRefusesAnUnknownSymbolOrTheOneItShows() throws {
        var (engine, state) = start()
        state = engine.apply(.play(handIndex: try handIndex(of: .dial, in: state, engine), slot: 0), to: state).0
        #expect(engine.apply(.turn(slot: 0, symbol: "Q"), to: state).1 == [.rejected(.unknownSymbol)])
        #expect(engine.apply(.turn(slot: 0, symbol: "A"), to: state).1 == [.rejected(.alreadyShown)])
    }

    @Test func aReplacedDialGoesToDiscardAndShowsItsPrintedSymbolAgain() throws {
        var (engine, state) = start()
        state = engine.apply(.play(handIndex: try handIndex(of: .dial, in: state, engine), slot: 0), to: state).0
        state = engine.apply(.turn(slot: 0, symbol: "K"), to: state).0
        state = engine.apply(.play(handIndex: try handIndex(of: .dial, in: state, engine), slot: 0), to: state).0
        #expect(state.board[0]?.symbol == "A")
        #expect(state.discardPile.count == 1)
    }

    @Test func aProbeRevealsTheSlotAndLeavesTheBoardAlone() throws {
        var (engine, state) = start()
        let index = try handIndex(of: .probe, in: state, engine)
        let (after, events) = engine.apply(.play(handIndex: index, slot: 2), to: state)
        #expect(after.revealed[2] == state.code[2])
        #expect(after.board[2] == nil)
        #expect(after.discardPile.count == 1)
        #expect(after.energy == state.energy - content.costs.probe)
        #expect(events == [.probed(slot: 2, symbol: state.code[2])])
        state = after
        let again = try handIndex(of: .probe, in: state, engine)
        #expect(engine.apply(.play(handIndex: again, slot: 2), to: state).1 == [.rejected(.alreadyKnown)])
    }
}
