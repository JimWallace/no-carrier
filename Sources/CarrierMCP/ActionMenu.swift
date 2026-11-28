package import CarrierCore

/// A legal action as a tool shows it: a stable id, a short label, and the
/// action it stands for.
package struct MenuItem<Action: Equatable & Sendable>: Equatable, Sendable {
    package let id: String
    package let label: String
    package let action: Action

    var json: JSONValue { ["id": .string(id), "label": .string(label)] }
}

/// The actions the engines would accept now. The engines decide what is
/// legal (`rejection(for:in:)`); this only lists the candidates and names
/// them. An id is built from the action, so the same action has the same id
/// in every game: `attack-4`, `play-2`, `take-1-delete-7`.
package enum ActionMenu {
    package static func contract(_ state: ContractState, engine: ContractEngine) -> [MenuItem<ContractAction>] {
        let content = engine.content
        var items: [MenuItem<ContractAction>] = []
        switch state.phase {
        case .map:
            let nodes = state.network.nodes
            for node in state.network.attackable {
                let what = nodes[node].visibility == .scanned ? nodes[node].type.label : "UNKNOWN"
                let verb = nodes[node].accessed ? "CLAIM" : "ATTACK"
                items.append(
                    .init(id: "attack-\(node)", label: "\(verb) NODE \(node) (\(what))", action: .attack(node: node)))
            }
            for node in nodes where node.isFoothold && node.contested {
                items.append(
                    .init(
                        id: "reinforce-\(node.index)", label: "REINFORCE NODE \(node.index)",
                        action: .reinforce(node: node.index)))
            }
            for node in nodes where node.visibility == .detected {
                items.append(
                    .init(
                        id: "scan-\(node.index)", label: "SCAN NODE \(node.index) (+ALERT)",
                        action: .scan(node: node.index)))
            }
            items.append(.init(id: "wait", label: "WAIT (PASS THE TICK)", action: .wait))
            items.append(.init(id: "jack-out", label: "JACK OUT (END THE CONTRACT)", action: .jackOut))
        case .accessChoice:
            items.append(.init(id: "claim", label: "CLAIM (FIGHT ON AND CAPTURE)", action: .claim))
            items.append(.init(id: "ghost", label: "GHOST (TAKE ACCESS AND LEAVE)", action: .ghost))
        case .fight:
            guard let context = FightContext(contract: state, engine: engine) else { break }
            items = fightItems(context).map {
                .init(id: $0.id, label: $0.label, action: .fight($0.action))
            }
        case .reward(_, let choices):
            let full = state.deck.count >= state.storage
            for (choice, id) in choices.enumerated() {
                let name = content.card(id)?.name ?? id
                guard full else {
                    items.append(
                        .init(
                            id: "take-\(choice + 1)", label: "TAKE \(name)",
                            action: .takeReward(choice: choice, replacing: nil)))
                    continue
                }
                // Storage is full: one item per distinct card to delete,
                // at its first place in the deck.
                var seen: [String] = []
                for (position, deckID) in state.deck.enumerated() where !seen.contains(deckID) {
                    seen.append(deckID)
                    items.append(
                        .init(
                            id: "take-\(choice + 1)-delete-\(position + 1)",
                            label: "TAKE \(name), DELETE \(content.card(deckID)?.name ?? deckID)",
                            action: .takeReward(choice: choice, replacing: position)))
                }
            }
            items.append(.init(id: "skip", label: "SKIP THE LOOT", action: .skipReward))
        case .upgrade(_, let choices, _):
            for (choice, upgrade) in choices.enumerated() {
                items.append(
                    .init(id: "upgrade-\(choice + 1)", label: upgrade.label, action: .chooseUpgrade(choice: choice)))
            }
        case .over:
            break
        }
        return items.filter { engine.rejection(for: $0.action, in: state) == nil }
    }

    /// Hand cards that can run now, then END and LOGOUT.
    static func fight(_ context: FightContext) -> [MenuItem<Action>] {
        fightItems(context)
    }

    private static func fightItems(_ context: FightContext) -> [MenuItem<Action>] {
        let fight = context.fight
        guard !fight.isOver else { return [] }
        var items: [MenuItem<Action>] = []
        for (index, instance) in fight.hand.enumerated() where context.rejection(index) == nil {
            let card = context.content.card(instance.cardID)
            let name = card?.name ?? instance.cardID
            items.append(
                .init(
                    id: "play-\(index + 1)", label: "RUN \(name) (\(card?.cost.label ?? "?") CYC)",
                    action: .play(handIndex: index)))
        }
        items.append(.init(id: "end", label: "END TURN", action: .endTurn))
        items.append(
            .init(id: "logout", label: "LOGOUT (TRACE +\(context.rules.tuning.trace.logout))", action: .logout))
        return items
    }

    /// Reads an action id, legal now or not, so the engine can say why an
    /// illegal one is refused. Nil when `text` is not an id.
    package static func contractAction(id text: String) -> ContractAction? {
        let parts = text.lowercased().split(separator: "-").map(String.init)
        let numbers = parts.dropFirst().compactMap { Int($0) }
        switch (parts.first, parts.count) {
        case ("attack", 2): return numbers.first.map { .attack(node: $0) }
        case ("reinforce", 2): return numbers.first.map { .reinforce(node: $0) }
        case ("scan", 2): return numbers.first.map { .scan(node: $0) }
        case ("wait", 1): return .wait
        case ("jack", 2) where parts[1] == "out": return .jackOut
        case ("claim", 1): return .claim
        case ("ghost", 1): return .ghost
        case ("skip", 1): return .skipReward
        case ("take", 2): return numbers.first.map { .takeReward(choice: $0 &- 1, replacing: nil) }
        case ("take", 4) where parts[2] == "delete" && numbers.count == 2:
            return .takeReward(choice: numbers[0] &- 1, replacing: numbers[1] &- 1)
        case ("upgrade", 2): return numbers.first.map { .chooseUpgrade(choice: $0 &- 1) }
        default: return fightAction(id: text).map { .fight($0) }
        }
    }

    package static func fightAction(id text: String) -> Action? {
        let parts = text.lowercased().split(separator: "-").map(String.init)
        switch (parts.first, parts.count) {
        case ("play", 2): return Int(parts[1]).map { .play(handIndex: $0 &- 1) }
        case ("end", 1): return .endTurn
        case ("logout", 1): return .logout
        default: return nil
        }
    }
}
