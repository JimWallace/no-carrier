public import CarrierCore

/// Rough worth of a card, in tenths of a damage point per cycle, for the
/// greedy bot's choices. A heuristic for a bot, not a balance number: it
/// ignores weakness tags, daemons' long tail, and the deck around the card.
public enum CardValue {
    /// Damage a card's effects deal in one play, before modifiers, with
    /// `cycles` spent on an X cost.
    public static func damage(_ card: CardDefinition, cycles: Int) -> Int {
        damage(card.effects, cycles: cycles)
    }

    static func damage(_ effects: [Effect], cycles: Int) -> Int {
        effects.reduce(0) { total, effect in
            switch effect {
            case .damage(let amount, let hits): total + amount * hits
            case .damagePerCycle(let amount): total + amount * cycles
            case .ifLayer(_, let then, let otherwise):
                total + max(damage(then, cycles: cycles), damage(otherwise, cycles: cycles))
            default: total
            }
        }
    }

    static func shield(_ card: CardDefinition) -> Int {
        card.effects.reduce(0) { total, effect in
            if case .shield(let amount) = effect { return total + amount }
            return total
        }
    }

    static func kernelDamage(_ card: CardDefinition) -> Int {
        card.effects.reduce(0) { total, effect in
            if case .kernelDamage(let amount) = effect { return total + amount }
            return total
        }
    }

    /// Tenths of a point per cycle: BRUTE.EXE (6 damage for 1) is 60.
    public static func score(_ card: CardDefinition, rigCycles: Int) -> Int {
        let cost: Int
        switch card.cost {
        case .fixed(let value): cost = max(1, value)
        case .x: cost = max(1, rigCycles)
        case .unplayable: return 0
        }
        switch card.type {
        case .exploit: return damage(card, cycles: rigCycles) * 10 / cost
        case .proxy: return shield(card) * 8 / cost
        case .daemon: return 70
        case .script: return 30
        case .payload, .malware: return 0
        }
    }
}
