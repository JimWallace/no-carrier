import CarrierCore
import CarrierGen

/// One contract, for the Godot screens. It holds the state and the log, and
/// changes the state only by sending actions to the engine: the rules stay
/// in CarrierCore, as they do for `carrier play`.
struct ContractSession {
    let content: ContentPack
    let engine: ContractEngine
    private(set) var state: ContractState
    /// Every event line so far, oldest first.
    private(set) var log: [String] = []

    init(content: ContentPack, seed: UInt64, objectiveID: String) throws(SessionError) {
        guard let objective = content.objective(objectiveID) else { throw .unknownObjective(objectiveID) }
        let network: Network
        do {
            network = try NetworkGenerator(content: content).generate(seed: seed)
        } catch {
            throw .generation(String(describing: error))
        }
        self.content = content
        engine = ContractEngine(content: content)
        let (state, events) = engine.start(seed: seed, network: network, objective: objective)
        self.state = state
        record(events)
    }

    /// Sends one action and keeps the events. A refused action leaves the
    /// state as it was and logs why.
    mutating func send(_ action: ContractAction) {
        let (next, events) = engine.apply(action, to: state)
        state = next
        record(events)
    }

    /// The hand position's refusal, if the card cannot run now.
    func refusal(forPlaying index: Int) -> RejectReason? {
        guard let fight = state.fight else { return nil }
        return engine.fightEngine.rejection(forPlaying: index, in: fight, rules: state.rules)
    }

    /// What a node type gives its owner, as the map key says it.
    func meaning(of type: NodeType) -> String {
        let network = state.rules.tuning.network
        let payload = content.card(network.payloadCard)?.name ?? "PAYLOAD"
        return type.meaning(tuning: network, payloadName: payload)
    }

    /// What each ICE program will do at the end of the turn.
    func telegraphs() -> [ICETelegraph] {
        guard let fight = state.fight else { return [] }
        return engine.fightEngine.telegraph(fight, rules: state.rules)
    }

    private mutating func record(_ events: [ContractEvent]) {
        log += events.map { $0.line(content: content) }.filter { !$0.isEmpty }
    }
}

enum SessionError: Error, CustomStringConvertible {
    case unknownObjective(String)
    case generation(String)

    var description: String {
        switch self {
        case .unknownObjective(let id): "NO OBJECTIVE \(id.uppercased())"
        case .generation(let reason): "NETWORK GENERATION FAILED: \(reason)"
        }
    }
}
