import CarrierCore
import Foundation
import TestSupport
import Testing

/// Addendum 02, §1: the RuleSet, its layers and its checks.
@Suite struct RuleSetTests {
    let content: ContentPack

    init() throws {
        content = try BundledContent.load()
    }

    func objective(_ id: String) throws -> ObjectiveDefinition {
        try #require(content.objective(id))
    }

    func on(_ rules: RuleSet) -> [MechanicFlag] {
        rules.flags.on
    }

    @Test func theDefaultsMatchEachObjective() throws {
        let takeover = RuleSet.defaults(content: content, objective: try objective("takeover"))
        #expect(on(takeover) == [.alert, .revoke, .scan, .jackOut])
        let infiltrate = RuleSet.defaults(content: content, objective: try objective("infiltrate"))
        #expect(on(infiltrate) == [.alert, .revoke, .ghost, .fog, .scan, .jackOut])
        let exfiltration = RuleSet.defaults(content: content, objective: try objective("exfiltration"))
        #expect(on(exfiltration) == MechanicFlag.allCases)
    }

    @Test func theSandboxGetsTheBaseLayer() {
        let base = RuleSet.defaults(content: content, objective: nil)
        #expect(on(base) == content.flags.filter(\.default).compactMap(\.flag))
        #expect(base.tuning == content.tuning)
    }

    @Test func laterLayersOverrideEarlierOnes() throws {
        let takeover = try objective("takeover")
        let overrides = [FlagSetting(.ghost, true), FlagSetting(.alert, false)]
        let rules = try RuleSet.compose(content: content, objective: takeover, overrides: overrides)
        #expect(rules.isOn(.ghost))
        #expect(!rules.isOn(.alert))
        let layers = RuleSet.layers(content: content, objective: takeover, overrides: overrides)
        #expect(layers.map(\.kind) == RuleLayer.Kind.allCases)
        #expect(RuleSet.source(of: .ghost, in: layers) == .overrides)
        #expect(RuleSet.source(of: .fog, in: layers) == .contract)
        #expect(RuleSet.source(of: .scan, in: layers) == .base)
    }

    @Test func theLastSettingOfAFlagWins() throws {
        let overrides = [FlagSetting(.scan, false), FlagSetting(.scan, true)]
        let rules = try RuleSet.compose(content: content, objective: try objective("takeover"), overrides: overrides)
        #expect(rules.isOn(.scan))
    }

    @Test func theDifficultyAndRunStageLayersAreEmpty() throws {
        let layers = RuleSet.layers(content: content, objective: try objective("exfiltration"))
        let middle = layers.filter { $0.kind == .difficulty || $0.kind == .runStage }
        #expect(middle.count == 2)
        let empty = middle.allSatisfy(\.flags.isEmpty)
        #expect(empty)
    }

    @Test func aBrokenRequirementIsRefusedUnlessUnsafe() throws {
        let infiltrate = try objective("infiltrate")
        let overrides = [FlagSetting(.revoke, false)]
        #expect(throws: RuleSetError.missingRequirement(flag: .ghost, requires: .revoke)) {
            try RuleSet.compose(content: content, objective: infiltrate, overrides: overrides)
        }
        let rules = try RuleSet.compose(content: content, objective: infiltrate, overrides: overrides, unsafe: true)
        #expect(rules.isOn(.ghost) && !rules.isOn(.revoke))
    }

    @Test(arguments: [MechanicFlag.transfer, .jackOut])
    func exfiltrationNeedsItsFlags(flag: MechanicFlag) throws {
        let exfiltration = try objective("exfiltration")
        #expect(throws: RuleSetError.objectiveNeeds(objective: "exfiltration", flag: flag)) {
            try RuleSet.compose(content: content, objective: exfiltration, overrides: [FlagSetting(flag, false)])
        }
    }

    @Test func onlyAscensionZeroExists() throws {
        let takeover = try objective("takeover")
        #expect(throws: RuleSetError.noAscension(level: 1)) {
            try RuleSet.compose(content: content, objective: takeover, ascension: 1, unsafe: true)
        }
        #expect(
            try RuleSet.compose(content: content, objective: takeover, ascension: 0)
                == .defaults(
                    content: content, objective: takeover))
    }

    @Test func fogForcedOnGetsTheDefaultMode() throws {
        let takeover = try objective("takeover")
        let rules = try RuleSet.compose(content: content, objective: takeover, overrides: [FlagSetting(.fog, true)])
        #expect(rules.fog(for: takeover) == .on)
        #expect(RuleSet.defaults(content: content, objective: takeover).fog(for: takeover) == .off)
    }

    @Test func flagSettingsParse() {
        #expect(FlagSetting.parse("ghost=on") == FlagSetting(.ghost, true))
        #expect(FlagSetting.parse("JACKOUT=OFF") == FlagSetting(.jackOut, false))
        #expect(FlagSetting.parse("ghost") == nil)
        #expect(FlagSetting.parse("ghost=yes") == nil)
        #expect(FlagSetting.parse("implants=on") == nil)
    }

    @Test func aRuleSetRoundTripsThroughJSON() throws {
        let rules = try RuleSet.compose(
            content: content, objective: try objective("exfiltration"), overrides: [FlagSetting(.scan, false)])
        #expect(try JSONDecoder().decode(RuleSet.self, from: JSONEncoder().encode(rules)) == rules)
    }

    @Test func aFlagMissingFromARecordIsOff() throws {
        let flags = try JSONDecoder().decode(FlagSet.self, from: Data(#"{ "alert": true }"#.utf8))
        #expect(flags.on == [.alert])
    }

    @Test func anUnknownFlagInARecordIsAnError() {
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(FlagSet.self, from: Data(#"{ "implants": true }"#.utf8))
        }
    }
}

/// Addendum 02, §1: the RuleSet is stored in the state and written into
/// the replay header; old replays stay readable.
@Suite struct RuleSetRecordTests {
    @Test func theContractStateHoldsTheComposedRules() throws {
        let fixture = try ContractFixture(objective: "exfiltration", flags: [FlagSetting(.scan, false)])
        let exfiltration = try #require(fixture.content.objective("exfiltration"))
        var expected = RuleSet.defaults(content: fixture.content, objective: exfiltration)
        expected.flags[.scan] = false
        #expect(fixture.state.rules == expected)
    }

    @Test func aContractReplayRecordsItsRules() throws {
        let content = try BundledContent.load()
        let rules = RuleSet.defaults(content: content, objective: content.objective("infiltrate"))
        let replay = ContractReplay(
            carrierVersion: CarrierVersion.current, seed: 8, objective: "infiltrate", rules: rules, actions: [.wait])
        let decoded = try JSONDecoder().decode(ContractReplay.self, from: JSONEncoder().encode(replay))
        #expect(decoded.rules == rules)
    }

    @Test func aContractReplayWithoutRulesIsStillRead() throws {
        let json = #"""
            { "kind": "contract", "format": 1, "carrierVersion": "0.5.0", "seed": 8, "objective": "takeover",
              "actions": [{ "wait": {} }] }
            """#
        let replay = try JSONDecoder().decode(ContractReplay.self, from: Data(json.utf8))
        #expect(replay.rules == nil)
        #expect(replay.actions == [.wait])
    }

    @Test func aFightReplayWithoutRulesIsStillRead() throws {
        let json = #"{ "format": 1, "carrierVersion": "0.2.0", "seed": 8, "role": "neutral", "actions": [] }"#
        let replay = try JSONDecoder().decode(FightReplay.self, from: Data(json.utf8))
        #expect(replay.rules == nil)
    }
}
