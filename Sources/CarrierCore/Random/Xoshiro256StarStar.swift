/// The game's only source of randomness: xoshiro256** (Blackman and Vigna,
/// 2018), with its state stored in the game state so that a seed and an
/// action log replay a game exactly.
///
/// It deliberately does not conform to `RandomNumberGenerator`. The standard
/// library's `random(in:using:)` and `shuffled(using:)` do not promise a fixed
/// algorithm across Swift releases, and a replay must not depend on one. The
/// bounded draws and the shuffle below are written out here instead.
public struct Xoshiro256StarStar: Codable, Sendable, Equatable {
    public private(set) var s0: UInt64
    public private(set) var s1: UInt64
    public private(set) var s2: UInt64
    public private(set) var s3: UInt64

    /// Expands a 64-bit seed with SplitMix64, as the reference code advises.
    public init(seed: UInt64) {
        var expander = SplitMix64(seed: seed)
        s0 = expander.next()
        s1 = expander.next()
        s2 = expander.next()
        s3 = expander.next()
    }

    public mutating func next() -> UInt64 {
        let result = rotl(s1 &* 5, 7) &* 9
        let t = s1 << 17
        s2 ^= s0
        s3 ^= s1
        s1 ^= s2
        s0 ^= s3
        s2 ^= t
        s3 = rotl(s3, 45)
        return result
    }

    /// A uniform integer in `0..<bound` (Lemire's method, with rejection, so
    /// there is no modulo bias). `bound` must be positive; a bound of zero or
    /// less returns 0 and draws nothing.
    public mutating func nextInt(below bound: Int) -> Int {
        guard bound > 1 else { return 0 }
        let range = UInt64(bound)
        var product = next().multipliedFullWidth(by: range)
        if product.low < range {
            let threshold = (0 &- range) % range
            while product.low < threshold {
                product = next().multipliedFullWidth(by: range)
            }
        }
        return Int(product.high)
    }

    /// A uniform integer in `range`, both ends included.
    public mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + nextInt(below: range.upperBound - range.lowerBound + 1)
    }

    /// One element of `items`, or nil when it is empty (and then nothing is
    /// drawn).
    public mutating func pick<T>(_ items: [T]) -> T? {
        guard !items.isEmpty else { return nil }
        return items[nextInt(below: items.count)]
    }

    /// Fisher-Yates, from the last index down.
    public mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for index in stride(from: items.count - 1, to: 0, by: -1) {
            let other = nextInt(below: index + 1)
            items.swapAt(index, other)
        }
    }

    private func rotl(_ value: UInt64, _ amount: UInt64) -> UInt64 {
        (value << amount) | (value >> (64 - amount))
    }
}
