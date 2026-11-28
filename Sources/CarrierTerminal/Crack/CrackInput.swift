package import CarrierCore

/// A line typed at the crack prompt. Numbers count from 1 on screen and
/// from 0 in the action.
package enum CrackInput: Equatable {
    case action(CrackAction)
    /// TAKE, REMOVE or SKIP at a reward.
    case reward(CrackRunAction)
    case info
    case deck
    case help
    case quit
    case empty
    case unknown(String)

    /// `P 1 3`, `PLACE 1 3`, `1 3` or `13`: hand card 1 used on slot 3.
    /// `T 2 K` or `TURN 2 K`: the dial in slot 2 turned to K.
    /// `1`: hand card 1 played on its own (DEBUG, SPOOF, SHIFT, OVERCLOCK).
    /// `H` or `HOLD`; `INFO`; `DECK`; at a reward, `TAKE 1`, `REMOVE 5`,
    /// `SKIP`.
    /// `S 1 2` or `SWAP 1 2`; `D 1` or `DROP 1`; `G` or `GUESS`; `LOGOUT`;
    /// `HELP` or `?`; `QUIT`.
    package static func parse(_ text: String) -> Self {
        let words = text.uppercased().split(separator: " ").map(String.init)
        guard let first = words.first else { return .empty }
        let numbers = words.dropFirst().compactMap { Int($0) }
        let rest = words.count - 1
        // A `where` clause binds only to the pattern beside it, so each
        // command checks its own word count.
        switch (first, rest, numbers.count) {
        case ("G", 0, _), ("GUESS", 0, _):
            return .action(.guess)
        case ("H", 0, _), ("HOLD", 0, _):
            return .action(.hold)
        case ("INFO", 0, _):
            return .info
        case ("DECK", 0, _):
            return .deck
        case ("TAKE", 1, 1):
            return .reward(.take(numbers[0] - 1))
        case ("REMOVE", 1, 1):
            return .reward(.remove(numbers[0] - 1))
        case ("SKIP", 0, _):
            return .reward(.skip)
        case ("LOGOUT", 0, _):
            return .action(.logout)
        case ("HELP", _, _), ("?", _, _):
            return .help
        case ("QUIT", _, _), ("EXIT", _, _):
            return .quit
        case ("P", 2, 2), ("PLACE", 2, 2):
            return .action(.play(handIndex: numbers[0] - 1, slot: numbers[1] - 1))
        case ("T", 2, 1), ("TURN", 2, 1):
            guard let slot = Int(words[1]) else { break }
            return .action(.turn(slot: slot - 1, symbol: words[2]))
        case ("S", 2, 2), ("SWAP", 2, 2):
            return .action(.swap(numbers[0] - 1, numbers[1] - 1))
        case ("D", 1, 1), ("DROP", 1, 1):
            return .action(.drop(handIndex: numbers[0] - 1))
        default:
            break
        }
        if words.count == 1, first.count == 1, let card = Int(first) {
            return .action(.use(handIndex: card - 1))
        }
        if words.count == 2, let card = Int(words[0]), let slot = Int(words[1]) {
            return .action(.play(handIndex: card - 1, slot: slot - 1))
        }
        if words.count == 1, first.count == 2, let card = Int(String(first.prefix(1))),
            let slot = Int(String(first.suffix(1)))
        {
            return .action(.play(handIndex: card - 1, slot: slot - 1))
        }
        return .unknown(text.uppercased())
    }
}
