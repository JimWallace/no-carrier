/// One kind of server: the shape of its lock, how it answers a guess, and
/// what it does back (addendum 03, §6).
public struct CrackServer: Codable, Sendable, Equatable {
    public var id: String
    /// What the screen calls it.
    public var name: String
    /// The symbols its code uses: some or all of the content's symbols.
    public var symbols: [String]
    /// How many slots the code, and the board, has.
    public var codeLength: Int
    /// The most times one symbol may appear in its code.
    public var maxRepeats: Int
    /// What the first guess adds to the alarm.
    public var alarmPerGuess: Int
    /// Added to the alarm cost of each guess after the first: with 5, the
    /// second guess costs 5 more than the first, the third 10 more.
    public var escalation: Int
    public var feedback: CrackFeedbackStyle
    /// What it does to the player, and how often.
    public var interference: [CrackInterference]
}

/// How a server answers a guess.
public enum CrackFeedbackStyle: String, Codable, Sendable, Equatable {
    /// HIT and NEAR counts (Mastermind).
    case counts
    /// The HIT count only.
    case hits
    /// A mark under each slot: hit, near or miss (Wordle).
    case slots
}

/// A server program that acts at the end of every `every`th turn, after the
/// guess. The screen says when each acts next.
public struct CrackInterference: Codable, Sendable, Equatable {
    public var kind: CrackInterferenceKind
    public var every: Int

    public init(kind: CrackInterferenceKind, every: Int) {
        self.kind = kind
        self.every = every
    }
}

public enum CrackInterferenceKind: String, Codable, Sendable, Equatable {
    /// Two slots of the player's board trade places.
    case scramble
    /// The code moves one slot to the right; the last slot wraps to the
    /// first. What probes revealed moves with it.
    case rotate

    /// What the player reads.
    public var label: String {
        switch self {
        case .scramble: "SCRAMBLE"
        case .rotate: "ROTATE"
        }
    }
}
