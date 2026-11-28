import CarrierCore
import TestSupport
import Testing

/// THE OPERATOR switches pattern once the machine is down to its KERNEL.
@Suite struct BossTests {
    @Test func operatorChangesTacticsAtTheKernel() throws {
        let content = try BundledContent.load()
        let engine = Engine(content: content)
        var fixture = FightFixture()
        fixture.ice = ["operator"]
        fixture.layers = [
            SecurityLayer(kind: .firewall, hp: 0), SecurityLayer(kind: .auth, hp: 0),
            SecurityLayer(kind: .kernel, hp: 20),
        ]
        let state = fixture.state(content: content)
        #expect(
            engine.telegraph(state.fight, rules: state.rules).first?.intents == [.trace(amount: 4), .attack(amount: 6)])
        let (after, events) = engine.apply(.endTurn, to: state)
        #expect(events.contains(.icePhaseChanged(iceID: "operator")))
        #expect(after.fight.trace == 4)
        #expect(after.fight.ice.first?.inPhaseTwo == true)
        #expect(
            engine.telegraph(after.fight, rules: after.rules).first?.intents == [
                .injectMalware(cardID: "tracer"), .attack(amount: 5),
            ])
    }

    @Test func operatorUsesItsFirstPatternBeforeTheKernel() throws {
        let content = try BundledContent.load()
        var fixture = FightFixture()
        fixture.ice = ["operator"]
        let state = fixture.state(content: content)
        #expect(
            Engine(content: content).telegraph(state.fight, rules: state.rules).first?.intents == [.attack(amount: 6)])
    }
}
