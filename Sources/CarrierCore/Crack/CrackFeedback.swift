/// Mastermind feedback for one guess: how many slots hold the right symbol
/// (`hits`), and how many more symbols are in the code but in another slot
/// (`near`). It says which counts, never which slots.
public struct CrackFeedback: Codable, Sendable, Equatable {
    public let hits: Int
    public let near: Int

    public init(hits: Int, near: Int) {
        self.hits = hits
        self.near = near
    }

    /// Scores `guess` against `code`. An empty slot (nil) matches nothing.
    /// Each code symbol is matched at most once: a symbol that appears twice
    /// in the guess and once in the code counts once.
    public static func score(guess: [String?], code: [String]) -> Self {
        var hits = 0
        for (slot, symbol) in code.enumerated() where slot < guess.count && guess[slot] == symbol {
            hits += 1
        }
        // Distinct code symbols, in code order, so nothing depends on a
        // dictionary's iteration order.
        var distinct: [String] = []
        for symbol in code where !distinct.contains(symbol) {
            distinct.append(symbol)
        }
        var common = 0
        for symbol in distinct {
            let inCode = code.count { $0 == symbol }
            let inGuess = guess.count { $0 == symbol }
            common += min(inCode, inGuess)
        }
        return Self(hits: hits, near: common - hits)
    }
}
