/// One thing a card does, in two forms: a short keyword for a 40-column hand
/// (`ATK 6`) and a plain sentence for a card panel or `INFO`
/// (`DEAL 6 DAMAGE TO THE CURRENT LAYER`).
///
/// Abilities are derived from a card's effects and flags, so the words can
/// never disagree with what the card does. Every frontend (the terminal, the
/// MCP view, later Godot) uses the same vocabulary; `AbilityGlossary` lists
/// it.
public struct CardAbility: Sendable, Equatable {
    public let short: String
    public let long: String

    public init(short: String, long: String) {
        self.short = short
        self.long = long
    }
}

extension CardDefinition {
    /// What the card does, in play order, then its daemon, its flags and its
    /// noise.
    public var abilities: [CardAbility] {
        var result = effects.map(CardAbility.init(effect:))
        if let daemon {
            result.append(
                CardAbility(
                    short: "RAM \(daemon.ram)", long: "RUNS AS A DAEMON, USING \(daemon.ram) RAM UNTIL THE FIGHT ENDS"))
            for effect in daemon.onTurnStart {
                let inner = CardAbility(effect: effect)
                result.append(
                    CardAbility(short: "\(inner.short)/TURN", long: "AT THE START OF EVERY TURN: \(inner.long)"))
            }
            result += daemon.passives.map(CardAbility.init(passive:))
        }
        for effect in endOfTurnInHand {
            let inner = CardAbility(effect: effect)
            result.append(
                CardAbility(short: "HELD: \(inner.short)", long: "IF STILL IN HAND WHEN THE TURN ENDS: \(inner.long)"))
        }
        if let requiresLayer {
            result.append(
                CardAbility(
                    short: "\(requiresLayer.label) ONLY",
                    long: "PLAYABLE ONLY WHILE \(requiresLayer.label) IS THE CURRENT LAYER"))
        }
        if consumed {
            result.append(CardAbility(short: "SPENT", long: "LEAVES YOUR DECK FOR GOOD WHEN PLAYED"))
        } else if exhaust {
            result.append(CardAbility(short: "ONCE", long: "WORKS ONCE PER FIGHT"))
        }
        if cost == .unplayable {
            result.append(CardAbility(short: "DEAD", long: "CANNOT BE PLAYED. MALWARE CLOGS YOUR HAND"))
        }
        if temporary {
            result.append(CardAbility(short: "", long: "REMOVED FROM YOUR DECK WHEN THE FIGHT ENDS"))
        }
        if noisePerCycle > 0 {
            result.append(
                CardAbility(short: "NOISE \(noisePerCycle)/CYC", long: "ALERT +\(noisePerCycle) PER CYCLE SPENT"))
        } else if noise > 0 {
            result.append(CardAbility(short: "NOISE \(noise)", long: "ALERT +\(noise): THE SYSOP NOTICES"))
        } else if noise < 0 {
            result.append(CardAbility(short: "ALERT \(noise)", long: "ALERT \(noise): COVERS YOUR TRACKS"))
        }
        return result
    }

