import CarrierCore
import Testing

/// Mastermind scoring (addendum 03): hits are right symbol, right slot;
/// near is right symbol, wrong slot; each code symbol counts once.
@Suite struct CrackFeedbackTests {
    @Test func anExactGuessIsAllHits() {
        #expect(
            CrackFeedback.score(guess: ["A", "K", "R", "Z"], code: ["A", "K", "R", "Z"]) == .init(hits: 4, near: 0))
    }

    @Test func theRightSymbolsInTheWrongSlotsAreNear() {
        #expect(
            CrackFeedback.score(guess: ["K", "A", "Z", "R"], code: ["A", "K", "R", "Z"]) == .init(hits: 0, near: 4))
    }

    @Test func aSymbolNotInTheCodeScoresNothing() {
        #expect(
            CrackFeedback.score(guess: ["X", "X", "E", "E"], code: ["A", "K", "R", "Z"]) == .init(hits: 0, near: 0))
    }

    @Test func aRepeatedGuessSymbolCountsOnlyAsOftenAsTheCodeHasIt() {
        #expect(
            CrackFeedback.score(guess: ["A", "A", "A", "A"], code: ["A", "K", "R", "A"]) == .init(hits: 2, near: 0))
        #expect(
            CrackFeedback.score(guess: ["K", "A", "A", "X"], code: ["A", "K", "R", "Z"]) == .init(hits: 0, near: 2))
    }

    @Test func aHitIsNotAlsoCountedNear() {
        #expect(
            CrackFeedback.score(guess: ["A", "K", "E", "K"], code: ["R", "K", "R", "A"]) == .init(hits: 1, near: 1))
    }

    @Test func anEmptySlotMatchesNothing() {
        #expect(
            CrackFeedback.score(guess: ["A", nil, nil, "R"], code: ["A", "K", "R", "Z"]) == .init(hits: 1, near: 1))
    }
}
