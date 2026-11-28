/// The active rules of a contract or a fight (addendum 02, §1): which
/// mechanics are on, and every tuning number. Built from layers (base,
/// difficulty, run stage, contract, overrides) by `compose`, stored in the
/// state, and written into the replay header.
public struct RuleSet: Codable, Sendable, Equatable {
    public var flags: FlagSet
    public var tuning: Tuning

    public init(flags: FlagSet, tuning: Tuning) {
        self.flags = flags
        self.tuning = tuning
    }

    public func isOn(_ flag: MechanicFlag) -> Bool {
        flags[flag]
    }

    /// The fog mode a contract starts with: off when the flag is off, else
    /// the objective's mode, or `on` when the objective has none.
    public func fog(for objective: ObjectiveDefinition) -> FogMode {
        guard isOn(.fog) else { return .off }
        return objective.fog == .off ? .on : objective.fog
    }
}

extension RuleSet {
    /// The layers for a contract on `objective` (nil: the fight sandbox,
    /// which has no contract layer), in the order they apply.
    public static func layers(
        content: ContentPack, objective: ObjectiveDefinition?, ascension: Int = 0, overrides: [FlagSetting] = []
    ) -> [RuleLayer] {
        let base = content.flags.compactMap { definition in
            definition.flag.map { FlagSetting($0, definition.default) }
        }
        return [
            RuleLayer(kind: .base, flags: base),
            RuleLayer(kind: .difficulty),
            RuleLayer(kind: .runStage),
            RuleLayer(kind: .contract, flags: objective?.ruleSettings ?? []),
            RuleLayer(kind: .overrides, flags: overrides),
        ]
    }

    /// Applies `layers` in order to the content's tuning.
    public static func apply(_ layers: [RuleLayer], tuning: Tuning) -> RuleSet {
        var flags = FlagSet()
        for layer in layers {
            for setting in layer.flags {
                flags.apply(setting)
            }
        }
        return RuleSet(flags: flags, tuning: tuning)
    }

    /// The default rules for `objective`: no difficulty, no run stage, no
    /// overrides, and not checked. Validated content guarantees that these
    /// are valid (`ContentPack.validate()`).
    public static func defaults(content: ContentPack, objective: ObjectiveDefinition?) -> RuleSet {
        apply(layers(content: content, objective: objective), tuning: content.tuning)
    }

    /// Builds and checks the rules. Only ascension 0 exists. With `unsafe`,
    /// a broken requirement is let through, for experiments.
    public static func compose(
        content: ContentPack, objective: ObjectiveDefinition?, ascension: Int = 0, overrides: [FlagSetting] = [],
        unsafe: Bool = false
    ) throws(RuleSetError) -> RuleSet {
        guard ascension == 0 else { throw .noAscension(level: ascension) }
        let rules = apply(
            layers(content: content, objective: objective, ascension: ascension, overrides: overrides),
            tuning: content.tuning)
        if !unsafe, let first = rules.violations(content: content, objective: objective).first {
            throw first
        }
        return rules
    }

    /// Every requirement these rules break, in `MechanicFlag.allCases` order.
    public func violations(content: ContentPack, objective: ObjectiveDefinition?) -> [RuleSetError] {
        var errors: [RuleSetError] = []
        for flag in flags.on {
            guard let definition = content.flags.first(where: { $0.flag == flag }) else { continue }
            for name in definition.requires {
                if let required = MechanicFlag(rawValue: name), !isOn(required) {
                    errors.append(.missingRequirement(flag: flag, requires: required))
                }
            }
        }
        if let objective {
            for flag in objective.win.requiredFlags where !isOn(flag) {
                errors.append(.objectiveNeeds(objective: objective.id, flag: flag))
            }
        }
        return errors
    }

    /// The layer that last set `flag`, for `carrier rules`.
    public static func source(of flag: MechanicFlag, in layers: [RuleLayer]) -> RuleLayer.Kind? {
        layers.last { layer in layer.flags.contains { $0.flag == flag } }?.kind
    }
}

extension ObjectiveDefinition {
    /// The contract layer (addendum 02, §1): the objective's switches as
    /// flags. `ghost` is the `ghost` flag, a fog other than `off` is `fog`,
    /// a target is `transfer`, and extra rewards are `objectiveLoot`.
    public var ruleSettings: [FlagSetting] {
        [
            FlagSetting(.ghost, ghost),
            FlagSetting(.fog, fog != .off),
            FlagSetting(.transfer, target != nil),
            FlagSetting(.objectiveLoot, !extraRewards.isEmpty),
        ]
    }
}

extension ObjectiveWin {
    /// The flags without which the objective cannot be won.
    public var requiredFlags: [MechanicFlag] {
        switch self {
        case .captureRoot: []
        case .exfiltrate: [.transfer, .jackOut]
        }
    }
}
