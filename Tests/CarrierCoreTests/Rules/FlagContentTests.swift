import CarrierCore
import TestSupport
import Testing

/// `flags.json` and its checks (addendum 02, §1).
@Suite struct FlagContentTests {
    let content: ContentPack

    init() throws {
        content = try BundledContent.load()
    }

    func with(flags: [FlagDefinition]) -> ContentPack {
        ContentPack(
            cards: content.cards, ice: content.ice, osFamilies: content.osFamilies, hardware: content.hardware,
            orgs: content.orgs, tuning: content.tuning, maps: content.maps, objectives: content.objectives,
            flags: flags)
    }

    func replacing(_ name: String, _ change: (inout FlagDefinition) -> Void) -> [FlagDefinition] {
        content.flags.map { definition in
            var copy = definition
            if copy.name == name { change(&copy) }
            return copy
        }
    }

    @Test func everyFlagHasOneEntryWithACategory() {
        #expect(content.flags.compactMap(\.flag) == MechanicFlag.allCases)
        #expect(content.flags.allSatisfy { !$0.description.isEmpty })
    }

    /// Addendum 02, §1: a mechanic that already shipped keeps its rules,
    /// so the M5 and M6 core flags are on by default and the contract
    /// flags are left to the objective.
    @Test func coreFlagsAreOnAndContractFlagsAreOff() {
        for definition in content.flags {
            #expect(definition.default == (definition.category == .core), "\(definition.name)")
        }
    }

    @Test func aMissingEntryIsAnError() {
        let broken = with(flags: content.flags.filter { $0.name != "scan" })
        #expect(broken.validate() == [.invalidValue(field: "flags.json", reason: "no entry for the flag scan")])
    }

    @Test func anUnknownNameIsAnError() {
        let extra = FlagDefinition(name: "implants", description: "Not yet.", default: false, category: .core)
        #expect(
            with(flags: content.flags + [extra]).validate() == [
                .unknownFlag(name: "implants", referencedBy: "flags.json")
            ])
    }

    @Test func anUnknownOrSelfRequirementIsAnError() {
        let unknown = with(flags: replacing("fog") { $0.requires = ["reimage"] })
        #expect(unknown.validate() == [.unknownFlag(name: "reimage", referencedBy: "flag fog requires")])
        let itself = with(flags: replacing("fog") { $0.requires = ["fog"] })
        #expect(itself.validate() == [.invalidValue(field: "flag fog", reason: "a flag cannot require itself")])
    }

    @Test func defaultsThatBreakARequirementAreAnError() {
        let broken = with(flags: replacing("revoke") { $0.default = false })
        let errors = broken.validate()
        #expect(errors.count == 2)
        #expect(
            errors.allSatisfy { error in
                if case .invalidValue(let field, _) = error { field.hasPrefix("objective ") } else { false }
            })
    }
}
