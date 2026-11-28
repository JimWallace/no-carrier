import ArgumentParser
import CarrierCore
import CarrierGen
import CarrierTerminal
import Foundation

/// `carrier fight`: one node fight against a generated machine (M2).
struct FightCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fight",
        abstract: "Play one node fight against a generated machine.",
        discussion: """
            Play a card with its number key, or type its name (Tab completes) and press Return. \
            END ends the turn, LOGOUT leaves the node, HELP lists the hand, QUIT abandons the session.
            """
    )

    @OptionGroup var seedOption: SeedOption
    @OptionGroup var contentOptions: ContentOptions

    @Option(name: .long, help: "The machine: neutral, sysop or root.")
    var role = "neutral"

    @Option(
        name: .long,
        help: "PAYLOAD cards to add to the starter deck. Default: from tuning.json when the machine has a KERNEL.")
    var payload: Int?

    @Option(name: .long, help: "Write a replay of this session to this file, for a bug report.")
    var record: String?

    @Flag(name: .long, help: "Read whole lines and print plain frames, even on a terminal.")
    var plain = false

    func run() throws {
        guard let machineRole = NodeRole(rawValue: role.lowercased()) else {
            throw ValidationError("--role: \"\(role)\" is not neutral, sysop or root")
        }
        let content = try contentOptions.load()
        let seed = try seedOption.resolve()
        let setup = try SandboxFight.setup(seed: seed, role: machineRole, payload: payload, content: content)
        // The sandbox has no contract, so it runs under the base rules.
        let rules = RuleSet.defaults(content: content, objective: nil)
        let replay = FightReplay(
            carrierVersion: CarrierVersion.current, seed: seed, role: machineRole, payload: payload, rules: rules)
        var session = FightSession(
            engine: Engine(content: content), setup: setup, rules: rules, replay: replay,
            recordURL: record.map { URL(fileURLWithPath: $0) }
        )
        try session.start()

        let style = Phosphor.forStandardOutput()
        if let terminal = plain ? nil : RawTerminal() {
            try FightLoop.interactive(&session, terminal: terminal)
            // The alternate screen is gone; leave the last frame on the
            // normal one, with the banner under it.
            let final = FightScreen(session: session, style: style).lines(prompt: nil, hint: "")
            Output.write(style.screen(final + [""] + FightLoop.banner(for: session, command: self)) + "\n")
        } else {
            try FightLoop.lines(&session)
            Output.write(style.screen([""] + FightLoop.banner(for: session, command: self)) + "\n")
        }
    }
}

/// Writes to standard output at once, unbuffered.
enum Output {
    static func write(_ text: String) {
        FileHandle.standardOutput.write(Data(text.utf8))
    }
}
