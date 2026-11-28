import ArgumentParser
import CarrierCore

/// `--flag name=on|off`, `--unsafe` and `--ascension N`: the override and
/// difficulty layers of the RuleSet (addendum 02, §1).
struct RuleOptions: ParsableArguments {
    @Option(name: .long, help: "Switch a mechanic: name=on or name=off. Repeat for more. See carrier rules.")
    var flag: [String] = []

    @Flag(name: .long, help: "Allow flag combinations that break a requirement, for experiments.")
    var unsafe = false

    @Option(name: .long, help: "The ascension level. Only 0 exists so far.")
    var ascension = 0

    /// The `--flag` settings, in the order given.
    func overrides() throws -> [FlagSetting] {
        try flag.map { text in
            guard let setting = FlagSetting.parse(text) else {
                let known = MechanicFlag.allCases.map(\.rawValue).joined(separator: ", ")
                throw ValidationError("--flag: \"\(text)\" is not name=on or name=off for one of \(known)")
            }
            return setting
        }
    }

    /// The composed rules for `objective` (nil: the fight sandbox), with
    /// `extra` settings applied after the `--flag` ones.
    func compose(
        content: ContentPack, objective: ObjectiveDefinition?, extra: [FlagSetting] = []
    ) throws -> RuleSet {
        do {
            return try RuleSet.compose(
                content: content, objective: objective, ascension: ascension, overrides: try overrides() + extra,
                unsafe: unsafe)
        } catch let error as RuleSetError {
            let hint = error.isUnsafeOverridable ? " (--unsafe allows it)" : ""
            throw ValidationError("rules: \(error.description)\(hint)")
        }
    }
}
