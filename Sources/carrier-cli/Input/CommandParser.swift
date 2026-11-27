/// Reads the fight prompt (kickoff §7: "your hand is your command
/// vocabulary"). A card plays by its number or its name, case-insensitive;
/// a unique prefix is enough. Only cards in hand can be typed.
struct CommandParser {
    static let commands = ["END", "LOGOUT", "HELP", "QUIT"]

    /// The names of the cards in hand, in hand order.
    let handNames: [String]
    /// Every card name in the content, to tell "not in hand" from nonsense.
    let allCardNames: Set<String>

    func parse(_ text: String) -> ParsedCommand {
        let input = text.uppercased().split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        if input.isEmpty { return .empty }
        if let number = Int(input) {
            // Only 0 to 99 is a card number; anything else (a huge or
            // negative number) is nonsense, not an overflow.
            guard (0...99).contains(number) else { return .unknown(input) }
            return .play(handIndex: number == 0 ? 9 : number - 1)
        }
        if input == "?" { return .help }
        if let command = command(input) { return command }
        if let index = handNames.firstIndex(of: input) {
            return .play(handIndex: index)
        }
        let matches = candidates(for: input)
        if matches.count == 1, let match = matches.first {
            return command(match) ?? handNames.firstIndex(of: match).map { .play(handIndex: $0) } ?? .unknown(input)
        }
        if allCardNames.contains(input) { return .notInHand(input) }
        return .unknown(input)
    }

    /// Every hand card name and command that starts with `prefix`, in hand
    /// order then command order, without repeats.
    func candidates(for prefix: String) -> [String] {
        let upper = prefix.uppercased()
        var seen: Set<String> = []
        var result: [String] = []
        for name in handNames + Self.commands where name.hasPrefix(upper) && !seen.contains(name) {
            seen.insert(name)
            result.append(name)
        }
        return result
    }

    /// Tab completion: the single match, or the longest prefix all matches
    /// share. The second value lists the matches when there are several.
    func complete(_ prefix: String) -> (text: String, matches: [String]) {
        let matches = candidates(for: prefix)
        guard let first = matches.first else { return (prefix.uppercased(), []) }
        if matches.count == 1 { return (first, matches) }
        var common = first
        for match in matches.dropFirst() {
            while !match.hasPrefix(common) { common.removeLast() }
        }
        return (common.count >= prefix.count ? common : prefix.uppercased(), matches)
    }

    private func command(_ input: String) -> ParsedCommand? {
        switch input {
        case "END": .endTurn
        case "LOGOUT": .logout
        case "HELP": .help
        case "QUIT", "EXIT": .quit
        default: nil
        }
    }
}
