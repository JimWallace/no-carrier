/// Works one action through a mutable copy of the fight, collecting events.
/// The engine creates one per action and keeps the result.
struct FightResolver {
    var fight: FightState
    let content: ContentPack
    private(set) var events: [Event] = []

    init(fight: FightState, content: ContentPack) {
        self.fight = fight
        self.content = content
    }

    mutating func emit(_ event: Event) {
        events.append(event)
    }

    var tuning: Tuning { content.tuning }

    var usedRAM: Int {
        fight.daemons.reduce(0) { $0 + (content.card($1.cardID)?.daemon?.ram ?? 0) }
    }

    var passives: [Passive] {
        fight.daemons.flatMap { content.card($0.cardID)?.daemon?.passives ?? [] }
    }

    var exploitBonus: Int {
        passives.reduce(0) { total, passive in
            if case .exploitBonus(let amount) = passive { return total + amount }
            return total
        }
    }

    var iceTraceReduction: Int {
        passives.reduce(0) { total, passive in
            if case .iceTraceReduction(let amount) = passive { return total + amount }
            return total
        }
    }

    var cpuTier: CPUTierTuning {
        tuning.cpuTier(fight.machine.cpu.tier)
            ?? CPUTierTuning(tier: fight.machine.cpu.tier, intentsPerTurn: 1, attackBonus: 0)
    }

    // MARK: - Ending the fight

    /// Ends the fight once, with the first outcome that applies.
    mutating func end(_ outcome: FightOutcome) {
        guard fight.outcome == nil else { return }
        fight.outcome = outcome
        emit(.fightEnded(outcome: outcome))
    }

    /// Checks the three ways a fight ends on its own. Capture wins a tie:
    /// the node falls before the trace completes.
    mutating func checkForEnd() {
        guard fight.outcome == nil else { return }
        if fight.currentLayerIndex == nil {
            emit(.nodeCaptured)
            end(.captured)
        } else if fight.integrity <= 0 {
            end(.flatlined)
        } else if fight.trace >= tuning.trace.max {
            end(.traced)
        }
    }

    /// LOGOUT (kickoff §4): the node is unchanged and Trace goes up. If that
    /// fills Trace, the line drops instead: NO CARRIER.
    mutating func logout() {
        emit(.loggedOut)
        changeTrace(by: tuning.trace.logout)
        end(fight.trace >= tuning.trace.max ? .traced : .loggedOut)
    }

    // MARK: - Shared rules

    /// Changes Trace, never below zero. A change that moves nothing (SPOOF
    /// at zero) emits nothing.
    mutating func changeTrace(by delta: Int) {
        let total = max(0, fight.trace + delta)
        let applied = total - fight.trace
        guard applied != 0 else { return }
        fight.trace = total
        emit(.traceChanged(by: applied, total: total))
    }

    mutating func gainProxy(_ amount: Int) {
        fight.proxy += amount
        emit(.proxyGained(amount: amount, total: fight.proxy))
    }

    /// Draws up to `count` cards. An empty draw pile takes the shuffled
    /// discard pile; a full hand stops the draw.
    mutating func draw(_ count: Int) {
        var drawn: [String] = []
        for _ in 0..<max(0, count) {
            if fight.hand.count >= fight.rig.maxHandSize {
                if !drawn.isEmpty { emit(.cardsDrawn(cardIDs: drawn)) }
                drawn = []
                emit(.handFull)
                break
            }
            if fight.drawPile.isEmpty {
                guard !fight.discardPile.isEmpty else { break }
                if !drawn.isEmpty { emit(.cardsDrawn(cardIDs: drawn)) }
                drawn = []
                var pile = fight.discardPile
                fight.discardPile = []
                fight.rng.shuffle(&pile)
                fight.drawPile = pile
                emit(.deckReshuffled(count: pile.count))
            }
            let card = fight.drawPile.removeFirst()
            fight.hand.append(card)
            drawn.append(card.cardID)
        }
        if !drawn.isEmpty { emit(.cardsDrawn(cardIDs: drawn)) }
    }

    mutating func newCard(_ cardID: String) -> CardInstance {
        defer { fight.nextUID += 1 }
        return CardInstance(uid: fight.nextUID, cardID: cardID)
    }
}
