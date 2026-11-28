import CarrierCore
import TestSupport
import Testing

/// What makes servers differ (addendum 03, §6): the feedback style, the
/// alarm's escalation and the interference programs. One rule, one test.
@Suite struct CrackServerTests {
    let content: CrackContent
    let engine: CrackEngine

    init() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.starterDeck = crack.starterDeck.filter { crack.card($0)?.kind == .symbol }
        content = crack
        engine = CrackEngine(content: crack)
    }

    func server(_ id: String, _ change: (inout CrackServer) -> Void = { _ in }) throws -> CrackServer {
        var server = try #require(content.server(id))
        change(&server)
        return server
    }

    @Test func countsGiveHitsAndNear() {
        let feedback = CrackFeedback.score(guess: ["A", "K", "E", "K"], code: ["R", "K", "R", "A"], style: .counts)
        #expect(feedback == CrackFeedback(hits: 1, near: 1))
        #expect(feedback.text == "1 HIT 1 NEAR")
    }

    @Test func hitsHideTheNearCount() {
        let feedback = CrackFeedback.score(guess: ["A", "K", "E", "K"], code: ["R", "K", "R", "A"], style: .hits)
        #expect(feedback == CrackFeedback(hits: 1, near: nil))
        #expect(feedback.text == "1 HIT")
    }

    @Test func slotsMarkEachSlotAndNeverCountASymbolTwice() {
        let feedback = CrackFeedback.score(guess: ["A", "K", "A", "K"], code: ["R", "K", "R", "A"], style: .slots)
        #expect(feedback.marks == [.near, .hit, .miss, .miss])
        #expect(feedback.text == "N H - -")
        #expect(feedback.near == 1)
    }

    @Test func escalationRaisesEachGuessByMore() throws {
        let root = try server("root") { $0.interference = [] }
        var (state, _) = engine.start(seed: 4, server: root)
        state = engine.apply(.guess, to: state).0
        #expect(state.alarm == root.alarmPerGuess)
        state = engine.apply(.guess, to: state).0
        #expect(state.alarm == 2 * root.alarmPerGuess + root.escalation)
    }

    @Test func scrambleSwapsTwoSlotsOnItsTurn() throws {
        let corporate = try server("corporate") { $0.interference = [CrackInterference(kind: .scramble, every: 1)] }
        var (state, _) = engine.start(seed: 4, server: corporate)
        for slot in 0..<min(state.energy, state.board.count) {
            state = engine.apply(.play(handIndex: 0, slot: slot), to: state).0
        }
        let before = state.board
        let (after, events) = engine.apply(.guess, to: state)
        let swaps = events.compactMap { if case .scrambled(let a, let b) = $0 { (a, b) } else { nil } }
        let (first, second) = try #require(swaps.first)
        #expect(first != second)
        #expect(after.board[first] == before[second])
        #expect(after.board[second] == before[first])
    }

    @Test func rotateMovesTheCodeAndTheRevealedSlotsRight() throws {
        let root = try server("root") { $0.interference = [CrackInterference(kind: .rotate, every: 1)] }
        var withProbe = content
        withProbe.starterDeck = Array(repeating: "probe", count: 10)
        let engine = CrackEngine(content: withProbe)
        var (state, _) = engine.start(seed: 4, server: root)
        state = engine.apply(.play(handIndex: 0, slot: 0), to: state).0
        let code = state.code
        let (after, events) = engine.apply(.guess, to: state)
        #expect(events.contains(.rotated))
        #expect(after.code == [code[code.count - 1]] + code.dropLast())
        #expect(after.revealed[1] == code[0])
        #expect(after.rotations == [1])
    }

    @Test func aProgramActsOnlyOnItsTurn() throws {
        let corporate = try server("corporate") { $0.interference = [CrackInterference(kind: .scramble, every: 3)] }
        var (state, _) = engine.start(seed: 4, server: corporate)
        #expect(engine.turnsUntil(corporate.interference[0], in: state) == 2)
        for _ in 0..<2 {
            let (next, events) = engine.apply(.guess, to: state)
            #expect(!events.contains { if case .scrambled = $0 { true } else { false } })
            state = next
        }
        #expect(engine.turnsUntil(corporate.interference[0], in: state) == 0)
        #expect(engine.apply(.guess, to: state).1.contains { if case .scrambled = $0 { true } else { false } })
    }
}
