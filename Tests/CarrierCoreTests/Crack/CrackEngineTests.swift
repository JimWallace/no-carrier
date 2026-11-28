import CarrierCore
import TestSupport
import Testing

/// The crack prototype's rules (addendum 03), one test each.
@Suite struct CrackEngineTests {
    let content: CrackContent

    /// The bundled crack with only plain symbol cards in the deck, so a
    /// test can play the first card in hand onto the board.
    init() throws {
        var crack = try #require(try BundledContent.load().crack)
        crack.starterDeck = crack.starterDeck.filter { crack.card($0)?.kind == .symbol }
        content = crack
    }

    @Test func theFirstTurnDrawsAFullHandAndFullEnergy() {
        let (state, _) = CrackEngine(content: content).start(seed: 1)
        #expect(state.turn == 1)
        #expect(state.hand.count == content.handSize)
        #expect(state.energy == content.energy)
        #expect(state.board == Array(repeating: nil, count: content.codeLength))
    }

    @Test(arguments: 0..<50 as Range<UInt64>)
    func theCodeHasTheRightLengthAndRespectsMaxRepeats(seed: UInt64) {
        let (state, _) = CrackEngine(content: content).start(seed: seed)
        #expect(state.code.count == content.codeLength)
        for symbol in state.code {
            #expect(content.symbols.contains(symbol))
            #expect(state.code.count { $0 == symbol } <= content.maxRepeats)
        }
    }

    @Test func theSameSeedGivesTheSameCodeAndHand() {
        let engine = CrackEngine(content: content)
        #expect(engine.start(seed: 7).0 == engine.start(seed: 7).0)
    }

    @Test func placingACardCostsEnergyAndSendsTheCardInTheSlotToDiscard() {
        let engine = CrackEngine(content: content)
        var (state, _) = engine.start(seed: 3)
        let first = state.hand[0]
        let second = state.hand[1]
        state = engine.apply(.play(handIndex: 0, slot: 2), to: state).0
        #expect(state.board[2]?.card == first)
        #expect(state.energy == content.energy - content.costs.place)
        state = engine.apply(.play(handIndex: 0, slot: 2), to: state).0
        #expect(state.board[2]?.card == second)
        #expect(state.discardPile == [first])
    }

    @Test func swappingTradesTwoSlots() throws {
        let engine = CrackEngine(content: content)
        var (state, _) = engine.start(seed: 3)
        let card = state.hand[0]
        state = engine.apply(.play(handIndex: 0, slot: 0), to: state).0
        state = engine.apply(.swap(0, 3), to: state).0
        #expect(state.board[0] == nil)
        #expect(state.board[3]?.card == card)
    }

    @Test func droppingMovesACardFromTheHandToDiscard() {
        let engine = CrackEngine(content: content)
        var (state, _) = engine.start(seed: 3)
        let card = state.hand[1]
        state = engine.apply(.drop(handIndex: 1), to: state).0
        #expect(!state.hand.contains(card))
        #expect(state.discardPile == [card])
    }

    @Test func anActionWithoutEnoughEnergyIsRefusedAndChangesNothing() {
        let engine = CrackEngine(content: content)
        var (state, _) = engine.start(seed: 3)
        for slot in 0..<content.energy {
            state = engine.apply(.play(handIndex: 0, slot: slot), to: state).0
        }
        let (after, events) = engine.apply(.play(handIndex: 0, slot: 3), to: state)
        #expect(events == [.rejected(.noEnergy)])
        #expect(after == state)
    }

    @Test func aGuessRaisesTheAlarmKeepsTheBoardAndRefillsTheHand() {
        let engine = CrackEngine(content: content)
        var (state, _) = engine.start(seed: 3)
        state = engine.apply(.play(handIndex: 0, slot: 0), to: state).0
        let board = state.board
        state = engine.apply(.guess, to: state).0
        #expect(state.alarm == content.alarm.perGuess)
        #expect(state.board == board)
        #expect(state.hand.count == content.handSize)
        #expect(state.energy == content.energy)
        #expect(state.turn == 2)
        #expect(state.guesses.count == 1)
    }

    @Test func theUnplayedHandIsKeptBetweenTurns() {
        let engine = CrackEngine(content: content)
        var (state, _) = engine.start(seed: 3)
        let kept = Array(state.hand.dropFirst())
        state = engine.apply(.play(handIndex: 0, slot: 0), to: state).0
        state = engine.apply(.guess, to: state).0
        #expect(Array(state.hand.prefix(kept.count)) == kept)
    }

    @Test func allHitsCracksTheCode() throws {
        var rich = content
        rich.energy = rich.codeLength
        rich.handSize = rich.starterDeck.count
        let engine = CrackEngine(content: rich)
        var (state, _) = engine.start(seed: 11)
        for (slot, symbol) in state.code.enumerated() {
            let index = try #require(state.hand.firstIndex { engine.label($0) == symbol })
            state = engine.apply(.play(handIndex: index, slot: slot), to: state).0
        }
        let (after, events) = engine.apply(.guess, to: state)
        #expect(after.outcome == .cracked)
        #expect(events.last == .ended(.cracked))
    }

    @Test func aFullAlarmTracesTheLine() {
        var loud = content
        loud.alarm.perGuess = loud.alarm.max
        let engine = CrackEngine(content: loud)
        let (state, _) = engine.start(seed: 11)
        let (after, events) = engine.apply(.guess, to: state)
        #expect(after.outcome == .traced)
        #expect(events.last == .ended(.traced))
        #expect(engine.apply(.guess, to: after).1 == [.rejected(.over)])
    }

    @Test func anEmptyDrawPileTakesTheDiscardPileBack() {
        let engine = CrackEngine(content: content)
        var (state, _) = engine.start(seed: 5)
        var reshuffled = false
        for _ in 0..<6 where !state.isOver {
            for _ in 0..<content.energy where !state.hand.isEmpty {
                state = engine.apply(.drop(handIndex: 0), to: state).0
            }
            let result = engine.apply(.guess, to: state)
            state = result.0
            reshuffled = reshuffled || result.1.contains { if case .reshuffled = $0 { true } else { false } }
        }
        #expect(reshuffled)
    }
}