    /// The short forms on one line, for a hand.
    public var abilityLine: String {
        abilities.map(\.short).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// What the card does when played, without its flags or noise: the
    /// line a 40-column hand has room for (`ATK 6`, `ATK 3/TURN`).
    public var headline: String {
        var parts = effects.map { CardAbility(effect: $0).short }
        if let daemon {
            parts += daemon.onTurnStart.map { CardAbility(effect: $0).short + "/TURN" }
            parts += daemon.passives.map { CardAbility(passive: $0).short }
        }
        parts += endOfTurnInHand.map { "HELD: " + CardAbility(effect: $0).short }
        if parts.isEmpty { return abilityLine.isEmpty ? "NO EFFECT" : abilityLine }
        return parts.joined(separator: " ")
    }
}

extension CardAbility {
    init(effect: Effect) {
        switch effect {
        case .damage(let amount, let hits):
            self =
                hits > 1
                ? CardAbility(short: "ATK \(amount)x\(hits)", long: "HIT \(hits) TIMES FOR \(amount) DAMAGE EACH")
                : CardAbility(short: "ATK \(amount)", long: "DEAL \(amount) DAMAGE TO THE CURRENT LAYER")
        case .damagePerCycle(let amount):
            self = CardAbility(short: "ATK \(amount)/CYC", long: "SPEND ALL YOUR CYCLES: \(amount) DAMAGE PER CYCLE")
        case .kernelDamage(let amount):
            self = CardAbility(
                short: "KERNEL \(amount)", long: "DEAL \(amount) DAMAGE TO THE KERNEL, THE ONLY WAY TO HURT IT")
        case .shield(let amount):
            self = CardAbility(short: "DEF \(amount)", long: "BLOCK \(amount) ICE DAMAGE THIS TURN")
        case .draw(let amount):
            self = CardAbility(short: "DRAW \(amount)", long: "DRAW \(amount) CARD\(amount == 1 ? "" : "S")")
        case .trace(let amount):
            self =
                amount < 0
                ? CardAbility(short: "TRACE \(amount)", long: "LOWER TRACE BY \(-amount)")
                : CardAbility(short: "TRACE +\(amount)", long: "RAISE TRACE BY \(amount): A RISK")
        case .cyclesNextTurn(let amount):
            self = CardAbility(short: "+\(amount) CYC NEXT", long: "\(amount) MORE CYCLES NEXT TURN")
        case .probe:
            self = CardAbility(short: "PROBE", long: "SHOW WHAT THIS MACHINE IS WEAK TO AND RESISTS")
        case .deleteMalware(let amount):
            self = CardAbility(short: "CLEAN \(amount)", long: "DELETE \(amount) MALWARE CARD FROM HAND OR DISCARD")
        case .retaliate(let amount):
            self = CardAbility(
                short: "THORNS \(amount)", long: "WHEN ICE NEXT ATTACKS THIS TURN, HIT BACK FOR \(amount)")
        case .transferBoost(let amount):
            self = CardAbility(short: "XFER +\(amount)", long: "COPY \(amount) MB MORE OF A RUNNING TRANSFER")
        case .traceShield(let amount):
            self = CardAbility(short: "MUTE \(amount)", long: "ICE TRACE INTENTS -\(amount) THIS TURN")
        case .ifLayer(let layer, let then, let otherwise):
            if case .damage(let special, 1)? = then.first, then.count == 1,
                case .damage(let normal, 1)? = otherwise.first, otherwise.count == 1
            {
                self = CardAbility(
                    short: "ATK \(normal) (\(special) VS \(layer.label))",
                    long: "DEAL \(normal) DAMAGE, OR \(special) WHILE \(layer.label) IS THE CURRENT LAYER")
                return
            }
            let normal = otherwise.map(CardAbility.init(effect:))
            let special = then.map(CardAbility.init(effect:))
            self = CardAbility(
                short: normal.map(\.short).joined(separator: " ")
                    + " (\(special.map(\.short).joined(separator: " ")) ON \(layer.label))",
                long: normal.map(\.long).joined(separator: ", ") + "; ON \(layer.label) INSTEAD: "
                    + special.map(\.long).joined(separator: ", "))
        }
    }

    init(passive: Passive) {
        switch passive {
        case .exploitBonus(let amount):
            self = CardAbility(short: "EXPLOITS +\(amount)", long: "EVERY EXPLOIT HIT DEALS \(amount) MORE DAMAGE")
        case .iceTraceReduction(let amount):
            self = CardAbility(short: "ICE TRACE -\(amount)", long: "ICE TRACE INTENTS -\(amount) EVERY TURN")
        case .quietFirstCard:
            self = CardAbility(short: "1ST CARD SILENT", long: "THE FIRST CARD YOU PLAY EACH TURN MAKES NO NOISE")
        }
    }
}
