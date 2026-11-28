/// Something a SNIFF or COUNT learned about the code. Both survive a
/// ROTATE: moving the code does not change which symbols it holds.
public enum CrackFact: Codable, Sendable, Equatable {
    /// Whether `symbol` is anywhere in the code.
    case contains(symbol: String, Bool)
    /// How many times `symbol` is in the code.
    case count(symbol: String, Int)

    /// Whether `code` agrees with this fact.
    public func holds(for code: [String]) -> Bool {
        switch self {
        case .contains(let symbol, let isIn): code.contains(symbol) == isIn
        case .count(let symbol, let count): code.count { $0 == symbol } == count
        }
    }

    /// What the player reads.
    public var text: String {
        switch self {
        case .contains(let symbol, let isIn): isIn ? "\(symbol) IS IN THE CODE" : "NO \(symbol) IN THE CODE"
        case .count(let symbol, let count): "\(symbol) IS IN THE CODE \(count)X"
        }
    }
}
