import CarrierCore
import TestSupport
import Testing

/// The reward cards and HOLD (addendum 03, §8). One rule, one test.
@Suite struct CrackCardEffectTests {
    let content: CrackContent
    let server: CrackServer

    /// Symbol cards and one copy of every other kind, with energy to spare;
    /// the corporate server without interference.
    init() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.starterDeck = crack.starterDeck.filter { crack.card($0)?.kind == .symbol }
        crack.handSize = crack.starterDeck.count + 20
        crack.energy = 20
        content = crack
        var corporate = try #require(crack.server("corporate"))
        corporate.interference = []
        server = corporate
    }

    /// A crack whose deck is the symbol cards plus `extra`, all in hand.
    func start(_ extra: [String], server: CrackServer? = nil) -> (CrackEngine, CrackState) {
        let engine = CrackEngine(content: content)
        let state = engine.start(seed: 6, server: server ?? self.server, deck: content.starterDeck + extra).0
        return (engine, state)
    }

    func index(_ id: String, _ state: CrackState) throws -> Int {
        try #require(state.hand.firstIndex { $0.cardID == id })
    }

    /// Puts the code's first symbol on slot 0 and a symbol not in the code
    /// (if any) on slot 1.
    func placeKnown(_ engine: CrackEngine, _ state: inout CrackState) throws {
        let first = try #require(state.hand.firstIndex { engine.label($0) == state.code[0] })
        state = engine.apply(.play(handIndex: first, slot: 0), to: state).0
        if let absent = state.hand.firstIndex(where: { !state.code.contains(engine.label($0)) }) {
            state = engine.apply(.play(handIndex: absent, slot: 1), to: state).0
        }
    }

    @Test func holdEndsTheTurnWithoutAGuessForTheHoldAlarm() {
        let (engine, state) = start([])
        let (after, events) = engine.apply(.hold, to: state)
        #expect(after.guesses.isEmpty)
        #expect(after.alarm == content.alarm.hold)
        #expect(after.turn == state.turn + 1)
        #expect(events.first == .held(alarm: content.alarm.hold))
    }

    @Test func holdAtAFullAlarmTracesTheLine() {
        var crack = content
        crack.alarm.hold = crack.alarm.max
        let engine = CrackEngine(content: crack)
        let state = engine.start(seed: 6, server: server).0
        #expect(engine.apply(.hold, to: state).0.outcome == .traced)
    }

    @Test func sniffSaysWhetherASlotsSymbolIsInTheCode() throws {
        var (engine, state) = start(["sniff"])
        try placeKnown(engine, &state)
        let (after, _) = engine.apply(.play(handIndex: try index("sniff", state), slot: 0), to: state)
        #expect(after.facts == [.contains(symbol: state.code[0], true)])
    }

    @Test func countSaysHowManyOfASlotsSymbolAreInTheCode() throws {
        var (engine, state) = start(["count"])
        try placeKnown(engine, &state)
        let symbol = state.code[0]
        let (after, _) = engine.apply(.play(handIndex: try index("count", state), slot: 0), to: state)
        #expect(after.facts == [.count(symbol: symbol, state.code.count { $0 == symbol })])
    }

    @Test func sniffCountAndLockNeedAFullSlot() throws {
        let (engine, state) = start(["sniff", "count", "lock"])
        for id in ["sniff", "count", "lock"] {
            #expect(
                engine.apply(.play(handIndex: try index(id, state), slot: 4), to: state).1 == [.rejected(.emptySlot)])
        }
    }

    @Test func aLockedSlotIsSafeFromScramble() throws {
        var scrambling = server
        scrambling.interference = [CrackInterference(kind: .scramble, every: 1)]
        var (engine, state) = start(["lock", "lock", "lock"], server: scrambling)
        for slot in state.board.indices {
            let card = try #require(state.hand.firstIndex { engine.kind($0) == .symbol })
            state = engine.apply(.play(handIndex: card, slot: slot), to: state).0
        }
        for slot in 0..<3 {
            state = engine.apply(.play(handIndex: try index("lock", state), slot: slot), to: state).0
        }
        let events = engine.apply(.guess, to: state).1
        #expect(events.contains(.scrambled(3, 4)))
    }

    @Test func replacingALockedCardUnlocksTheSlot() throws {
        var (engine, state) = start(["lock"])
        state = engine.apply(.play(handIndex: 0, slot: 0), to: state).0
        state = engine.apply(.play(handIndex: try index("lock", state), slot: 0), to: state).0
        #expect(state.locked[0])
        state = engine.apply(.play(handIndex: 0, slot: 0), to: state).0
        #expect(!state.locked[0])
    }

    @Test func debugAnswersTheNextGuessPerSlotForItsAlarm() throws {
        var hidden = server
        hidden.feedback = .hits
        var (engine, state) = start(["debug"], server: hidden)
        state = engine.apply(.use(handIndex: try index("debug", state)), to: state).0
        let amount = content.card("debug")?.amount ?? 0
        #expect(engine.nextGuessCost(state) == hidden.alarmPerGuess + amount)
        state = engine.apply(.guess, to: state).0
        #expect(state.guesses[0].style == .slots)
        #expect(state.guesses[0].feedback.marks != nil)
        #expect(state.debugAlarm == nil)
    }

    @Test func spoofCutsTheNextGuessToItsPercent() throws {
        var (engine, state) = start(["spoof"])
        state = engine.apply(.use(handIndex: try index("spoof", state)), to: state).0
        let percent = content.card("spoof")?.amount ?? 100
        state = engine.apply(.guess, to: state).0
        #expect(state.alarm == server.alarmPerGuess * percent / 100)
        #expect(state.spoofPercent == nil)
    }

    @Test func shiftMovesTheWholeBoardOneSlotRight() throws {
        var (engine, state) = start(["shift"])
        state = engine.apply(.play(handIndex: 0, slot: 0), to: state).0
        let card = state.board[0]
        state = engine.apply(.use(handIndex: try index("shift", state)), to: state).0
        #expect(state.board[1] == card)
        #expect(state.board[0] == nil)
    }

    @Test func overclockAddsEnergyNowAndTakesItsPenaltyNextTurn() throws {
        var crack = content
        crack.energy = 3
        let engine = CrackEngine(content: crack)
        var state = engine.start(seed: 6, server: server, deck: crack.starterDeck + ["overclock"]).0
        let card = try #require(crack.card("overclock"))
        state = engine.apply(.use(handIndex: try index("overclock", state)), to: state).0
        #expect(state.energy == 3 - (card.cost ?? 0) + (card.amount ?? 0))
        state = engine.apply(.guess, to: state).0
        #expect(state.energy == 3 - (card.penalty ?? 0))
    }

    @Test func aSlotCardMustBePlayedOnASlotAndASelfCardMustNot() throws {
        let (engine, state) = start(["shift", "probe"])
        #expect(
            engine.apply(.play(handIndex: try index("shift", state), slot: 0), to: state).1 == [.rejected(.needsNoSlot)]
        )
        #expect(engine.apply(.use(handIndex: try index("probe", state)), to: state).1 == [.rejected(.needsSlot)])
    }

    @Test func factsHoldForTheCodesTheyDescribe() {
        #expect(CrackFact.contains(symbol: "A", true).holds(for: ["A", "K"]))
        #expect(!CrackFact.contains(symbol: "A", true).holds(for: ["E", "K"]))
        #expect(CrackFact.count(symbol: "K", 2).holds(for: ["K", "A", "K"]))
        #expect(!CrackFact.count(symbol: "K", 1).holds(for: ["K", "A", "K"]))
    }
}
