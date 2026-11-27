/// Hierarchical seeds (run → network → node → filesystem).
///
/// A child seed is derived from its parent and a label, so each piece of the
/// world can be generated lazily and on its own: generating node 4 never
/// depends on whether node 3 was generated first.
public enum Seed {
    /// The child of `parent` named `label`. The label is hashed with 64-bit
    /// FNV-1a over its UTF-8 bytes, which is the same on every platform and
    /// every run (unlike `hashValue`), then mixed with the parent.
    public static func derive(_ parent: UInt64, _ label: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in label.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x0000_0100_0000_01B3
        }
        return SplitMix64.mix(parent ^ SplitMix64.mix(hash))
    }

    /// The seed as players see and type it: `0x` and 16 upper-case hex
    /// digits. The prefix keeps an all-digit hex seed from reading as decimal.
    public static func display(_ seed: UInt64) -> String {
        let digits = String(seed, radix: 16, uppercase: true)
        return "0x" + String(repeating: "0", count: max(0, 16 - digits.count)) + digits
    }

    /// Parses a seed typed as hex with `0x`, or as decimal.
    public static func parse(_ text: String) -> UInt64? {
        let lower = text.trimmingSpaces().lowercased()
        if lower.hasPrefix("0x") {
            return UInt64(lower.dropFirst(2), radix: 16)
        }
        return UInt64(lower)
    }
}

extension String {
    func trimmingSpaces() -> String {
        var view = Substring(self)
        while view.first == " " { view = view.dropFirst() }
        while view.last == " " { view = view.dropLast() }
        return String(view)
    }
}
