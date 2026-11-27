import ArgumentParser
import CarrierCore
import CarrierGen

/// `carrier gen`: print generated machines, to check the procgen flavour.
struct GenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gen",
        abstract: "Print generated machines and their filesystems."
    )

    @OptionGroup var seedOption: SeedOption
    @OptionGroup var contentOptions: ContentOptions

    @Option(name: .long, help: "How many machines to print.")
    var count = 5

    @Option(name: .long, help: "neutral, sysop or root. Without it, the roles alternate.")
    var role: String?

    func run() throws {
        let fixedRole = try role.map { name in
            guard let value = NodeRole(rawValue: name.lowercased()) else {
                throw ValidationError("--role: \"\(name)\" is not neutral, sysop or root")
            }
            return value
        }
        let content = try contentOptions.load()
        let seed = try seedOption.resolve()
        let generator = MachineGenerator(content: content)
        let style = Phosphor.forStandardOutput()
        var lines = ["NO CARRIER GEN  SEED \(Seed.display(seed))", ""]
        for index in 0..<max(0, count) {
            let machineRole = fixedRole ?? NodeRole.allCases[index % NodeRole.allCases.count]
            let machineSeed = Seed.derive(seed, "gen/\(index)")
            let machine = try generator.generate(seed: machineSeed, role: machineRole)
            lines += MachineReadout.lines(for: machine, content: content)
            lines.append("")
        }
        print(style.screen(lines))
    }
}
