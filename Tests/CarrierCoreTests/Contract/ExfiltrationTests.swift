import CarrierCore
import TestSupport
import Testing

/// Addendum 01, §3.2: EXFILTRATION.
@Suite struct ExfiltrationTests {
    func exfil(seed: UInt64 = 1994) throws -> ContractFixture {
        try ContractFixture(seed: seed, objective: "exfiltration")
    }

    @Test func theTargetIsMarkedAwayFromEntry() throws {
        for seed in 0..<40 {
            let fixture = try exfil(seed: UInt64(seed))
            let target = try #require(fixture.state.targetNode)
            let node = fixture.state.network.nodes[target]
            #expect(node.type == .data)
            #expect(node.visibility != .hidden)
            #expect(!node.machine.layers.contains { $0.kind == .kernel })
            #expect((6...12).contains(fixture.state.fileMB))
            let entry = try #require(fixture.state.network.nodes.firstIndex { $0.type == .entry })
            #expect((fixture.state.network.distances(from: entry)[target] ?? 0) >= 2)
        }
    }

    @Test func takeoverHasNoTarget() throws {
        let fixture = try ContractFixture()
        #expect(fixture.state.targetNode == nil)
    }

    /// Breaches the TARGET with one BRUTE.EXE, then ends turns until the
    /// file is copied.
    func copyTheFile(_ fixture: inout ContractFixture) throws {
        let target = try #require(fixture.state.targetNode)
        fixture.state.network.nodes[target].visibility = .scanned
        fixture.state.network.nodes[target].machine.layers = [SecurityLayer(kind: .firewall, hp: 1)]
        fixture.state.network.nodes[target].machine.ice = []
        let neighbour = try #require(fixture.state.network.neighbours(of: target).first)
        fixture.state.network.nodes[neighbour].owner = .player
        fixture.state.deck = Array(repeating: "brute", count: 10)
        fixture.apply(.attack(node: target))
        let events = fixture.apply(.fight(.play(handIndex: 0)))
        #expect(!events.contains(.accessChoiceOffered(node: target)))
        for _ in 0..<12 where fixture.state.fight?.transfer?.isComplete == false {
            fixture.apply(.fight(.endTurn))
        }
    }

    @Test func copyingTheFileThenJackingOutWins() throws {
        var fixture = try exfil()
        try copyTheFile(&fixture)
        let events = fixture.apply(.fight(.logout))
        #expect(events.contains(.fileCopied(fileMB: fixture.state.fileMB)))
        #expect(fixture.state.hasFile)
        #expect(fixture.state.outcome == nil)
        fixture.state.alertState = .dormant
        let ending = fixture.apply(.jackOut)
        #expect(ending.contains(.payout(.clean)))
        #expect(fixture.state.outcome == .won)
    }

    @Test(arguments: [(AlertState.suspicious, PayoutTier.full), (.active, .half)])
    func payoutFollowsTheAlertState(alert: AlertState, tier: PayoutTier) throws {
        var fixture = try exfil()
        fixture.state.hasFile = true
        fixture.state.alertState = alert
        fixture.apply(.jackOut)
        #expect(fixture.state.payout == tier)
        #expect(fixture.state.outcome == .won)
    }

    @Test func leavingBeforeTheCopyEndsGetsNothing() throws {
        var fixture = try exfil()
        let target = try #require(fixture.state.targetNode)
        fixture.state.network.nodes[target].machine.layers = [SecurityLayer(kind: .firewall, hp: 1)]
        let neighbour = try #require(fixture.state.network.neighbours(of: target).first)
        fixture.state.network.nodes[neighbour].owner = .player
        fixture.state.deck = Array(repeating: "brute", count: 10)
        fixture.apply(.attack(node: target))
        fixture.apply(.fight(.play(handIndex: 0)))
        fixture.apply(.fight(.logout))
        #expect(!fixture.state.hasFile)
        #expect(fixture.apply(.jackOut).contains(.contractEnded(outcome: .jackedOut)))
    }

