import ArgumentParser
import CarrierCore
import Foundation

/// `carrier rules`: prints the composed RuleSet for an objective (addendum
/// 02, §1): every flag, the layer that set it, and the tuning.
struct RulesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rules",
        abstract: "Print the rules a contract runs under: every flag and the tuning."
    )

    @OptionGroup var contentOptions: ContentOptions
    @OptionGroup var objectiveOption: ObjectiveOption
    @OptionGroup var ruleOptions: RuleOptions

    @Flag(name: .long, help: "Print the whole RuleSet as JSON, as a replay records it.")
    var json = false

    func run() throws {
        let content = try contentOptions.load()
        let objective = try objectiveOption.resolve(content)
        let rules = try ruleOptions.compose(content: content, objective: objective)
        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            Output.write((String(bytes: try encoder.encode(rules), encoding: .utf8) ?? "") + "\n")
            return
        }
        let layers = RuleSet.layers(
            content: content, objective: objective, ascension: ruleOptions.ascension,
            overrides: try ruleOptions.overrides())
        let style = Phosphor.forStandardOutput()
        Output.write(
            style.screen(
                RulesReadout.lines(
                    rules, layers: layers, objective: objective, ascension: ruleOptions.ascension, content: content))
                + "\n")
    }
}
