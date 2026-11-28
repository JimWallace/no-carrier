import CarrierCore

/// What the engines say about a running fight, under its rules: the ICE
/// telegraph and why a hand card cannot run. A contract fight asks
/// `ContractEngine`, the sandbox asks `Engine`, so the MCP code never picks
/// the rules itself.
struct FightContext {
    let fight: FightState
    let content: ContentPack
    let rules: RuleSet
    let telegraph: [ICETelegraph]
    let rejection: (Int) -> RejectReason?

    /// The fight running in a contract.
    init?(contract state: ContractState, engine: ContractEngine) {
        guard let fight = state.fight else { return nil }
        self.fight = fight
        content = engine.content
        rules = state.rules
        telegraph = engine.telegraph(state)
        rejection = { engine.rejection(forPlaying: $0, in: state) }
    }

    /// A sandbox fight.
    init(sandbox state: GameState, engine: Engine) {
        fight = state.fight
        content = engine.content
        rules = state.rules
        telegraph = engine.telegraph(state.fight, rules: state.rules)
        rejection = { engine.rejection(forPlaying: $0, in: state.fight, rules: state.rules) }
    }
}
