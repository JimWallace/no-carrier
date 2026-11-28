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
        let simulation = Simulation(
            content: content, objective: try objectiveOption.resolve(content), actionLimit: limit)
        let report = try simulation.run(runs: runs, seed: seed, makeBot: makeBot)
        let style = Phosphor.forStandardOutput()
        Output.write(style.screen(SimReadout.lines(report, content: content)) + "\n")
    }
}
