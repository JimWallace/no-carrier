import CarrierCore
import CarrierGen
import Foundation
import TestSupport
import Testing

/// Kickoff §8, "Golden-transcript tests": a fixed seed and a fixed way of
/// choosing actions give an event log that must match the stored snapshot.
///
/// A rule or content change that alters the log regenerates the snapshot
/// (CLAUDE.md, "Testing Conventions"). A change with neither is a
/// determinism bug.
@Suite struct GoldenTranscriptTests {
    let content: ContentPack
    let engine: Engine

    init() throws {
        content = try BundledContent.load()
        engine = Engine(content: content)
    }

    /// Plays the first playable card until none is left, then ends the turn.
    /// Deterministic, so the action list it produces is fixed for a seed.
    func greedyGame(seed: UInt64, role: NodeRole, maxActions: Int = 200) throws -> (GameState, [Action], [Event]) {
        let setup = try SandboxFight.setup(seed: seed, role: role, content: content)
        var (state, events) = engine.startFight(setup, rules: RuleSet.defaults(content: content, objective: nil))
        var actions: [Action] = []
        while !state.fight.isOver && actions.count < maxActions {
            let playable = state.fight.hand.indices.first {
                engine.rejection(forPlaying: $0, in: state.fight, rules: state.rules) == nil
            }
            let action = playable.map { Action.play(handIndex: $0) } ?? .endTurn
            actions.append(action)
            let result = engine.apply(action, to: state)
            state = result.0
            events += result.1
        }
        return (state, actions, events)
    }

    @Test(arguments: [(UInt64(1994), NodeRole.neutral), (UInt64(2600), NodeRole.sysop)])
    func transcriptMatchesTheSnapshot(seed: UInt64, role: NodeRole) throws {
        let (state, actions, events) = try greedyGame(seed: seed, role: role)
        var lines = ["SEED \(Seed.display(seed)) ROLE \(role.label)", "ACTIONS \(actions.count)"]
        lines += events.map { $0.line(content: content) }
        lines.append("OUTCOME \(state.fight.outcome?.rawValue ?? "none")")
        let outcome = try Snapshot.compare(lines.joined(separator: "\n"), named: "transcript-\(role.rawValue)-\(seed)")
        #expect(outcome == .matches, "\(outcome.message)")
    }

    @Test func replayingTheActionsReproducesTheGame() throws {
        let (finalState, actions, events) = try greedyGame(seed: 77, role: .neutral)
        let setup = try SandboxFight.setup(seed: 77, role: .neutral, content: content)
        var (state, replayed) = engine.startFight(setup, rules: RuleSet.defaults(content: content, objective: nil))
        for action in actions {
            let result = engine.apply(action, to: state)
            state = result.0
            replayed += result.1
        }
        #expect(state == finalState)
        #expect(replayed == events)
    }

    @Test func aReplayFileRoundTrips() throws {
        let replay = FightReplay(
            carrierVersion: CarrierVersion.current, seed: 9, role: .sysop,
            actions: [.play(handIndex: 2), .endTurn, .logout]
        )
        let data = try JSONEncoder().encode(replay)
        #expect(try JSONDecoder().decode(FightReplay.self, from: data) == replay)
    }

    @Test func gameStateRoundTripsThroughJSON() throws {
        let (state, _, _) = try greedyGame(seed: 5, role: .sysop, maxActions: 7)
        let data = try JSONEncoder().encode(state)
        #expect(try JSONDecoder().decode(GameState.self, from: data) == state)
    }
}
