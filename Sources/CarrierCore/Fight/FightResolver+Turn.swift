extension FightResolver {
    /// The start of a turn (kickoff §4, "Turn order"): Proxy resets, cycles
    /// refill (plus CRON's bonus), draw, then each daemon triggers in the
    /// order it started.
    mutating func startTurn(startingProxy: Int = 0) {
        fight.turn += 1
        fight.proxy = 0
        fight.retaliation = 0
        fight.turnTraceShield = 0
        fight.cycles = fight.rig.cycles + fight.bonusCyclesNextTurn
        fight.bonusCyclesNextTurn = 0
        emit(.turnStarted(turn: fight.turn, cycles: fight.cycles))
        if var transfer = fight.transfer, transfer.started, !transfer.isComplete {
            transfer.turnsRunning += 1
            fight.transfer = transfer
            advanceTransfer(by: transfer.rateMB)
        }
        if startingProxy > 0 {
            gainProxy(startingProxy)
        }
        draw(fight.rig.handSize)
        for daemon in fight.daemons {
            guard let card = content.card(daemon.cardID), let spec = card.daemon, !spec.onTurnStart.isEmpty else {
                continue
            }
            guard fight.outcome == nil else { return }
            emit(.daemonTriggered(cardID: card.id))
            resolve(spec.onTurnStart, card: nil)
            checkForEnd()
        }
    }

    /// `END`: malware left in hand fires, the hand is discarded, the ICE
    /// carries out its intents, and the next turn starts.
    mutating func endTurn() {
        for instance in fight.hand {
            guard let card = content.card(instance.cardID), !card.endOfTurnInHand.isEmpty else { continue }
            emit(.malwareTriggered(cardID: card.id))
            resolve(card.endOfTurnInHand, card: nil)
        }
        let count = fight.hand.count
        fight.discardPile += fight.hand
        fight.hand = []
        emit(.handDiscarded(count: count))
        checkForEnd()
        guard fight.outcome == nil else { return }

        runICE()
        guard fight.outcome == nil else { return }
        startTurn()
    }

    /// Moves a running TRANSFER on, up to its size.
    mutating func advanceTransfer(by amount: Int) {
        guard var transfer = fight.transfer, transfer.started, !transfer.isComplete, amount > 0 else { return }
        let moved = min(amount, transfer.totalMB - transfer.doneMB)
        transfer.doneMB += moved
        fight.transfer = transfer
        emit(.transferProgressed(by: moved, doneMB: transfer.doneMB, totalMB: transfer.totalMB))
        if transfer.isComplete {
            emit(.transferComplete)
        }
    }
}
