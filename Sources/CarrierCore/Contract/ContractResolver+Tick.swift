extension ContractResolver {
    /// The end of a tick (kickoff §3, "A tick", steps 3 to 6): production,
    /// the sysop's announced intent and the next announcement, Trace drift,
    /// and the check.
    mutating func endTick() {
        produce()
        if let intent = state.sysopIntent {
            resolveSysop(intent)
            guard state.outcome == nil else { return }
        }
        telegraphSysop()
        changeTrace(by: network.traceDrift)
        if state.trace >= content.tuning.trace.max {
            end(.traced)
            return
        }
        state.tick += 1
        state.actionsLeft = state.bandwidth
        emit(.tickStarted(tick: state.tick))
    }

    /// REPAIR and VIRUS nodes, in node order.
    private mutating func produce() {
        for node in state.network.nodes where node.owner == .player {
            switch node.type {
            case .repair:
                let healed = min(state.rig.maxIntegrity, state.integrity + network.repairIntegrity)
                if healed > state.integrity {
                    emit(.integrityRepaired(amount: healed - state.integrity, total: healed))
                    state.integrity = healed
                }
            case .virus:
                let room = max(0, state.storage - state.deck.count)
                let count = min(room, network.virusPayload)
                if count > 0 {
                    state.deck += Array(repeating: network.payloadCard, count: count)
                    emit(.payloadProduced(count: count, deckSize: state.deck.count))
                } else if network.virusPayload > 0 {
                    emit(.storageFull)
                }
            default:
                break
            }
        }
    }

    private mutating func resolveSysop(_ intent: SysopIntent) {
        state.sysopIntent = nil
        switch intent {
        case .contest(let node):
            guard state.network.nodes[node].owner == .player, state.network.nodes[node].contested else {
                emit(.sysopFizzled(intent))
                return
            }
            emit(.sysopActed(intent))
            loseNode(node)
        case .harden(let node):
            guard state.network.nodes[node].owner == .sysop,
                let layer = state.network.nodes[node].machine.layers.firstIndex(where: { !$0.isBreached })
            else {
                emit(.sysopFizzled(intent))
                return
            }
            emit(.sysopActed(intent))
            state.network.nodes[node].machine.layers[layer].hp += network.hardenAmount
            let hardened = state.network.nodes[node].machine.layers[layer]
            state.network.nodes[node].machine.layers[layer].maxHP = max(hardened.maxHP, hardened.hp)
            emit(.nodeHardened(node: node, layer: hardened.kind, amount: network.hardenAmount, hp: hardened.hp))
        case .spawnICE(let node, let iceID):
            guard state.network.nodes[node].owner == .sysop,
                state.network.nodes[node].machine.ice.count < network.maxICE
            else {
                emit(.sysopFizzled(intent))
                return
            }
            emit(.sysopActed(intent))
            state.network.nodes[node].machine.ice.append(iceID)
            emit(.iceSpawned(node: node, iceID: iceID))
        case .sweep:
            emit(.sysopActed(intent))
            changeTrace(by: network.sweepTrace)
        }
    }

    /// The sysop takes a node back. Its layers stand again at full, and it
    /// gains a KERNEL if it had none. Losing ENTRY ends the contract.
    private mutating func loseNode(_ index: Int) {
        var node = state.network.nodes[index]
        node.owner = .sysop
        node.contested = false
        for layer in node.machine.layers.indices {
            node.machine.layers[layer].hp = node.machine.layers[layer].maxHP
        }
        if !node.machine.layers.contains(where: { $0.kind == .kernel }), let range = content.tuning.roles.sysop.kernel {
            let bonus = node.machine.ramMB / content.tuning.ice.ramPerLayerHP
            node.machine.layers.append(
                SecurityLayer(kind: .kernel, hp: state.rng.nextInt(in: range.min...range.max) + bonus))
        }
        node.machine.role = .sysop
        state.network.nodes[index] = node
        emit(.nodeLost(node: index))
        if node.type == .entry {
            end(.entryLost)
        }
    }

    /// Chooses and announces the next intent (kickoff §3, step 4): a
    /// weighted kind among those that have a target, then a target.
    mutating func telegraphSysop() {
        let nodes = state.network.nodes
        let sysopNodes = nodes.indices.filter { nodes[$0].owner == .sysop }
        let contestable = nodes.indices.filter { index in
            nodes[index].owner == .player && !nodes[index].contested
                && state.network.neighbours(of: index).contains { nodes[$0].owner == .sysop }
        }
        let spawnable = sysopNodes.filter { nodes[$0].machine.ice.count < network.maxICE }
        let weights = network.sysopIntents
        var table: [(Int, Int)] = []
        if !contestable.isEmpty { table.append((0, weights.contest)) }
        if !sysopNodes.isEmpty { table.append((1, weights.harden)) }
        if !spawnable.isEmpty && !content.tuning.roles.sysop.icePool.isEmpty { table.append((2, weights.spawnICE)) }
        table.append((3, weights.sweep))
        let total = table.reduce(0) { $0 + max(0, $1.1) }
        var roll = state.rng.nextInt(below: max(1, total))
        var kind = 3
        for (candidate, weight) in table where weight > 0 {
            if roll < weight {
                kind = candidate
                break
            }
            roll -= weight
        }
        let intent: SysopIntent
        switch kind {
        case 0:
            let node = state.rng.pick(contestable) ?? 0
            state.network.nodes[node].contested = true
            intent = .contest(node: node)
        case 1:
            intent = .harden(node: state.rng.pick(sysopNodes) ?? 0)
        case 2:
            let node = state.rng.pick(spawnable) ?? 0
            intent = .spawnICE(node: node, iceID: state.rng.pick(content.tuning.roles.sysop.icePool) ?? "")
        default:
            intent = .sweep
        }
        state.sysopIntent = intent
        emit(.sysopTelegraphed(intent))
    }
}