    @Test func ghostDaemonSilencesTheFirstCardEachTurn() throws {
        var fixture = try exfil()
        let target = fixture.target
        fixture.state.deck = ["ghost-dmn"] + Array(repeating: "forkbomb", count: 9)
        fixture.state.rig.cycles = 9
        // No WATCHDOG to purge the daemon.
        fixture.state.network.nodes[target].machine.ice = []
        fixture.state.network.nodes[target].machine.layers = [SecurityLayer(kind: .firewall, hp: 200)]
        fixture.apply(.attack(node: target))
        let hand = try #require(fixture.state.fight?.hand.map(\.cardID))
        guard let ghost = hand.firstIndex(of: "ghost-dmn") else {
            fixture.state.phase = .map
            return
        }
        fixture.apply(.fight(.play(handIndex: ghost)))
        // The rest of this turn is loud.
        let before = fixture.state.alert
        fixture.apply(.fight(.play(handIndex: 0)))
        #expect(fixture.state.alert == before + 3)
        guard fixture.state.fight != nil else { return }
        fixture.apply(.fight(.endTurn))
        guard fixture.state.fight != nil else { return }
        let quiet = fixture.state.alert
        fixture.apply(.fight(.play(handIndex: 0)))
        #expect(fixture.state.alert == quiet)
        fixture.apply(.fight(.play(handIndex: 0)))
        #expect(fixture.state.alert == quiet + 3)
    }

    @Test func scrubLowersAlert() throws {
        var fixture = try exfil()
        fixture.state.alert = 20
        fixture.state.alertState = .dormant
        fixture.state.deck = Array(repeating: "scrub", count: 6)
        fixture.apply(.attack(node: fixture.target))
        fixture.apply(.fight(.play(handIndex: 0)))
        #expect(fixture.state.alert == 15)
    }

    @Test func onlyExfiltrationLootsTheNewCards() throws {
        let content = try BundledContent.load()
        let takeover = try #require(content.objective("takeover"))
        let exfiltration = try #require(content.objective("exfiltration"))
        #expect(takeover.extraRewards.isEmpty)
        #expect(Set(exfiltration.extraRewards) == ["compress", "scrub", "ghost-dmn", "null-route"])
        #expect(content.tuning.network.rewardPool.allSatisfy { !exfiltration.extraRewards.contains($0) })
    }
}

/// Findings of the M6 review.
@Suite struct ExfiltrationEdgeCaseTests {
    @Test func aCaptureAfterTheFileDoesNotEndTheContract() throws {
        var fixture = try ContractFixture(objective: "exfiltration")
        fixture.state.hasFile = true
        let target = fixture.target
        fixture.state.network.nodes[target].type = .relay
        _ = fixture.captureEasy(target)
        if case .upgrade = fixture.state.phase { return }
        #expect(fixture.state.outcome == nil)
        #expect(fixture.state.network.nodes[target].owner == .player || fixture.state.phase != .map)
    }

    @Test func ghostDaemonDoesNotCancelScrub() throws {
        var fixture = try ContractFixture(objective: "exfiltration")
        let target = fixture.target
        fixture.state.alert = 20
        fixture.state.network.nodes[target].machine.ice = []
        fixture.state.deck = Array(repeating: "scrub", count: 10)
        fixture.state.rig.cycles = 9
        fixture.apply(.attack(node: target))
        guard case .fight(let node, var fight, let deck) = fixture.state.phase else {
            Issue.record("no fight")
            return
        }
        fight.daemons = [CardInstance(uid: 99, cardID: "ghost-dmn")]
        fixture.state.phase = .fight(node: node, state: fight, deck: deck)
        fixture.apply(.fight(.play(handIndex: 0)))
        #expect(fixture.state.alert == 15)
    }

    @Test func compressWithNoTransferSaysSo() throws {
        let content = try BundledContent.load()
        var fixture = FightFixture()
        fixture.hand = ["compress"]
        let (_, events) = Engine(content: content).apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(events.contains(.cardHadNoEffect(cardID: "compress")))
    }
}
