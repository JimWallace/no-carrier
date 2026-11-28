import CarrierCore
import CarrierGen
import Foundation
import TestSupport
import Testing

/// Addendum 02, §1, "Testing": every flag with it on and with it off.
@Suite struct MechanicFlagTests {
    func fixture(_ objective: String, _ flags: FlagSetting...) throws -> ContractFixture {
        try ContractFixture(objective: objective, flags: flags)
    }

    /// Plays one FORKBOMB (noise 3) on the first target.
    func makeNoise(_ fixture: inout ContractFixture) -> [ContractEvent] {
        fixture.state.deck = Array(repeating: "forkbomb", count: 10)
        fixture.apply(.attack(node: fixture.target))
        return fixture.apply(.fight(.play(handIndex: 0)))
    }

    // MARK: - alert

    @Test func alertOnMakesNoiseAndStartsQuiet() throws {
        var fixture = try fixture("infiltrate", FlagSetting(.alert, true))
        #expect(fixture.state.alertState == .dormant)
        #expect(makeNoise(&fixture).contains(.alertChanged(by: 3, total: 3)))
    }

    @Test func alertOffKeepsTheSysopActiveAndSilent() throws {
        var fixture = try fixture("infiltrate", FlagSetting(.alert, false))
        #expect(fixture.state.alertState == .active)
        #expect(fixture.state.alert == fixture.content.tuning.network.alert.active)
        #expect(fixture.state.sysopIntent != nil)
        let events = makeNoise(&fixture)
        #expect(!events.contains { if case .alertChanged = $0 { true } else { false } })
        #expect(fixture.state.alert == fixture.content.tuning.network.alert.active)
    }

    // MARK: - revoke

    /// A node with access, an ACTIVE sysop whose only weighted intent is
    /// REVOKE, and the tick ended so the sysop announces again.
    func nextIntentWithAccess(revoke: Bool) throws -> SysopIntent? {
        var fixture = try fixture("infiltrate", FlagSetting(.revoke, revoke))
        let target = fixture.target
        fixture.state.network.nodes[target].accessed = true
        fixture.state.alert = 80
        fixture.state.alertState = .active
        fixture.state.rules.tuning.network.sysopIntents.contest = 0
        fixture.state.rules.tuning.network.sysopIntents.harden = 0
        fixture.state.rules.tuning.network.sysopIntents.spawnICE = 0
        fixture.state.rules.tuning.network.sysopIntents.sweep = 0
        fixture.state.rules.tuning.network.sysopIntents.revoke = 1
        fixture.apply(.wait)
        return fixture.state.sysopIntent
    }

    @Test func revokeOnLetsTheSysopRevoke() throws {
        let intent = try nextIntentWithAccess(revoke: true)
        let isRevoke: Bool = if case .revoke = intent { true } else { false }
        #expect(isRevoke)
    }

    @Test func revokeOffNeverRevokes() throws {
        #expect(try nextIntentWithAccess(revoke: false) == nil)
    }

    // MARK: - ghost

    func breachEasyNode(_ fixture: inout ContractFixture) -> [ContractEvent] {
        let target = fixture.target
        fixture.makeEasy(target)
        return fixture.apply(.attack(node: target)) + fixture.apply(.fight(.play(handIndex: 0)))
    }

    @Test func ghostOnOffersTheChoice() throws {
        var fixture = try fixture("takeover", FlagSetting(.ghost, true))
        let target = fixture.target
        #expect(breachEasyNode(&fixture).contains(.accessChoiceOffered(node: target)))
    }

    @Test func ghostOffCapturesAtOnce() throws {
        var fixture = try fixture("infiltrate", FlagSetting(.ghost, false))
        let target = fixture.target
        let events = breachEasyNode(&fixture)
        #expect(!events.contains(.accessChoiceOffered(node: target)))
        #expect(fixture.state.network.nodes[target].owner == .player)
    }

    // MARK: - fog

    @Test func fogOnHidesTheNetwork() throws {
        let fixture = try fixture("takeover", FlagSetting(.fog, true))
        #expect(fixture.state.network.nodes.contains { $0.visibility == .hidden })
    }

    @Test func fogOffShowsEveryNode() throws {
        let fixture = try fixture("infiltrate", FlagSetting(.fog, false))
        #expect(fixture.state.network.nodes.allSatisfy { $0.visibility == .scanned })
    }

    // MARK: - scan

    func detectedNode(_ fixture: ContractFixture) throws -> Int {
        try #require(fixture.state.network.nodes.first { $0.visibility == .detected }?.index)
    }

