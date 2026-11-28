import ArgumentParser
import CarrierCore
import CarrierGen
import Foundation

/// `carrier play`: one full contract (M3, the MVP).
struct PlayCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "play",
        abstract: "Play one contract: take the network node by node and capture ROOT.",
        discussion: """
            On the map, press a node number to attack it, or type ATTACK N, REINFORCE N, WAIT, SCAN N, DECK, \
            HELP or QUIT. In a fight, press a card number or type its name (Tab completes); END and LOGOUT.
            """
    )

    @OptionGroup var seedOption: SeedOption
    @OptionGroup var contentOptions: ContentOptions
    @OptionGroup var objectiveOption: ObjectiveOption

    @Option(name: .long, help: "Write a replay of this contract to this file, for a bug report.")
    var record: String?

    @Flag(name: .long, help: "Read whole lines and print plain frames, even on a terminal.")
    var plain = false

    func run() throws {
        let content = try contentOptions.load()
        let seed = try seedOption.resolve()
        let network = try NetworkGenerator(content: content).generate(seed: seed)
        var session = PlaySession(
            engine: ContractEngine(content: content), seed: seed, network: network,
            objective: try objectiveOption.resolve(content), recordURL: record.map { URL(fileURLWithPath: $0) })
        try session.start()

        let style = Phosphor.forStandardOutput()
        if let terminal = plain ? nil : RawTerminal() {
            try PlayLoop.interactive(&session, terminal: terminal)
            let final = session.screen(style: style, rows: 24, prompt: nil, hint: "")
            Output.write(style.screen(final + [""] + banner(session, seed: seed)) + "\n")
        } else {
            try PlayLoop.lines(&session)
            Output.write(style.screen([""] + banner(session, seed: seed)) + "\n")
        }
    }

    private func banner(_ session: PlaySession, seed: UInt64) -> [String] {
        var lines = session.banner
        if let record {
            lines += Columns.wrap("REPLAY: carrier replay \(record)")
        } else {
            lines += Columns.wrap(
                "AGAIN: carrier play --seed \(Seed.display(seed)) --objective \(session.state.objective.id)")
        }
        return lines
    }
}
