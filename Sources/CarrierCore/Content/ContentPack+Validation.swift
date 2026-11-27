extension ContentPack {
    /// Every cross-reference and range problem in the pack, in a fixed
    /// order. An empty list means the pack is usable.
    public func validate() -> [ContentError] {
        var errors: [ContentError] = []
        errors += duplicates(cards.map(\.id), kind: "card")
        errors += duplicates(cards.map(\.name), kind: "card name")
        errors += duplicates(ice.map(\.id), kind: "ICE")
        errors += duplicates(osFamilies.map(\.id), kind: "OS family")
        errors += duplicates(orgs.map(\.id), kind: "org")
        errors += validateCards()
        errors += validateICE()
        errors += validateOSFamilies()
        errors += validateTuning()
        for role in NodeRole.allCases {
            errors += validateRole(role)
        }
        return errors
    }

    private func duplicates(_ ids: [String], kind: String) -> [ContentError] {
        var seen: Set<String> = []
        var errors: [ContentError] = []
        for id in ids {
            if seen.contains(id) {
                errors.append(.duplicateID(kind: kind, id: id))
            }
            seen.insert(id)
        }
        return errors
    }

    private func validateCards() -> [ContentError] {
        var errors: [ContentError] = []
        if cards.isEmpty { errors.append(.emptyList(field: "cards")) }
        for card in cards {
            if (card.type == .daemon) != (card.daemon != nil) {
                errors.append(
                    .invalidValue(
                        field: "card \(card.id)",
                        reason: "a daemon card needs a daemon spec, and only a daemon card may have one"))
            }
            if let daemon = card.daemon, daemon.ram < 1 {
                errors.append(.invalidValue(field: "card \(card.id)", reason: "daemon RAM must be at least 1"))
            }
            if case .fixed(let cost) = card.cost, cost < 0 {
                errors.append(.invalidValue(field: "card \(card.id)", reason: "cost must not be negative"))
            }
            if card.name.isEmpty || card.name != card.name.uppercased() || card.name.contains("  ") {
                errors.append(
                    .invalidValue(
                        field: "card \(card.id)", reason: "a name is upper case, not empty, with single spaces"))
            }
        }
        return errors
    }

    private func validateICE() -> [ContentError] {
        var errors: [ContentError] = []
        if ice.isEmpty { errors.append(.emptyList(field: "ice")) }
        for program in ice {
            if program.pattern.isEmpty || program.pattern.contains(where: \.isEmpty) {
                errors.append(
                    .invalidValue(field: "ICE \(program.id)", reason: "every pattern step needs at least one intent"))
            }
            for step in program.pattern {
                for case .injectMalware(let cardID) in step where card(cardID) == nil {
                    errors.append(.unknownCard(id: cardID, referencedBy: "ICE \(program.id)"))
                }
            }
        }
        return errors
    }

    private func validateOSFamilies() -> [ContentError] {
        var errors: [ContentError] = []
        if osFamilies.isEmpty { errors.append(.emptyList(field: "osFamilies")) }
        for family in osFamilies {
            if family.versions.isEmpty { errors.append(.emptyList(field: "OS family \(family.id) versions")) }
            if family.cpus.isEmpty { errors.append(.emptyList(field: "OS family \(family.id) cpus")) }
            for name in family.cpus where cpu(named: name) == nil {
                errors.append(.unknownCPU(name: name, referencedBy: "OS family \(family.id)"))
            }
        }
        for model in hardware.cpus where tuning.cpuTier(model.tier) == nil {
            errors.append(
                .invalidValue(field: "CPU \(model.name)", reason: "tier \(model.tier) has no entry in tuning.cpuTiers"))
        }
        for org in orgs {
            let lists = [org.firstNames, org.secondNames, org.hosts, org.users, org.files]
            if lists.contains(where: \.isEmpty) {
                errors.append(.emptyList(field: "org \(org.id) names, hosts, users or files"))
            }
        }
        if orgs.isEmpty { errors.append(.emptyList(field: "orgs")) }
        return errors
    }

    private func validateTuning() -> [ContentError] {
        var errors: [ContentError] = []
        let rig = tuning.rig
        let positives: [(String, Int)] = [
            ("rig.cycles", rig.cycles), ("rig.handSize", rig.handSize), ("rig.integrity", rig.integrity),
            ("rig.storage", rig.storage), ("rig.bandwidth", rig.bandwidth), ("trace.max", tuning.trace.max),
            ("ice.ramPerExtra", tuning.ice.ramPerExtra), ("ice.ramPerLayerHP", tuning.ice.ramPerLayerHP),
            ("ice.max", tuning.ice.max),
        ]
        for (field, value) in positives where value < 1 {
            errors.append(.invalidValue(field: field, reason: "must be at least 1"))
        }
        let nonNegatives: [(String, Int)] = [
            ("rig.ram", rig.ram), ("weakPercent", tuning.weakPercent), ("resistPercent", tuning.resistPercent),
            ("trace.logout", tuning.trace.logout), ("sandbox.payloadVersusKernel", tuning.sandbox.payloadVersusKernel),
        ]
        for (field, value) in nonNegatives where value < 0 {
            errors.append(.invalidValue(field: field, reason: "must not be negative"))
        }
        for tier in tuning.cpuTiers {
            if tier.intentsPerTurn < 1 {
                errors.append(
                    .invalidValue(field: "cpuTiers[\(tier.tier)].intentsPerTurn", reason: "must be at least 1"))
            }
            if tier.attackBonus < 0 {
                errors.append(
                    .invalidValue(field: "cpuTiers[\(tier.tier)].attackBonus", reason: "must not be negative"))
            }
        }
        for modem in hardware.modems where modem.tracePercent < 0 {
            errors.append(.invalidValue(field: "modem \(modem.name)", reason: "tracePercent must not be negative"))
        }
        if rig.maxHandSize < rig.handSize {
            errors.append(.invalidValue(field: "rig.maxHandSize", reason: "must be at least rig.handSize"))
        }
        if tuning.starterDeck.isEmpty { errors.append(.emptyList(field: "starterDeck")) }
        if tuning.starterDeck.count > rig.storage {
            errors.append(.invalidValue(field: "starterDeck", reason: "holds more cards than rig.storage"))
        }
        for id in tuning.starterDeck where card(id) == nil {
            errors.append(.unknownCard(id: id, referencedBy: "starterDeck"))
        }
        if card(tuning.sandbox.payloadCard) == nil {
            errors.append(.unknownCard(id: tuning.sandbox.payloadCard, referencedBy: "sandbox.payloadCard"))
        }
        return errors
    }

    private func validateRole(_ role: NodeRole) -> [ContentError] {
        let roleTuning = tuning.roles[role]
        let field = "roles.\(role.rawValue)"
        var errors: [ContentError] = []
        if roleTuning.osFamilies.isEmpty { errors.append(.emptyList(field: "\(field).osFamilies")) }
        if roleTuning.ramMB.isEmpty { errors.append(.emptyList(field: "\(field).ramMB")) }
        if roleTuning.modems.isEmpty { errors.append(.emptyList(field: "\(field).modems")) }
        if roleTuning.icePool.isEmpty { errors.append(.emptyList(field: "\(field).icePool")) }
        for id in roleTuning.osFamilies where osFamily(id) == nil {
            errors.append(.unknownOSFamily(id: id, referencedBy: field))
        }
        for name in roleTuning.modems where modem(named: name) == nil {
            errors.append(.unknownModem(name: name, referencedBy: field))
        }
        for id in roleTuning.icePool where iceDefinition(id) == nil {
            errors.append(.unknownICE(id: id, referencedBy: field))
        }
        for megabytes in roleTuning.ramMB where megabytes < 1 {
            errors.append(.invalidValue(field: "\(field).ramMB", reason: "must be at least 1"))
        }
        let ranges =
            [("firewall", roleTuning.firewall), ("auth", roleTuning.auth)]
            + (roleTuning.kernel.map { [("kernel", $0)] } ?? [])
        for (name, range) in ranges where range.min < 1 || range.max < range.min {
            errors.append(.invalidValue(field: "\(field).\(name)", reason: "needs 1 <= min <= max"))
        }
        if role != .neutral && roleTuning.kernel == nil {
            errors.append(.invalidValue(field: "\(field).kernel", reason: "a sysop or root machine has a KERNEL layer"))
        }
        if role == .neutral && roleTuning.kernel != nil {
            errors.append(.invalidValue(field: "\(field).kernel", reason: "a neutral machine has no KERNEL layer"))
        }
        return errors
    }
}
