/// A crack run in progress: the deck carried between cracks and where the
/// run stands.
public struct CrackRunState: Codable, Sendable, Equatable {
    public let seed: UInt64
    /// Card ids, in the order they were added.
    public internal(set) var deck: [String]
    /// Which server of the run, from 0.
    public internal(set) var round: Int
    public internal(set) var phase: CrackRunPhase
    /// The last crack that ended, so a frontend can show its board and its
    /// code over the reward or the end of the run.
    public internal(set) var lastCrack: CrackState?

    /// The crack under way, or else the last one that ended.
    public var currentOrLastCrack: CrackState? {
        if case .cracking(let crack) = phase { return crack }
        return lastCrack
    }

    public var isOver: Bool {
        switch phase {
        case .won, .lost: true
        case .cracking, .reward: false
        }
    }
}

/// Where a run stands.
public enum CrackRunPhase: Codable, Sendable, Equatable {
    case cracking(CrackState)
    /// Between cracks: the cards on offer and the server that comes next.
    case reward(cards: [String], next: String)
    case won
    case lost
}
