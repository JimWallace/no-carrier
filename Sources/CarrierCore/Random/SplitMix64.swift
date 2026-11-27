/// SplitMix64 (Steele, Lea and Flood, 2014). Used only to expand one 64-bit
/// seed into the 256-bit state of `Xoshiro256StarStar`, and as the mixing
/// step of `Seed.derive`.
public struct SplitMix64: Sendable, Equatable {
    public private(set) var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        return Self.mix(state)
    }

    /// The SplitMix64 output function: a bijective avalanche of one word.
    public static func mix(_ value: UInt64) -> UInt64 {
        var z = value
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
