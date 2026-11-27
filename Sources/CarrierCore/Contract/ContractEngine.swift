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

    /// Starts a contract on `network` with the starting rig and starter
    /// deck, and announces the sysop's first intent.
    public func start(seed: UInt64, network: Network) -> (ContractState, [ContractEvent]) {
        let rig = Rig(tuning: content.tuning.rig)
        let state = ContractState(
            seed: seed,
            network: network,
            deck: content.tuning.starterDeck,
            rig: rig,
            storage: content.tuning.rig.storage,
            bandwidth: content.tuning.rig.bandwidth,
            integrity: rig.maxIntegrity,
            trace: 0,
            rng: Xoshiro256StarStar(seed: Seed.derive(seed, "contract"))
        )
        var resolver = ContractResolver(state: state, engine: self)
        resolver.emit(.contractStarted(org: network.orgName, templateID: network.templateID))
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
        state.network.count(owner: .player, type: .relay) * content.tuning.network.relayProxy
    }
}
