/// One thing a card (or a daemon at the start of a turn) does. Cards list
/// their effects in JSON, and the engine applies them in order.
///
/// A new card that these cases can express is a JSON change only. A new case
/// needs its JSON coding (`EffectCoding`), its rule in the engine, a summary,
/// and a test.
public indirect enum Effect: Sendable, Equatable {
    /// `hits` separate hits of `amount` damage to the current layer. Exploit
    /// modifiers apply to each hit. Damage carries from FIREWALL to AUTH and
    /// stops at KERNEL, which only `kernelDamage` can hurt.
    case damage(amount: Int, hits: Int)
    /// One hit of `amount` damage for each cycle the X cost spent.
    case damagePerCycle(amount: Int)
    /// Damage to the KERNEL layer only (PAYLOAD).
    case kernelDamage(amount: Int)
    /// Proxy: absorbs ICE attacks until the start of the next turn.
    case shield(amount: Int)
    case draw(amount: Int)
    /// Changes global Trace. Negative lowers it, never below zero.
    case trace(amount: Int)
    case cyclesNextTurn(amount: Int)
    /// Reveals the machine's weak and resist tags (PROBE).
    case probe
    /// Deletes up to `amount` malware cards, from the hand first, then the
    /// discard pile (DEFRAG).
    case deleteMalware(amount: Int)
    /// Deals `amount` back to the machine when ICE next attacks this turn
    /// (HONEYPOT).
    case retaliate(amount: Int)
    /// Runs `then` when the current layer is `layer`, else `otherwise`.
    case ifLayer(layer: LayerKind, then: [Effect], otherwise: [Effect])

    /// A short upper-case description for a 40-column card list.
    public var summary: String {
        switch self {
        case .damage(let amount, let hits):
            hits > 1 ? "\(amount)x\(hits) DMG" : "\(amount) DMG"
        case .damagePerCycle(let amount): "\(amount) DMG PER CYCLE"
        case .kernelDamage(let amount): "\(amount) KERNEL DMG"
        case .shield(let amount): "\(amount) PROXY"
        case .draw(let amount): "DRAW \(amount)"
        case .trace(let amount): amount < 0 ? "TRACE \(amount)" : "TRACE +\(amount)"
        case .cyclesNextTurn(let amount): "+\(amount) CYCLES NEXT TURN"
        case .probe: "REVEAL WEAK/RESIST"
        case .deleteMalware(let amount): "DELETE \(amount) MALWARE"
        case .retaliate(let amount): "\(amount) BACK IF ATTACKED"
        case .ifLayer(let layer, let then, let otherwise):
            "\(Self.summary(of: otherwise)); \(layer.label): \(Self.summary(of: then))"
        }
    }

    public static func summary(of effects: [Self]) -> String {
        effects.map(\.summary).joined(separator: ", ")
    }
}
