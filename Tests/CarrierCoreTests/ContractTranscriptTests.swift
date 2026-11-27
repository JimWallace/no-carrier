import CarrierCore
import CarrierGen
import Foundation
import TestSupport
import Testing

/// The contract golden transcript: a fixed seed and the greedy bot give an
/// event log that must match the stored snapshot (CLAUDE.md, "Testing
/// Conventions").
@Suite struct ContractTranscriptTests {
    let content: ContentPack
    let engine: ContractEngine

    init() throws {
        content = try BundledContent.load()
        engine = ContractEngine(content: content)
    }

    func start(seed: UInt64) throws -> (ContractState, [ContractEvent]) {
        let network = try NetworkGenerator(content: content).generate(seed: seed)
        return engine.start(seed: seed, network: network)
    }

    @Test func transcriptMatchesTheSnapshot() throws {
        let (initial, opening) = try start(seed: 1994)
        let (final, actions, events) = GreedyContractBot(engine: engine).play(initial)
        var lines = ["SEED \(Seed.display(1994)) MAP \(initial.network.templateID)", "ACTIONS \(actions.count)"]
        lines += (opening + events).map { $0.line(content: content) }
        lines.append("OUTCOME \(final.outcome?.rawValue ?? "none") TICK \(final.tick) TRACE \(final.trace)")
        let outcome = try Snapshot.compare(lines.joined(separator: "\n"), named: "contract-1994")
        #expect(outcome == .matches, "\(outcome.message)")
    }

    @Test func replayingTheActionsReproducesTheContract() throws {
        let (initial, _) = try start(seed: 31)
        let (final, actions, _) = GreedyContractBot(engine: engine).play(initial)
        var state = try start(seed: 31).0
        for action in actions {
            state = engine.apply(action, to: state).0
        }
        #expect(state == final)
    }

    @Test func contractStateAndReplayRoundTripThroughJSON() throws {
        let (initial, _) = try start(seed: 8)
        let (state, actions, _) = GreedyContractBot(engine: engine).play(initial, limit: 25)
        #expect(try JSONDecoder().decode(ContractState.self, from: JSONEncoder().encode(state)) == state)
        let replay = ContractReplay(carrierVersion: CarrierVersion.current, seed: 8, actions: actions)
        #expect(try JSONDecoder().decode(ContractReplay.self, from: JSONEncoder().encode(replay)) == replay)
    }

    /// Not a balance test: it shows how the simplest bot fares, so a
    /// tuning change that makes contracts trivial or impossible is visible.
    @Test func greedyBotOutcomesAcrossSeeds() throws {
        var outcomes: [String: Int] = [:]
        for seed in 0..<40 {
            let (initial, _) = try start(seed: UInt64(seed))
            let (final, _, _) = GreedyContractBot(engine: engine).play(initial)
            outcomes[final.outcome?.rawValue ?? "none", default: 0] += 1
        }
        let summary = outcomes.keys.sorted().map { "\($0) \(outcomes[$0] ?? 0)" }.joined(separator: ", ")
        print("GREEDY BOT OVER 40 SEEDS: \(summary)")
        #expect(outcomes["none"] == nil, "a contract that never ends: \(summary)")
    }
}
