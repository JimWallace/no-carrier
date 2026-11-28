/// A RuleSet that cannot be built, or that breaks a requirement.
public enum RuleSetError: Error, Sendable, Equatable, CustomStringConvertible {
    /// A flag is on, but a flag it requires is off (`flags.json`).
    case missingRequirement(flag: MechanicFlag, requires: MechanicFlag)
    /// The objective cannot be won without this flag.
    case objectiveNeeds(objective: String, flag: MechanicFlag)
    /// Ascension levels do not exist yet; only 0 is allowed.
    case noAscension(level: Int)

    /// Whether `--unsafe` lets the RuleSet through anyway.
    public var isUnsafeOverridable: Bool {
        switch self {
        case .missingRequirement, .objectiveNeeds: true
        case .noAscension: false
        }
    }

    public var description: String {
        switch self {
        case .missingRequirement(let flag, let requires):
            "\(flag.rawValue) requires \(requires.rawValue)"
        case .objectiveNeeds(let objective, let flag):
            "the objective \(objective) cannot be won without \(flag.rawValue)"
        case .noAscension(let level):
            "ascension \(level) does not exist yet; only 0 is allowed"
        }
    }
}
