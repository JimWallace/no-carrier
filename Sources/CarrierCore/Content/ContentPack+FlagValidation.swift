extension ContentPack {
    /// `flags.json` (addendum 02, §1): one entry per flag this build knows,
    /// requirements that name known flags, and default rules that keep
    /// every requirement for every objective.
    func validateFlags() -> [ContentError] {
        var errors = duplicates(flags.map(\.name), kind: "flag")
        for definition in flags {
            let field = "flag \(definition.name)"
            if definition.flag == nil {
                errors.append(.unknownFlag(name: definition.name, referencedBy: "flags.json"))
            }
            if definition.description.isEmpty {
                errors.append(.invalidValue(field: field, reason: "needs a description"))
            }
            for name in definition.requires {
                if MechanicFlag(rawValue: name) == nil {
                    errors.append(.unknownFlag(name: name, referencedBy: "\(field) requires"))
                } else if name == definition.name {
                    errors.append(.invalidValue(field: field, reason: "a flag cannot require itself"))
                }
            }
        }
        for flag in MechanicFlag.allCases where !flags.contains(where: { $0.flag == flag }) {
            errors.append(.invalidValue(field: "flags.json", reason: "no entry for the flag \(flag.rawValue)"))
        }
        // Only a whole flag table can be checked against the objectives.
        guard errors.isEmpty else { return errors }
        for objective in objectives {
            for violation in RuleSet.defaults(content: self, objective: objective).violations(
                content: self, objective: objective)
            {
                errors.append(.invalidValue(field: "objective \(objective.id)", reason: "default rules: \(violation)"))
            }
        }
        return errors
    }
}
