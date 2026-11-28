import ArgumentParser
import CarrierCore
import CarrierSim
import CarrierTerminal

/// `carrier crack`: the code-cracking prototype (addendum 03). One lock, no
/// map, no rewards: is matching a hidden code with cards fun?
struct CrackCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "crack",
        abstract: "Crack one hidden code with your cards (prototype).",
        discussion: """
            Put cards from your hand on the board, then GUESS. HIT: right symbol in the right slot. \
            NEAR: right symbol in the wrong slot. 1 3 puts hand card 1 in slot 3; S 1 2 swaps slots; \
            D 1 drops a card; HELP lists the rest.
            """
    )

    @OptionGroup var seedOption: SeedOption
    @OptionGroup var contentOptions: ContentOptions

    @Option(name: .long, help: "Play this many cracks with a bot instead, and report how they went.")
    var sim: Int?

    @Option(
        name: .long, help: "The server, by id (see crack.json). Default: the first. With --sim and none: every one.")
    var server: String?

    @Flag(name: .long, help: "Read whole lines and print plain frames, even on a terminal.")
    var plain = false

    func run() throws {
        let content = try contentOptions.load()
        guard let crack = content.crack else { throw ValidationError("content: crack.json is missing") }
        let seed = try seedOption.resolve()
        var servers = crack.servers
        if let server {
            guard let found = crack.server(server.lowercased()) else {
                let known = crack.servers.map(\.id).joined(separator: ", ")
                throw ValidationError("--server: \"\(server)\" is not one of \(known)")
            }
            servers = [found]
        }
        if let sim {
            guard sim >= 1 else { throw ValidationError("--sim must be at least 1") }
            var lines: [String] = []
            for server in servers {
                let report = CrackSimulation(content: crack, server: server).run(runs: sim, seed: seed)
                lines += Self.readout(report, server: server, seed: seed) + [""]
            }
            Output.write(Phosphor.forStandardOutput().screen(lines) + "\n")
            return
        }
        guard let first = servers.first else { throw ValidationError("content: crack.json has no servers") }
        var session = CrackSession(engine: CrackEngine(content: crack), seed: seed, server: first)

        let style = Phosphor.forStandardOutput()
        if let terminal = plain ? nil : RawTerminal() {
            CrackLoop.interactive(&session, terminal: terminal)
            let final = CrackScreen(session: session, style: style).lines(prompt: nil, hint: "")
            Output.write(style.screen(final + [""] + CrackLoop.banner(for: session)) + "\n")
        } else {
            CrackLoop.lines(&session)
            Output.write(style.screen([""] + CrackLoop.banner(for: session)) + "\n")
        }
    }

    /// The bot report, one line a fact.
    static func readout(_ report: CrackReport, server: CrackServer, seed: UInt64) -> [String] {
        var lines = [
            "\(server.name): \(report.runs) RUNS, SEED \(Seed.display(seed))",
            "CRACKED \(report.cracked)  TRACED \(report.traced)",
            "GUESSES ALLOWED \(report.guessLimit)",
            "MEAN GUESSES \(report.meanGuessesTenths / 10).\(report.meanGuessesTenths % 10)",
            "PROBES PLAYED \(report.probes)",
            "CRACKED WITHIN N GUESSES:",
        ]
        for guesses in stride(from: 1, through: report.guessLimit, by: 1) {
            let count = report.byGuesses[guesses]
            lines.append("  \(guesses < 10 ? " " : "")\(guesses)  \(count)  (\(report.percentWithin(guesses))% BY NOW)")
        }
        return lines
    }
}
