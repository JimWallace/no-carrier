/// Everything that happens in a crack, in order. A frontend renders these;
/// it never reads a change from the state that no event announced.
public enum CrackEvent: Codable, Sendable, Equatable {
    case started(server: String, codeLength: Int, symbols: [String])
    case turnStarted(turn: Int, energy: Int)
    case drew(symbols: [String])
    case reshuffled(count: Int)
    /// `slot` counts from 0; `replaced` is the symbol that went to discard.
    case placed(symbol: String, slot: Int, replaced: String?)
    case swapped(Int, Int)
    case turned(slot: Int, from: String, to: String)
    /// A probe showed the code's symbol in `slot`.
    case probed(slot: Int, symbol: String)
    case dropped(card: String)
    /// The server swapped two of the player's slots.
    case scrambled(Int, Int)
    /// The server moved its code one slot to the right.
    case rotated
    case guessed(CrackGuess, alarm: Int)
    case ended(CrackOutcome)
    case rejected(CrackRejectReason)

    /// One log line, in the terminal voice.
    public var line: String {
        switch self {
        case .started(let server, let length, let symbols):
            return "\(server): \(length) SLOTS, SYMBOLS \(symbols.joined(separator: " "))"
        case .turnStarted(let turn, let energy):
            return "-- TURN \(turn): ENERGY \(energy)"
        case .drew(let symbols):
            return "DRAW " + symbols.joined(separator: " ")
        case .reshuffled(let count):
            return "RESHUFFLE \(count) CARDS"
        case .placed(let symbol, let slot, let replaced):
            let over = replaced.map { " OVER \($0)" } ?? ""
            return "\(symbol) TO SLOT \(slot + 1)\(over)"
        case .swapped(let first, let second):
            return "SWAP SLOTS \(first + 1) AND \(second + 1)"
        case .turned(let slot, let from, let to):
            return "DIAL \(slot + 1): \(from) TO \(to)"
        case .probed(let slot, let symbol):
            return "PROBE: SLOT \(slot + 1) IS \(symbol)"
        case .dropped(let card):
            return "DROP \(card)"
        case .guessed(let guess, let alarm):
            let text = guess.symbols.map { $0 ?? "." }.joined(separator: " ")
            return "GUESS \(text): \(guess.feedback.text). ALARM \(alarm)"
        case .scrambled(let first, let second):
            return "SERVER SCRAMBLES SLOTS \(first + 1) AND \(second + 1)"
        case .rotated:
            return "SERVER ROTATES ITS CODE ONE SLOT RIGHT"
        case .ended(.cracked):
            return "ACCESS GRANTED"
        case .ended(.traced):
            return "ALARM FULL. LINE TRACED."
        case .ended(.loggedOut):
            return "LOGGED OUT"
        case .rejected(let reason):
            return "?" + reason.label
        }
    }
}
