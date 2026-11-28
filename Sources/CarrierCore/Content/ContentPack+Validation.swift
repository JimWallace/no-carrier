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
        errors += validateNetwork()
        errors += maps.flatMap(validateMap)
        for role in NodeRole.allCases {
            errors += validateRole(role)
        }
        return errors
    }

    func duplicates(_ ids: [String], kind: String) -> [ContentError] {
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
            if let phaseTwo = program.phaseTwo, phaseTwo.isEmpty || phaseTwo.contains(where: \.isEmpty) {
                errors.append(
                    .invalidValue(field: "ICE \(program.id) phaseTwo", reason: "every step needs at least one intent"))
            }
            for step in program.pattern + (program.phaseTwo ?? []) {
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
        for id in roleTuning.requiredICE where iceDefinition(id) == nil {
            errors.append(.unknownICE(id: id, referencedBy: "\(field).requiredICE"))
        }
        if roleTuning.requiredICE.count > tuning.ice.max {
            errors.append(.invalidValue(field: "\(field).requiredICE", reason: "names more programs than ice.max"))
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

    private func validateNetwork() -> [ContentError] {
        let network = tuning.network
        var errors: [ContentError] = []
        if card(network.payloadCard) == nil {
            errors.append(.unknownCard(id: network.payloadCard, referencedBy: "network.payloadCard"))
        }
        for id in network.rewardPool where card(id) == nil {
            errors.append(.unknownCard(id: id, referencedBy: "network.rewardPool"))
        }
        if network.rewardPool.isEmpty { errors.append(.emptyList(field: "network.rewardPool")) }
        if network.dataUpgrades.isEmpty { errors.append(.emptyList(field: "network.dataUpgrades")) }
        if network.rewardChoices < 1 {
            errors.append(.invalidValue(field: "network.rewardChoices", reason: "must be at least 1"))
        }
        let values: [(String, Int)] = [
            ("network.alert.dormantDrift", network.alert.dormantDrift),
            ("network.alert.suspiciousDrift", network.alert.suspiciousDrift),
            ("network.alert.activeDrift", network.alert.activeDrift), ("network.alert.decay", network.alert.decay),
            ("network.alert.capture", network.alert.capture), ("network.alert.access", network.alert.access),
            ("network.alert.scan", network.alert.scan), ("network.sweepTrace", network.sweepTrace),
            ("network.hardenAmount", network.hardenAmount), ("network.repairIntegrity", network.repairIntegrity),
            ("network.relayProxy", network.relayProxy), ("network.virusPayload", network.virusPayload),
            ("network.maxICE", network.maxICE),
        ]
        for (field, value) in values where value < 0 {
            errors.append(.invalidValue(field: field, reason: "must not be negative"))
        }
        let intents = network.sysopIntents
        let intentWeights = [intents.contest, intents.harden, intents.spawnICE, intents.sweep, intents.revoke]
        if intentWeights.contains(where: { $0 < 0 }) || intentWeights.reduce(0, +) < 1 {
            errors.append(
                .invalidValue(
                    field: "network.sysopIntents", reason: "weights are not negative and add up to at least 1"))
        }
        let typeWeights = network.nodeTypes.table.map(\.1)
        if typeWeights.contains(where: { $0 < 0 }) || typeWeights.reduce(0, +) < 1 {
            errors.append(
                .invalidValue(field: "network.nodeTypes", reason: "weights are not negative and add up to at least 1"))
        }
        if maps.isEmpty { errors.append(.emptyList(field: "maps")) }
        let alert = network.alert
        if !(0 < alert.suspicious && alert.suspicious < alert.active && alert.active <= alert.max) {
            errors.append(.invalidValue(field: "network.alert", reason: "needs 0 < suspicious < active <= max"))
        }
        errors += validateObjectives()
        errors += validateFlags()
        return errors
    }

    /// A template is usable when it has one player ENTRY and one sysop ROOT,
    /// at most 10 nodes (they are numbered 0 to 9), one node per grid
    /// cell, links between grid neighbours only, and every node reachable.
    private func validateMap(_ map: MapTemplate) -> [ContentError] {
        let field = "map \(map.id)"
        var errors: [ContentError] = []
        let count = map.nodes.count
        if count < 2 || count > 10 {
            errors.append(.invalidValue(field: field, reason: "needs 2 to 10 nodes"))
        }
        let entries = map.nodes.filter { $0.type == .entry }
        if entries.count != 1 || entries.first?.owner != .player {
            errors.append(.invalidValue(field: field, reason: "needs exactly one ENTRY, owned by the player"))
        }
        let roots = map.nodes.filter { $0.type == .root }
        if roots.count != 1 || roots.first?.owner != .sysop {
            errors.append(.invalidValue(field: field, reason: "needs exactly one ROOT, owned by the sysop"))
        }
        if map.nodes.contains(where: { $0.owner == .player && $0.type != .entry }) {
            errors.append(.invalidValue(field: field, reason: "the player starts with the ENTRY only"))
        }
        var cells: Set<Int> = []
        for slot in map.nodes {
            if slot.column < 0 || slot.column > 4 || slot.row < 0 || slot.row > 3 {
                errors.append(.invalidValue(field: field, reason: "a node is off the 5 by 4 grid"))
            }
            if !cells.insert(slot.row * 10 + slot.column).inserted {
                errors.append(.invalidValue(field: field, reason: "two nodes share a grid cell"))
            }
        }
        for link in map.links {
            guard link.count == 2, link.allSatisfy(map.nodes.indices.contains), link[0] != link[1] else {
                errors.append(.invalidValue(field: field, reason: "a link must join two different nodes"))
                continue
            }
            let a = map.nodes[link[0]]
            let b = map.nodes[link[1]]
            if abs(a.column - b.column) + abs(a.row - b.row) != 1 {
                errors.append(
                    .invalidValue(field: field, reason: "link \(link[0])-\(link[1]) does not join grid neighbours"))
            }
        }
        if count > 0 && errors.isEmpty {
            errors += validateLayout(map, field: field)
            var reached: [Bool] = Array(repeating: false, count: count)
            var queue = [0]
            reached[0] = true
            while let node = queue.popLast() {
                for link in map.links where link.contains(node) {
                    let other = link[0] == node ? link[1] : link[0]
                    if !reached[other] {
                        reached[other] = true
                        queue.append(other)
                    }
                }
            }
            if reached.contains(false) {
                errors.append(.invalidValue(field: field, reason: "some nodes cannot be reached"))
            }
        }
        return errors
    }

    /// Kickoff §3: ROOT 3 to 4 hops from ENTRY, the sysop holding ROOT and 2
    /// or 3 more nodes, and room for a neutral VIRUS within 2 hops of ENTRY.
    private func validateLayout(_ map: MapTemplate, field: String) -> [ContentError] {
        guard let entry = map.nodes.firstIndex(where: { $0.type == .entry }),
            let root = map.nodes.firstIndex(where: { $0.type == .root })
        else { return [] }
        var distance: [Int?] = Array(repeating: nil, count: map.nodes.count)
        distance[entry] = 0
        var frontier = [entry]
        while !frontier.isEmpty {
            var next: [Int] = []
            for node in frontier {
                for link in map.links where link.contains(node) {
                    let other = link[0] == node ? link[1] : link[0]
                    if distance[other] == nil {
                        distance[other] = (distance[node] ?? 0) + 1
                        next.append(other)
                    }
                }
            }
            frontier = next
        }
        var errors: [ContentError] = []
        if !(3...4).contains(distance[root] ?? 0) {
            errors.append(.invalidValue(field: field, reason: "ROOT must be 3 or 4 hops from ENTRY"))
        }
        if !(3...4).contains(map.nodes.count { $0.owner == .sysop }) {
            errors.append(.invalidValue(field: field, reason: "the sysop holds ROOT and 2 or 3 more nodes"))
        }
        let virusRoom = map.nodes.indices.contains { index in
            let slot = map.nodes[index]
            return slot.owner == .neutral && (slot.type == nil || slot.type == .virus)
                && (distance[index].map { (1...2).contains($0) } ?? false)
        }
        if !virusRoom {
            errors.append(
                .invalidValue(field: field, reason: "needs an open neutral node within 2 hops of ENTRY for a VIRUS"))
        }
        return errors
    }

    private func validateObjectives() -> [ContentError] {
        let alert = tuning.network.alert
        var errors: [ContentError] = []
        if objectives.isEmpty { errors.append(.emptyList(field: "objectives")) }
        errors += duplicates(objectives.map(\.id), kind: "objective")
        for objective in objectives {
            let field = "objective \(objective.id)"
            if !(0...alert.max).contains(objective.startAlert) {
                errors.append(.invalidValue(field: field, reason: "startAlert must be 0 to network.alert.max"))
            }
            for id in objective.extraRewards where card(id) == nil {
                errors.append(.unknownCard(id: id, referencedBy: "\(field) extraRewards"))
            }
            if let target = objective.target {
                if target.nodeType == .entry || target.nodeType == .root {
                    errors.append(.invalidValue(field: field, reason: "a TARGET cannot be ENTRY or ROOT"))
                }
                if target.fileMB.min < 1 || target.fileMB.max < target.fileMB.min {
                    errors.append(.invalidValue(field: field, reason: "fileMB needs 1 <= min <= max"))
                }
            }
            if objective.win == .exfiltrate && objective.target == nil {
                errors.append(.invalidValue(field: field, reason: "EXFILTRATE needs a target"))
            }
        }
        for modem in hardware.modems where modem.transferMB < 1 {
            errors.append(.invalidValue(field: "modem \(modem.name)", reason: "transferMB must be at least 1"))
        }
        return errors
    }
}
