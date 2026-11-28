import CarrierCore
import CarrierGen
import TestSupport
import Testing

/// Edge cases from the M2 engine review.
@Suite struct EdgeCaseTests {
    let content: ContentPack
    let engine: Engine

    init() throws {
        content = try BundledContent.load()
        engine = Engine(content: content)
    }

    @Test func aHugeHandIndexIsRefusedAndPrintable() {
        let (_, events) = engine.apply(.play(handIndex: Int.max), to: FightFixture().state(content: content))
        #expect(events == [.actionRejected(reason: .noSuchCard(handIndex: Int.max))])
        #expect(events[0].line(content: content).hasPrefix("?NO CARD"))
    }

    @Test func aHitReducedToNothingStillShows() {
        var fixture = FightFixture()
        fixture.hand = ["dictionary"]
        fixture.cycles = 0
        let (_, events) = engine.apply(.play(handIndex: 0), to: fixture.state(content: content))
        #expect(events.contains(.damageDealt(layer: .firewall, amount: 0, modifier: nil)))
    }

    @Test func traceMatchesTheTelegraphEvenWhenCloakIsPurged() {
        var fixture = FightFixture()
        fixture.ice = ["watchdog", "sentry"]
        fixture.daemons = ["cloak"]
        fixture.tracePercent = 200
        let state = fixture.state(content: content)
        #expect(engine.telegraph(state.fight, rules: state.rules).last?.intents == [.trace(amount: 4)])
        let (after, events) = engine.apply(.endTurn, to: state)
        #expect(events.contains(.daemonPurged(cardID: "cloak")))
        #expect(after.fight.trace == 4)
    }

    @Test func aFightThatStartsLostEndsAtOnce() throws {
        var setup = try SandboxFight.setup(seed: 1, role: .neutral, content: content)
        setup.trace = content.tuning.trace.max
        let (state, events) = engine.startFight(setup, rules: RuleSet.defaults(content: content, objective: nil))
        #expect(state.fight.outcome == .traced)
        #expect(!events.contains(.turnStarted(turn: 1, cycles: 3)))
    }

    @Test func validationRefusesATierWithNoIntents() throws {
        var tuning = content.tuning
        tuning.cpuTiers[0].intentsPerTurn = -1
        tuning.weakPercent = -50
        let broken = ContentPack(
            cards: content.cards, ice: content.ice, osFamilies: content.osFamilies,
            hardware: content.hardware, orgs: content.orgs, tuning: tuning, maps: content.maps,
            objectives: content.objectives, flags: content.flags
        )
        #expect(broken.validate().count == 2)
    }
}
