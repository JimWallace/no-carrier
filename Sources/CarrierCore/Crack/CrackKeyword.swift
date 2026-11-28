/// A game word that card text shows in bold, with a short explanation a
/// frontend shows on demand: on hover in Godot, with `? WORD` in the
/// terminal (`crack.json`, `keywords`).
public struct CrackKeyword: Codable, Sendable, Equatable {
    /// Upper case, as card text writes it.
    public let word: String
    /// Ten words or fewer, like card text.
    public let text: String

    public init(word: String, text: String) {
        self.word = word
        self.text = text
    }
}

/// One piece of card text: plain words, or a keyword to show in bold.
public enum CrackTextSpan: Sendable, Equatable {
    case plain(String)
    /// `word` is the keyword; `shown` is how the text writes it (`SLOT'S`).
    case keyword(word: String, shown: String)

    public var shown: String {
        switch self {
        case .plain(let text): text
        case .keyword(_, let shown): shown
        }
    }
}
