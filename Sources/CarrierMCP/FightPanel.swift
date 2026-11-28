import CarrierCore
import CarrierTerminal

/// A running fight as JSON: what `FightScreen` draws, field by field. It
/// shows only what the screen shows: the weak and resist tags stay `???`
/// until PROBE, and the draw pile is a count, never an order.
enum FightPanel {
    static func json(_ context: FightContext) -> JSONValue {
        let fight = context.fight
        let content = context.content
        let machine = fight.machine
        let telegraphs: [JSONValue] = context.telegraph.map { telegraph in
            [
                "name": .string(content.iceDefinition(telegraph.iceID)?.name ?? telegraph.iceID),
                "next": .strings(telegraph.intents.map(\.label)),
            ]
        }
        let current = fight.currentLayerIndex
        let layers: [JSONValue] = machine.layers.enumerated().map { index, layer in
            [
                "layer": .string(layer.kind.label),
                "hp": .int(layer.hp),
                "max_hp": .int(layer.maxHP),
                "current": .bool(index == current),
            ]
        }
        let usedRAM = fight.daemons.reduce(0) { $0 + (content.card($1.cardID)?.daemon?.ram ?? 0) }
        var fields: [String: JSONValue] = [
            "turn": .int(fight.turn),
            "machine": [
                "os": .string("\(machine.osName) \(machine.osVersion)"),
                "org": .string(machine.orgName),
                "hostname": .string(machine.hostname),
                "cpu": .string(machine.cpu.name),
                "ram_mb": .int(machine.ramMB),
                "modem": .string(machine.modem.name),
            ],
            "ice": .array(telegraphs),
            "layers": .array(layers),
            "weak": .string(fight.revealed ? MachineReadout.tags(machine.weak) : "???"),
            "resist": .string(fight.revealed ? MachineReadout.tags(machine.resist) : "???"),
            "cycles": .int(fight.cycles),
            "max_cycles": .int(fight.rig.cycles),
            "ram_used": .int(usedRAM),
            "ram": .int(fight.rig.ram),
            "proxy": .int(fight.proxy),
            "integrity": .int(fight.integrity),
            "max_integrity": .int(fight.rig.maxIntegrity),
            "trace": .int(fight.trace),
            "draw_pile": .int(fight.drawPile.count),
            "discard_pile": .int(fight.discardPile.count),
            "gone": .int(fight.exhaustPile.count + fight.consumedCards.count),
            "daemons": .strings(fight.daemons.map { content.card($0.cardID)?.name ?? $0.cardID }),
            "hand": .array(hand(context)),
        ]
        if let transfer = fight.transfer {
            fields["transfer"] = [
                "done_mb": .int(transfer.doneMB),
                "total_mb": .int(transfer.totalMB),
                "started": .bool(transfer.started),
            ]
        }
        if let outcome = fight.outcome {
            fields["outcome"] = .string(outcome.rawValue)
        }
        return .object(fields)
    }

    /// The hand in order, with the rules text and the reason a card cannot
    /// run now.
    static func hand(_ context: FightContext) -> [JSONValue] {
        context.fight.hand.enumerated().map { index, instance in
            guard let card = context.content.card(instance.cardID) else {
                return ["slot": .int(index + 1), "name": .string(instance.cardID)]
            }
            var fields: [String: JSONValue] = [
                "slot": .int(index + 1),
                "name": .string(card.name),
                "type": .string(card.type.label),
                "cost": .string(card.cost.label),
                "rules": .string(card.summary),
                "noise": .int(card.noise),
            ]
            if card.noisePerCycle != 0 { fields["noise_per_cycle"] = .int(card.noisePerCycle) }
            if !card.tags.isEmpty { fields["tags"] = .strings(card.tags.map(\.label)) }
            if let reason = context.rejection(index) {
                fields["blocked"] = .string(reason.line(content: context.content))
            }
            return .object(fields)
        }
    }

}
