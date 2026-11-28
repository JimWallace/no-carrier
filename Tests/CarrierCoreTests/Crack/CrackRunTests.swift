import CarrierCore
import TestSupport
import Testing

/// The crack run (addendum 03, §8): servers in a row, a reward between
/// each, the deck carried along.
@Suite struct CrackRunTests {
    let content: CrackContent
    let engine: CrackRunEngine

    init() throws {
        content = try #require(try BundledContent.load().crack)
        engine = CrackRunEngine(content: content)
    }

    /// Plays the crack under way to its end by placing code symbols from
    /// the hand and dropping cards the code does not use. A test helper
    /// that knows the code, not a strategy.
    static func finishCrack(
        _ engine: CrackRunEngine, _ state: CrackRunState
    ) -> (CrackRunState, [CrackRunEvent]) {
        var current = state
        var events: [CrackRunEvent] = []
        var steps = 0
        while case .cracking(let crack) = current.phase, steps < 300 {
            steps += 1
            let rules = engine.crack
            var action = CrackAction.guess
            let wanted = crack.code.indices.first { slot in
                crack.board[slot]?.symbol != crack.code[slot]
                    && crack.hand.contains { rules.label($0) == crack.code[slot] }
            }
            if let slot = wanted, let card = crack.hand.firstIndex(where: { rules.label($0) == crack.code[slot] }),
                rules.rejection(of: .play(handIndex: card, slot: slot), in: crack) == nil
            {
                action = .play(handIndex: card, slot: slot)
            } else if let junk = crack.hand.firstIndex(where: { !crack.code.contains(rules.label($0)) }),
                rules.rejection(of: .drop(handIndex: junk), in: crack) == nil
            {
                action = .drop(handIndex: junk)
            }
            let result = engine.apply(.crack(action), to: current)
            current = result.0
            events += result.1
        }
        return (current, events)
    }

    func crackCurrent(_ state: CrackRunState) -> (CrackRunState, [CrackRunEvent]) {
        Self.finishCrack(engine, state)
    }

    @Test func aRunStartsOnTheFirstServerWithTheStarterDeck() throws {
        let (state, _) = engine.start(seed: 2)
        guard case .cracking(let crack) = state.phase else { throw CrackRunTestError.notCracking }
        #expect(crack.server.id == content.run.servers[0])
        #expect(state.deck == content.starterDeck)
        #expect(state.round == 0)
    }

    @Test func crackingAServerOffersARewardAndNamesTheNext() throws {
        let (after, events) = crackCurrent(engine.start(seed: 2).0)
        guard case .reward(let cards, let next) = after.phase else { throw CrackRunTestError.noReward }
        #expect(cards.count == content.run.rewardChoices)
        #expect(Set(cards).count == cards.count)
        #expect(cards.allSatisfy(content.run.rewardPool.contains))
        #expect(next == content.run.servers[1])
        #expect(events.contains(.rewardOffered(cards: cards, next: next)))
    }

    @Test func takingACardAddsItAndStartsTheNextServer() throws {
        let (atReward, _) = crackCurrent(engine.start(seed: 2).0)
        guard case .reward(let cards, _) = atReward.phase else { throw CrackRunTestError.noReward }
        let (after, _) = engine.apply(.take(0), to: atReward)
        #expect(after.deck == content.starterDeck + [cards[0]])
        guard case .cracking(let crack) = after.phase else { throw CrackRunTestError.notCracking }
        #expect(crack.server.id == content.run.servers[1])
        #expect(crack.drawPile.count + crack.hand.count == after.deck.count)
    }

    @Test func removingACardTakesItOutOfTheDeck() throws {
        let (atReward, _) = crackCurrent(engine.start(seed: 2).0)
        let (after, events) = engine.apply(.remove(0), to: atReward)
        #expect(after.deck == Array(content.starterDeck.dropFirst()))
        #expect(events.first == .removed(content.starterDeck[0]))
    }

    @Test func aFullDeckCannotTakeACard() throws {
        var full = content
        full.run.deckLimit = full.starterDeck.count
        let engine = CrackRunEngine(content: full)
        let (atReward, _) = Self.finishCrack(engine, engine.start(seed: 2).0)
        #expect(engine.apply(.take(0), to: atReward).1 == [.rejected(.deckFull)])
        #expect(engine.apply(.skip, to: atReward).1.first == .skipped)
    }

    @Test func aDeckAtItsSmallestCannotLoseACard() throws {
        var small = content
        let next = try #require(small.server(small.run.servers[1]))
        small.starterDeck = Array(small.starterDeck.prefix(small.handSize + next.codeLength))
        let engine = CrackRunEngine(content: small)
        let (atReward, _) = Self.finishCrack(engine, engine.start(seed: 2).0)
        guard case .reward = atReward.phase else { throw CrackRunTestError.noReward }
        #expect(engine.apply(.remove(0), to: atReward).1 == [.rejected(.deckTooSmall)])
    }

    @Test func rewardActionsAreRefusedInACrackAndCrackActionsAtAReward() throws {
        let (state, _) = engine.start(seed: 2)
        #expect(engine.apply(.skip, to: state).1 == [.rejected(.notAtAReward)])
        let (atReward, _) = crackCurrent(state)
        #expect(engine.apply(.crack(.guess), to: atReward).1 == [.rejected(.notInACrack)])
    }

    @Test func theRunKeepsTheCrackThatEndedForTheScreens() throws {
        let (atReward, _) = crackCurrent(engine.start(seed: 2).0)
        let last = try #require(atReward.lastCrack)
        #expect(last.outcome == .cracked)
        #expect(atReward.currentOrLastCrack == last)
        let (next, _) = engine.apply(.skip, to: atReward)
        guard case .cracking(let crack) = next.phase else { throw CrackRunTestError.notCracking }
        #expect(next.currentOrLastCrack == crack)
    }

    @Test func aTracedCrackLosesTheRun() throws {
        var loud = content
        loud.alarm.hold = loud.alarm.max
        let engine = CrackRunEngine(content: loud)
        let (after, events) = engine.apply(.crack(.hold), to: engine.start(seed: 2).0)
        #expect(after.phase == .lost)
        #expect(events.last == .lost(round: 0))
    }

    @Test func crackingTheLastServerWinsTheRun() throws {
        var short = content
        short.run.servers = [short.run.servers[0]]
        let engine = CrackRunEngine(content: short)
        let (after, events) = Self.finishCrack(engine, engine.start(seed: 2).0)
        #expect(after.phase == .won)
        #expect(events.last == .won(servers: 1))
    }
}

enum CrackRunTestError: Error {
    case notCracking
    case noReward
}
