import ArgumentParser
import CarrierContent
import CarrierCore
import CarrierSim
import CarrierTerminal
import Testing

@testable import carrier_cli

/// `--flag`, `--unsafe`, `--ascension`, `carrier rules` and the comparison
/// readout (addendum 02, §1).
@Suite struct RuleCommandTests {
    let content: ContentPack
    let takeover: ObjectiveDefinition

    init() throws {
        content = try ContentLoader.loadBundled()
        takeover = try #require(content.objective("takeover"))
    }

    @Test func flagsComposeIntoTheRules() throws {
        let options = try RuleOptions.parse(["--flag", "fog=on", "--flag", "SCAN=off"])
        let rules = try options.compose(content: content, objective: takeover)
        #expect(rules.isOn(.fog))
        #expect(!rules.isOn(.scan))
    }

    @Test func aBadFlagIsRefused() throws {
        let options = try RuleOptions.parse(["--flag", "fog"])
        #expect(throws: ValidationError.self) { try options.compose(content: content, objective: takeover) }
    }

    @Test func aBrokenRequirementNeedsUnsafe() throws {
        let ghost = ["--flag", "ghost=on", "--flag", "revoke=off"]
        #expect(throws: ValidationError.self) {
            try RuleOptions.parse(ghost).compose(content: content, objective: takeover)
        }
        let rules = try RuleOptions.parse(ghost + ["--unsafe"]).compose(content: content, objective: takeover)
        #expect(rules.isOn(.ghost) && !rules.isOn(.revoke))
    }

    @Test func anyAscensionButZeroIsRefused() throws {
        #expect(throws: ValidationError.self) {
            try RuleOptions.parse(["--ascension", "1", "--unsafe"]).compose(content: content, objective: takeover)
        }
        #expect(throws: Never.self) {
            try RuleOptions.parse(["--ascension", "0"]).compose(content: content, objective: takeover)
        }
    }

    @Test func theRulesReadoutFitsFortyColumns() throws {
        let rules = RuleSet.defaults(content: content, objective: takeover)
        let lines = RulesReadout.lines(
            rules, layers: RuleSet.layers(content: content, objective: takeover), objective: takeover, ascension: 0,
            content: content)
        #expect(lines.allSatisfy { $0.count <= Columns.textWidth })
        #expect(lines.contains { $0.hasPrefix("GHOST") && $0.contains("OFF") && $0.contains("CONTRACT") })
    }

    @Test func theComparisonReadoutFitsFortyColumns() throws {
        let rules = RuleSet.defaults(content: content, objective: takeover)
        var off = rules
        off.flags[.alert] = false
        let comparison = try FlagComparison.run(
            .alert, on: Simulation(content: content, objective: takeover, rules: rules),
            off: Simulation(content: content, objective: takeover, rules: off), runs: 3, seed: 1,
            makeBot: { _ in GreedyBot() })
        let lines = ComparisonReadout.lines(comparison)
        #expect(lines.allSatisfy { $0.count <= Columns.textWidth })
        #expect(lines.contains { $0.hasPrefix("FLATLINED") })
    }
}
