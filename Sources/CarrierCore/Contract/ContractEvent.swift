/// Something that happened in a contract. Fight events arrive wrapped in
/// `.fight`, so one stream carries the whole game.
public enum ContractEvent: Codable, Sendable, Equatable {
    case contractStarted(org: String, templateID: String)
    case tickStarted(tick: Int)
    case fight(Event)
    case fightStarting(node: Int, startingProxy: Int)
    case nodeCaptured(node: Int)
    case nodeLeft(node: Int)
    case reinforced(node: Int)
    case waited
    case upgradeOffered(choices: [RigUpgrade])
    case upgradeChosen(RigUpgrade)
    case rewardOffered(cardIDs: [String])
    case cardAdded(cardID: String)
    case cardDeleted(cardID: String)
    case cardsSpent(cardIDs: [String])
    case rewardSkipped
    case integrityRepaired(amount: Int, total: Int)
    case payloadProduced(count: Int, deckSize: Int)
    case storageFull
    case sysopActed(SysopIntent)
    case sysopFizzled(SysopIntent)
    case sysopTelegraphed(SysopIntent)
    case nodeLost(node: Int)
    case nodeHardened(node: Int, layer: LayerKind, amount: Int, hp: Int)
    case iceSpawned(node: Int, iceID: String)
    case traceChanged(by: Int, total: Int)
    case contractEnded(outcome: ContractOutcome)
    case actionRejected(reason: ContractRejectReason)

    public func line(content: ContentPack) -> String {
        func card(_ id: String) -> String { content.card(id)?.name ?? id }
        switch self {
        case .contractStarted(let org, _): return "CONTRACT: \(org)"
        case .tickStarted(let tick): return "== TICK \(tick) =="
        case .fight(let event): return event.line(content: content)
        case .fightStarting(let node, let proxy):
            return proxy > 0 ? "ATTACK NODE \(node) (RELAY PROXY \(proxy))" : "ATTACK NODE \(node)"
        case .nodeCaptured(let node): return "NODE \(node) IS YOURS"
        case .nodeLeft(let node): return "LEFT NODE \(node)"
        case .reinforced(let node): return "NODE \(node) REINFORCED"
        case .waited: return "WAIT"
        case .upgradeOffered: return "DATA: CHOOSE AN UPGRADE"
        case .upgradeChosen(let upgrade): return "RIG: \(upgrade.label)"
        case .rewardOffered: return "LOOT: TAKE ONE CARD OR SKIP"
        case .cardAdded(let id): return "+\(card(id)) TO DECK"
        case .cardDeleted(let id): return "-\(card(id)) DELETED"
        case .cardsSpent(let ids): return "SPENT: \(ids.map(card).joined(separator: ", "))"
        case .rewardSkipped: return "LOOT SKIPPED"
        case .integrityRepaired(let amount, let total): return "REPAIR +\(amount) INTEGRITY (\(total))"
        case .payloadProduced(let count, let size): return "VIRUS: +\(count) PAYLOAD (DECK \(size))"
        case .storageFull: return "VIRUS: STORAGE FULL"
        case .sysopActed(let intent): return "SYSOP: \(intent.label(content: content))"
        case .sysopFizzled(let intent): return "SYSOP: \(intent.label(content: content)) FAILS"
        case .sysopTelegraphed(let intent): return "SYSOP NEXT: \(intent.label(content: content))"
        case .nodeLost(let node): return "NODE \(node) LOST TO THE SYSOP"
        case .nodeHardened(let node, let layer, let amount, let hp):
            return "NODE \(node) \(layer.label) +\(amount) (\(hp))"
        case .iceSpawned(let node, let id):
            return "NODE \(node) RUNS \(content.iceDefinition(id)?.name ?? id)"
        case .traceChanged(let delta, let total): return "TRACE \(delta < 0 ? "" : "+")\(delta) (\(total))"
        case .contractEnded(let outcome): return "CONTRACT OVER: \(outcome.rawValue.uppercased())"
        case .actionRejected(let reason): return reason.line
        }
    }
}
