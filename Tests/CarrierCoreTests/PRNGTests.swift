import CarrierCore
import Foundation
import Testing

@Suite struct PRNGTests {
    /// The reference vector from the SplitMix64 reference implementation.
    @Test func splitMixMatchesTheReference() {
        var generator = SplitMix64(seed: 1_234_567)
        #expect(generator.next() == 6_457_827_717_110_365_317)
        #expect(generator.next() == 3_203_168_211_198_807_973)
        #expect(generator.next() == 9_817_491_932_198_370_423)
    }

    /// Pins the first outputs, so any change to the generator (which would
    /// break every recorded replay) fails here first.
    @Test func xoshiroOutputIsPinned() {
        var generator = Xoshiro256StarStar(seed: 1994)
        let outputs = (0..<4).map { _ in generator.next() }
        #expect(outputs == Self.pinnedOutputs)
    }

    static let pinnedOutputs: [UInt64] = [
        10_985_599_389_106_287_629, 8_427_545_374_570_396_621, 3_977_006_415_831_860_346, 17_550_751_545_099_951_058,
    ]

    @Test func sameSeedSameSequence() {
        var first = Xoshiro256StarStar(seed: 42)
        var second = Xoshiro256StarStar(seed: 42)
        for _ in 0..<100 {
            #expect(first.next() == second.next())
        }
    }

    @Test(arguments: [1, 2, 3, 7, 10, 100])
    func boundedDrawsStayInRange(bound: Int) {
        var generator = Xoshiro256StarStar(seed: UInt64(bound))
        var seen = Set<Int>()
        for _ in 0..<2000 {
            let value = generator.nextInt(below: bound)
            #expect((0..<bound).contains(value))
            seen.insert(value)
        }
        #expect(seen.count == bound)
    }

    @Test func inclusiveRangeHitsBothEnds() {
        var generator = Xoshiro256StarStar(seed: 5)
        let values = (0..<500).map { _ in generator.nextInt(in: 10...12) }
        #expect(values.min() == 10)
        #expect(values.max() == 12)
    }

    @Test func emptyChoicesDrawNothing() {
        var generator = Xoshiro256StarStar(seed: 9)
        let before = generator
        #expect(generator.pick([Int]()) == nil)
        #expect(generator.nextInt(below: 1) == 0)
        #expect(generator == before)
    }

    @Test func shuffleIsAPermutation() {
        var generator = Xoshiro256StarStar(seed: 11)
        var items = Array(0..<20)
        generator.shuffle(&items)
        #expect(items.sorted() == Array(0..<20))
        #expect(items != Array(0..<20))
    }

    @Test func stateSurvivesCoding() throws {
        var generator = Xoshiro256StarStar(seed: 77)
        _ = generator.next()
        let data = try JSONEncoder().encode(generator)
        var decoded = try JSONDecoder().decode(Xoshiro256StarStar.self, from: data)
        #expect(decoded.next() == generator.next())
    }
}
