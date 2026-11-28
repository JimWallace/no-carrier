import CarrierCore
import CarrierGen
import CarrierSim
import TestSupport
import Testing

@Suite struct SimulationTests {
    let content: ContentPack
    let engine: ContractEngine
    let objective: ObjectiveDefinition

    init() throws {
        content = try BundledContent.load()
        engine = ContractEngine(content: content)
        objective = try #require(content.objective("takeover"))
    }

    /// Plays whole contracts and checks every action the bot sends is one
    /// the engine accepts, and that every contract ends.
    func check(_ makeBot: (UInt64) -> any ContractBot, seeds: Range<Int>) throws {
        for seed in seeds {
            let runSeed = UInt64(seed)
            var (state, _) = engine.start(
                seed: runSeed, network: try NetworkGenerator(content: content).generate(seed: runSeed),
                objective: objective)
            var bot = makeBot(runSeed)
            var actions = 0
            while state.outcome == nil && actions < 5000 {
                let action = bot.choose(state, engine: engine)
                #expect(engine.rejection(for: action, in: state) == nil, "seed \(seed): \(action) in \(state.phase)")
                state = engine.apply(action, to: state).0
                actions += 1
            }
            #expect(state.outcome != nil, "seed \(seed) did not end")
        }
    }

    @Test func greedyBotOnlySendsLegalActions() throws {
        try check({ _ in GreedyBot() }, seeds: 0..<25)
    }

    @Test func ghostBotOnlySendsLegalActions() throws {
        try check({ _ in GreedyBot(quiet: true) }, seeds: 0..<25)
    }

    @Test func randomBotOnlySendsLegalActions() throws {
        try check({ RandomBot(seed: $0) }, seeds: 0..<25)
    }

    @Test func legalActionsAreAllAccepted() throws {
        var (state, _) = engine.start(
            seed: 3, network: try NetworkGenerator(content: content).generate(seed: 3), objective: objective)
        var bot = RandomBot(seed: 3)
        for _ in 0..<200 where state.outcome == nil {
            let legal = LegalActions.list(state, engine: engine)
            #expect(!legal.isEmpty)
            #expect(legal.allSatisfy { engine.rejection(for: $0, in: state) == nil })
            state = engine.apply(bot.choose(state, engine: engine), to: state).0
        }
    }

    @Test func theSameSeedGivesTheSameReport() throws {
        let simulation = Simulation(content: content, objective: objective)
        let first = try simulation.run(runs: 20, seed: 1994) { _ in GreedyBot() }
        let second = try simulation.run(runs: 20, seed: 1994) { _ in GreedyBot() }
        #expect(first == second)
        let random = try simulation.run(runs: 20, seed: 1994) { RandomBot(seed: $0) }
        #expect(random == (try simulation.run(runs: 20, seed: 1994) { RandomBot(seed: $0) }))
    }

    @Test func theReportAddsUp() throws {
        let report = try Simulation(content: content, objective: objective).run(runs: 30, seed: 7) { _ in GreedyBot() }
        #expect(report.runs == 30)
        #expect(report.endings.reduce(0, +) == 30)
        #expect(zip(report.taken, report.offered).allSatisfy { $0 <= $1 })
        #expect(report.endedAtRoot <= report.rootAttempts)
        #expect(report.bot == "greedy")
    }

    @Test func aStalledContractIsCounted() throws {
        let report = try Simulation(content: content, objective: objective, actionLimit: 3).run(runs: 2, seed: 1) { _ in
            GreedyBot()
        }
        #expect(report.count(.stalled) == 2)
    }

    @Test func percentagesUseIntegerTenths() {
        #expect(SimulationReport.perMille(1, of: 3) == 333)
        #expect(SimulationReport.perMille(5, of: 0) == 0)
    }
}
