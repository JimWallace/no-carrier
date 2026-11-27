/// Something that happened. The engine returns these with every new state,
/// and a frontend renders them; it never reads a rule outcome any other way.
/// The golden transcripts compare their `line`s.
public enum Event: Codable, Sendable, Equatable {
    case fightStarted(hostname: String, ice: [String])
    case turnStarted(turn: Int, cycles: Int)
    case cardsDrawn(cardIDs: [String])
    case deckReshuffled(count: Int)
    case handFull
    case cardPlayed(cardID: String, cyclesSpent: Int)
    case damageDealt(layer: LayerKind, amount: Int, modifier: DamageModifier?)
    case kernelBlocked(amount: Int)
    case layerBreached(layer: LayerKind)
    case proxyGained(amount: Int, total: Int)
    case traceChanged(by: Int, total: Int)
    case weaknessRevealed(weak: [ExploitTag], resist: [ExploitTag])
    case cyclesQueued(amount: Int)
    case malwareDeleted(cardID: String)
    case retaliationArmed(amount: Int)
    case daemonStarted(cardID: String, ramUsed: Int)
    case daemonTriggered(cardID: String)
    case cardExhausted(cardID: String)
    case cardConsumed(cardID: String)
    case malwareTriggered(cardID: String)
    case handDiscarded(count: Int)
    case iceActed(iceID: String, intent: Intent)
    case attackResolved(proxyAbsorbed: Int, integrityLost: Int, integrity: Int)
    case retaliated(amount: Int)
    case layerHardened(layer: LayerKind, amount: Int, hp: Int)
    case daemonPurged(cardID: String)
    case purgeFoundNothing
    case malwareInjected(cardID: String)
    case nodeCaptured
    case loggedOut
    case fightEnded(outcome: FightOutcome)
    case actionRejected(reason: RejectReason)

    /// The event as one log line. Card and ICE ids are resolved to names
    /// through `content`, so the line reads as the player sees it.
    public func line(content: ContentPack) -> String {
        func card(_ id: String) -> String { content.card(id)?.name ?? id }
        func ice(_ id: String) -> String { content.iceDefinition(id)?.name ?? id }
        switch self {
        case .fightStarted(let hostname, let programs):
            return "CONNECT \(hostname) ICE: \(programs.map(ice).joined(separator: ", "))"
        case .turnStarted(let turn, let cycles):
            return "-- TURN \(turn) -- \(cycles) CYCLES"
        case .cardsDrawn(let ids):
            return "DRAW \(ids.map(card).joined(separator: ", "))"
        case .deckReshuffled(let count):
            return "RESHUFFLE \(count) CARDS"
        case .handFull:
            return "HAND FULL"
        case .cardPlayed(let id, let spent):
            return ">\(card(id)) (\(spent))"
        case .damageDealt(let layer, let amount, let modifier):
            let tag = modifier.map { " \($0.rawValue.uppercased())" } ?? ""
            return "\(layer.label) -\(amount)\(tag)"
        case .kernelBlocked(let amount):
            return "KERNEL BLOCKS \(amount): NEEDS PAYLOAD"
        case .layerBreached(let layer):
            return "\(layer.label) BREACHED"
        case .proxyGained(let amount, let total):
            return "PROXY +\(amount) (\(total))"
        case .traceChanged(let delta, let total):
            return "TRACE \(delta < 0 ? "" : "+")\(delta) (\(total))"
        case .weaknessRevealed(let weak, let resist):
            return "WEAK: \(Self.tags(weak)) RESIST: \(Self.tags(resist))"
        case .cyclesQueued(let amount):
            return "+\(amount) CYCLES NEXT TURN"
        case .malwareDeleted(let id):
            return "DELETED \(card(id))"
        case .retaliationArmed(let amount):
            return "HONEYPOT ARMED (\(amount))"
        case .daemonStarted(let id, let ram):
            return "\(card(id)) RUNNING (RAM \(ram))"
        case .daemonTriggered(let id):
            return "\(card(id)):"
        case .cardExhausted(let id):
            return "\(card(id)) EXHAUSTED"
        case .cardConsumed(let id):
            return "\(card(id)) CONSUMED"
        case .malwareTriggered(let id):
            return "\(card(id)) IN HAND:"
        case .handDiscarded(let count):
            return "END: DISCARD \(count)"
        case .iceActed(let id, let intent):
            return "\(ice(id)): \(intent.label)"
        case .attackResolved(let absorbed, let lost, let integrity):
            return "PROXY -\(absorbed) INTEGRITY -\(lost) (\(integrity))"
        case .retaliated(let amount):
            return "HONEYPOT HITS BACK \(amount)"
        case .layerHardened(let layer, let amount, let hp):
            return "\(layer.label) +\(amount) (\(hp))"
        case .daemonPurged(let id):
            return "\(card(id)) PURGED"
        case .purgeFoundNothing:
            return "NO DAEMON TO PURGE"
        case .malwareInjected(let id):
            return "\(card(id)) IN DISCARD"
        case .nodeCaptured:
            return "ACCESS GRANTED"
        case .loggedOut:
            return "LOGOUT"
        case .fightEnded(let outcome):
            return "END OF SESSION: \(outcome.rawValue.uppercased())"
        case .actionRejected(let reason):
            return reason.line(content: content)
        }
    }

    private static func tags(_ tags: [ExploitTag]) -> String {
        tags.isEmpty ? "-" : tags.map(\.label).joined(separator: ", ")
    }
}

extension RejectReason {
    public func line(content: ContentPack) -> String {
        func card(_ id: String) -> String { content.card(id)?.name ?? id }
        switch self {
        case .fightOver: return "?SESSION CLOSED"
        case .noSuchCard(let index): return "?NO CARD \(index &+ 1)"
        case .unplayable(let id): return "?\(card(id)) IS UNPLAYABLE"
        case .notEnoughCycles(let id, let cost, let cycles):
            return "?\(card(id)) NEEDS \(cost) CYCLES, HAVE \(cycles)"
        case .notEnoughRAM(let id, let needed, let free):
            return "?\(card(id)) NEEDS \(needed) RAM, \(free) FREE"
        case .wrongLayer(let id, let layer): return "?\(card(id)) ONLY WORKS ON \(layer.label)"
        case .unknownCard(let id): return "?UNKNOWN CARD \(id)"
        }
    }
}
