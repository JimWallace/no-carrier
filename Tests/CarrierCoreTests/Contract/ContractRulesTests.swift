import CarrierCore
import CarrierGen
import TestSupport
import Testing

/// Kickoff §3: the network layer.
@Suite struct ContractRulesTests {
    @Test func theContractStartsOnTheMapWithASysopIntent() throws {
        let fixture = try ContractFixture()
        #expect(fixture.state.phase == .map)
        #expect(fixture.state.tick == 1)
        #expect(fixture.state.sysopIntent != nil)
        #expect(fixture.state.deck == fixture.content.tuning.starterDeck)
    }

    @Test func attackNeedsALink() throws {
        var fixture = try ContractFixture()
        let unlinked = try #require(
            fixture.state.network.nodes.indices.first { index in
                fixture.state.network.nodes[index].owner != .player && !fixture.state.network.attackable.contains(index)
            })
        let before = fixture.state
        let events = fixture.apply(.attack(node: unlinked))
        #expect(events == [.actionRejected(reason: .notLinked(node: unlinked))])
        #expect(fixture.state == before)
        #expect(fixture.apply(.attack(node: 0)) == [.actionRejected(reason: .alreadyOwned(node: 0))])
        #expect(fixture.apply(.attack(node: 42)) == [.actionRejected(reason: .noSuchNode(node: 42))])
    }

    @Test func captureGivesTheNodeAndOffersLoot() throws {
        var fixture = try ContractFixture()
        let target = fixture.target
        fixture.state.network.nodes[target].type = .relay
        let events = fixture.captureEasy(target)
        #expect(events.contains(.nodeCaptured(node: target)))
        #expect(fixture.state.network.nodes[target].owner == .player)
        guard case .reward(_, let choices) = fixture.state.phase else {
            Issue.record("expected the reward phase, got \(fixture.state.phase)")
            return
        }
        #expect(choices.count == 3)
        #expect(Set(choices).count == 3)
        let tick = fixture.state.tick
        fixture.apply(.takeReward(choice: 1, replacing: nil))
        #expect(fixture.state.deck.last == choices[1])
        #expect(fixture.state.tick == tick + 1)
    }

    @Test func aFullDeckMustDeleteToTakeLoot() throws {
        var fixture = try ContractFixture()
        let target = fixture.target
        fixture.state.network.nodes[target].type = .relay
        _ = fixture.captureEasy(target)
        fixture.state.deck = Array(repeating: "brute", count: fixture.state.storage)
        #expect(fixture.apply(.takeReward(choice: 0, replacing: nil)) == [.actionRejected(reason: .storageFull)])
        fixture.state.deck[3] = "proxy"
        fixture.apply(.takeReward(choice: 0, replacing: 3))
        #expect(fixture.state.deck.count == fixture.state.storage)
        #expect(!fixture.state.deck.contains("proxy"))
    }

    @Test func dataGivesAnUpgradeThenLoot() throws {
        var fixture = try ContractFixture()
        let target = fixture.target
        fixture.state.network.nodes[target].type = .data
        _ = fixture.captureEasy(target)
        guard case .upgrade = fixture.state.phase else {
            Issue.record("expected the upgrade phase, got \(fixture.state.phase)")
            return
        }
        let cycles = fixture.state.rig.cycles
        fixture.apply(.chooseUpgrade(choice: 0))
        #expect(fixture.state.rig.cycles == cycles + 1)
        #expect(fixture.state.network.nodes[target].upgradeTaken)
        guard case .reward = fixture.state.phase else {
            Issue.record("expected the reward phase, got \(fixture.state.phase)")
            return
        }
    }

    @Test func logoutLeavesTheNodeAndEndsTheTick() throws {
        var fixture = try ContractFixture()
        let target = fixture.target
        let machine = fixture.state.network.nodes[target].machine
        fixture.apply(.attack(node: target))
        #expect(fixture.state.fight != nil)
        let events = fixture.apply(.fight(.logout))
        #expect(events.contains(.nodeLeft(node: target)))
        #expect(fixture.state.network.nodes[target].machine == machine)
        #expect(fixture.state.network.nodes[target].owner != .player)
        #expect(fixture.state.tick == 2)
        #expect(fixture.state.trace >= fixture.content.tuning.trace.logout + fixture.content.tuning.network.traceDrift)
    }

    @Test func relaysGiveStartingProxy() throws {
        var fixture = try ContractFixture()
        let target = fixture.target
        fixture.state.network.nodes[0].type = .relay
        let events = fixture.apply(.attack(node: target))
        #expect(events.first == .fightStarting(node: target, startingProxy: 2))
        #expect(fixture.state.fight?.proxy == 2)
    }

    @Test func playedPayloadLeavesTheDeck() throws {
        var fixture = try ContractFixture()
        let target = fixture.target
        fixture.state.network.nodes[target].machine.layers = [
            SecurityLayer(kind: .firewall, hp: 0), SecurityLayer(kind: .kernel, hp: 5),
        ]
        fixture.state.network.nodes[target].machine.ice = []
        fixture.state.network.nodes[target].type = .relay
        fixture.state.deck = Array(repeating: "payload", count: 6)
        fixture.apply(.attack(node: target))
        let events = fixture.apply(.fight(.play(handIndex: 0)))
        #expect(events.contains(.cardsSpent(cardIDs: ["payload"])))
        #expect(fixture.state.deck.count { $0 == "payload" } == 5)
    }

    @Test func repairAndVirusProduceAtTheEndOfTheTick() throws {
        var fixture = try ContractFixture()
        fixture.state.network.nodes[0].type = .repair
        fixture.state.integrity = 30
        var events = fixture.apply(.wait)
        #expect(events.contains(.integrityRepaired(amount: 3, total: 33)))
        fixture.state.network.nodes[0].type = .virus
        let size = fixture.state.deck.count
        events = fixture.apply(.wait)
        #expect(fixture.state.deck.count == size + 1)
        #expect(fixture.state.deck.last == "payload")
        fixture.state.deck = Array(repeating: "brute", count: fixture.state.storage)
        events = fixture.apply(.wait)
        #expect(events.contains(.storageFull))
        #expect(fixture.state.deck.count == fixture.state.storage)
    }

    @Test func traceDriftsEveryTick() throws {
        var fixture = try ContractFixture()
        fixture.state.sysopIntent = nil
        let before = fixture.state.trace
        fixture.apply(.wait)
        #expect(fixture.state.trace == before + 3)
    }

    @Test func contestFlipsANodeUnlessReinforced() throws {
        var fixture = try ContractFixture()
        let target = fixture.target
        fixture.state.network.nodes[target].type = .relay
        _ = fixture.captureEasy(target)
        fixture.apply(.skipReward)
        fixture.state.network.nodes[target].contested = true
        fixture.state.sysopIntent = .contest(node: target)
        fixture.apply(.reinforce(node: target))
        #expect(fixture.state.network.nodes[target].owner == .player)

        fixture.state.network.nodes[target].contested = true
        fixture.state.sysopIntent = .contest(node: target)
        let events = fixture.apply(.wait)
        #expect(events.contains(.nodeLost(node: target)))
        let node = fixture.state.network.nodes[target]
        #expect(node.owner == .sysop)
        #expect(node.machine.layers.last?.kind == .kernel)
        #expect(node.machine.layers.allSatisfy { $0.hp > 0 })
    }

    @Test func losingEntryEndsTheContract() throws {
        var fixture = try ContractFixture()
        fixture.state.network.nodes[0].contested = true
        fixture.state.sysopIntent = .contest(node: 0)
        fixture.apply(.wait)
        #expect(fixture.state.outcome == .entryLost)
    }

    @Test func hardenAndSpawnChangeSysopNodes() throws {
        var fixture = try ContractFixture()
        let sysop = try #require(fixture.state.network.nodes.firstIndex { $0.owner == .sysop && $0.type != .root })
        let hp = fixture.state.network.nodes[sysop].machine.layers[0].hp
        fixture.state.sysopIntent = .harden(node: sysop)
        fixture.apply(.wait)
        #expect(fixture.state.network.nodes[sysop].machine.layers[0].hp == hp + 5)
        fixture.state.network.nodes[sysop].machine.ice = ["sentry"]
        fixture.state.sysopIntent = .spawnICE(node: sysop, iceID: "blackice")
        fixture.apply(.wait)
        #expect(fixture.state.network.nodes[sysop].machine.ice == ["sentry", "blackice"])
    }

    @Test func sweepAddsTrace() throws {
        var fixture = try ContractFixture()
        fixture.state.sysopIntent = .sweep
        let before = fixture.state.trace
        fixture.apply(.wait)
        #expect(fixture.state.trace == before + 8 + 3)
    }

    @Test func fullTraceEndsTheContract() throws {
        var fixture = try ContractFixture()
        fixture.state.sysopIntent = nil
        fixture.state.trace = 98
        fixture.apply(.wait)
        #expect(fixture.state.outcome == .traced)
    }

    @Test func capturingRootWins() throws {
        var fixture = try ContractFixture()
        let root = try #require(fixture.state.network.nodes.firstIndex { $0.type == .root })
        let neighbour = try #require(fixture.state.network.neighbours(of: root).first)
        fixture.state.network.nodes[neighbour].owner = .player
        _ = fixture.captureEasy(root)
        #expect(fixture.state.outcome == .won)
    }

    @Test func flatliningInAFightEndsTheContract() throws {
        var fixture = try ContractFixture()
        fixture.state.integrity = 1
        let target = fixture.target
        fixture.state.network.nodes[target].machine.ice = ["blackice"]
        fixture.apply(.attack(node: target))
        fixture.apply(.fight(.endTurn))
        #expect(fixture.state.outcome == .flatlined)
    }
}
