public import CarrierCore
public import CarrierGen

/// Plays many contracts headless with one bot (M4). Run `i` uses the
/// network and contract seed `Seed.derive(seed, "run/i")`, so the same seed
/// gives the same report, and run `i` can be replayed on its own.
public struct Simulation: Sendable {
    public let content: ContentPack
    public let objective: ObjectiveDefinition
    /// The rules every contract runs under (addendum 02, §1).
    public let rules: RuleSet
    /// A contract that has not ended after this many actions is `stalled`.
    public var actionLimit: Int

    /// A simulation under `rules`, or the objective's default rules.
    public init(content: ContentPack, objective: ObjectiveDefinition, rules: RuleSet? = nil, actionLimit: Int = 5000) {
        self.content = content
        self.objective = objective
        self.rules = rules ?? RuleSet.defaults(content: content, objective: objective)
        self.actionLimit = actionLimit
    }

    public static func runSeed(_ seed: UInt64, run: Int) -> UInt64 {
        Seed.derive(seed, "run/\(run)")
    }

    public func run(
        runs: Int, seed: UInt64, makeBot: (UInt64) -> any ContractBot
    ) throws(GenerationError) -> SimulationReport {
        let engine = ContractEngine(content: content)
        let generator = NetworkGenerator(content: content)
        var report = SimulationReport(
            bot: makeBot(seed).name, objective: objective.id, seed: seed,
            rewardPool: rules.tuning.network.rewardPool, upgrades: rules.tuning.network.dataUpgrades)
        for index in 0..<max(0, runs) {
            let runSeed = Self.runSeed(seed, run: index)
            let network = try generator.generate(seed: runSeed)
            var (state, events) = engine.start(seed: runSeed, network: network, objective: objective, rules: rules)
            var highest = state.alertState
            var bot = makeBot(runSeed)
            var actions = 0
            record(events, state: state, into: &report)
            while state.outcome == nil && actions < actionLimit {
                let before = state
                (state, events) = engine.apply(bot.choose(state, engine: engine), to: state)
                actions += 1
                record(events, state: before, into: &report)
                highest = max(highest, state.alertState)
                if let outcome = state.outcome, outcome != .won,
                    case .fight(let node, _, _) = before.phase, before.network.nodes[node].type == .root
                {
                    report.endedAtRoot += 1
                }
            }
            finish(state, actions: actions, into: &report)
            if let index = AlertState.allCases.firstIndex(of: highest) {
                report.highestAlert[index] += 1
            }
        }
        return report
    }

    private func record(_ events: [ContractEvent], state: ContractState, into report: inout SimulationReport) {
        var offeredNow: [String] = []
        if case .reward(_, let choices) = state.phase { offeredNow = choices }
        for event in events {
            switch event {
            case .fightStarting(let node, _):
                report.fights += 1
                if state.network.nodes[node].type == .root { report.rootAttempts += 1 }
            case .nodeLeft: report.logouts += 1
            case .nodeCaptured(let node):
                if let type = NodeType.allCases.firstIndex(of: state.network.nodes[node].type) {
                    report.capturesByType[type] += 1
                }
            case .rewardOffered(let ids):
                for id in ids {
                    if let index = report.rewardPool.firstIndex(of: id) { report.offered[index] += 1 }
                }
            case .cardAdded(let id) where offeredNow.contains(id):
                if let index = report.rewardPool.firstIndex(of: id) { report.taken[index] += 1 }
            case .upgradeChosen(let upgrade):
                if let index = report.upgrades.firstIndex(of: upgrade) { report.upgradePicks[index] += 1 }
            default: break
            }
        }
    }

    private func finish(_ state: ContractState, actions: Int, into report: inout SimulationReport) {

        let ending: SimulationReport.Ending =
            switch state.outcome {
            case .won: .won
            case .flatlined: .flatlined
            case .traced: .traced
            case .entryLost: .entryLost
            case .jackedOut: .jackedOut
            case nil: .stalled
            }
        if let index = SimulationReport.Ending.allCases.firstIndex(of: ending) {
            report.endings[index] += 1
        }
        if let payout = state.payout, let index = PayoutTier.allCases.firstIndex(of: payout) {
            report.payouts[index] += 1
        }
        report.runs += 1
        report.totalTraceAtEnd += state.trace
        report.totalTicks += state.tick
        report.totalActions += actions
    }
}
