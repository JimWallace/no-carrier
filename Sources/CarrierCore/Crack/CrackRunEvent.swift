/// Everything that happens in a run, in order.
public enum CrackRunEvent: Codable, Sendable, Equatable {
    case crack(CrackEvent)
    case rewardOffered(cards: [String], next: String)
    case took(String)
    case removed(String)
    case skipped
    case won(servers: Int)
    case lost(round: Int)
    case rejected(CrackRunRejectReason)

    /// One log line. `label` names a card id as the player sees it.
    public func line(label: (String) -> String) -> String {
        switch self {
        case .crack(let event): event.line
        case .rewardOffered(let cards, let next):
            "REWARD: " + cards.map(label).joined(separator: ", ") + ". NEXT: \(next.uppercased())"
        case .took(let card): "TOOK \(label(card))"
        case .removed(let card): "REMOVED \(label(card))"
        case .skipped: "SKIPPED THE REWARD"
        case .won(let servers): "RUN COMPLETE: \(servers) SERVERS CRACKED"
        case .lost(let round): "RUN OVER ON SERVER \(round + 1)"
        case .rejected(let reason): "?" + reason.label
        }
    }
}

/// Why the run refused an action.
public enum CrackRunRejectReason: String, Codable, Sendable, Equatable {
    case over
    case notAtAReward
    case notInACrack
    case noSuchChoice
    case deckFull
    case deckTooSmall

    public var label: String {
        switch self {
        case .over: "RUN OVER"
        case .notAtAReward: "NO REWARD NOW"
        case .notInACrack: "NOT IN A CRACK"
        case .noSuchChoice: "NO SUCH CHOICE"
        case .deckFull: "DECK FULL: REMOVE A CARD OR SKIP"
        case .deckTooSmall: "DECK TOO SMALL TO REMOVE MORE"
        }
    }
}
