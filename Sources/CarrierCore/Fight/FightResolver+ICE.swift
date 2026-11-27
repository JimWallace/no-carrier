extension FightResolver {
    /// The ICE phase: each program in order carries out its next pattern
    /// steps, as many as the CPU tier allows (kickoff §6).
    mutating func runICE() {
        for index in fight.ice.indices {
            for _ in 0..<cpuTier.intentsPerTurn {
                let program = fight.ice[index]
                guard let definition = content.iceDefinition(program.iceID), !definition.pattern.isEmpty else {
                    break
                }
                let step = definition.pattern[program.step % definition.pattern.count]
                fight.ice[index].step += 1
                for intent in step {
                    carryOut(intent, by: program.iceID)
                    checkForEnd()
                    guard fight.outcome == nil else { return }
                }
            }
        }
    }

    /// The intents `program` will carry out at the next end of turn, with
    /// the amounts the player will feel.
    func upcomingIntents(for program: ICEInstance) -> [Intent] {
        guard let definition = content.iceDefinition(program.iceID), !definition.pattern.isEmpty else {
            return []
        }
        return (0..<cpuTier.intentsPerTurn).flatMap { offset in
            definition.pattern[(program.step + offset) % definition.pattern.count].map(effective)
        }
    }

    /// An intent with the tier's attack bonus, CLOAK's reduction and the
    /// modem's Trace multiplier applied.
    func effective(_ intent: Intent) -> Intent {
        switch intent {
        case .attack(let amount): .attack(amount: amount + cpuTier.attackBonus)
        case .trace(let amount):
            .trace(amount: max(0, amount - iceTraceReduction) * fight.machine.modem.tracePercent / 100)
        default: intent
        }
    }

    private mutating func carryOut(_ raw: Intent, by iceID: String) {
        let intent = effective(raw)
        emit(.iceActed(iceID: iceID, intent: intent))
        switch intent {
        case .attack(let amount):
            if fight.retaliation > 0 {
                let back = fight.retaliation
                fight.retaliation = 0
                emit(.retaliated(amount: back))
                hit(back)
                checkForEnd()
                guard fight.outcome == nil else { return }
            }
            let absorbed = min(fight.proxy, amount)
            fight.proxy -= absorbed
            fight.integrity = max(0, fight.integrity - (amount - absorbed))
            emit(.attackResolved(proxyAbsorbed: absorbed, integrityLost: amount - absorbed, integrity: fight.integrity))
        case .trace(let amount):
            changeTrace(by: amount)
        case .harden(let amount):
            guard let index = fight.currentLayerIndex else { return }
            fight.machine.layers[index].hp += amount
            fight.machine.layers[index].maxHP = max(fight.machine.layers[index].maxHP, fight.machine.layers[index].hp)
            emit(
                .layerHardened(
                    layer: fight.machine.layers[index].kind, amount: amount, hp: fight.machine.layers[index].hp))
        case .purgeDaemon:
            purgeLargestDaemon()
        case .injectMalware(let cardID):
            fight.discardPile.append(newCard(cardID))
            emit(.malwareInjected(cardID: cardID))
        }
    }

    /// WATCHDOG removes the daemon that uses the most RAM; on a tie, the one
    /// that started first. It goes to the discard pile.
    private mutating func purgeLargestDaemon() {
        var best: (index: Int, ram: Int)?
        for (index, daemon) in fight.daemons.enumerated() {
            let ram = content.card(daemon.cardID)?.daemon?.ram ?? 0
            if best == nil || ram > (best?.ram ?? 0) {
                best = (index, ram)
            }
        }
        guard let best else {
            emit(.purgeFoundNothing)
            return
        }
        let purged = fight.daemons.remove(at: best.index)
        fight.discardPile.append(purged)
        emit(.daemonPurged(cardID: purged.cardID))
    }
}
