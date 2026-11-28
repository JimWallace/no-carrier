/// What a server says about one guess. Which fields it fills depends on
/// its style: `counts` gives hits and near, `hits` gives hits only, and
/// `slots` gives a mark per slot (and the counts they add up to).
public struct CrackFeedback: Codable, Sendable, Equatable {
    public let hits: Int
    /// Nil when the style does not tell.
    public let near: Int?
    /// One mark per slot, under the `slots` style only.
    public let marks: [CrackMark]?

    public init(hits: Int, near: Int?, marks: [CrackMark]? = nil) {
        self.hits = hits
        self.near = near
        self.marks = marks
    }

    /// What the player reads: `2 HIT 1 NEAR`, `2 HIT`, or `H N - -`.
    public var text: String {
        if let marks { return marks.map(\.glyph).joined(separator: " ") }
        if let near { return "\(hits) HIT \(near) NEAR" }
        return "\(hits) HIT"
    }

    /// Scores `guess` against `code` in a style. An empty slot (nil)
    /// matches nothing. Each code symbol is matched at most once: a symbol
    /// that appears twice in the guess and once in the code counts once.
    public static func score(guess: [String?], code: [String], style: CrackFeedbackStyle = .counts) -> Self {
        let marks = mark(guess: guess, code: code)
        let hits = marks.count { $0 == .hit }
        let near = marks.count { $0 == .near }
        switch style {
        case .counts: return Self(hits: hits, near: near)
        case .hits: return Self(hits: hits, near: nil)
        case .slots: return Self(hits: hits, near: near, marks: marks)
        }
    }

    /// Hits first; then, left to right, a near for each guess symbol that a
    /// code symbol not yet matched still has. The near count equals the
    /// Mastermind count.
    static func mark(guess: [String?], code: [String]) -> [CrackMark] {
        var marks = Array(repeating: CrackMark.miss, count: guess.count)
        var unmatched: [String] = []
        for (slot, symbol) in code.enumerated() {
            if slot < guess.count && guess[slot] == symbol {
                marks[slot] = .hit
            } else {
                unmatched.append(symbol)
            }
        }
        for (slot, symbol) in guess.enumerated() where marks[slot] != .hit {
            guard let symbol, let index = unmatched.firstIndex(of: symbol) else { continue }
            unmatched.remove(at: index)
            marks[slot] = .near
        }
        return marks
    }
}
