import CarrierCore
import CarrierSim
import TestSupport
import Testing

/// The crack bot and its simulation (addendum 03).
@Suite struct CrackSimulationTests {
    @Test func theSameSeedGivesTheSameReport() throws {
        let simulation = CrackSimulation(content: try #require(try BundledContent.load().crack))
        #expect(simulation.run(runs: 20, seed: 5) == simulation.run(runs: 20, seed: 5))
    }

    @Test func theBotCracksMostCodesWithTheBundledTuning() throws {
        let report = CrackSimulation(content: try #require(try BundledContent.load().crack)).run(runs: 100, seed: 5)
        #expect(report.cracked + report.traced == 100)
        #expect(report.cracked >= 50)
        #expect(report.probes > 0)
    }

    @Test func theBotOnlyEverAimsAtCodesThatFitTheFeedback() throws {
        let engine = CrackEngine(content: try #require(try BundledContent.load().crack))
        var (state, _) = engine.start(seed: 21)
        var bot = CrackBot(engine: engine)
        while !state.isOver {
            state = engine.apply(bot.next(state), to: state).0
            #expect(bot.candidates.contains(state.code) || state.isOver)
        }
    }
}
