import CarrierCore
import CarrierSim
import TestSupport
import Testing

/// The crack bot and its simulation (addendum 03).
@Suite struct CrackSimulationTests {
    let content: CrackContent

    init() throws {
        content = try #require(try BundledContent.load().crack)
    }

    @Test func theSameSeedGivesTheSameReport() throws {
        let simulation = CrackSimulation(content: content, server: try #require(content.server("corporate")))
        #expect(simulation.run(runs: 20, seed: 5) == simulation.run(runs: 20, seed: 5))
    }

    @Test func theBotCracksMostKioskCodes() throws {
        let report = CrackSimulation(content: content, server: try #require(content.server("kiosk")))
            .run(runs: 100, seed: 5)
        #expect(report.cracked + report.traced == 100)
        #expect(report.cracked >= 80)
        #expect(report.probes > 0)
    }

    @Test func theGuessLimitCountsEscalation() throws {
        var server = try #require(content.server("root"))
        server.alarmPerGuess = 10
        server.escalation = 10
        // 10 + 20 + 30 + 40 reaches 100 on the fourth guess.
        #expect(CrackSimulation(content: content, server: server).guessLimit == 4)
    }

    /// Every server style, including ROTATE: the bot's candidates always
    /// hold the real code, so it reads every style and follows rotations.
    @Test(arguments: ["kiosk", "corporate", "root"])
    func theBotNeverRulesOutTheRealCode(serverID: String) throws {
        let server = try #require(content.server(serverID))
        let engine = CrackEngine(content: content)
        for seed in 0..<UInt64(20) {
            var (state, _) = engine.start(seed: seed, server: server)
            var bot = CrackBot(engine: engine, server: server)
            while !state.isOver {
                // The bot learns when asked for a move, so check then.
                let action = bot.next(state)
                #expect(bot.candidates.contains(state.code))
                state = engine.apply(action, to: state).0
            }
        }
    }
}
