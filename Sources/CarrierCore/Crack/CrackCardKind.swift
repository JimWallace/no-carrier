/// What a crack card does when it is played.
public enum CrackCardKind: String, Codable, Sendable, Equatable, CaseIterable {
    /// Sits on the slot and shows its symbol.
    case symbol
    /// Sits on the slot like a symbol card, and can be turned to another
    /// symbol where it stands.
    case dial
    /// Reveals the slot's symbol in the code.
    case probe
    /// Says whether the symbol on a board slot is anywhere in the code.
    case sniff
    /// Says how many times the symbol on a board slot is in the code.
    case count
    /// Pins a board slot: SCRAMBLE leaves it alone until its card is
    /// replaced.
    case lock
    /// The next guess is answered with a mark per slot, whatever the
    /// server's style, and costs `amount` more alarm.
    case debug
    /// The next guess costs `amount` percent of its alarm.
    case spoof
    /// Every card on the board moves one slot right; the last wraps to the
    /// first.
    case shift
    /// `amount` more energy now, `penalty` less next turn.
    case overclock

    /// Whether the card is played on a slot (`1 3`) or on its own (`1`).
    public var needsSlot: Bool {
        switch self {
        case .symbol, .dial, .probe, .sniff, .count, .lock: true
        case .debug, .spoof, .shift, .overclock: false
        }
    }

    /// Whether the card stays on the board when played.
    public var staysOnBoard: Bool {
        self == .symbol || self == .dial
    }
}
