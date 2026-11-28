/// What a line typed at the map prompt means.
enum MapCommand: Equatable {
    case attack(node: Int)
    case reinforce(node: Int)
    case wait
    case scan(node: Int)
    case info(node: Int)
    case jackOut
    case deck
    case help
    case quit
    case empty
    case unknown(String)

    static let words = ["ATTACK", "REINFORCE", "WAIT", "SCAN", "INFO", "JACK", "DECK", "HELP", "QUIT"]

    /// Reads `ATTACK 4`, `A 4`, a bare `4`, `REINFORCE 2`, `R 2`, `WAIT`,
    /// `SCAN 4`, `INFO 4`, `JACK OUT`, `DECK`, `HELP` or `?`, and `QUIT`.
    /// A unique prefix of a word is enough; `JACK OUT` is spelled out, so it
    /// cannot end a contract by accident.
    static func parse(_ text: String) -> Self {
        let words = text.uppercased().split(separator: " ").map(String.init)
        guard let first = words.first else { return .empty }
        if words.count == 1, let node = Int(first) {
            return (0...9).contains(node) ? .attack(node: node) : .unknown(first)
        }
        if first == "?" { return .help }
        let matches = Self.words.filter { $0.hasPrefix(first) }
        guard matches.count == 1, let word = matches.first else { return .unknown(words.joined(separator: " ")) }
        let node = words.count == 2 ? Int(words[1]).flatMap { (0...9).contains($0) ? $0 : nil } : nil
        switch (word, node, words.count) {
        case ("ATTACK", let node?, _): return .attack(node: node)
        case ("REINFORCE", let node?, _): return .reinforce(node: node)
        case ("SCAN", let node?, _): return .scan(node: node)
        case ("INFO", let node?, _): return .info(node: node)
        case ("JACK", _, 2) where first == "JACK" && words[1] == "OUT": return .jackOut
        case ("WAIT", _, 1): return .wait
        case ("DECK", _, 1): return .deck
        case ("HELP", _, 1): return .help
        case ("QUIT", _, 1): return .quit
        default: return .unknown(words.joined(separator: " "))
        }
    }

    /// Tab completion over the first word.
    static func complete(_ prefix: String) -> (text: String, matches: [String]) {
        let upper = prefix.uppercased()
        guard !upper.contains(" ") else { return (upper, []) }
        let matches = words.filter { $0.hasPrefix(upper) }
        if matches.count == 1, let match = matches.first { return (match + " ", matches) }
        return (upper, matches)
    }
}
