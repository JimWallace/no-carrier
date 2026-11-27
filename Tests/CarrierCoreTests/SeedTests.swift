import CarrierCore
import Testing

@Suite struct SeedTests {
    /// Pinned: a change here moves every generated machine and replay.
    @Test func deriveIsPinned() {
        #expect(Seed.derive(1994, "filesystem") == Self.pinnedFilesystemSeed)
    }

    static let pinnedFilesystemSeed: UInt64 = 11_792_804_323_544_803_190

    @Test func labelsAndParentsGiveDifferentChildren() {
        let parent: UInt64 = 1994
        #expect(Seed.derive(parent, "node/1") != Seed.derive(parent, "node/2"))
        #expect(Seed.derive(parent, "node/1") != Seed.derive(parent + 1, "node/1"))
        #expect(Seed.derive(parent, "node/1") == Seed.derive(parent, "node/1"))
    }

    @Test(arguments: [UInt64(0), 7, 1994, UInt64.max])
    func displayRoundTrips(seed: UInt64) {
        let text = Seed.display(seed)
        #expect(text.count == 18)
        #expect(Seed.parse(text) == seed)
    }

    @Test func parseReadsDecimalAndHex() {
        #expect(Seed.parse("1994") == 1994)
        #expect(Seed.parse("0x7CA") == 1994)
        #expect(Seed.parse(" 0X7ca ") == 1994)
        #expect(Seed.parse("banana") == nil)
    }
}
