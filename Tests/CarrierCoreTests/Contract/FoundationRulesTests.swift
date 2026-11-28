import CarrierCore
import TestSupport
import Testing

/// Addendum 01, §2: Noise and Alert, access, fog, SCAN and JACK OUT, on the
/// INFILTRATE test objective (Alert 0, fog on, GHOST allowed).
@Suite struct FoundationRulesTests {
    func infiltrate() throws -> ContractFixture {
        try ContractFixture(objective: "infiltrate")
    }

    @Test func aQuietStartIsDormantAndFogged() throws {
        let fixture = try infiltrate()
        let state = fixture.state
        #expect(state.alert == 0)
        #expect(state.alertState == .dormant)
        #expect(state.sysopIntent == nil)
        let entry = try #require(state.network.nodes.first { $0.type == .entry })
        #expect(entry.visibility == .scanned)
        for node in state.network.nodes where node.index != entry.index {
            let linked = state.network.isLinked(node.index, entry.index)
            #expect(node.visibility == (linked ? .detected : .hidden))
        }
        #expect(state.network.attackable.allSatisfy { state.network.isLinked($0, entry.index) })
    }

    @Test func cardsMakeNoiseAndQuietTicksDecay() throws {
        var fixture = try infiltrate()
        let target = fixture.target
        fixture.state.deck = Array(repeating: "forkbomb", count: 10)
        fixture.apply(.attack(node: target))
        let events = fixture.apply(.fight(.play(handIndex: 0)))
        #expect(events.contains(.alertChanged(by: 3, total: 3)))
        fixture.apply(.fight(.logout))
        #expect(fixture.state.alert == 3)
        fixture.apply(.wait)
        #expect(fixture.state.alert == 0)
    }

    @Test func dictionaryMakesNoisePerCycleAndSpoofLowersAlert() throws {
        var fixture = try infiltrate()
        fixture.state.alert = 20
        fixture.state.deck = ["dictionary", "spoof", "spoof", "spoof", "spoof"]
        fixture.apply(.attack(node: fixture.target))
        let hand = try #require(fixture.state.fight?.hand.map(\.cardID))
        let spoof = try #require(hand.firstIndex(of: "spoof"))
        fixture.apply(.fight(.play(handIndex: spoof)))
        #expect(fixture.state.alert == 18)
        let dictionary = try #require(fixture.state.fight?.hand.firstIndex { $0.cardID == "dictionary" })
        fixture.apply(.fight(.play(handIndex: dictionary)))
        #expect(fixture.state.alert == 20)
    }

    @Test func suspiciousSysopsOnlyDefend() throws {
        var fixture = try infiltrate()
        fixture.state.alert = 29
        fixture.state.deck = Array(repeating: "brute", count: 10)
        fixture.apply(.attack(node: fixture.target))
        let events = fixture.apply(.fight(.play(handIndex: 0)))
        #expect(events.contains(.alertStateChanged(.suspicious)))
        fixture.apply(.fight(.logout))
        for _ in 0..<20 {
            switch fixture.state.sysopIntent {
            case .harden, .spawnICE, nil: break
            default: Issue.record("a SUSPICIOUS sysop announced \(String(describing: fixture.state.sysopIntent))")
            }
            fixture.state.alert = 40
            fixture.apply(.wait)
        }
    }

    @Test func driftFollowsTheAlertState() throws {
        var fixture = try infiltrate()
        let trace = fixture.state.trace
        fixture.apply(.wait)
        #expect(fixture.state.trace == trace)
        fixture.state.alert = 40
        fixture.state.alertState = .suspicious
        fixture.state.sysopIntent = nil
        fixture.apply(.wait)
        #expect(fixture.state.trace == trace + 1)
    }

    @Test func activeStaysActive() throws {
        var fixture = try infiltrate()
        fixture.state.alert = 69
        fixture.state.alertState = .suspicious
        fixture.state.deck = Array(repeating: "brute", count: 5) + Array(repeating: "spoof", count: 5)
        fixture.apply(.attack(node: fixture.target))
        let hand = try #require(fixture.state.fight?.hand.map(\.cardID))
        if let brute = hand.firstIndex(of: "brute") {
            fixture.apply(.fight(.play(handIndex: brute)))
        }
        #expect(fixture.state.alertState == .active)
        if let spoof = fixture.state.fight?.hand.firstIndex(where: { $0.cardID == "spoof" }) {
            fixture.apply(.fight(.play(handIndex: spoof)))
            #expect(fixture.state.alert < 70)
        }
        #expect(fixture.state.alertState == .active)
    }

    @Test func breachingAuthOffersGhostAndGhostGivesAccess() throws {
        var fixture = try infiltrate()
        let target = fixture.target
        fixture.makeEasy(target)
        fixture.apply(.attack(node: target))
        let offered = fixture.apply(.fight(.play(handIndex: 0)))
        #expect(offered.contains(.accessChoiceOffered(node: target)))
        let alert = fixture.state.alert
        let events = fixture.apply(.ghost)
        #expect(events.contains(.accessGained(node: target)))
        let node = fixture.state.network.nodes[target]
        #expect(node.accessed)
        #expect(node.owner != .player)
        #expect(node.visibility == .scanned)
        #expect(fixture.state.alert == alert + 3)
        #expect(fixture.state.phase == .map)
        for neighbour in fixture.state.network.neighbours(of: target) {
            #expect(fixture.state.network.nodes[neighbour].visibility != .hidden)
        }
        let beyond = fixture.state.network.neighbours(of: target).filter {
            $0 != 0 && !fixture.state.network.isLinked($0, 0)
        }
        for node in beyond where fixture.state.network.nodes[node].owner != .player {
            #expect(fixture.state.network.attackable.contains(node))
        }
    }

