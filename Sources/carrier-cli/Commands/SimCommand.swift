import ArgumentParser
import CarrierCore
import CarrierSim

/// `carrier sim`: many headless contracts with one bot, to sanity-check
/// tuning between human playtests (M4).
struct SimCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sim",
        abstract: "Play many contracts with a bot and report how they ended."
    )

    @OptionGroup var seedOption: SeedOption
    @OptionGroup var contentOptions: ContentOptions

    @Option(name: .long, help: "How many contracts to play.")
    var runs = 100

    @Option(name: .long, help: "greedy or random.")
    var bot = "greedy"

    @Option(name: .long, help: "Actions before a contract counts as stalled.")
    var limit = 5000

    func run() throws {
        let makeBot: (UInt64) -> any ContractBot
        switch bot.lowercased() {
        case "greedy": makeBot = { _ in GreedyBot() }
        case "random": makeBot = { RandomBot(seed: $0) }
        default: throw ValidationError("--bot: \"\(bot)\" is not greedy or random")
        }
        guard runs >= 1 else { throw ValidationError("--runs must be at least 1") }
        let content = try contentOptions.load()
        let seed = try seedOption.resolve()
        let report = try Simulation(content: content, actionLimit: limit).run(runs: runs, seed: seed, makeBot: makeBot)
        let style = Phosphor.forStandardOutput()
        Output.write(style.screen(SimReadout.lines(report, content: content)) + "\n")
    }
}