    @Test func scanOnScansADetectedNode() throws {
        var fixture = try fixture("infiltrate", FlagSetting(.scan, true))
        let node = try detectedNode(fixture)
        #expect(fixture.apply(.scan(node: node)).contains(.scanned(node: node)))
    }

    @Test func scanOffRefusesScan() throws {
        var fixture = try fixture("infiltrate", FlagSetting(.scan, false))
        let node = try detectedNode(fixture)
        #expect(fixture.apply(.scan(node: node)) == [.actionRejected(reason: .ruleOff(.scan))])
    }

    // MARK: - jackOut

    @Test func jackOutOnEndsTheContract() throws {
        var fixture = try fixture("takeover", FlagSetting(.jackOut, true))
        fixture.apply(.jackOut)
        #expect(fixture.state.outcome == .jackedOut)
    }

    @Test func jackOutOffRefusesJackOut() throws {
        var fixture = try fixture("takeover", FlagSetting(.jackOut, false))
        #expect(fixture.apply(.jackOut) == [.actionRejected(reason: .ruleOff(.jackOut))])
        #expect(fixture.state.outcome == nil)
    }

    // MARK: - transfer

    @Test func transferOnMarksTheTarget() throws {
        let fixture = try fixture("exfiltration", FlagSetting(.transfer, true))
        #expect(fixture.state.targetNode != nil)
    }

    @Test func transferOffMarksNoTarget() throws {
        let fixture = try fixture("exfiltration", FlagSetting(.transfer, false))
        #expect(fixture.state.targetNode == nil)
        #expect(fixture.state.fileMB == 0)
    }

    // MARK: - objectiveLoot

    /// The loot offered after a capture, with the shared pool emptied so
    /// that only the objective's extra cards can be drawn.
    func lootWithOnlyTheExtras(objectiveLoot: Bool) throws -> [String] {
        var fixture = try fixture(
            "exfiltration", FlagSetting(.objectiveLoot, objectiveLoot), FlagSetting(.ghost, false))
        fixture.state.rules.tuning.network.rewardPool = []
        let target = try #require(
            fixture.state.network.attackable.first { fixture.state.network.nodes[$0].type != .data })
        fixture.makeEasy(target)
        fixture.apply(.attack(node: target))
        let events = fixture.apply(.fight(.play(handIndex: 0)))
        return events.compactMap { event in
            if case .rewardOffered(let ids) = event { return ids }
            return nil
        }.first ?? []
    }

    @Test func objectiveLootOnOffersTheExtraCards() throws {
        let content = try BundledContent.load()
        let extras = try #require(content.objective("exfiltration")).extraRewards
        let offered = try lootWithOnlyTheExtras(objectiveLoot: true)
        #expect(!offered.isEmpty)
        #expect(offered.allSatisfy { extras.contains($0) })
    }

    @Test func objectiveLootOffLeavesThemOut() throws {
        #expect(try lootWithOnlyTheExtras(objectiveLoot: false).isEmpty)
    }
}

/// Addendum 01, §8 and addendum 02, §1: with Alert off, TAKEOVER is the
/// MVP itself. The transcript is the M3 snapshot with nothing filtered.
@Suite struct AlertOffRegressionTests {
    @Test func takeoverWithoutAlertIsTheM3Transcript() throws {
        let content = try BundledContent.load()
        let engine = ContractEngine(content: content)
        let network = try NetworkGenerator(content: content).generate(seed: 1994)
        let takeover = try #require(content.objective("takeover"))
        let rules = try RuleSet.compose(content: content, objective: takeover, overrides: [FlagSetting(.alert, false)])
        let (initial, opening) = engine.start(seed: 1994, network: network, objective: takeover, rules: rules)
        let (final, actions, events) = GreedyContractBot(engine: engine).play(initial)
        var lines = ["SEED \(Seed.display(1994)) MAP \(initial.network.templateID)", "ACTIONS \(actions.count)"]
        lines += (opening + events).map { $0.line(content: content) }
        lines.append("OUTCOME \(final.outcome?.rawValue ?? "none") TICK \(final.tick) TRACE \(final.trace)")
        // The M3 snapshot sits in the suite folder above this one.
        let suiteFile = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("ContractTranscriptTests.swift")
        let outcome = try Snapshot.compare(
            lines.joined(separator: "\n"), named: "contract-1994", filePath: suiteFile.path)
        #expect(outcome == .matches, "\(outcome.message)")
    }
}
