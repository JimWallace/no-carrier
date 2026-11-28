/// The contract reducer (kickoff §3): the network layer around the fight
/// engine. Pure, like `Engine`: every random draw comes from the state's
/// PRNG, so a seed and an action log replay a contract exactly.
public struct ContractEngine: Sendable {
    public let content: ContentPack
    public let fightEngine: Engine

    public init(content: ContentPack) {
        self.content = content
        fightEngine = Engine(content: content)
    }

    /// Starts a contract for `objective` under its default rules.
    public func start(
        seed: UInt64, network: Network, objective: ObjectiveDefinition
    ) -> (ContractState, [ContractEvent]) {
        start(
            seed: seed, network: network, objective: objective,
            rules: RuleSet.defaults(content: content, objective: objective))
    }

    /// Starts a contract for `objective` on `network` under `rules`, with
    /// the starting rig and starter deck, sets the fog, and announces the
    /// sysop's first intent. Without the `alert` flag the sysop is ACTIVE
    /// from the start, as in the MVP.
    public func start(
        seed: UInt64, network: Network, objective: ObjectiveDefinition, rules: RuleSet
    ) -> (ContractState, [ContractEvent]) {
        let tuning = rules.tuning
        let rig = Rig(tuning: tuning.rig)
        let alert = rules.isOn(.alert) ? objective.startAlert : tuning.network.alert.active
        var state = ContractState(
            seed: seed,
            network: network,
            deck: tuning.starterDeck,
            rig: rig,
            storage: tuning.rig.storage,
            bandwidth: tuning.rig.bandwidth,
            integrity: rig.maxIntegrity,
            trace: 0,
            rng: Xoshiro256StarStar(seed: Seed.derive(seed, "contract")),
            objective: objective,
            rules: rules,
            alert: alert,
            alertState: rules.isOn(.alert) ? AlertState.of(alert, tuning: tuning.network.alert) : .active
        )
        let start: Visibility =
            switch rules.fog(for: objective) {
            case .off: .scanned
            case .on: .hidden
            case .partial: .detected
            }
        for index in state.network.nodes.indices {
            state.network.nodes[index].visibility = state.network.nodes[index].owner == .player ? .scanned : start
        }
        var resolver = ContractResolver(state: state, engine: self)
        resolver.emit(.contractStarted(org: network.orgName, templateID: network.templateID))
        if rules.isOn(.transfer), let spec = objective.target {
            resolver.markTarget(spec, seed: seed)
        }
        resolver.revealAroundFootholds()
        resolver.emit(.tickStarted(tick: 1))
        resolver.telegraphSysop()
        return (resolver.state, resolver.events)
    }

    public func apply(_ action: ContractAction, to state: ContractState) -> (ContractState, [ContractEvent]) {
        if state.outcome != nil {
            return (state, [.actionRejected(reason: .contractOver)])
        }
        var resolver = ContractResolver(state: state, engine: self)
        if let reason = resolver.rejection(for: action) {
            return (state, [.actionRejected(reason: reason)])
        }
        resolver.perform(action)
        return (resolver.state, resolver.events)
    }

    /// Why `action` cannot be taken now, or nil when it can.
    public func rejection(for action: ContractAction, in state: ContractState) -> ContractRejectReason? {
        guard state.outcome == nil else { return .contractOver }
        return ContractResolver(state: state, engine: self).rejection(for: action)
    }

    /// Starting Proxy in a fight: per RELAY the player owns.
    public func relayProxy(_ state: ContractState) -> Int {
        state.network.count(owner: .player, type: .relay) * state.rules.tuning.network.relayProxy
    }

    /// What each ICE program in the running fight will do at the end of
    /// this turn, under the contract's rules. Empty outside a fight.
    public func telegraph(_ state: ContractState) -> [ICETelegraph] {
        state.fight.map { fightEngine.telegraph($0, rules: state.rules) } ?? []
    }

    /// Why the card at `handIndex` in the running fight cannot be played
    /// now, or nil when it can.
    public func rejection(forPlaying handIndex: Int, in state: ContractState) -> RejectReason? {
        guard let fight = state.fight else { return .fightOver }
        return fightEngine.rejection(forPlaying: handIndex, in: fight, rules: state.rules)
    }
}
