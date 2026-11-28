import CarrierCore
import TestSupport
import Testing

/// A golden transcript for the crack prototype: a fixed seed and a fixed
/// way of choosing actions give an event log that must match the snapshot.
@Suite struct CrackTranscriptTests {
    /// Fills empty slots left to right from the front of the hand, then
    /// guesses. Deterministic, so the actions for a seed are fixed.
    func play(seed: UInt64, engine: CrackEngine) -> (CrackState, [CrackAction], [CrackEvent]) {
        var (state, events) = engine.start(seed: seed)
        var actions: [CrackAction] = []
        while !state.isOver && actions.count < 200 {
            let empty = state.board.firstIndex { $0 == nil }
            var action = CrackAction.guess
            if let empty, !state.hand.isEmpty, engine.rejection(of: .play(handIndex: 0, slot: empty), in: state) == nil
            {
                action = .play(handIndex: 0, slot: empty)
            } else if empty == nil, let last = state.guesses.last, last.feedback.hits < 2,
                engine.rejection(of: .play(handIndex: 0, slot: state.turn % state.board.count), in: state) == nil
            {
                action = .play(handIndex: 0, slot: state.turn % state.board.count)
            }
            actions.append(action)
            let result = engine.apply(action, to: state)
            state = result.0
            events += result.1
        }
        return (state, actions, events)
    }

    @Test func transcriptMatchesTheSnapshot() throws {
        let engine = CrackEngine(content: try #require(try BundledContent.load().crack))
        let (state, actions, events) = play(seed: 1994, engine: engine)
        var lines = [
            "SEED \(Seed.display(1994))", "CODE \(state.code.joined(separator: " "))", "ACTIONS \(actions.count)",
        ]
        lines += events.map(\.line)
        lines.append("OUTCOME \(state.outcome?.rawValue ?? "none")")
        let outcome = try Snapshot.compare(lines.joined(separator: "\n"), named: "crack-1994")
        #expect(outcome == .matches, "\(outcome.message)")
    }

    @Test func replayingTheActionsReproducesTheCrack() throws {
        let engine = CrackEngine(content: try #require(try BundledContent.load().crack))
        let (final, actions, events) = play(seed: 77, engine: engine)
        var (state, replayed) = engine.start(seed: 77)
        for action in actions {
            let result = engine.apply(action, to: state)
            state = result.0
            replayed += result.1
        }
        #expect(state == final)
        #expect(replayed == events)
    }
}
