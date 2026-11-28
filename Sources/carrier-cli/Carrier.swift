import ArgumentParser
import CarrierCore

@main
struct Carrier: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "carrier",
        abstract: "NO CARRIER: a hacking deckbuilder on a green-phosphor terminal.",
        version: CarrierVersion.current,
        subcommands: [
            PlayCommand.self, FightCommand.self, GenCommand.self, SimCommand.self, RulesCommand.self,
            ReplayCommand.self, MCPCommand.self, CrackCommand.self,
        ]
    )
}