    @Test func claimFightsOnAndCaptures() throws {
        var fixture = try infiltrate()
        let target = fixture.target
        fixture.state.network.nodes[target].type = .relay
        fixture.makeEasy(target)
        fixture.apply(.attack(node: target))
        fixture.apply(.fight(.play(handIndex: 0)))
        let events = fixture.apply(.claim)
        #expect(events.contains(.nodeCaptured(node: target)))
        #expect(fixture.state.network.nodes[target].owner == .player)
    }

    @Test func claimOnAKernelNodeKeepsFighting() throws {
        var fixture = try infiltrate()
        let target = fixture.target
        fixture.state.network.nodes[target].machine.layers = [
            SecurityLayer(kind: .firewall, hp: 1), SecurityLayer(kind: .kernel, hp: 20),
        ]
        fixture.state.network.nodes[target].machine.ice = []
        fixture.state.deck = Array(repeating: "brute", count: 10)
        fixture.apply(.attack(node: target))
        fixture.apply(.fight(.play(handIndex: 0)))
        #expect(fixture.state.phase != .map)
        fixture.apply(.claim)
        guard case .fight = fixture.state.phase else {
            Issue.record("expected the fight to go on, got \(fixture.state.phase)")
            return
        }
        let events = fixture.apply(.fight(.play(handIndex: 0)))
        #expect(!events.contains(.accessChoiceOffered(node: target)))
    }

    @Test func revokeTakesAccessUnlessReinforced() throws {
        var fixture = try infiltrate()
        let target = fixture.target
        fixture.makeEasy(target)
        fixture.apply(.attack(node: target))
        fixture.apply(.fight(.play(handIndex: 0)))
        fixture.apply(.ghost)
        fixture.state.alertState = .active
        fixture.state.network.nodes[target].contested = true
        fixture.state.sysopIntent = .revoke(node: target)
        fixture.apply(.reinforce(node: target))
        #expect(fixture.state.network.nodes[target].accessed)
        fixture.state.network.nodes[target].contested = true
        fixture.state.sysopIntent = .revoke(node: target)
        let events = fixture.apply(.wait)
        #expect(events.contains(.accessRevoked(node: target)))
        #expect(!fixture.state.network.nodes[target].accessed)
    }

    @Test func accessedNodesDoNotProduce() throws {
        var fixture = try infiltrate()
        let target = fixture.target
        fixture.state.network.nodes[target].type = .virus
        fixture.makeEasy(target)
        fixture.apply(.attack(node: target))
        fixture.apply(.fight(.play(handIndex: 0)))
        fixture.apply(.ghost)
        let deck = fixture.state.deck.count
        fixture.apply(.wait)
        #expect(fixture.state.deck.count == deck)
    }

    @Test func scanRevealsADetectedNodeForAlert() throws {
        var fixture = try infiltrate()
        let target = fixture.target
        #expect(fixture.state.network.nodes[target].visibility == .detected)
        let tick = fixture.state.tick
        let events = fixture.apply(.scan(node: target))
        #expect(events.contains(.nodeRevealed(node: target, visibility: .scanned)))
        #expect(events.contains(.alertChanged(by: 2, total: 2)))
        #expect(fixture.state.tick == tick + 1)
        #expect(fixture.apply(.scan(node: target)) == [.actionRejected(reason: .notDetected(node: target))])
    }

    @Test func probeScansTheNode() throws {
        var fixture = try infiltrate()
        let target = fixture.target
        fixture.state.deck = Array(repeating: "probe", count: 10)
        fixture.apply(.attack(node: target))
        let events = fixture.apply(.fight(.play(handIndex: 0)))
        #expect(events.contains(.nodeRevealed(node: target, visibility: .scanned)))
    }

    @Test func hiddenNodesCannotBeAttacked() throws {
        var fixture = try infiltrate()
        let hidden = try #require(fixture.state.network.nodes.first { $0.visibility == .hidden })
        #expect(
            fixture.apply(.attack(node: hidden.index)) == [.actionRejected(reason: .noSuchNode(node: hidden.index))])
    }

    @Test func jackingOutEarlyFails() throws {
        var fixture = try infiltrate()
        let events = fixture.apply(.jackOut)
        #expect(events == [.jackedOut, .contractEnded(outcome: .jackedOut)])
    }

    @Test func takeoverNeverOffersGhost() throws {
        var fixture = try ContractFixture()
        let target = fixture.target
        fixture.state.network.nodes[target].type = .relay
        let events = fixture.captureEasy(target)
        #expect(!events.contains(.accessChoiceOffered(node: target)))
        #expect(fixture.state.network.nodes[target].owner == .player)
    }
}

/// Findings of the M5 review.
@Suite struct FoundationEdgeCaseTests {
    @Test func aSysopThatGoesDormantAnnouncesNothing() throws {
        var fixture = try ContractFixture(objective: "infiltrate")
        fixture.state.alert = 31
        fixture.state.alertState = .suspicious
        fixture.state.sysopIntent = nil
        fixture.apply(.wait)
        #expect(fixture.state.alertState == .dormant)
        #expect(fixture.state.sysopIntent == nil)
    }

    @Test func anAccessedNodeCanBeClaimedWithoutALinkedFoothold() throws {
        var fixture = try ContractFixture(objective: "infiltrate")
        let target = fixture.target
        fixture.state.network.nodes[target].accessed = true
        for neighbour in fixture.state.network.neighbours(of: target) where neighbour != target {
            fixture.state.network.nodes[neighbour].owner = .neutral
        }
        #expect(fixture.state.network.attackable.contains(target))
    }
}
