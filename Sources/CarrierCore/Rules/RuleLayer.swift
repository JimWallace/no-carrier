/// One layer of a RuleSet (addendum 02, §1). Later layers override earlier
/// ones. A layer only sets flags today; tuning changes join a layer when
/// the first layer needs one (the ascension ladder, §4.2).
public struct RuleLayer: Sendable, Equatable {
    public var kind: Kind
    public var flags: [FlagSetting]

    public init(kind: Kind, flags: [FlagSetting] = []) {
        self.kind = kind
        self.flags = flags
    }

    /// The layers, in the order they apply.
    public enum Kind: String, Sendable, CaseIterable {
        /// `flags.json` defaults and `tuning.json`.
        case base
        /// The ascension level. Empty until ascension levels exist.
        case difficulty
        /// Contract 1, 2 or 3 of a run. Empty until runs exist (M8).
        case runStage
        /// The objective (and its modifiers, when they exist).
        case contract
        /// `--flag` on the command line, for experiments.
        case overrides

        public var label: String {
            switch self {
            case .base: "BASE"
            case .difficulty: "DIFFICULTY"
            case .runStage: "RUN STAGE"
            case .contract: "CONTRACT"
            case .overrides: "OVERRIDE"
            }
        }
    }
}
