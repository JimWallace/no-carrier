package import CarrierCore

/// A line typed at the crack prompt. Numbers count from 1 on screen and
/// from 0 in the action.
package enum CrackInput: Equatable {
    case action(CrackAction)
    case help
    case quit
    case empty
    case unknown(String)

    /// `P 1 3`, `PLACE 1 3`, `1 3` or `13`: hand card 1 to slot 3.
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
        case ("LOGOUT", 0, _):
            return .action(.logout)
        case ("HELP", _, _), ("?", _, _):
            return .help
        case ("QUIT", _, _), ("EXIT", _, _):
            return .quit
        case ("P", 2, 2), ("PLACE", 2, 2):
            return .action(.place(handIndex: numbers[0] - 1, slot: numbers[1] - 1))
        case ("S", 2, 2), ("SWAP", 2, 2):
            return .action(.swap(numbers[0] - 1, numbers[1] - 1))
        case ("D", 1, 1), ("DROP", 1, 1):
            return .action(.drop(handIndex: numbers[0] - 1))
        default:
            break
        }
        if words.count == 2, let card = Int(words[0]), let slot = Int(words[1]) {
            return .action(.place(handIndex: card - 1, slot: slot - 1))
        }
        if words.count == 1, first.count == 2, let card = Int(String(first.prefix(1))),
            let slot = Int(String(first.suffix(1)))
        {
            return .action(.place(handIndex: card - 1, slot: slot - 1))
        }
        return .unknown(text.uppercased())
    }
}
