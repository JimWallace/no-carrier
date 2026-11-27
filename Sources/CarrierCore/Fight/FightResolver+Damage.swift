extension FightResolver {
    /// One hit of `amount` to the machine (kickoff §4, "Security layers").
    ///
    /// The hit lands on the current layer. Excess carries from FIREWALL to
    /// AUTH, and is lost when AUTH breaches: it stops at KERNEL. KERNEL takes
    /// only `kernelOnly` damage (PAYLOAD), and PAYLOAD hurts nothing else.
    mutating func hit(_ amount: Int, kernelOnly: Bool = false, modifier: DamageModifier? = nil) {
        var remaining = max(0, amount)
        while remaining > 0, let index = fight.currentLayerIndex {
            let kind = fight.machine.layers[index].kind
            if (kind == .kernel) != kernelOnly {
                if kind == .kernel { emit(.kernelBlocked(amount: remaining)) }
                return
            }
            let dealt = min(remaining, fight.machine.layers[index].hp)
            fight.machine.layers[index].hp -= dealt
            remaining -= dealt
            emit(.damageDealt(layer: kind, amount: dealt, modifier: modifier))
            guard fight.machine.layers[index].isBreached else { return }
            emit(.layerBreached(layer: kind))
            guard kind == .firewall else { return }
        }
    }

    /// An exploit's hit after its modifiers: KEYLOGGER's bonus first, then
    /// the weakness or resistance percent, rounded down. A tag the OS is
    /// weak to beats one it resists.
    func exploitDamage(_ base: Int, card: CardDefinition) -> (amount: Int, modifier: DamageModifier?) {
        guard card.type == .exploit else { return (base, nil) }
        let boosted = base + exploitBonus
        if card.tags.contains(where: fight.machine.weak.contains) {
            return (boosted * tuning.weakPercent / 100, .weak)
        }
        if card.tags.contains(where: fight.machine.resist.contains) {
            return (boosted * tuning.resistPercent / 100, .resist)
        }
        return (boosted, nil)
    }
}
