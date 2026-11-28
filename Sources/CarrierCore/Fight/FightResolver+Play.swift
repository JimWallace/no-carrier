extension FightResolver {
    /// Why the card at `handIndex` cannot be played now, or nil when it can.
    func rejection(forPlaying handIndex: Int) -> RejectReason? {
        guard fight.hand.indices.contains(handIndex) else { return .noSuchCard(handIndex: handIndex) }
        let cardID = fight.hand[handIndex].cardID
        guard let card = content.card(cardID) else { return .unknownCard(cardID: cardID) }
        if case .fixed(let cost) = card.cost, cost > fight.cycles {
            return .notEnoughCycles(cardID: cardID, cost: cost, cycles: fight.cycles)
        }
        if card.cost == .unplayable {
            return .unplayable(cardID: cardID)
        }
        if let required = card.requiresLayer, fight.currentLayer != required {
            return .wrongLayer(cardID: cardID, required: required)
        }
        if let daemon = card.daemon, usedRAM + daemon.ram > fight.rig.ram {
            return .notEnoughRAM(cardID: cardID, needed: daemon.ram, free: fight.rig.ram - usedRAM)
        }
        return nil
    }

    /// Plays a card that `rejection(forPlaying:)` cleared. The card leaves
    /// the hand, its effects resolve in order, and then it goes to its zone:
    /// running daemons, consumed, exhaust, or the discard pile.
    mutating func play(handIndex: Int) {
        let instance = fight.hand.remove(at: handIndex)
        guard let card = content.card(instance.cardID) else { return }
        let spent: Int
        switch card.cost {
        case .fixed(let cost): spent = cost
        case .x: spent = fight.cycles
        case .unplayable: spent = 0
        }
        fight.cycles -= spent
        emit(.cardPlayed(cardID: card.id, cyclesSpent: spent))

        let before = events.count
        resolve(card.effects, card: card, xCycles: spent)
        if !card.effects.isEmpty && events.count == before {
            emit(.cardHadNoEffect(cardID: card.id))
        }

        if let daemon = card.daemon {
            fight.daemons.append(instance)
            emit(.daemonStarted(cardID: card.id, ramUsed: daemon.ram))
        } else if card.consumed {
            fight.consumedCards.append(instance)
            emit(.cardConsumed(cardID: card.id))
        } else if card.exhaust {
            fight.exhaustPile.append(instance)
            emit(.cardExhausted(cardID: card.id))
        } else {
            fight.discardPile.append(instance)
        }
        checkForEnd()
    }

    /// Applies effects in order. `card` decides whether exploit modifiers
    /// apply (nil for a daemon's start-of-turn effects and for malware).
    mutating func resolve(_ effects: [Effect], card: CardDefinition?, xCycles: Int = 0) {
        for effect in effects {
            guard fight.currentLayerIndex != nil || !effect.hitsTheMachine else { continue }
            apply(effect, card: card, xCycles: xCycles)
        }
    }

    private mutating func apply(_ effect: Effect, card: CardDefinition?, xCycles: Int) {
        switch effect {
        case .damage(let amount, let hits):
            for _ in 0..<max(0, hits) where fight.currentLayerIndex != nil {
                strike(amount, card: card)
            }
        case .damagePerCycle(let amount):
            strike(amount * xCycles, card: card)
        case .kernelDamage(let amount):
            hit(amount, kernelOnly: true)
        case .shield(let amount):
            gainProxy(amount)
        case .draw(let amount):
            draw(amount)
        case .trace(let amount):
            changeTrace(by: amount)
        case .cyclesNextTurn(let amount):
            fight.bonusCyclesNextTurn += amount
            emit(.cyclesQueued(amount: amount))
        case .probe:
            fight.revealed = true
            emit(.weaknessRevealed(weak: fight.machine.weak, resist: fight.machine.resist))
        case .deleteMalware(let amount):
            deleteMalware(amount)
        case .retaliate(let amount):
            fight.retaliation += amount
            emit(.retaliationArmed(amount: fight.retaliation))
        case .transferBoost(let amount):
            advanceTransfer(by: amount)
        case .traceShield(let amount):
            fight.turnTraceShield += amount
            emit(.traceShielded(amount: fight.turnTraceShield))
        case .ifLayer(let layer, let then, let otherwise):
            resolve(fight.currentLayer == layer ? then : otherwise, card: card, xCycles: xCycles)
        }
    }

    /// One hit with the card's exploit modifiers.
    private mutating func strike(_ base: Int, card: CardDefinition?) {
        guard let card else {
            hit(base)
            return
        }
        let (amount, modifier) = exploitDamage(base, card: card)
        hit(amount, modifier: modifier)
    }

    /// DEFRAG: malware in the hand goes first, then the discard pile.
    private mutating func deleteMalware(_ count: Int) {
        for _ in 0..<max(0, count) {
            if let index = fight.hand.firstIndex(where: isMalware) {
                emit(.malwareDeleted(cardID: fight.hand.remove(at: index).cardID))
            } else if let index = fight.discardPile.firstIndex(where: isMalware) {
                emit(.malwareDeleted(cardID: fight.discardPile.remove(at: index).cardID))
            } else {
                return
            }
        }
    }

    private func isMalware(_ instance: CardInstance) -> Bool {
        content.card(instance.cardID)?.type == .malware
    }
}

extension Effect {
    /// Damage needs a layer to land on; after the node falls it does nothing.
    var hitsTheMachine: Bool {
        switch self {
        case .damage, .damagePerCycle, .kernelDamage: true
        default: false
        }
    }
}
