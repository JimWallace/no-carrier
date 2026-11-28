/// The words both frontends use for the crack, so the terminal and Godot
/// say the same thing (CLAUDE.md, "Architecture").
extension CrackServer {
    /// The server in one line, for choosing a reward: `5 SLOTS, 6 SYMBOLS,
    /// HIT AND NEAR COUNTS, SCRAMBLE EVERY 2.`
    public var profile: String {
        var parts = ["\(codeLength) SLOTS", "\(symbols.count) SYMBOLS", feedback.name]
        parts += interference.map { "\($0.kind.label) EVERY \($0.every)" }
        if escalation > 0 { parts.append("ALARM RISES EACH GUESS") }
        return parts.joined(separator: ", ") + "."
    }
}

extension CrackFeedbackStyle {
    /// What the style is called.
    public var name: String {
        switch self {
        case .counts: "HIT AND NEAR COUNTS"
        case .hits: "HITS ONLY"
        case .slots: "A MARK PER SLOT"
        }
    }

    /// How to read it, in a line.
    public var legend: String {
        switch self {
        case .counts: "HIT: RIGHT SYMBOL, RIGHT SLOT. NEAR: RIGHT SYMBOL, WRONG SLOT."
        case .hits: "THIS SERVER COUNTS HITS ONLY: RIGHT SYMBOL, RIGHT SLOT."
        case .slots: "A MARK PER SLOT. H: RIGHT SYMBOL. N: IN THE CODE, ANOTHER SLOT. -: NOT THERE."
        }
    }
}

extension CrackMark {
    /// The mark as a word: HIT, NEAR, MISS.
    public var label: String {
        switch self {
        case .hit: "HIT"
        case .near: "NEAR"
        case .miss: "MISS"
        }
    }
}

extension CrackCardKind {
    /// How a card of this kind is played, for its face.
    public var playLabel: String {
        switch self {
        case .symbol: "SYMBOL"
        case .dial: "DIAL"
        default: needsSlot ? "ON A SLOT" : "ON ITS OWN"
        }
    }
}
