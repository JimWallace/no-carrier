public import CarrierCore

/// Plays many cracks with `CrackBot` and counts how they ended, to tune the
/// crack between playtests. Run `i` uses `Seed.derive(seed, "crack/i")`.
public struct CrackSimulation: Sendable {
    public let engine: CrackEngine

    public init(content: CrackContent) {
        engine = CrackEngine(content: content)
    }

    public func run(runs: Int, seed: UInt64) -> CrackReport {
        var report = CrackReport(runs: runs, guessLimit: guessLimit)
        for index in 0..<max(0, runs) {
            var (state, _) = engine.start(seed: Seed.derive(seed, "crack/\(index)"))
            var bot = CrackBot(engine: engine)
            var actions = 0
            while !state.isOver && actions < 1000 {
                let action = bot.next(state)
                if case .play(let card, _) = action, engine.kind(state.hand[card]) == .probe {
                    report.probes += 1
                }
                state = engine.apply(action, to: state).0
                actions += 1
            }
            report.add(state)
        }
        return report
    }

    /// The most guesses the alarm allows.
    public var guessLimit: Int {
        let alarm = engine.content.alarm
        return (alarm.max + alarm.perGuess - 1) / alarm.perGuess
    }
}

/// How a batch of cracks ended.
public struct CrackReport: Sendable, Equatable {
    public let runs: Int
    public let guessLimit: Int
    public var cracked = 0
    public var traced = 0
    public var probes = 0
    /// `byGuesses[n]`: cracks that took n guesses.
    public var byGuesses: [Int]

    init(runs: Int, guessLimit: Int) {
        self.runs = runs
        self.guessLimit = guessLimit
        byGuesses = Array(repeating: 0, count: guessLimit + 1)
    }

    mutating func add(_ state: CrackState) {
        switch state.outcome {
        case .cracked:
            cracked += 1
            if byGuesses.indices.contains(state.guesses.count) { byGuesses[state.guesses.count] += 1 }
        case .traced:
            traced += 1
        case .loggedOut, nil:
            break
        }
    }

    /// Cracks that took at most `guesses` guesses, as a whole percent of
    /// all runs.
    public func percentWithin(_ guesses: Int) -> Int {
        guard runs > 0 else { return 0 }
        return byGuesses.prefix(guesses + 1).reduce(0, +) * 100 / runs
    }

    /// The mean guesses of a crack, in tenths (`47` is 4.7).
    public var meanGuessesTenths: Int {
        guard cracked > 0 else { return 0 }
        let total = byGuesses.enumerated().reduce(0) { $0 + $1.offset * $1.element }
        return total * 10 / cracked
    }
}
