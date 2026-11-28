import CarrierCore
import CarrierGen
import CarrierSim
import TestSupport
import Testing

/// `carrier sim --compare` and `--flag` (addendum 02, §1).
@Suite struct FlagComparisonTests {
    let content: ContentPack
    let infiltrate: ObjectiveDefinition

    init() throws {
        content = try BundledContent.load()
        infiltrate = try #require(content.objective("infiltrate"))
    }

    func rules(_ settings: FlagSetting...) throws -> RuleSet {
        try RuleSet.compose(content: content, objective: infiltrate, overrides: settings)
    }

    func report(_ rules: RuleSet) throws -> SimulationReport {
        try Simulation(content: content, objective: infiltrate, rules: rules)
            .run(runs: 20, seed: 1994, makeBot: { _ in GreedyBot(quiet: true) })
    }

    @Test func theDefaultRulesGiveTheSameReportAsBefore() throws {
        let plain = try Simulation(content: content, objective: infiltrate)
            .run(runs: 20, seed: 1994, makeBot: { _ in GreedyBot(quiet: true) })
        #expect(try report(RuleSet.defaults(content: content, objective: infiltrate)) == plain)
    }

    @Test func aComparisonPlaysTheSameSeedsOnAndOff() throws {
        let on = try rules(FlagSetting(.fog, true))
        let off = try rules(FlagSetting(.fog, false))
        let comparison = try FlagComparison.run(
            .fog, on: Simulation(content: content, objective: infiltrate, rules: on),
            off: Simulation(content: content, objective: infiltrate, rules: off), runs: 20, seed: 1994,
            makeBot: { _ in GreedyBot(quiet: true) })
        #expect(comparison.on == (try report(on)))
        #expect(comparison.off == (try report(off)))
        #expect(comparison.on.seed == comparison.off.seed)
        #expect(comparison.on.runs == 20 && comparison.off.runs == 20)
    }

    /// Each bot only sends actions the engine accepts, with a flag off.
    @Test(arguments: [MechanicFlag.scan, .jackOut, .alert, .ghost, .fog, .revoke])
    func botsStayLegalWithAFlagOff(flag: MechanicFlag) throws {
        let off = try RuleSet.compose(
            content: content, objective: infiltrate, overrides: [FlagSetting(flag, false)], unsafe: true)
        let engine = ContractEngine(content: content)
        let bots: [(UInt64) -> any ContractBot] = [
            { _ in GreedyBot() }, { _ in GreedyBot(quiet: true) }, { RandomBot(seed: $0) },
        ]
        for makeBot in bots {
            for seed in UInt64(0)..<4 {
                let network = try NetworkGenerator(content: content).generate(seed: seed)
                var state = engine.start(seed: seed, network: network, objective: infiltrate, rules: off).0
                var bot = makeBot(seed)
                var actions = 0
                while state.outcome == nil && actions < 3000 {
                    let action = bot.choose(state, engine: engine)
                    #expect(engine.rejection(for: action, in: state) == nil, "\(flag) seed \(seed): \(action)")
                    state = engine.apply(action, to: state).0
                    actions += 1
                }
                #expect(state.outcome != nil)
            }
        }
    }
}
