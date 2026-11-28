import ArgumentParser
import CarrierCore
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

    @Flag(name: .long, help: "Read whole lines and print plain frames, even on a terminal.")
    var plain = false

    func run() throws {
        let content = try contentOptions.load()
        guard let crack = content.crack else { throw ValidationError("content: crack.json is missing") }
        let seed = try seedOption.resolve()
        var session = CrackSession(engine: CrackEngine(content: crack), seed: seed)

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
}
