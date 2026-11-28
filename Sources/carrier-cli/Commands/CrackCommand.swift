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
        name: .long,
        help: "One server, by id (see crack.json), instead of the run. With --sim and none: every server.")
    var server: String?

    @Option(name: .long, help: "With --sim: add this card to the starter deck. Repeat for more.")
    var with: [String] = []

    @Flag(name: .long, help: "With --sim: what each reward card is worth, per server.")
    var values = false

    @Flag(name: .long, help: "Read whole lines and print plain frames, even on a terminal.")
    var plain = false

    func run() throws {
        let content = try contentOptions.load()
        guard var crack = content.crack else { throw ValidationError("content: crack.json is missing") }
        let seed = try seedOption.resolve()
        var servers = crack.run.servers.compactMap(crack.server)
        if let server {
            guard let found = crack.server(server.lowercased()) else {
                let known = crack.servers.map(\.id).joined(separator: ", ")
                throw ValidationError("--server: \"\(server)\" is not one of \(known)")
            }
            servers = [found]
        }
        if !with.isEmpty && (sim == nil || values) {
            throw ValidationError("--with needs --sim, and does not go with --values")
        }
        for card in with where crack.card(card.lowercased()) == nil {
            throw ValidationError("--with: no card \"\(card)\"")
        }
        if let sim {
            guard sim >= 1 else { throw ValidationError("--sim must be at least 1") }
            let deck = crack.starterDeck + with.map { $0.lowercased() }
            let lines =
                values
                ? Self.values(crack, servers: servers, runs: sim, seed: seed)
                : servers.flatMap { server in
                    let report = CrackSimulation(content: crack, server: server, deck: deck).run(runs: sim, seed: seed)
                    return Self.readout(report, server: server, seed: seed) + [""]
                }
            Output.write(Phosphor.forStandardOutput().screen(lines) + "\n")
            return
        }
        // One server is a run of one.
        crack.run.servers = servers.map(\.id)
        var session = CrackSession(engine: CrackRunEngine(content: crack), seed: seed)

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
            "CARDS PLAYED \(report.cardsPlayed)  HOLDS \(report.holds)",
            "CRACKED WITHIN N GUESSES:",
        ]
        for guesses in stride(from: 1, through: report.guessLimit, by: 1) {
            let count = report.byGuesses[guesses]
            lines.append("  \(guesses < 10 ? " " : "")\(guesses)  \(count)  (\(report.percentWithin(guesses))% BY NOW)")
        }
        return lines
    }

    /// Each reward card added to the starter deck alone: the bot's win rate
    /// with it, against none, per server.
    static func values(_ crack: CrackContent, servers: [CrackServer], runs: Int, seed: UInt64) -> [String] {
        var lines = ["CARD VALUES: \(runs) RUNS, SEED \(Seed.display(seed))", "WIN % WITH THE CARD ADDED, PER SERVER"]
        lines.append("CARD      " + servers.map { String($0.id.prefix(6)).uppercased().padding(7) }.joined())
        func rates(_ deck: [String]) -> [Int] {
            servers.map {
                CrackSimulation(content: crack, server: $0, deck: deck).run(runs: runs, seed: seed).cracked * 100 / runs
            }
        }
        let base = rates(crack.starterDeck)
        lines.append("(NONE)    " + base.map { "\($0)%".padding(7) }.joined())
        var pool: [String] = []
        for card in crack.run.rewardPool where !pool.contains(card) { pool.append(card) }
        for card in pool {
            let label = (crack.card(card)?.label ?? card).padding(10)
            let rows = zip(rates(crack.starterDeck + [card]), base).map { rate, none in
                let delta = rate - none
                return (delta >= 0 ? "+\(delta)" : "\(delta)").padding(7)
            }
            lines.append(label + rows.joined())
        }
        return lines
    }
}

extension String {
    fileprivate func padding(_ width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
