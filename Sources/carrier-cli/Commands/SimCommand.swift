import ArgumentParser
import CarrierCore
import CarrierSim
import CarrierTerminal

/// `carrier sim`: many headless contracts with one bot, to sanity-check
/// tuning between human playtests (M4).
struct SimCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sim",
        abstract: "Play many contracts with a bot and report how they ended."
    )

    @OptionGroup var seedOption: SeedOption
    @OptionGroup var contentOptions: ContentOptions
    @OptionGroup var objectiveOption: ObjectiveOption
    @OptionGroup var ruleOptions: RuleOptions

    @Option(name: .long, help: "A flag to compare: play the same seeds with it on and off, and report the difference.")
    var compare: String?

    @Option(name: .long, help: "How many contracts to play.")
    var runs = 100

    @Option(name: .long, help: "greedy, ghost (greedy but quiet) or random.")
    var bot = "greedy"

    @Option(name: .long, help: "Actions before a contract counts as stalled.")
    var limit = 5000

    func run() throws {
        let makeBot: (UInt64) -> any ContractBot
        switch bot.lowercased() {
        case "greedy": makeBot = { _ in GreedyBot() }
        case "ghost": makeBot = { _ in GreedyBot(quiet: true) }
        case "random": makeBot = { RandomBot(seed: $0) }
        default: throw ValidationError("--bot: \"\(bot)\" is not greedy, ghost or random")
        }
        guard runs >= 1 else { throw ValidationError("--runs must be at least 1") }
        let content = try contentOptions.load()
        let seed = try seedOption.resolve()
        let objective = try objectiveOption.resolve(content)
        let style = Phosphor.forStandardOutput()
        if let compare {
            guard let flag = MechanicFlag.named(compare) else {
                let known = MechanicFlag.allCases.map(\.rawValue).joined(separator: ", ")
                throw ValidationError("--compare: \"\(compare)\" is not one of \(known)")
            }
            func simulation(_ isOn: Bool) throws -> Simulation {
                let rules = try ruleOptions.compose(
                    content: content, objective: objective, extra: [FlagSetting(flag, isOn)])
                return Simulation(content: content, objective: objective, rules: rules, actionLimit: limit)
            }
            let comparison = try FlagComparison.run(
                flag, on: try simulation(true), off: try simulation(false), runs: runs, seed: seed, makeBot: makeBot)
            Output.write(style.screen(ComparisonReadout.lines(comparison)) + "\n")
            return
        }
        let rules = try ruleOptions.compose(content: content, objective: objective)
        let simulation = Simulation(content: content, objective: objective, rules: rules, actionLimit: limit)
        let report = try simulation.run(runs: runs, seed: seed, makeBot: makeBot)
        var lines = SimReadout.lines(report, content: content)
        let changed = RulesReadout.changedFlags(rules, from: RuleSet.defaults(content: content, objective: objective))
        if !changed.isEmpty {
            lines.insert(contentsOf: Columns.wrap("RULES: " + changed), at: 3)
        }
        Output.write(style.screen(lines) + "\n")
    }
}
