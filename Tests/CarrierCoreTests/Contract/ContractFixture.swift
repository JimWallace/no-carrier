import CarrierCore
import CarrierGen
import TestSupport

/// A contract on a generated network, with helpers to put it where a test
/// needs it.
struct ContractFixture {
    let content: ContentPack
    let engine: ContractEngine
    var state: ContractState

    init(seed: UInt64 = 1994) throws {
        content = try BundledContent.load()
        engine = ContractEngine(content: content)
        let network = try NetworkGenerator(content: content).generate(seed: seed)
        state = engine.start(seed: seed, network: network).0
    }

    /// The first node the player can attack.
    var target: Int {
        state.network.attackable.first ?? 0
    }

    /// Makes `node` fall to one BRUTE.EXE, and the deck all BRUTE.EXE.
    mutating func makeEasy(_ node: Int) {
        state.network.nodes[node].machine.layers = [SecurityLayer(kind: .firewall, hp: 1)]
        state.network.nodes[node].machine.ice = []
        state.deck = Array(repeating: "brute", count: 10)
    }

    @discardableResult
    mutating func apply(_ action: ContractAction) -> [ContractEvent] {
        let (next, events) = engine.apply(action, to: state)
        state = next
        return events
    }

    /// Ends the running fight by capturing: plays the first card.
    mutating func captureEasy(_ node: Int) -> [ContractEvent] {
        makeEasy(node)
        return apply(.attack(node: node)) + apply(.fight(.play(handIndex: 0)))
    }
}
