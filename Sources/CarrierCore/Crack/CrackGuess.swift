/// One submitted guess and what the server said about it.
public struct CrackGuess: Codable, Sendable, Equatable {
    /// The board's symbols at the time, nil for an empty slot.
    public let symbols: [String?]
    public let feedback: CrackFeedback
    /// The style it was answered in: the server's, or `slots` after DEBUG.
    public let style: CrackFeedbackStyle

    public init(symbols: [String?], feedback: CrackFeedback, style: CrackFeedbackStyle) {
        self.symbols = symbols
        self.feedback = feedback
        self.style = style
    }
}
