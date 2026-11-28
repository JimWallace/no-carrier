/// One submitted guess and what the server said about it.
public struct CrackGuess: Codable, Sendable, Equatable {
    /// The board's symbols at the time, nil for an empty slot.
    public let symbols: [String?]
    public let feedback: CrackFeedback

    public init(symbols: [String?], feedback: CrackFeedback) {
        self.symbols = symbols
        self.feedback = feedback
    }
}
